import SwiftUI
import MarkdownUI

struct ChatMessageView: View {
    let message: ChatMessage

    @State private var cursorOpacity: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Role label
            Text(message.role == .user ? "kevin" : "erestor")
                .font(DS.mono(9))
                .foregroundColor(DS.muted)

            if message.role == .user {
                // User messages: plain text
                Text(message.text)
                    .font(DS.body(11.5))
                    .foregroundColor(DS.subtle)
                    .lineSpacing(1.5)
                    .textSelection(.enabled)
            } else if message.isStreaming {
                // Streaming assistant message: plain Text (avoids MarkdownUI re-parsing per token)
                HStack(alignment: .bottom, spacing: 0) {
                    Text(message.text)
                        .font(DS.body(11.5))
                        .foregroundColor(DS.text)
                        .lineSpacing(1.5)

                    // Blinking cursor
                    Text("|")
                        .font(DS.mono(11.5))
                        .foregroundColor(DS.green)
                        .opacity(cursorOpacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                                cursorOpacity = 0.2
                            }
                        }
                }
            } else {
                // Completed assistant message: full markdown rendering
                Markdown(message.text)
                    .markdownTheme(.erestor)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Custom Erestor Markdown Theme (Vesper Dark)

extension MarkdownUI.Theme {
    static let erestor = Theme()
        .text {
            ForegroundColor(DS.text)
            FontSize(11.5)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(10.5)
            ForegroundColor(DS.bright)
            BackgroundColor(DS.bg)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(14)
                    ForegroundColor(DS.bright)
                }
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(13)
                    ForegroundColor(DS.bright)
                }
                .markdownMargin(top: 6, bottom: 3)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(12)
                    ForegroundColor(DS.bright)
                }
                .markdownMargin(top: 4, bottom: 2)
        }
        .strong {
            ForegroundColor(DS.bright)
        }
        .link {
            ForegroundColor(DS.blue)
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(10.5)
                    ForegroundColor(DS.bright)
                }
                .padding(8)
                .background(DS.bg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DS.border, lineWidth: 1)
                )
                .markdownMargin(top: 4, bottom: 4)
        }
        .listItem { configuration in
            configuration.label
                .markdownTextStyle {
                    ForegroundColor(DS.text)
                }
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
}
