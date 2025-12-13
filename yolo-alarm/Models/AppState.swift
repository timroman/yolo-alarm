import Foundation
import Combine

enum AppScreen {
    case onboarding
    case setup
    case monitoring
    case alarm
}

@MainActor
class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .setup
    @Published var settings: AlarmSettings {
        didSet { saveSettings() }
    }
    @Published var currentDecibelLevel: Float = -160.0
    @Published var isMonitoring: Bool = false
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: onboardingKey) }
    }

    private let settingsKey = "alarmSettings"
    private let onboardingKey = "hasCompletedOnboarding"

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)

        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AlarmSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }

        // Show onboarding if not completed
        if !hasCompletedOnboarding {
            currentScreen = .onboarding
        }
    }

    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    func recalculateWakeWindow() {
        let calendar = Calendar.current
        let now = Date()

        // Extract just the hour/minute from the selected times
        let startHour = calendar.component(.hour, from: settings.wakeWindowStart)
        let startMinute = calendar.component(.minute, from: settings.wakeWindowStart)
        let endHour = calendar.component(.hour, from: settings.wakeWindowEnd)
        let endMinute = calendar.component(.minute, from: settings.wakeWindowEnd)

        // Get today at midnight
        let todayStart = calendar.startOfDay(for: now)

        // Create today's start and end times
        var startToday = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: todayStart)!
        var endToday = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: todayStart)!

        // If end time is before start time, it means end is next day
        if endToday <= startToday {
            endToday = calendar.date(byAdding: .day, value: 1, to: endToday)!
        }

        // If we've already passed the end time, use tomorrow's window
        if now > endToday {
            startToday = calendar.date(byAdding: .day, value: 1, to: startToday)!
            endToday = calendar.date(byAdding: .day, value: 1, to: endToday)!
        }

        settings.wakeWindowStart = startToday
        settings.wakeWindowEnd = endToday
    }

    func startMonitoring() {
        currentScreen = .monitoring
        isMonitoring = true
    }

    func stopMonitoring() {
        isMonitoring = false
        currentScreen = .setup
    }

    func triggerAlarm() {
        currentScreen = .alarm
    }

    func dismissAlarm() {
        isMonitoring = false
        currentScreen = .setup
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        currentScreen = .setup
    }

    var wakeWindowFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: settings.wakeWindowStart)
        let end = formatter.string(from: settings.wakeWindowEnd)
        return "\(start) - \(end)"
    }
}
