#if os(iOS)
import SwiftUI

struct iOS_PainelView: View {
    @ObservedObject var chatService: ChatService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let ctx = chatService.context {
                    // Card 1: Current event
                    if let event = ctx.currentEvent {
                        VStack(spacing: 0) {
                            EventCardView(
                                title: event.title,
                                timeRange: "\(event.startTime) \u{2014} \(event.endTime)",
                                progress: eventProgress(start: event.startTime, end: event.endTime),
                                eventType: eventTypeFromTitle(event.title)
                            )
                        }
                        .background(DS.s2)
                        .cornerRadius(12)
                    }

                    // Card 2: Timer (if active)
                    if let timer = ctx.timer {
                        HStack {
                            TimerChipView(
                                elapsed: formatMinutes(timer.minutes),
                                label: timer.desc,
                                onStop: { stopTimer() }
                            )
                            Spacer()
                        }
                        .padding(16)
                        .background(DS.s2)
                        .cornerRadius(12)
                    }

                    // Card 3: Next event
                    if let next = ctx.nextEvent {
                        let minsText: String = {
                            if let mins = ctx.minsToNext {
                                if mins <= 0 { return "agora" }
                                if mins < 60 { return "\(mins)min" }
                                let h = mins / 60
                                let m = mins % 60
                                return m > 0 ? "\(h)h\(m)" : "\(h)h"
                            }
                            return timeUntil(next.startTime)
                        }()
                        NextEventView(
                            timeRemaining: minsText,
                            title: next.title
                        )
                        .background(DS.s2)
                        .cornerRadius(12)
                    }

                    // Card 4: Tasks
                    let tasks = ctx.p1Tasks + ctx.p2Tasks
                    if !tasks.isEmpty {
                        TaskListView(tasks: tasks)
                            .background(DS.s2)
                            .cornerRadius(12)
                    }
                } else {
                    // No data placeholder
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 28))
                            .foregroundColor(DS.muted)
                        Text("Sem dados")
                            .font(DS.body(14))
                            .foregroundColor(DS.subtle)
                        Text("Aguardando contexto do servidor...")
                            .font(DS.body(11))
                            .foregroundColor(DS.dim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(DS.bg)
        .refreshable {
            chatService.startEventStream()
        }
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, 0)
        }
        return String(format: "%02d:%02d", m, 0)
    }

    private func eventProgress(start: String, end: String) -> Double {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        guard let s = fmt.date(from: start),
              let e = fmt.date(from: end) else { return 0 }
        let now = Date()
        let calendar = Calendar.current
        let todayStart = calendar.dateComponents([.hour, .minute], from: s)
        let todayEnd = calendar.dateComponents([.hour, .minute], from: e)
        let todayNow = calendar.dateComponents([.hour, .minute], from: now)

        let startMin = (todayStart.hour ?? 0) * 60 + (todayStart.minute ?? 0)
        let endMin = (todayEnd.hour ?? 0) * 60 + (todayEnd.minute ?? 0)
        let nowMin = (todayNow.hour ?? 0) * 60 + (todayNow.minute ?? 0)

        guard endMin > startMin else { return 0 }
        return Double(nowMin - startMin) / Double(endMin - startMin)
    }

    private func timeUntil(_ startTime: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        guard let target = fmt.date(from: startTime) else { return "" }
        let calendar = Calendar.current
        let targetComps = calendar.dateComponents([.hour, .minute], from: target)
        let nowComps = calendar.dateComponents([.hour, .minute], from: Date())

        let targetMin = (targetComps.hour ?? 0) * 60 + (targetComps.minute ?? 0)
        let nowMin = (nowComps.hour ?? 0) * 60 + (nowComps.minute ?? 0)
        let diff = targetMin - nowMin

        if diff <= 0 { return "agora" }
        if diff < 60 { return "\(diff)min" }
        let h = diff / 60
        let m = diff % 60
        return m > 0 ? "\(h)h\(m)" : "\(h)h"
    }

    private func eventTypeFromTitle(_ title: String) -> EventType {
        let lower = title.lowercased()
        if lower.contains("descanso") || lower.contains("almoco") || lower.contains("almoco")
            || lower.contains("pausa") || lower.contains("desacelerar") || lower.contains("wind")
            || lower.contains("cafe") || lower.contains("cafe") {
            return .rest
        }
        if lower.contains("deep") || lower.contains("work") || lower.contains("foco")
            || lower.contains("reuniao") || lower.contains("reuniao") || lower.contains("mentoria")
            || lower.contains("vender") || lower.contains("construir") || lower.contains("entregar") {
            return .work
        }
        return .free
    }

    private func stopTimer() {
        Task {
            guard let url = ErestorConfig.url(for: "/api/timer/stop") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 10
            ErestorConfig.authorize(&request)
            _ = try? await URLSession.shared.data(for: request)
        }
    }
}
#endif
