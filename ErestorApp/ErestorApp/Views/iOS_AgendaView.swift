#if os(iOS)
import SwiftUI

struct iOS_AgendaView: View {
    @ObservedObject var chatService: ChatService

    @State private var selectedDate = Date()
    @State private var currentPage = 1  // 0=yesterday, 1=today, 2=tomorrow
    @State private var selectedEvent: GCalEvent?

    private let hourHeight: CGFloat = 60
    private let startHour = 6
    private let endHour = 23

    var body: some View {
        VStack(spacing: 0) {
            // Date header
            HStack {
                Text(formattedDate(selectedDate))
                    .font(DS.body(18, weight: .medium))
                    .foregroundColor(DS.bright)
                Spacer()
                if Calendar.current.isDateInToday(selectedDate) {
                    Text("Hoje")
                        .font(DS.mono(11))
                        .foregroundColor(DS.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DS.green.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Swipe pages
            TabView(selection: $currentPage) {
                dayPage(offset: -1).tag(0)
                dayPage(offset: 0).tag(1)
                dayPage(offset: 1).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentPage) { newPage in
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                selectedDate = calendar.date(byAdding: .day, value: newPage - 1, to: today) ?? today
            }
        }
        .background(DS.bg)
        .sheet(item: $selectedEvent) { event in
            iOS_EventDetailSheet(event: event)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Day Page

    @ViewBuilder
    private func dayPage(offset: Int) -> some View {
        let dayDate = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let isToday = Calendar.current.isDateInToday(dayDate)
        let events = isToday ? (chatService.context?.todayEvents ?? []) : []

        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid lines
                    VStack(spacing: 0) {
                        ForEach(startHour..<endHour, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 8) {
                                Text(String(format: "%02d:00", hour))
                                    .font(DS.mono(10))
                                    .foregroundColor(DS.dim)
                                    .frame(width: 40, alignment: .trailing)

                                VStack {
                                    Divider()
                                        .background(DS.border)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(height: hourHeight)
                            .id(hour)
                        }
                    }

                    // Event blocks
                    let leftInset: CGFloat = 56
                    ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                        let yOffset = yPosition(for: event)
                        let height = eventHeight(for: event)
                        let isCurrent = isCurrentEvent(event)

                        Button {
                            selectedEvent = event
                        } label: {
                            eventBlock(event: event, isCurrent: isCurrent, height: height)
                        }
                        .buttonStyle(.plain)
                        .offset(x: leftInset, y: yOffset)
                        .frame(width: UIScreen.main.bounds.width - leftInset - 24)
                    }

                    // Current time indicator (red line)
                    if isToday {
                        let nowY = currentTimeYOffset()
                        HStack(spacing: 0) {
                            Circle()
                                .fill(DS.red)
                                .frame(width: 8, height: 8)
                            Rectangle()
                                .fill(DS.red)
                                .frame(height: 1.5)
                        }
                        .offset(x: 44, y: nowY)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .onAppear {
                if isToday {
                    let currentHour = Calendar.current.component(.hour, from: Date())
                    let scrollTo = max(startHour, currentHour - 1)
                    proxy.scrollTo(scrollTo, anchor: .top)
                }
            }
        }
    }

    // MARK: - Event Block

    @ViewBuilder
    private func eventBlock(event: GCalEvent, isCurrent: Bool, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(DS.body(isCurrent ? 14 : 12, weight: isCurrent ? .medium : .regular))
                .foregroundColor(isCurrent ? DS.bright : DS.text)
                .lineLimit(isCurrent ? 2 : 1)

            Text("\(event.startTime) \u{2014} \(event.endTime)")
                .font(DS.mono(10))
                .foregroundColor(DS.subtle)

            if isCurrent {
                // Progress bar
                let progress = eventProgress(event)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DS.border)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DS.green)
                            .frame(width: geo.size.width * max(0, min(1, progress)), height: 3)
                    }
                }
                .frame(height: 3)

                // Tasks for current event
                if let tasks = chatService.context?.activeP1s, !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(tasks.prefix(3), id: \.title) { task in
                            HStack(spacing: 6) {
                                Circle()
                                    .strokeBorder(DS.subtle, lineWidth: 1)
                                    .frame(width: 10, height: 10)
                                Text(task.title)
                                    .font(DS.body(11))
                                    .foregroundColor(DS.text)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(isCurrent ? 12 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: height, alignment: .top)
        .background(isCurrent ? DS.green.opacity(0.12) : DS.s2)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isCurrent ? DS.green.opacity(0.3) : DS.border, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        fmt.dateFormat = "EEE, d MMM yyyy"
        var result = fmt.string(from: date)
        // Capitalize first letter
        if let first = result.first {
            result = first.uppercased() + result.dropFirst()
        }
        return result
    }

    private func yPosition(for event: GCalEvent) -> CGFloat {
        guard let startStr = event.start?.dateTime else { return 0 }
        let comps = extractHourMinute(from: startStr)
        let fractionalHour = Double(comps.hour) + Double(comps.minute) / 60.0
        return CGFloat(fractionalHour - Double(startHour)) * hourHeight
    }

    private func eventHeight(for event: GCalEvent) -> CGFloat {
        guard let startStr = event.start?.dateTime,
              let endStr = event.end?.dateTime else { return 30 }
        let startComps = extractHourMinute(from: startStr)
        let endComps = extractHourMinute(from: endStr)
        let startMins = startComps.hour * 60 + startComps.minute
        let endMins = endComps.hour * 60 + endComps.minute
        let durationHours = Double(endMins - startMins) / 60.0
        return max(30, CGFloat(durationHours) * hourHeight)
    }

    private func isCurrentEvent(_ event: GCalEvent) -> Bool {
        guard let current = chatService.context?.currentEvent else { return false }
        return event.summary == current.summary && event.startTime == current.startTime
    }

    private func eventProgress(_ event: GCalEvent) -> Double {
        let startStr = event.startTime
        let endStr = event.endTime
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        guard let s = fmt.date(from: startStr),
              let e = fmt.date(from: endStr) else { return 0 }
        let cal = Calendar.current
        let sComps = cal.dateComponents([.hour, .minute], from: s)
        let eComps = cal.dateComponents([.hour, .minute], from: e)
        let nComps = cal.dateComponents([.hour, .minute], from: Date())
        let startMin = (sComps.hour ?? 0) * 60 + (sComps.minute ?? 0)
        let endMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
        let nowMin = (nComps.hour ?? 0) * 60 + (nComps.minute ?? 0)
        guard endMin > startMin else { return 0 }
        return Double(nowMin - startMin) / Double(endMin - startMin)
    }

    private func currentTimeYOffset() -> CGFloat {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let fractional = Double(hour) + Double(minute) / 60.0
        return CGFloat(fractional - Double(startHour)) * hourHeight
    }

    private func extractHourMinute(from iso: String) -> (hour: Int, minute: Int) {
        // "2026-03-09T21:30:00-03:00" -> hour=21, minute=30
        guard let tIdx = iso.firstIndex(of: "T") else { return (0, 0) }
        let timePart = iso[iso.index(after: tIdx)...]
        let parts = timePart.prefix(5).split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return (0, 0) }
        return (h, m)
    }
}

// MARK: - Make GCalEvent Identifiable for sheet presentation

extension GCalEvent: Identifiable {
    var id: String {
        "\(summary ?? "")-\(start?.dateTime ?? "")"
    }
}
#endif
