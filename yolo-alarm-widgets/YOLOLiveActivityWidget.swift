import ActivityKit
import SwiftUI
import WidgetKit

struct YOLOLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: YOLOActivityAttributes.self) { context in
            // Lock screen / banner view
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isAlarming ? "bell.fill" : "alarm")
                        .foregroundColor(context.state.isAlarming ? .yellow : .white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.isAlarming ? "😊" : context.state.wakeWindow)
                        .font(.caption.bold())
                        .foregroundColor(context.state.isAlarming ? .yellow : .white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.message)
                        .font(.caption2)
                        .foregroundColor(context.state.isAlarming ? .white : .gray)
                }
            } compactLeading: {
                Image(systemName: context.state.isAlarming ? "bell.fill" : "alarm")
                    .foregroundColor(context.state.isAlarming ? .yellow : .white)
            } compactTrailing: {
                Image(systemName: context.state.isAlarming ? "exclamationmark.circle.fill" : "waveform")
                    .foregroundColor(context.state.isAlarming ? .yellow : .green)
            } minimal: {
                Image(systemName: context.state.isAlarming ? "bell.fill" : "alarm")
                    .foregroundColor(context.state.isAlarming ? .yellow : .white)
            }
        }
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<YOLOActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.isAlarming ? "It's time to wake up 😊" : "Alarm \(context.state.wakeWindow)")
                    .font(.headline.bold())
                    .foregroundColor(context.state.isAlarming ? .yellow : .white)
                Text(context.state.message)
                    .font(.subheadline)
                    .foregroundColor(context.state.isAlarming ? .white : .gray)
            }

            Spacer()

            Image(systemName: context.state.isAlarming ? "bell.fill" : "waveform")
                .font(.title)
                .foregroundColor(context.state.isAlarming ? .yellow : .white.opacity(0.5))
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
}
