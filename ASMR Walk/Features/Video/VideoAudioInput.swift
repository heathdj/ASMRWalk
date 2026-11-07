import AVFoundation
import Observation

struct VideoAudioInput: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case builtIn = "Built-in"
        case bluetooth = "Bluetooth"
        case usb = "USB"
        case other = "External"
    }

    let id: String
    let name: String
    let kind: Kind

    init(id: String, name: String, portType: AVAudioSession.Port) {
        self.id = id
        switch portType {
        case .builtInMic: kind = .builtIn
        case .bluetoothHFP, .bluetoothLE: kind = .bluetooth
        case .usbAudio: kind = .usb
        default: kind = .other
        }
        self.name = kind == .builtIn ? "iPhone Microphone" : name
    }
}

@MainActor
protocol VideoAudioSessionRouting {
    var availableInputs: [VideoAudioInput] { get }
    var currentInput: VideoAudioInput? { get }
    func activate() throws
    func deactivate() throws
    func setPreferredInput(id: String?) throws
}

@MainActor
struct SystemVideoAudioSession: VideoAudioSessionRouting {
    private let session = AVAudioSession.sharedInstance()

    var availableInputs: [VideoAudioInput] {
        (session.availableInputs ?? []).map(Self.input)
    }

    var currentInput: VideoAudioInput? {
        session.currentRoute.inputs.first.map(Self.input)
    }

    func activate() throws {
        // Manual routing prevents AVCaptureSession from replacing the user's preference.
        // High-quality Bluetooth is optional; HFP remains the supported fallback.
        do {
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.allowBluetoothHFP, .bluetoothHighQualityRecording])
        } catch {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP])
        }
        try session.setActive(true)
    }

    func deactivate() throws {
        try session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func setPreferredInput(id: String?) throws {
        guard let id else {
            try session.setPreferredInput(nil)
            return
        }
        guard let port = session.availableInputs?.first(where: { $0.uid == id }) else {
            throw VideoAudioInputController.RoutingError.unavailable
        }
        try session.setPreferredInput(port)
    }

    private static func input(_ port: AVAudioSessionPortDescription) -> VideoAudioInput {
        VideoAudioInput(id: port.uid, name: port.portName, portType: port.portType)
    }
}

/// UI-owned routing state. AVAudioSession descriptions never cross isolation boundaries.
@MainActor
@Observable
final class VideoAudioInputController {
    enum RoutingError: LocalizedError {
        case unavailable
        case recording
        case inactive
        case routeNotSelected

        var errorDescription: String? {
            switch self {
            case .unavailable: "That microphone is no longer connected."
            case .recording: "Stop recording before changing the microphone."
            case .inactive: "Prepare the camera and microphone before choosing an input."
            case .routeNotSelected: "iOS has not activated the selected microphone. Choose another input or Automatic before recording."
            }
        }
    }

    private(set) var availableInputs: [VideoAudioInput] = []
    private(set) var currentInput: VideoAudioInput?
    private(set) var selectedID: String?
    private(set) var message: String?
    private(set) var isActive = false
    private(set) var isRecording = false
    private let routing: any VideoAudioSessionRouting

    init(routing: (any VideoAudioSessionRouting)? = nil) {
        self.routing = routing ?? SystemVideoAudioSession()
    }

    func activate() throws {
        try routing.activate()
        isActive = true
        try refresh()
        try routing.setPreferredInput(id: selectedID)
        currentInput = routing.currentInput
    }

    func select(id: String?) throws {
        guard isActive else { throw RoutingError.inactive }
        guard isRecording == false else { throw RoutingError.recording }
        guard id == nil || routing.availableInputs.contains(where: { $0.id == id }) else {
            throw RoutingError.unavailable
        }
        do {
            try routing.setPreferredInput(id: id)
            selectedID = id
            message = nil
            try refresh()
        } catch {
            currentInput = routing.currentInput
            message = error.localizedDescription
            throw error
        }
    }

    func refresh() throws {
        guard isActive else { return }
        let previous = currentInput
        // Even a failed fallback request must show the route iOS is actually using.
        defer { currentInput = routing.currentInput }
        availableInputs = routing.availableInputs
        if let selectedID, availableInputs.contains(where: { $0.id == selectedID }) == false {
            // A disconnected peripheral cannot remain a meaningful preference.
            try routing.setPreferredInput(id: nil)
            self.selectedID = nil
            message = "The selected microphone disconnected. Using Automatic."
        }
        currentInput = routing.currentInput
        if isRecording, previous?.id != currentInput?.id {
            message = "The microphone changed during recording. Now using \(currentInput?.name ?? "no available input")."
        }
    }

    func verifyEffectiveInput() throws {
        try refresh()
        guard currentInput != nil else { throw RoutingError.unavailable }
        guard selectedID == nil || currentInput?.id == selectedID else {
            throw RoutingError.routeNotSelected
        }
    }

    func setRecording(_ recording: Bool) {
        isRecording = recording
    }

    func deactivate() throws {
        try routing.deactivate()
    }

    func stop() {
        isActive = false
        currentInput = nil
        availableInputs = []
    }

    var effectiveInputMessage: String {
        if let selectedID, selectedID != currentInput?.id {
            return RoutingError.routeNotSelected.localizedDescription
        }
        return message ?? "Using \(currentInput?.name ?? "no available microphone")."
    }
}

#if DEBUG
/// Deterministic inputs for UI tests; never configures hardware or requests permission.
@MainActor
final class PreviewVideoAudioSession: VideoAudioSessionRouting {
    let availableInputs = [
        VideoAudioInput(id: "builtIn", name: "iPhone", portType: .builtInMic),
        VideoAudioInput(id: "usb", name: "USB Receiver", portType: .usbAudio),
        VideoAudioInput(id: "bluetooth", name: "Bluetooth Microphone", portType: .bluetoothHFP)
    ]
    var currentInput: VideoAudioInput?

    func activate() { currentInput = availableInputs.first }
    func deactivate() {}
    func setPreferredInput(id: String?) {
        currentInput = availableInputs.first { $0.id == id } ?? availableInputs.first
    }
}
#endif
