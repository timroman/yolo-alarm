import SwiftUI
@preconcurrency import AVFoundation
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
    private var playerA: AVAudioPlayer?
    private var playerB: AVAudioPlayer?
    private var activePlayer: AVAudioPlayer? // Currently playing at full volume
    private var soundURL: URL?
    private var volumeRampTimer: Timer?
    private var crossfadeTimer: Timer?
    private var targetVolume: Float = 1.0
    private var currentVolume: Float = 0.0 // Tracks actual volume during ramp
    private let rampDuration: Float = 60.0 // seconds
    private let crossfadeDuration: TimeInterval = 1.5 // seconds for crossfade

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

        self.soundURL = soundURL

        do {
            // Initialize both players with the same sound
            playerA = try AVAudioPlayer(contentsOf: soundURL)
            playerB = try AVAudioPlayer(contentsOf: soundURL)
            playerA?.prepareToPlay()
            playerB?.prepareToPlay()

            // Start player A
            playerA?.volume = 0
            playerA?.play()
            activePlayer = playerA

            print("🔔 Alarm started with crossfade looping, ramping volume over \(rampDuration) seconds")
            startVolumeRamp()
            scheduleCrossfade()
        } catch {
            print("Failed to play alarm: \(error)")
            playFallbackSound()
        }
    }

    private func startVolumeRamp() {
        // Update volume every 0.5 seconds over rampDuration
        let updateInterval: TimeInterval = 0.5
        let totalSteps = Int(rampDuration / Float(updateInterval))
        var currentStep = 0

        volumeRampTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                currentStep += 1
                let progress = Float(currentStep) / Float(totalSteps)
                self.currentVolume = self.targetVolume * progress

                // Apply to active player (crossfade will handle transitions)
                if let active = self.activePlayer {
                    active.volume = self.currentVolume
                }

                if currentStep >= totalSteps {
                    self.currentVolume = self.targetVolume
                    print("🔔 Volume ramp complete: \(Int(self.targetVolume * 2000))% of max")
                    timer.invalidate()
                    self.volumeRampTimer = nil
                }
            }
        }
    }

    private func scheduleCrossfade() {
        guard let player = activePlayer, player.duration > crossfadeDuration * 2 else {
            // Sound too short for crossfade, use simple loop
            playerA?.numberOfLoops = -1
            return
        }

        // Schedule crossfade to start before the track ends
        let crossfadeStartTime = player.duration - crossfadeDuration

        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, let active = self.activePlayer else {
                    timer.invalidate()
                    return
                }

                // Check if we're near the end of the track
                if active.currentTime >= crossfadeStartTime {
                    timer.invalidate()
                    self.performCrossfade()
                }
            }
        }
    }

    private func performCrossfade() {
        guard let soundURL = soundURL else { return }

        // Determine which player is next
        let outgoingPlayer = activePlayer
        let incomingPlayer: AVAudioPlayer?

        if activePlayer === playerA {
            // Reinitialize player B
            playerB = try? AVAudioPlayer(contentsOf: soundURL)
            playerB?.prepareToPlay()
            incomingPlayer = playerB
        } else {
            // Reinitialize player A
            playerA = try? AVAudioPlayer(contentsOf: soundURL)
            playerA?.prepareToPlay()
            incomingPlayer = playerA
        }

        guard let incoming = incomingPlayer else { return }

        // Start incoming player at zero volume
        incoming.volume = 0
        incoming.play()

        // Crossfade over crossfadeDuration
        let steps = 30
        let stepInterval = crossfadeDuration / Double(steps)
        var currentStep = 0

        Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                currentStep += 1
                let progress = Float(currentStep) / Float(steps)

                // Use current volume level (which may still be ramping up)
                let effectiveVolume = self.currentVolume > 0 ? self.currentVolume : self.targetVolume

                // Fade out outgoing, fade in incoming
                outgoingPlayer?.volume = effectiveVolume * (1.0 - progress)
                incoming.volume = effectiveVolume * progress

                if currentStep >= steps {
                    timer.invalidate()
                    outgoingPlayer?.stop()
                    incoming.volume = effectiveVolume
                    self.activePlayer = incoming
                    self.scheduleCrossfade() // Schedule next crossfade
                }
            }
        }
    }

    func stop() {
        volumeRampTimer?.invalidate()
        volumeRampTimer = nil
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
        playerA?.stop()
        playerB?.stop()
        playerA = nil
        playerB = nil
        activePlayer = nil
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
