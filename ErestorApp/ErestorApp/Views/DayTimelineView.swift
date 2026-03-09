import SwiftUI

struct DayTimelineView: View {
    let events: [ContextSummary.NextEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AGENDA")
                .font(DS.mono(9))
                .foregroundColor(DS.dim)
                .tracking(1)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(event.start)
                            .font(DS.mono(10))
                            .foregroundColor(DS.dim)
                            .frame(minWidth: 38, alignment: .leading)

                        Text(event.title)
                            .font(DS.body(11))
                            .foregroundColor(eventColor(event.title))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
    }

    private func eventColor(_ title: String) -> Color {
        let lower = title.lowercased()
        let isWork = lower.contains("deep") || lower.contains("work") || lower.contains("foco")
            || lower.contains("reuniao") || lower.contains("reunião") || lower.contains("mentoria")
        return isWork ? DS.green : DS.dim
    }
}
