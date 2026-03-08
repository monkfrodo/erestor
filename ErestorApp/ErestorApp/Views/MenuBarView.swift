import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var chatService: ChatService
    @State private var quickInput = ""

    var body: some View {
        VStack(spacing: 10) {
            // Status
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(chatService.serverOnline ? .green : .red)
                        .frame(width: 6, height: 6)
                    Text(chatService.serverOnline ? "Online" : "Offline")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let timer = chatService.context?.timer {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption2)
                        Text("\(timer.desc) \(timer.minutes)min")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                }
            }

            // Quick input
            HStack(spacing: 8) {
                TextField("Mensagem rápida...", text: $quickInput)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .onSubmit { sendQuick() }

                Button(action: sendQuick) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(quickInput.trimmingCharacters(in: .whitespaces).isEmpty ? .gray.opacity(0.4) : .blue)
                }
                .buttonStyle(.plain)
                .disabled(quickInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Last response
            if let last = chatService.messages.last(where: { $0.role == .assistant }) {
                Text(last.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()
                .opacity(0.5)

            Button {
                BubbleWindowController.shared.showChat()
            } label: {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                    Text("Abrir Erestor")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
        .padding(14)
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .task {
            await chatService.checkStatus()
            await chatService.loadContext()
        }
    }

    private func sendQuick() {
        let text = quickInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        quickInput = ""
        Task { await chatService.sendMessage(text) }
    }
}
