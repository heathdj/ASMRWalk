import AVFoundation
import Testing
@testable import ASMR_Walk

@MainActor
struct VideoAudioInputTests {
    @Test(arguments: [
        (AVAudioSession.Port.builtInMic, VideoAudioInput.Kind.builtIn),
        (.bluetoothHFP, .bluetooth), (.bluetoothLE, .bluetooth),
        (.usbAudio, .usb), (.headsetMic, .other)
    ])
    func mapsSystemPorts(port: AVAudioSession.Port, kind: VideoAudioInput.Kind) {
        let input = VideoAudioInput(id: "stable", name: "System Name", portType: port)
        #expect(input.id == "stable")
        #expect(input.kind == kind)
        #expect(input.name == (kind == .builtIn ? "iPhone Microphone" : "System Name"))
    }

    @Test func selectionUsesEffectiveRouteAndAutomaticClearsPreference() throws {
        let session = StubVideoAudioSession()
        let controller = VideoAudioInputController(routing: session)
        try controller.activate()
        try controller.select(id: "usb")
        #expect(controller.selectedID == "usb")
        #expect(controller.currentInput?.name == "USB Receiver")
        try controller.verifyEffectiveInput()
        try controller.select(id: nil)
        #expect(controller.selectedID == nil)
        #expect(session.preferredID == nil)
        #expect(controller.currentInput?.id == "builtIn")
    }

    @Test func connectingAndDisconnectingRefreshesInputsAndFallsBack() throws {
        let session = StubVideoAudioSession()
        let controller = VideoAudioInputController(routing: session)
        try controller.activate()
        try controller.select(id: "usb")
        session.availableInputs.removeAll { $0.id == "usb" }
        try controller.refresh()
        #expect(controller.selectedID == nil)
        #expect(controller.currentInput?.id == "builtIn")
        #expect(controller.message?.contains("disconnected") == true)
        session.availableInputs.append(.init(id: "bluetooth", name: "Wireless Mic", portType: .bluetoothHFP))
        try controller.refresh()
        #expect(controller.availableInputs.last?.id == "bluetooth")
    }

    @Test func recordingLocksUserSelectionButReportsHardwareFallback() throws {
        let session = StubVideoAudioSession()
        let controller = VideoAudioInputController(routing: session)
        try controller.activate()
        try controller.select(id: "usb")
        controller.setRecording(true)
        #expect(throws: VideoAudioInputController.RoutingError.self) {
            try controller.select(id: nil)
        }
        #expect(session.preferredID == "usb")
        session.availableInputs.removeAll { $0.id == "usb" }
        try controller.refresh()
        #expect(controller.currentInput?.id == "builtIn")
        #expect(controller.message?.contains("during recording") == true)
        controller.setRecording(false)
        try controller.select(id: "builtIn")
        #expect(controller.selectedID == "builtIn")
    }

    @Test func rejectedPreferenceDoesNotPretendSelectionSucceeded() throws {
        let session = StubVideoAudioSession()
        let controller = VideoAudioInputController(routing: session)
        try controller.activate()
        session.rejectSelection = true
        #expect(throws: StubVideoAudioSession.Failure.self) { try controller.select(id: "usb") }
        #expect(controller.selectedID == nil)
        #expect(controller.currentInput?.id == "builtIn")
        #expect(controller.message != nil)
    }

    @Test func systemIgnoringPreferenceBlocksRecordingUntilRouteSettles() throws {
        let session = StubVideoAudioSession()
        let controller = VideoAudioInputController(routing: session)
        try controller.activate()
        session.followsPreference = false
        try controller.select(id: "usb")
        #expect(controller.selectedID == "usb")
        #expect(controller.currentInput?.id == "builtIn")
        #expect(throws: VideoAudioInputController.RoutingError.self) {
            try controller.verifyEffectiveInput()
        }
        session.currentInput = session.availableInputs.last
        try controller.refresh()
        try controller.verifyEffectiveInput()
        #expect(controller.currentInput?.id == "usb")
    }

    @Test func activationFailureAndInactiveSelectionAreRecoverable() {
        let session = StubVideoAudioSession()
        session.rejectActivation = true
        let controller = VideoAudioInputController(routing: session)
        #expect(throws: StubVideoAudioSession.Failure.self) { try controller.activate() }
        #expect(controller.isActive == false)
        #expect(throws: VideoAudioInputController.RoutingError.self) { try controller.select(id: "usb") }
    }

    @Test func failedDisconnectFallbackStillDisplaysActualMicrophone() throws {
        let session = StubVideoAudioSession()
        let controller = VideoAudioInputController(routing: session)
        try controller.activate()
        try controller.select(id: "usb")
        session.availableInputs.removeAll { $0.id == "usb" }
        session.currentInput = session.availableInputs.first
        session.rejectSelection = true
        #expect(throws: StubVideoAudioSession.Failure.self) { try controller.refresh() }
        #expect(controller.currentInput?.id == "builtIn")
        #expect(throws: StubVideoAudioSession.Failure.self) { try controller.verifyEffectiveInput() }
    }

    @Test func unknownInputDoesNotSilentlySelectAutomatic() throws {
        let controller = VideoAudioInputController(routing: StubVideoAudioSession())
        try controller.activate()
        #expect(throws: VideoAudioInputController.RoutingError.self) { try controller.select(id: "gone") }
        #expect(controller.currentInput?.id == "builtIn")
    }

    @Test func stoppingRetainsPreferenceForNextPreview() throws {
        let session = StubVideoAudioSession()
        let controller = VideoAudioInputController(routing: session)
        try controller.activate()
        try controller.select(id: "usb")
        controller.stop()
        try controller.deactivate()
        #expect(controller.currentInput == nil)
        #expect(controller.isActive == false)
        #expect(session.deactivationCount == 1)
        try controller.activate()
        #expect(controller.currentInput?.id == "usb")
    }

    @Test func automaticTracksRouteChangesWithoutForcingAnInput() throws {
        let session = StubVideoAudioSession()
        let controller = VideoAudioInputController(routing: session)
        try controller.activate()
        session.currentInput = session.availableInputs.last
        try controller.refresh()
        #expect(controller.selectedID == nil)
        #expect(controller.currentInput?.id == "usb")
        #expect(session.preferredID == nil)
    }
}

@MainActor
private final class StubVideoAudioSession: VideoAudioSessionRouting {
    enum Failure: Error { case configuredFailure }
    var availableInputs = [
        VideoAudioInput(id: "builtIn", name: "Phone", portType: .builtInMic),
        VideoAudioInput(id: "usb", name: "USB Receiver", portType: .usbAudio)
    ]
    var currentInput: VideoAudioInput?
    var preferredID: String?
    var rejectSelection = false
    var rejectActivation = false
    var followsPreference = true
    var deactivationCount = 0

    func activate() throws {
        if rejectActivation { throw Failure.configuredFailure }
        currentInput = availableInputs.first
    }

    func deactivate() { deactivationCount += 1 }

    func setPreferredInput(id: String?) throws {
        if rejectSelection { throw Failure.configuredFailure }
        preferredID = id
        if followsPreference {
            currentInput = availableInputs.first { $0.id == id } ?? availableInputs.first
        }
    }
}
