import SwiftUI

struct MonitoringView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var audioMonitor = AudioMonitor()
    @State private var currentTime = Date()
    @State private var hasStarted = false
    @State private var wakeWindowTimer: Timer?

    var body: some View {
        ZStack {
            AppGradient.background(for: appState.settings.colorTheme)

            VStack {
                Spacer()

                // Current time - large and subtle
                Text(timeString)
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))

                // Wake window
                Text("Alarm \(appState.wakeWindowFormatted)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.2))
                    .padding(.top, 8)

                // Status info - only show when calibrating or listening
                VStack(spacing: 8) {
                    if audioMonitor.monitoringState != .idle {
                        Text(statusText)
                            .font(.caption.bold())
                            .foregroundColor(statusColor)
                    }

                    if audioMonitor.monitoringState.isCalibrating {
                        // Calibration progress
                        VStack(spacing: 4) {
                            ProgressView(value: audioMonitor.calibrationProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .yellow.opacity(0.8)))
                                .frame(width: 120)

                            Text("\(Int(audioMonitor.calibrationProgress * 30))s / 30s")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    } else if let baseline = audioMonitor.monitoringState.baseline {
                        // Only show levels when listening
                        HStack(spacing: 16) {
                            VStack(spacing: 2) {
                                Text("\(String(format: "%.0f", audioMonitor.currentLevel))")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                Text("dB")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(.white.opacity(0.4))

                            Text("/")
                                .foregroundColor(.white.opacity(0.2))

                            VStack(spacing: 2) {
                                Text("\(String(format: "%.0f", baseline + audioMonitor.sensitivityOffset))")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                Text("trigger")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .padding(.top, 20)

                Spacer()

                // Stop button - subtle
                Button(action: {
                    print("🛑 Stop button tapped")
                    stopWakeWindowTimer()
                    audioMonitor.stop()
                    YOLOLiveActivity.stop()
                    appState.stopMonitoring()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                        Text("Stop")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white.opacity(0.3))
                }
                .padding(.bottom, 40)
            }
        }
        .task {
            await startMonitoringAsync()
        }
        .onReceive(audioMonitor.$monitoringState) { state in
            // Update Live Activity with current status
            switch state {
            case .idle:
                break
            case .calibrating:
                YOLOLiveActivity.updateStatus("Calibrating...")
            case .listening:
                YOLOLiveActivity.updateStatus("Listening...")
            }
        }
        .onReceive(audioMonitor.$didTrigger) { triggered in
            if triggered {
                print("🚨 Trigger received, stopping monitor and switching to alarm")
                stopWakeWindowTimer()
                audioMonitor.stop()
                YOLOLiveActivity.triggerAlarm(message: appState.settings.tagline)
                appState.triggerAlarm()
            }
        }
        .onDisappear {
            // Clean up when view disappears
            stopWakeWindowTimer()
            audioMonitor.stop()
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: currentTime)
    }

    private var statusText: String {
        switch audioMonitor.monitoringState {
        case .idle:
            return "Waiting"
        case .calibrating:
            return "Calibrating..."
        case .listening:
            return "Listening"
        }
    }

    private var statusColor: Color {
        switch audioMonitor.monitoringState {
        case .idle:
            return .orange.opacity(0.8)
        case .calibrating:
            return .yellow.opacity(0.8)
        case .listening:
            return .green.opacity(0.8)
        }
    }

    private func startMonitoringAsync() async {
        guard !hasStarted else { return }
        hasStarted = true

        audioMonitor.sensitivityOffset = appState.settings.sensitivityOffset

        // Start audio engine NOW while device is unlocked
        // This ensures the audio session is established before the device locks
        audioMonitor.start()

        // Start Live Activity
        YOLOLiveActivity.start(wakeWindow: appState.wakeWindowFormatted)

        // Start wake window timer
        startWakeWindowTimer()

        // Check immediately
        checkWakeWindow()
    }

    private func startWakeWindowTimer() {
        wakeWindowTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            Task { @MainActor in
                currentTime = Date()
                checkWakeWindow()
            }
        }
        print("⏰ Wake window timer started")
    }

    private func stopWakeWindowTimer() {
        wakeWindowTimer?.invalidate()
        wakeWindowTimer = nil
    }

    private func checkWakeWindow() {
        let now = Date()
        let windowStart = appState.settings.wakeWindowStart
        let windowEnd = appState.settings.wakeWindowEnd

        let inWakeWindow = now >= windowStart && now <= windowEnd

        // Start calibration when wake window begins (audio engine already running)
        if inWakeWindow && audioMonitor.monitoringState == .idle {
            audioMonitor.startCalibration()
        }

        // Fallback alarm at end time
        if now >= windowEnd && appState.currentScreen == .monitoring {
            stopWakeWindowTimer()
            audioMonitor.stop()
            YOLOLiveActivity.triggerAlarm(message: appState.settings.tagline)
            appState.triggerAlarm()
        }
    }
}

#Preview {
    MonitoringView()
        .environmentObject(AppState())
}
