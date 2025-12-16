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

                // Audio waveform visualization - only show when listening
                if audioMonitor.monitoringState.isListening {
                    AudioWaveformView(level: appState.currentDecibelLevel)
                        .frame(height: 60)
                        .padding(.horizontal, 20)
                } else {
                    Spacer()
                        .frame(height: 60)
                }

                Spacer()
                    .frame(height: 40)

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
        .onReceive(audioMonitor.$currentLevel) { level in
            appState.currentDecibelLevel = level
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

        // Start audio engine and calibration when wake window begins
        if inWakeWindow && audioMonitor.monitoringState == .idle {
            audioMonitor.start()
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

struct AudioWaveformView: View {
    let level: Float
    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: 30)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 4, height: max(4, bars[index] * 60))
            }
        }
        .onChange(of: level) { _, newLevel in
            updateBars(level: newLevel)
        }
    }

    private func updateBars(level: Float) {
        // Shift bars left
        bars.removeFirst()
        // Normalize level (-160 to 0 dB) to 0-1 range
        let normalized = CGFloat((level + 160) / 160)
        bars.append(max(0.1, min(1.0, normalized)))
    }
}

#Preview {
    MonitoringView()
        .environmentObject(AppState())
}
