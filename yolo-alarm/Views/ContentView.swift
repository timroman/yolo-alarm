import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            switch appState.currentScreen {
            case .onboarding:
                OnboardingView()
                    .transition(.opacity)
            case .setup:
                SetupView()
                    .transition(.opacity)
            case .monitoring:
                MonitoringView()
                    .transition(.opacity)
            case .alarm:
                AlarmView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: appState.currentScreen)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
