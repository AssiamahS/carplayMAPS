import WidgetKit
import SwiftUI
import ActivityKit

@main
struct MapsWidgetBundle: WidgetBundle {
    var body: some Widget {
        GuidanceLiveActivity()
    }
}

struct GuidanceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GuidanceAttributes.self) { context in
            // Lock Screen banner
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.instruction)
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .lineLimit(2)
                    Text("\(context.state.distance) · ETA \(context.state.eta)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(.green)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.instruction)
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.distance) · ETA \(context.state.eta) · \(context.attributes.destination)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "arrow.turn.up.right")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(context.state.distance)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green)
            } minimal: {
                Image(systemName: "arrow.turn.up.right")
                    .foregroundStyle(.green)
            }
        }
    }
}
