import Foundation

struct AlarmSettings: Codable {
    var wakeWindowStart: Date
    var wakeWindowEnd: Date
    var sensitivityValue: Float  // 0.0 (less sensitive) to 1.0 (more sensitive)
    var volume: Float            // 0.0 to 1.0
    var selectedSound: AlarmSound
    var customSoundId: UUID?     // If set, use custom sound instead of built-in
    var tagline: String          // Customizable tagline under YOLO
    var hapticEnabled: Bool
    var hapticType: HapticType
    var colorTheme: ColorTheme

    var isUsingCustomSound: Bool {
        customSoundId != nil
    }

    // Convert sensitivity slider (0-1) to decibel offset above baseline
    // 0.0 = +15 dB above baseline (needs loud noise)
    // 1.0 = +3 dB above baseline (very sensitive - small sounds)
    var sensitivityOffset: Float {
        return 15.0 - (sensitivityValue * 12.0)
    }

    var sensitivityLabel: String {
        switch sensitivityValue {
        case 0.0..<0.33: return "Low"
        case 0.33..<0.66: return "Medium"
        default: return "High"
        }
    }

    static var `default`: AlarmSettings {
        let calendar = Calendar.current
        let now = Date()
        let startComponents = DateComponents(hour: 6, minute: 30)
        let endComponents = DateComponents(hour: 7, minute: 0)

        return AlarmSettings(
            wakeWindowStart: calendar.nextDate(after: now, matching: startComponents, matchingPolicy: .nextTime) ?? now,
            wakeWindowEnd: calendar.nextDate(after: now, matching: endComponents, matchingPolicy: .nextTime) ?? now,
            sensitivityValue: 0.5,  // Medium by default
            volume: 0.7,
            selectedSound: .gentleChime,
            customSoundId: nil,
            tagline: "Good Morning",
            hapticEnabled: true,
            hapticType: .heartbeat,
            colorTheme: .ocean
        )
    }
}

enum AlarmSound: String, Codable, CaseIterable, Identifiable {
    // Gentle Tones
    case gentleChime = "gentle_chime"
    case softBells = "soft_bells"

    // Nature Sounds
    case oceanWaves = "ocean_waves"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gentleChime: return "Gentle Chime"
        case .softBells: return "Soft Bells"
        case .oceanWaves: return "Ocean Waves"
        }
    }

    var category: SoundCategory {
        switch self {
        case .gentleChime, .softBells:
            return .gentle
        case .oceanWaves:
            return .nature
        }
    }

    enum SoundCategory: String, CaseIterable {
        case gentle = "Gentle Tones"
        case nature = "Nature Sounds"
    }
}

enum ColorTheme: String, Codable, CaseIterable, Identifiable {
    case ocean = "ocean"
    case sunset = "sunset"
    case forest = "forest"
    case lavender = "lavender"
    case midnight = "midnight"
    case coral = "coral"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        case .lavender: return "Lavender"
        case .midnight: return "Midnight"
        case .coral: return "Coral"
        }
    }
}

enum HapticType: String, Codable, CaseIterable, Identifiable {
    case heartbeat = "heartbeat"
    case pulse = "pulse"
    case escalating = "escalating"
    case steady = "steady"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heartbeat: return "Heartbeat"
        case .pulse: return "Pulse"
        case .escalating: return "Escalating"
        case .steady: return "Steady"
        }
    }

    var description: String {
        switch self {
        case .heartbeat: return "Rhythmic double-tap pattern"
        case .pulse: return "Gentle pulsing vibration"
        case .escalating: return "Gradually intensifying"
        case .steady: return "Continuous vibration"
        }
    }
}
