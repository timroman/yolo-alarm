import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var soundManager = CustomSoundManager.shared
    @State private var previewPlayer: AVAudioPlayer?
    @State private var showingFilePicker = false
    @State private var importError: String?
    @State private var showingImportError = false

    var body: some View {
        NavigationStack {
            List {
                // Sensitivity Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Less")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Slider(value: $appState.settings.sensitivityValue, in: 0.0...1.0, step: 0.05)
                            Text("More")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text(appState.settings.sensitivityLabel)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("+\(String(format: "%.0f", appState.settings.sensitivityOffset)) dB")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Noise Sensitivity")
                } footer: {
                    Text("Triggers when sound exceeds background noise by this amount. Higher sensitivity detects smaller sounds.")
                }

                // Volume Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.gray)
                            Slider(value: $appState.settings.volume, in: 0.1...1.0, step: 0.05)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.gray)
                        }
                        Text("\(Int(appState.settings.volume * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Alarm Volume")
                } footer: {
                    Text("This scales with your device volume. For best results, set device volume to max before bed.")
                }

                // Sound Selection Section
                Section {
                    // Built-in sounds
                    ForEach(AlarmSound.SoundCategory.allCases, id: \.self) { category in
                        let sounds = AlarmSound.allCases.filter { $0.category == category }
                        if !sounds.isEmpty {
                            DisclosureGroup(category.rawValue) {
                                ForEach(sounds) { sound in
                                    SoundRowView(
                                        sound: sound,
                                        isSelected: !appState.settings.isUsingCustomSound && appState.settings.selectedSound == sound,
                                        onSelect: {
                                            appState.settings.selectedSound = sound
                                            appState.settings.customSoundId = nil
                                        },
                                        onPreview: {
                                            previewSound(sound)
                                        }
                                    )
                                }
                            }
                        }
                    }

                    // Custom sounds section
                    DisclosureGroup("Custom") {
                        // Import button
                        Button(action: { showingFilePicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Import Sound")
                                    .foregroundColor(.blue)
                            }
                        }

                        // List custom sounds
                        ForEach(soundManager.customSounds) { sound in
                            CustomSoundRowView(
                                sound: sound,
                                isSelected: appState.settings.customSoundId == sound.id,
                                onSelect: {
                                    appState.settings.customSoundId = sound.id
                                },
                                onPreview: {
                                    previewCustomSound(sound)
                                },
                                onDelete: {
                                    if appState.settings.customSoundId == sound.id {
                                        appState.settings.customSoundId = nil
                                    }
                                    soundManager.deleteSound(sound)
                                }
                            )
                        }
                    }
                } header: {
                    Text("Alarm Sound")
                } footer: {
                    Text("Tap the play button to preview. Import MP3, WAV, or M4A files.")
                }

                // Haptic Section
                Section {
                    Toggle("Enable Haptics", isOn: $appState.settings.hapticEnabled)

                    if appState.settings.hapticEnabled {
                        Picker("Pattern", selection: $appState.settings.hapticType) {
                            ForEach(HapticType.allCases) { type in
                                VStack(alignment: .leading) {
                                    Text(type.displayName)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                } header: {
                    Text("Haptic Feedback")
                } footer: {
                    if appState.settings.hapticEnabled {
                        Text(appState.settings.hapticType.description)
                    } else {
                        Text("Vibration patterns to help wake you up.")
                    }
                }

                // Color Theme Section
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                        ForEach(ColorTheme.allCases) { theme in
                            Button(action: {
                                appState.settings.colorTheme = theme
                            }) {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: theme.gradientColors,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(appState.settings.colorTheme == theme ? Color.white : Color.clear, lineWidth: 2)
                                        )
                                    Text(theme.displayName)
                                        .font(.caption2)
                                        .foregroundColor(appState.settings.colorTheme == theme ? .white : .gray)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color Theme")
                }

                // Wake message Section
                Section {
                    TextField("Your motivation", text: $appState.settings.tagline)
                } header: {
                    Text("What do you live for?")
                } footer: {
                    Text("Displayed when your alarm goes off to start your day.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        stopPreview()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            stopPreview()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: CustomSoundManager.supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    do {
                        let sound = try soundManager.importSound(from: url)
                        appState.settings.customSoundId = sound.id
                    } catch {
                        importError = error.localizedDescription
                        showingImportError = true
                    }
                }
            case .failure(let error):
                importError = error.localizedDescription
                showingImportError = true
            }
        }
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK") { }
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    private func previewSound(_ sound: AlarmSound) {
        stopPreview()

        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3") else {
            return
        }

        do {
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            // Scale volume same as alarm playback (5% max)
            previewPlayer?.volume = appState.settings.volume * 0.05
            previewPlayer?.play()

            // Stop after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [self] in
                stopPreview()
            }
        } catch {
            print("Failed to preview sound: \(error)")
        }
    }

    private func previewCustomSound(_ sound: CustomSound) {
        stopPreview()

        guard let url = sound.fileURL else { return }

        do {
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            // Scale volume same as alarm playback (5% max)
            previewPlayer?.volume = appState.settings.volume * 0.05
            previewPlayer?.play()

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [self] in
                stopPreview()
            }
        } catch {
            print("Failed to preview custom sound: \(error)")
        }
    }

    private func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }
}

struct CustomSoundRowView: View {
    let sound: CustomSound
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                    Text(sound.name)
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onPreview) {
                Image(systemName: "play.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.vertical, 4)
    }
}

struct SoundRowView: View {
    let sound: AlarmSound
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                    Text(sound.displayName)
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onPreview) {
                Image(systemName: "play.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
