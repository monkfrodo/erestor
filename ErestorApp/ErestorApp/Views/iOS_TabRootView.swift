#if os(iOS)
import SwiftUI
import Combine

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

            // Tab 2: Agenda (placeholder)
            Text("Agenda")
                .font(DS.body(16))
                .foregroundColor(DS.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.bg)
                .tabItem {
                    Label("Agenda", systemImage: "calendar")
                }
                .tag(2)

            // Tab 3: Insights (placeholder)
            Text("Insights")
                .font(DS.body(16))
                .foregroundColor(DS.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.bg)
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)
        }
        .tint(DS.green)
        .preferredColorScheme(.dark)
        .sheet(item: $activePoll) { poll in
            iOS_PollSheetView(poll: poll) { response in
                Task {
                    await respondToPoll(pollId: poll.pollId, value: response)
                }
                chatService.activePolls.removeAll { $0.pollId == poll.pollId }
                activePoll = nil
            }
            .presentationDetents([.fraction(0.35)])
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

// MARK: - Poll Sheet (placeholder)

struct iOS_PollSheetView: View {
    let poll: PollSSEEvent
    let onResponse: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(poll.question)
                .font(DS.body(15, weight: .medium))
                .foregroundColor(DS.bright)
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            ForEach(poll.options, id: \.self) { option in
                Button(action: { onResponse(option) }) {
                    Text(option)
                        .font(DS.body(14))
                        .foregroundColor(DS.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DS.s2)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(DS.surface)
    }
}

// MARK: - Gate Sheet (placeholder)

struct iOS_GateSheetView: View {
    let gate: GateSSEEvent
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: gate.severity == "red" ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(gate.severity == "red" ? DS.red : DS.amber)
                .padding(.top, 20)

            Text(gate.text)
                .font(DS.body(15, weight: .medium))
                .foregroundColor(DS.bright)
                .multilineTextAlignment(.center)

            if let tasks = gate.tasks, !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tasks, id: \.self) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(DS.red)
                                .frame(width: 4, height: 4)
                            Text(task)
                                .font(DS.body(12))
                                .foregroundColor(DS.text)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Button(action: onDismiss) {
                Text("Entendi")
                    .font(DS.body(14, weight: .medium))
                    .foregroundColor(DS.bright)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DS.muted)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(DS.surface)
    }
}
#endif
