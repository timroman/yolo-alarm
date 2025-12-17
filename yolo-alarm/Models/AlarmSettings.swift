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
    var hapticIntensity: Float
    var colorTheme: ColorTheme
    var motionDetectionEnabled: Bool  // Trigger alarm on device movement

    var isUsingCustomSound: Bool {
        customSoundId != nil
    }

    // Convert sensitivity slider (0-1) to standard deviation multiplier
    // Uses statistical threshold: baseline + (multiplier × stdDev)
    // 0.0 = 5.0× stdDev (needs significant deviation from baseline - less sensitive)
    // 1.0 = 2.0× stdDev (triggers on smaller deviations - more sensitive)
    var sensitivityMultiplier: Float {
        return 5.0 - (sensitivityValue * 3.0)
    }

    var sensitivityLabel: String {
        switch sensitivityValue {
        case 0.0..<0.33: return "low"
        case 0.33..<0.66: return "medium"
        default: return "high"
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
            tagline: "good morning",
            hapticEnabled: true,
            hapticType: .heartbeat,
            hapticIntensity: 0.7,
            colorTheme: .ocean,
            motionDetectionEnabled: true
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
        case .gentleChime: return "gentle chime"
        case .softBells: return "soft bells"
        case .oceanWaves: return "ocean waves"
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
        case gentle = "gentle"
        case nature = "nature"
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
        case .ocean: return "ocean"
        case .sunset: return "sunset"
        case .forest: return "forest"
        case .lavender: return "lavender"
        case .midnight: return "midnight"
        case .coral: return "coral"
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
        case .heartbeat: return "heartbeat"
        case .pulse: return "pulse"
        case .escalating: return "escalating"
        case .steady: return "steady"
        }
    }

    var description: String {
        switch self {
        case .heartbeat: return "rhythmic double-tap pattern"
        case .pulse: return "gentle pulsing vibration"
        case .escalating: return "gradually intensifying"
        case .steady: return "continuous vibration"
        }
    }
}
