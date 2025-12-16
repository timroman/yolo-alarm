import ActivityKit
import Foundation

enum YOLOLiveActivity {
    private static var currentActivity: Activity<YOLOActivityAttributes>?

    static func start(wakeWindow: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }

        let attributes = YOLOActivityAttributes(startTime: Date())
        let state = YOLOActivityAttributes.ContentState(
            wakeWindow: wakeWindow,
            isActive: true,
            isAlarming: false,
            message: "Listening..."
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("Started Live Activity: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    static func updateStatus(_ status: String) {
        guard let activity = currentActivity else { return }

        let state = YOLOActivityAttributes.ContentState(
            wakeWindow: activity.content.state.wakeWindow,
            isActive: true,
            isAlarming: false,
            message: status
        )

        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: nil)
            )
            print("Live Activity status: \(status)")
        }
    }

    static func triggerAlarm(message: String) {
        let state = YOLOActivityAttributes.ContentState(
            wakeWindow: "",
            isActive: true,
            isAlarming: true,
            message: message
        )

        Task {
            await currentActivity?.update(
                ActivityContent(state: state, staleDate: nil)
            )
            print("Live Activity updated to alarm state")
        }
    }

    static func stop() {
        let state = YOLOActivityAttributes.ContentState(
            wakeWindow: "",
            isActive: false,
            isAlarming: false,
            message: ""
        )

        Task {
            await currentActivity?.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
            currentActivity = nil
            print("Live Activity stopped")
        }
    }
}
