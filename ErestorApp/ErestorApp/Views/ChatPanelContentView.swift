import SwiftUI

/// Wraps ChatWebViewVC with a thin header for the floating chat panel.
struct ChatPanelContentView: View {
    @EnvironmentObject var chatService: ChatService
    @EnvironmentObject var actionHandler: ActionHandler
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Circle()
                    .fill(chatService.serverOnline ? .green : .red)
                    .frame(width: 6, height: 6)

                Text("Erestor")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#d4c4b8"))

                if let timer = chatService.context?.timer {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.system(size: 9))
                        Text("\(timer.desc) \(timer.minutes)m")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(.orange)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "#7a6e66"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(hex: "#352e2c"))

            // Chat content
            ChatWebViewVC()
                .environmentObject(chatService)
                .environmentObject(actionHandler)
                .onReceive(chatService.$actions) { actions in
                    guard !actions.isEmpty else { return }
                    actionHandler.execute(actions)
                }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#2a2422"))
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(hex: "#4a3f3c").opacity(0.6), lineWidth: 1)
        )
        .task {
            await chatService.loadContext()
        }
    }
}
