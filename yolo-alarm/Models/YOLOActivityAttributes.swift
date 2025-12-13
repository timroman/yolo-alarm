import ActivityKit
import Foundation

struct YOLOActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var wakeWindow: String
        var isActive: Bool
        var isAlarming: Bool
        var message: String
    }

    var startTime: Date
}
