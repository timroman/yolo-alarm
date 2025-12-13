import SwiftUI
import AVFoundation
import CoreHaptics

struct AlarmView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var alarmPlayer = AlarmPlayer()
    @State private var currentTime = Date()
    @State private var hapticEngine: CHHapticEngine?

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppGradient.radialBackground(for: appState.settings.colorTheme)

            VStack(spacing: 40) {
                Spacer()

                // Current time
                Text(timeString)
                    .font(.system(size: 80, weight: .light, design: .rounded))
                    .foregroundColor(.white)

                Text(appState.settings.tagline)
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                // Dismiss button
                Button(action: {
                    alarmPlayer.stop()
                    YOLOLiveActivity.stop()
                    appState.dismissAlarm()
                }) {
                    Text("Stop")
                        .font(.title.bold())
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.white)
                        .cornerRadius(20)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .task {
            // Small delay to let audio session from monitoring settle
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            alarmPlayer.play(
                sound: appState.settings.selectedSound,
                customSoundId: appState.settings.customSoundId,
                volume: appState.settings.volume
            )
            if appState.settings.hapticEnabled {
                startHaptics(type: appState.settings.hapticType)
            }
        }
        .onDisappear {
            stopHaptics()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    private func startHaptics(type: HapticType) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()

            let events = createHapticEvents(for: type)
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
            print("📳 Haptic feedback started: \(type.displayName)")
        } catch {
            print("Haptic error: \(error)")
        }
    }

    private func createHapticEvents(for type: HapticType) -> [CHHapticEvent] {
        var events: [CHHapticEvent] = []

        switch type {
        case .heartbeat:
            // Double-tap pattern like a heartbeat
            for i in 0..<30 {
                let baseTime = Double(i) * 1.5
                // First beat
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: baseTime
                ))
                // Second beat (slightly softer)
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: baseTime + 0.2
                ))
            }

        case .pulse:
            // Gentle continuous pulse
            for i in 0..<60 {
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: Double(i) * 1.0,
                    duration: 0.5
                ))
            }

        case .escalating:
            // Gradually intensifying haptics
            for i in 0..<40 {
                let intensity = min(1.0, 0.2 + (Float(i) * 0.02))
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: Double(i) * 1.5
                ))
            }

        case .steady:
            // Continuous steady vibration with short breaks
            for i in 0..<30 {
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: Double(i) * 2.0,
                    duration: 1.5
                ))
            }
        }

        return events
    }

    private func stopHaptics() {
        hapticEngine?.stop()
        hapticEngine = nil
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: currentTime)
    }
}

@MainActor
class AlarmPlayer: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var volumeTimer: Timer?
    private var targetVolume: Float = 1.0
    private let rampDuration: Float = 60.0 // seconds

    func play(sound: AlarmSound, customSoundId: UUID?, volume: Float) {
        // Scale down the volume significantly - AVAudioPlayer is very loud
        // User's 0-100% maps to 0-0.05 actual volume (5% max)
        targetVolume = volume * 0.05

        // Configure audio session for playback
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            print("🔊 Audio session configured for alarm playback")
        } catch {
            print("⚠️ Failed to configure audio session: \(error)")
        }

        // Determine which sound URL to use
        let url: URL?
        if let customId = customSoundId,
           let customSound = CustomSoundManager.shared.customSounds.first(where: { $0.id == customId }),
           let customURL = customSound.fileURL {
            url = customURL
            print("🔔 Playing custom sound: \(customSound.name)")
        } else {
            url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3")
        }

        guard let soundURL = url else {
            print("Sound file not found: \(sound.rawValue)")
            playFallbackSound()
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0 // Start at zero
            audioPlayer?.play()
            print("🔔 Alarm started, ramping volume over \(rampDuration) seconds")
            startVolumeRamp()
        } catch {
            print("Failed to play alarm: \(error)")
            playFallbackSound()
        }
    }

    private func startVolumeRamp() {
        // Update volume every 0.5 seconds over 30 seconds = 60 steps
        let updateInterval: TimeInterval = 0.5
        let totalSteps = Int(rampDuration / Float(updateInterval))
        var currentStep = 0

        volumeTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer else {
                    timer.invalidate()
                    return
                }

                currentStep += 1
                let progress = Float(currentStep) / Float(totalSteps)
                let newVolume = self.targetVolume * progress
                player.volume = newVolume

                if currentStep >= totalSteps {
                    player.volume = self.targetVolume
                    print("🔔 Volume ramp complete: \(Int(self.targetVolume * 100))%")
                    timer.invalidate()
                    self.volumeTimer = nil
                }
            }
        }
    }

    func stop() {
        volumeTimer?.invalidate()
        volumeTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        print("🔔 Alarm stopped")

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🔊 Audio session deactivated")
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }

    private func playFallbackSound() {
        // Use system sound as fallback
        AudioServicesPlaySystemSound(1005)
    }
}

#Preview {
    AlarmView()
        .environmentObject(AppState())
}
