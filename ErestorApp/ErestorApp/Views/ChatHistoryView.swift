import SwiftUI

struct ChatHistoryView: View {
    let messages: [ChatMessage]
    let isStreaming: Bool

    private let bottomAnchorID = "chat-bottom-anchor"

    var body: some View {
        if !messages.isEmpty {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(messages) { msg in
                            ChatMessageView(message: msg)
                                .id(msg.id)
                        }

                        // Invisible anchor at the bottom for auto-scroll
                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .onChange(of: messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                }
                .onChange(of: messages.last?.text) { _ in
                    // Also scroll when streaming appends text to the last message
                    if isStreaming {
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                }
            }
        }
    }
}
