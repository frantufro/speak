import SwiftUI
import SpeakKit
import ServiceManagement

/// The four-section settings form.
struct SettingsView: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        Form {
            hotkeySection
            modelSection
            loginSection
            languageSection
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
    }

    // MARK: – Hotkey

    private var hotkeySection: some View {
        Section("Hotkey") {
            HStack {
                Text("Hold-to-talk")
                Spacer()
                HotkeyCaptureField(combo: $vm.hotkey, isCapturing: $vm.isCapturingHotkey)
            }
            if vm.hotkey.keyCode == 63 { // Fn key
                Text("Fn may conflict with Apple Intelligence / built-in dictation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if vm.isRebindBlocked {
                Text("Cannot rebind while a capture is in progress.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: – Model

    private var modelSection: some View {
        Section("Model") {
            Picker("WhisperKit model", selection: $vm.model) {
                ForEach(SettingsViewModel.availableModels, id: \.self) { m in
                    Text(m).tag(m)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: – Launch at login

    private var loginSection: some View {
        Section("Startup") {
            Toggle("Launch at login", isOn: $vm.launchAtLogin)
        }
    }

    // MARK: – Language

    private var languageSection: some View {
        Section("Language") {
            Toggle("Auto-detect language", isOn: $vm.autoDetect)
            if !vm.autoDetect {
                Picker("Source language", selection: $vm.language) {
                    Text("English").tag("en")
                    Text("Spanish").tag("es")
                }
                .pickerStyle(.menu)
            }
        }
    }
}
