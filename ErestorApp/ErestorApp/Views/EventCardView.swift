import SwiftUI

enum EventType {
    case work
    case rest
    case free

    var barColor: Color {
        switch self {
        case .work: return DS.green
        case .rest: return DS.blue
        case .free: return DS.muted
        }
    }

    var progressColor: Color {
        switch self {
        case .work: return DS.green
        case .rest: return DS.blue
        case .free: return DS.muted
        }
    }
}

struct EventCardView: View {
    let title: String
    let timeRange: String
    let progress: Double
    let eventType: EventType

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Colored vertical bar
            RoundedRectangle(cornerRadius: 2)
                .fill(eventType.barColor)
                .frame(width: 2.5)
                .frame(minHeight: 32)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(DS.body(13, weight: .medium))
                    .foregroundColor(DS.bright)
                    .lineSpacing(1.3)

                Text(timeRange)
                    .font(DS.body(10.5))
                    .foregroundColor(DS.subtle)
                    .padding(.top, 2)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(DS.border)
                            .frame(height: 2)

                        RoundedRectangle(cornerRadius: 1)
                            .fill(eventType.progressColor)
                            .frame(width: geo.size.width * min(max(progress, 0), 1), height: 2)
                    }
                }
                .frame(height: 2)
                .padding(.top, 8)
            }
        }
        .padding(.init(top: 14, leading: 14, bottom: 12, trailing: 14))
    }
}
