import SwiftUI
import AVFoundation
import UserNotifications

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var microphoneGranted = false
    @State private var notificationsGranted = false

    var body: some View {
        ZStack {
            AppGradient.meshBackground

            VStack(spacing: 40) {
                Spacer()

                // App logo
                VStack(spacing: 12) {
                    Image("yolo-logo")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 70)
                        .foregroundColor(.white)
                    Text("make the most of today")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Permission cards
            VStack(spacing: 16) {
                PermissionCard(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Required to detect noise and wake you up",
                    isGranted: microphoneGranted,
                    isActive: currentStep == 0
                ) {
                    requestMicrophonePermission()
                }

                PermissionCard(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "Get notified when your alarm triggers",
                    isGranted: notificationsGranted,
                    isActive: currentStep == 1
                ) {
                    requestNotificationPermission()
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue button
            if microphoneGranted && notificationsGranted {
                Button(action: {
                    appState.completeOnboarding()
                }) {
                    Text("Get Started")
                        .font(.title2.bold())
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)
            } else {
                Text("Grant permissions to continue")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
                .frame(height: 40)
            }
        }
        .onAppear {
            checkExistingPermissions()
        }
    }

    private func checkExistingPermissions() {
        // Check microphone
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            microphoneGranted = true
            currentStep = 1
        default:
            break
        }

        // Check notifications
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    notificationsGranted = true
                    if microphoneGranted {
                        currentStep = 2
                    }
                }
            }
        }
    }

    private func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                microphoneGranted = granted
                if granted {
                    currentStep = 1
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                notificationsGranted = granted
                if granted {
                    currentStep = 2
                }
            }
        }
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let isActive: Bool
    let onRequest: () -> Void

    var body: some View {
        Button(action: {
            if !isGranted && isActive {
                onRequest()
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isGranted ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: isGranted ? "checkmark" : icon)
                        .font(.title2)
                        .foregroundColor(isGranted ? .green : .white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                if !isGranted && isActive {
                    Text("Allow")
                        .font(.subheadline.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isActive && !isGranted ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isActive && !isGranted ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .disabled(isGranted || !isActive)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
