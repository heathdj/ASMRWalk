import SwiftUI

struct VideoMicrophonePicker: View {
    @Environment(\.dismiss) private var dismiss
    let camera: VideoCaptureService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    choice(name: "Automatic", detail: "Follow the microphone selected by iOS",
                           id: nil, selected: camera.audioInputs.selectedID == nil)
                    ForEach(camera.audioInputs.availableInputs) { input in
                        choice(name: input.name, detail: input.kind.rawValue, id: input.id,
                               selected: camera.audioInputs.selectedID == input.id)
                    }
                } header: {
                    Text("Microphone")
                } footer: {
                    Text("Connect Bluetooth or USB microphones to add them here. Input selection is locked while recording.")
                }
                Section("Active Input") {
                    Text(camera.audioInputs.currentInput?.name ?? "No microphone available")
                    Text(camera.audioInputs.effectiveInputMessage)
                        .foregroundStyle(.secondary)
                    if let error = camera.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Microphone Input")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("videoWalk.microphonePicker")
    }

    private func choice(name: String, detail: String, id: String?, selected: Bool) -> some View {
        Button {
            camera.selectAudioInput(id: id)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(name)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.primary)
        }
        .disabled(camera.canSelectAudioInput == false)
        .accessibilityLabel(name)
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("videoWalk.microphone." + (id ?? "automatic"))
    }
}
