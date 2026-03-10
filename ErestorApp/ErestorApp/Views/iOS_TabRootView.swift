#if os(iOS)
import SwiftUI
import Combine
import UserNotifications

struct iOS_TabRootView: View {
    @ObservedObject var chatService: ChatService
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab = 0
    @State private var activePoll: PollSSEEvent?
    @State private var activeGate: GateSSEEvent?

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Painel
            iOS_PainelView(chatService: chatService)
                .tabItem {
                    Label("Painel", systemImage: "square.grid.2x2")
                }
                .tag(0)

            // Tab 1: Chat
            VStack(spacing: 0) {
                ChatHistoryView(messages: chatService.messages, isStreaming: chatService.isStreaming)
                    .frame(maxHeight: .infinity)

                ChatInputView { text in
                    Task {
                        await chatService.sendMessageStreaming(text)
                    }
                }
                .disabled(chatService.isStreaming)
            }
            .background(DS.surface)
            .tabItem {
                Label("Chat", systemImage: "bubble.left")
            }
            .tag(1)

            // Tab 2: Agenda
            iOS_AgendaView(chatService: chatService)
                .tabItem {
                    Label("Agenda", systemImage: "calendar")
                }
                .tag(2)

            // Tab 3: Insights
            iOS_InsightsView(chatService: chatService)
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)
        }
        .tint(DS.green)
        .preferredColorScheme(.dark)
        .sheet(item: $activePoll) { poll in
            iOS_PollSheetView(poll: poll) { response in
                if response == "remind_10" {
                    scheduleReminder(for: poll)
                } else {
                    Task {
                        await respondToPoll(pollId: poll.pollId, value: response)
                    }
                }
                chatService.activePolls.removeAll { $0.pollId == poll.pollId }
                activePoll = nil
            }
            .presentationDetents([.fraction(0.4)])
        }
        .sheet(item: $activeGate) { gate in
            iOS_GateSheetView(gate: gate) {
                withAnimation {
                    chatService.activeGates.removeAll { $0.id == gate.id }
                }
                activeGate = nil
            }
            .presentationDetents([.medium])
        }
        .onReceive(chatService.$activePolls) { polls in
            if activePoll == nil, let first = polls.first {
                activePoll = first
            }
        }
        .onReceive(chatService.$activeGates) { gates in
            if activeGate == nil, let first = gates.first {
                activeGate = first
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                chatService.startEventStream()
            case .background:
                chatService.stopEventStream()
            default:
                break
            }
        }
    }

    // MARK: - Remind in 10min

    private func scheduleReminder(for poll: PollSSEEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Erestor"
        content.body = poll.question
        content.sound = .default
        content.categoryIdentifier = poll.pollType == "energy" ? "POLL_ENERGY" : "POLL_QUALITY"
        content.userInfo = ["poll_id": poll.pollId, "poll_type": poll.pollType]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(poll.pollId)_reminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("[Erestor-iOS] Reminder schedule failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Poll response

    private func respondToPoll(pollId: String, value: String) async {
        guard let url = ErestorConfig.url(for: "\(ErestorConfig.pollsPath)/\(pollId)/respond") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        ErestorConfig.authorize(&request)
        let body = ["value": value]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }
}
#endif
