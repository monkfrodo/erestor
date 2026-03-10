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

            ScrollView {
                VStack(spacing: 0) {
                    // Current event card (with timer inside, matching prototype)
                    if let event = chatService.context?.currentEvent {
                        EventCardView(
                            title: event.title,
                            timeRange: "\(event.startTime) \u{2014} \(event.endTime)",
                            progress: eventProgress(start: event.startTime, end: event.endTime),
                            eventType: eventTypeFromTitle(event.title)
                        )

                        // Timer chip lives inside the event section
                        if let timer = chatService.context?.timer {
                            TimerChipView(
                                elapsed: formatMinutes(timer.minutes),
                                label: timer.desc,
                                onStop: { stopTimer() }
                            )
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                        }
                    } else if chatService.context?.timer != nil {
                        // Timer without event
                        if let timer = chatService.context?.timer {
                            TimerChipView(
                                elapsed: formatMinutes(timer.minutes),
                                label: timer.desc,
                                onStop: { stopTimer() }
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                    }

                    // Dynamic cards (poll / gate) — appear right after event
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

                    // Next event
                    if let next = chatService.context?.nextEvent {
                        separator
                        let minsText: String = {
                            if let mins = chatService.context?.minsToNext {
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
                    }

                    // P1 Tasks
                    if let ctx = chatService.context, !ctx.p1Tasks.isEmpty {
                        separator
                        TaskListView(tasks: ctx.p1Tasks)
                    }
                }
            }

            Spacer(minLength: 0)

            // Chat history (expands upward when messages exist)
            ChatHistoryView(messages: chatService.messages, isStreaming: chatService.isStreaming)

            // Chat input — always at bottom, disabled during streaming
            ChatInputView { text in
                Task {
                    await chatService.sendMessageStreaming(text)
                }
            }
            .disabled(chatService.isStreaming)
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
            || lower.contains("pausa") || lower.contains("desacelerar") || lower.contains("wind")
            || lower.contains("café") || lower.contains("cafe") {
            return .rest
        }
        if lower.contains("deep") || lower.contains("work") || lower.contains("foco")
            || lower.contains("reuniao") || lower.contains("reunião") || lower.contains("mentoria")
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
