import SwiftUI
import Combine

struct ContextPanelView: View {
    @ObservedObject var chatService: ChatService
    var onClose: (() -> Void)? = nil

    @State private var activePoll: ActivePoll?
    @State private var activeGate: ActiveGate?
    private let pushObserver = NotificationCenter.default.publisher(for: .erestorPushMessageReceived)

    struct ActivePoll {
        let type: PollType
        let question: String
    }

    struct ActiveGate {
        let text: String
        let severity: GateSeverity
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Event card
            if let event = chatService.context?.currentEvent {
                EventCardView(
                    title: event.title,
                    timeRange: "\(event.start) \u{2014} \(event.end)",
                    progress: eventProgress(start: event.start, end: event.end),
                    eventType: eventTypeFromTitle(event.title)
                )

                // Timer chip (if active)
                if let timer = chatService.context?.timer {
                    TimerChipView(
                        elapsed: formatMinutes(timer.minutes),
                        label: timer.desc,
                        onStop: { stopTimer() }
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }

            separator

            // Next event
            if let next = chatService.context?.nextEvent {
                NextEventView(
                    timeRemaining: timeUntil(next.start),
                    title: "\(next.title)"
                )
                separator
            }

            // Tasks
            if let tasks = chatService.context?.p1Tasks, !tasks.isEmpty {
                TaskListView(tasks: tasks)
                separator
            }

            // Dynamic cards (poll / gate)
            if let poll = activePoll {
                PollCardView(type: poll.type, question: poll.question) { response in
                    Task {
                        await chatService.sendMessageStreaming("energia: \(response)")
                    }
                    activePoll = nil
                }
            }

            if let gate = activeGate {
                GateAlertView(
                    text: gate.text,
                    severity: gate.severity,
                    actions: [
                        GateAlertAction(label: "trocar timer") {
                            Task { await chatService.sendMessageStreaming("trocar timer") }
                            activeGate = nil
                        },
                        GateAlertAction(label: "ignorar") {
                            activeGate = nil
                        }
                    ]
                )
            }

            Spacer(minLength: 0)

            // Chat history
            ChatHistoryView(messages: chatService.messages)

            #if os(iOS)
            // Day timeline (iOS only)
            if let events = chatService.context?.todayEvents, !events.isEmpty {
                DayTimelineView(events: events)
                separator
            }
            #endif

            // Chat input
            ChatInputView { text in
                Task {
                    await chatService.sendMessageStreaming(text)
                }
            }
        }
        #if os(macOS)
        .frame(width: 288)
        #endif
        .background(DS.surface)
        #if os(macOS)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DS.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 16)
        #endif
        .onReceive(pushObserver) { notification in
            handlePush(notification)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 7) {
                Circle()
                    .fill(chatService.serverOnline ? DS.green : DS.muted)
                    .frame(width: 5, height: 5)

                Text(currentTimeString())
                    .font(DS.mono(10))
                    .foregroundColor(DS.subtle)
            }

            Spacer()

            if let onClose {
                Button(action: onClose) {
                    Text("\u{00d7}")
                        .font(.system(size: 13))
                        .foregroundColor(DS.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 0)
    }

    private var separator: some View {
        Rectangle()
            .fill(DS.border)
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    // MARK: - Push event handling

    private func handlePush(_ notification: Notification) {
        guard let info = notification.userInfo,
              let eventType = info["eventType"] as? String else { return }

        switch eventType {
        case "poll_energy":
            let text = info["text"] as? String ?? "Como ta a energia?"
            withAnimation { activePoll = ActivePoll(type: .energy, question: text) }

        case "poll_quality":
            let text = info["text"] as? String ?? "Como foi esse bloco?"
            withAnimation { activePoll = ActivePoll(type: .quality, question: text) }

        case "gate_inform":
            let text = info["text"] as? String ?? "Alerta"
            let sev = (info["severity"] as? String) == "red" ? GateSeverity.red : .amber
            withAnimation { activeGate = ActiveGate(text: text, severity: sev) }

        default:
            break
        }
    }

    // MARK: - Helpers

    private func currentTimeString() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        fmt.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        fmt.dateFormat = "EEE HH:mm"
        return fmt.string(from: Date()).lowercased().replacingOccurrences(of: ".", with: "")
    }

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
        if lower.contains("descanso") || lower.contains("almoco") || lower.contains("almoço")
            || lower.contains("pausa") || lower.contains("desacelerar") || lower.contains("wind") {
            return .rest
        }
        if lower.contains("deep") || lower.contains("work") || lower.contains("foco")
            || lower.contains("reuniao") || lower.contains("reunião") || lower.contains("mentoria") {
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
