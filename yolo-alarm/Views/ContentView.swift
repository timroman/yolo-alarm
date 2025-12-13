import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch appState.currentScreen {
        case .onboarding:
            OnboardingView()
        case .setup:
            SetupView()
        case .monitoring:
            MonitoringView()
        case .alarm:
            AlarmView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
