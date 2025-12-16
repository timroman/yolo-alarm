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

    // Thread-safe calibration state (accessed from audio thread)
    private let calibrationLock = NSLock()
    private var _calibrationSamples: [Float] = []
    private var _calibrationStartTime: Date?
    private var _isCalibrating = false
    private var _baseline: Float?
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
        calibrationLock.lock()
        _calibrationSamples.removeAll()
        _calibrationStartTime = Date()
        _isCalibrating = true
        _baseline = nil
        calibrationLock.unlock()

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
        calibrationProgress = 0.0

        calibrationLock.lock()
        _calibrationSamples.removeAll()
        _calibrationStartTime = nil
        _isCalibrating = false
        _baseline = nil
        calibrationLock.unlock()

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

        // Process calibration/trigger logic on audio thread (thread-safe)
        let result = processLevel(decibels)

        // Dispatch UI updates and Live Activity updates to main thread
        Task { @MainActor in
            self.currentLevel = decibels
            if let newProgress = result.progress {
                self.calibrationProgress = newProgress
            }
            if let newState = result.newState {
                self.monitoringState = newState
                // Update Live Activity when state changes
                if newState.isListening {
                    YOLOLiveActivity.updateStatus("Listening...")
                }
            }
            if result.shouldTrigger {
                self.didTrigger = true
            }
        }
    }

    private struct ProcessResult {
        var progress: Double?
        var newState: MonitoringState?
        var shouldTrigger: Bool = false
    }

    // Process on audio thread - uses thread-safe state
    private func processLevel(_ level: Float) -> ProcessResult {
        var result = ProcessResult()

        calibrationLock.lock()
        let isCalibrating = _isCalibrating
        let baseline = _baseline
        let startTime = _calibrationStartTime
        calibrationLock.unlock()

        if isCalibrating {
            // Collect samples for baseline calculation
            calibrationLock.lock()
            _calibrationSamples.append(level)
            let sampleCount = _calibrationSamples.count
            let samples = _calibrationSamples
            calibrationLock.unlock()

            guard let calibrationStart = startTime else { return result }
            let elapsed = Date().timeIntervalSince(calibrationStart)
            result.progress = min(elapsed / calibrationDuration, 1.0)

            // Check if calibration is complete
            if elapsed >= calibrationDuration && sampleCount > 0 {
                let calculatedBaseline = samples.reduce(0, +) / Float(sampleCount)

                calibrationLock.lock()
                _isCalibrating = false
                _baseline = calculatedBaseline
                calibrationLock.unlock()

                result.newState = .listening(baseline: calculatedBaseline)
                print("🎤 Calibration complete. Baseline: \(calculatedBaseline) dB, Threshold: \(calculatedBaseline + sensitivityOffset) dB")
            }
        } else if let currentBaseline = baseline {
            // Listening mode - check if noise exceeds baseline + offset
            let threshold = currentBaseline + sensitivityOffset
            if level > threshold {
                consecutiveTriggerCount += 1
                if consecutiveTriggerCount >= requiredConsecutiveTriggers {
                    print("🎤 Triggered! Level: \(level) dB exceeded threshold: \(threshold) dB")
                    result.shouldTrigger = true
                }
            } else {
                consecutiveTriggerCount = 0
            }
        } else {
            // Idle
            consecutiveTriggerCount = 0
        }

        return result
    }
}
