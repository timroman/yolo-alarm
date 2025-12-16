import AVFoundation
import Combine

enum MonitoringState: Equatable {
    case idle
    case calibrating(startTime: Date)
    case listening(baseline: Float)

    static func == (lhs: MonitoringState, rhs: MonitoringState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.calibrating, .calibrating):
            return true
        case (.listening(let l), .listening(let r)):
            return l == r
        default:
            return false
        }
    }

    var isCalibrating: Bool {
        if case .calibrating = self { return true }
        return false
    }

    var isListening: Bool {
        if case .listening = self { return true }
        return false
    }

    var baseline: Float? {
        if case .listening(let baseline) = self { return baseline }
        return nil
    }
}

@MainActor
class AudioMonitor: ObservableObject {
    @Published var currentLevel: Float = -160.0
    @Published var didTrigger: Bool = false
    @Published var monitoringState: MonitoringState = .idle
    @Published var calibrationProgress: Double = 0.0

    var sensitivityOffset: Float = 9.0  // Default medium (dB above baseline)

    private var audioEngine: AVAudioEngine?
    private var isRunning = false

    // Calibration samples
    private var calibrationSamples: [Float] = []
    private var calibrationStartTime: Date?
    private let calibrationDuration: TimeInterval = 30.0

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
            consecutiveTriggerCount = 0
            print("🎤 Audio engine started successfully!")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }

    func startCalibration() {
        calibrationSamples.removeAll()
        calibrationStartTime = Date()
        calibrationProgress = 0.0
        monitoringState = .calibrating(startTime: Date())
        print("🎤 Starting 30-second calibration...")
    }

    func stop() {
        guard isRunning else { return }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRunning = false
        didTrigger = false
        monitoringState = .idle
        calibrationSamples.removeAll()
        calibrationProgress = 0.0

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

    private func checkForTrigger(level: Float) {
        switch monitoringState {
        case .idle:
            // Not monitoring, do nothing
            consecutiveTriggerCount = 0
            return

        case .calibrating:
            // Collect samples for baseline calculation
            calibrationSamples.append(level)

            guard let startTime = calibrationStartTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            calibrationProgress = min(elapsed / calibrationDuration, 1.0)

            // Check if calibration is complete
            if elapsed >= calibrationDuration {
                let baseline = calibrationSamples.reduce(0, +) / Float(calibrationSamples.count)
                monitoringState = .listening(baseline: baseline)
                print("🎤 Calibration complete. Baseline: \(baseline) dB, Threshold: \(baseline + sensitivityOffset) dB")
            }

        case .listening(let baseline):
            // Check if noise exceeds baseline + offset
            let threshold = baseline + sensitivityOffset
            if level > threshold {
                consecutiveTriggerCount += 1
                if consecutiveTriggerCount >= requiredConsecutiveTriggers {
                    print("🎤 Triggered! Level: \(level) dB exceeded threshold: \(threshold) dB")
                    didTrigger = true
                }
            } else {
                consecutiveTriggerCount = 0
            }
        }
    }
}
