#if os(iOS)
import SwiftUI

struct iOS_EventDetailSheet: View {
    let event: GCalEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Event title
            Text(event.title)
                .font(DS.body(18, weight: .medium))
                .foregroundColor(DS.bright)

            // Time range
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                    .foregroundColor(DS.subtle)
                Text("\(event.startTime) \u{2014} \(event.endTime)")
                    .font(DS.mono(14))
                    .foregroundColor(DS.text)
            }

            // Calendar name badge
            if !event.calendarName.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(DS.subtle)
                    Text(event.calendarName)
                        .font(DS.body(13))
                        .foregroundColor(DS.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DS.muted.opacity(0.5))
                        .cornerRadius(6)
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.s2)
    }
}
#endif
