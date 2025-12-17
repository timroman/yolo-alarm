import SwiftUI

struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            AppGradient.meshBackground(for: appState.settings.colorTheme)

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

            // Wake window picker
            VStack(spacing: 24) {
                Text("wake window")
                    .font(.headline)
                    .foregroundColor(.gray)

                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("earliest")
                            .font(.caption)
                            .foregroundColor(.gray)
                        DatePicker("", selection: $appState.settings.wakeWindowStart, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .textCase(.lowercase)
                    }

                    Text("to")
                        .foregroundColor(.gray)

                    VStack(spacing: 8) {
                        Text("latest")
                            .font(.caption)
                            .foregroundColor(.gray)
                        DatePicker("", selection: $appState.settings.wakeWindowEnd, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .textCase(.lowercase)
                    }
                }
            }
            .padding(24)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)

            Spacer()

            // Start button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.recalculateWakeWindow()
                    appState.startMonitoring()
                }
            }) {
                Text("start")
                    .font(.title2.bold())
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)

            // Settings button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingSettings = true
                }
            }) {
                HStack {
                    Image(systemName: "gearshape")
                    Text("settings")
                }
                .foregroundColor(.gray)
            }
            .padding(.bottom, 20)
            }
            .padding()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    SetupView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
