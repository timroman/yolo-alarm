import AVFoundation
import Combine

@MainActor
class AudioMonitor: ObservableObject {
    @Published var currentLevel: Float = -160.0
    @Published var didTrigger: Bool = false
    @Published var isDetectionEnabled: Bool = false

    var sensitivityThreshold: Float = -27.5  // Default medium

    private var audioEngine: AVAudioEngine?
    private var isRunning = false

    // Smoothing for noise detection
    private var recentLevels: [Float] = []
    private let smoothingWindowSize = 30  // ~0.6 seconds of audio

    // Warm-up period to let audio levels stabilize
    private var warmUpBuffersRemaining = 0
    private let warmUpBufferCount = 100  // ~2 seconds at 48kHz/1024

    // Require sustained noise before triggering
    private var consecutiveTriggerCount = 0
    private let requiredConsecutiveTriggers = 3  // Must exceed threshold 3 times in a row

    func start() {
        guard !isRunning else {
            print("🎤 Already running, skipping start")
            return
        }

        // Configure audio session for recording
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            print("🔊 Audio session activated for monitoring")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
            return
        }

        print("🎤 Creating audio engine...")
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            print("❌ Failed to create audio engine")
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        print("🎤 Input format: \(format)")

        // Install tap to monitor audio levels
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        print("🎤 Tap installed")

        do {
            try audioEngine.start()
            isRunning = true
            warmUpBuffersRemaining = warmUpBufferCount
            consecutiveTriggerCount = 0
            print("🎤 Audio engine started successfully! Warming up for ~5 seconds...")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        guard isRunning else { return }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRunning = false
        didTrigger = false
        recentLevels.removeAll()

        // Deactivate audio session to stop microphone indicator
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🔊 Audio session deactivated")
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }

    private var bufferCount = 0

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferCount += 1
        if bufferCount == 1 {
            print("🎤 First audio buffer received!")
        }

        guard let channelData = buffer.floatChannelData?[0] else {
            print("❌ No channel data in buffer")
            return
        }

        let frameLength = Int(buffer.frameLength)

        // Calculate RMS (Root Mean Square) for the buffer
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        let decibels = 20 * log10(max(rms, 0.000001))

        Task { @MainActor in
            self.currentLevel = decibels
            self.checkForTrigger(level: decibels)
        }
    }

    private var logCounter = 0

    private func checkForTrigger(level: Float) {
        // Add to smoothing window
        recentLevels.append(level)
        if recentLevels.count > smoothingWindowSize {
            recentLevels.removeFirst()
        }

        // Handle warm-up period
        if warmUpBuffersRemaining > 0 {
            warmUpBuffersRemaining -= 1
            if warmUpBuffersRemaining == 0 {
                print("🎤 Warm-up complete, detection ready")
            }
            return
        }

        // Use the current level directly (not averaged) for more responsive detection
        let checkLevel = level


        if !isDetectionEnabled {
            consecutiveTriggerCount = 0
            return
        }

        // Check if noise exceeds threshold
        if checkLevel > sensitivityThreshold {
            consecutiveTriggerCount += 1
            if consecutiveTriggerCount >= requiredConsecutiveTriggers {
                didTrigger = true
            }
        } else {
            consecutiveTriggerCount = 0
        }
    }
}
