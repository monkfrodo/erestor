import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatService: ChatService
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if chatService.messages.isEmpty {
                            emptyState
                        }

                        ForEach(chatService.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }

                        if chatService.isLoading {
                            HStack(spacing: 8) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tint)
                                    .symbolEffect(.pulse)
                                Text("Pensando...")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)
                            .id("loading")
                        }
                    }
                    .padding(20)
                }
                .onChange(of: chatService.messages.count) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if let last = chatService.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input bar
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Fala comigo...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .onSubmit {
                        if canSend { send() }
                    }

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(canSend ? Color.accentColor : Color.primary.opacity(0.12))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .onAppear { inputFocused = true }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatService.isLoading
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task { await chatService.sendMessageStreaming(text) }
    }

    // MARK: - Welcome

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image(systemName: "brain.head.profile")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tint)

            VStack(spacing: 6) {
                Text("Erestor")
                    .font(.system(size: 18, weight: .bold))
                Text("Seu assistente pessoal, agora no desktop.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                welcRow(icon: "calendar", title: "Agenda e tarefas", desc: "Briefing, P1s, eventos")
                welcRow(icon: "bell.badge.fill", title: "Lembretes nativos", desc: "Notificacoes do macOS")
                welcRow(icon: "terminal.fill", title: "Abrir projetos", desc: "Claude Code no diretorio certo")
                welcRow(icon: "link", title: "Abrir URLs", desc: "Notion, calendario, links")
                welcRow(icon: "command", title: "Atalho global", desc: "Cmd+Shift+E de qualquer app")
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

            Text("Digita qualquer coisa pra comecar.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: 360)
    }

    private func welcRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    private var rendered: AttributedString {
        (try? AttributedString(
            markdown: message.text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(message.text)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 80) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                if message.role == .user {
                    Text(rendered)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 14))
                } else {
                    Text(rendered)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                }

                Text(message.timestamp)
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 4)
            }

            if message.role == .assistant { Spacer(minLength: 80) }
        }
    }
}
