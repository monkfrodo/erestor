import SwiftUI

struct ChatHistoryView: View {
    let messages: [ChatMessage]

    var body: some View {
        if !messages.isEmpty {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(messages) { msg in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(msg.role == .user ? "kevin" : "erestor")
                                    .font(DS.mono(9))
                                    .foregroundColor(DS.muted)

                                Text(msg.text)
                                    .font(DS.body(11.5))
                                    .foregroundColor(msg.role == .user ? DS.subtle : DS.text)
                                    .lineSpacing(1.5)
                            }
                            .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 180)
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}
