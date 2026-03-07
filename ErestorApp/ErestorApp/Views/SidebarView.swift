import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var chatService: ChatService

    var body: some View {
        VStack(spacing: 0) {
            // Header integrado (substitui toolbar)
            HStack(spacing: 6) {
                Text("erestor")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#4a9f68"))
                Spacer()
                Circle()
                    .fill(chatService.serverOnline ? Color(hex: "#4a9f68") : Color(hex: "#6a3030"))
                    .frame(width: 5, height: 5)
                Text(chatService.serverOnline ? "on" : "off")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(hex: "#333"))
            }
            .padding(.horizontal, 14)
            .padding(.top, 38) // space for traffic lights
            .padding(.bottom, 10)

            Divider()
                .background(Color(hex: "#1a1a20"))

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    if let ctx = chatService.context {

                        // Timer ativo
                        if let timer = ctx.timer {
                            TerminalCard {
                                HStack(spacing: 6) {
                                    Text(">>")
                                        .foregroundStyle(Color(hex: "#d4a06a"))
                                    Text("\(timer.desc) — \(timer.minutes)min")
                                }
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(hex: "#888"))
                            }
                        }

                        // Proximo evento
                        if let event = ctx.nextEvent {
                            TerminalCard {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#a0a0a0"))
                                    Text("\(event.start) – \(event.end)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#3a3a42"))
                                }
                            }
                        }

                        // P1 tasks
                        if let tasks = ctx.p1Tasks, !tasks.isEmpty {
                            TerminalCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("# p1")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#4a9f68"))
                                    ForEach(tasks, id: \.self) { task in
                                        HStack(alignment: .top, spacing: 5) {
                                            Text("-")
                                                .foregroundStyle(Color(hex: "#3a3a42"))
                                            Text(task)
                                                .foregroundStyle(Color(hex: "#777"))
                                        }
                                        .font(.system(size: 10, design: .monospaced))
                                    }
                                }
                            }
                        }

                        // Agenda
                        if let gcal = ctx.gcal, !gcal.isEmpty {
                            TerminalCard {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("# agenda")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#4a9f68"))
                                    Text(gcal)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#777"))
                                        .lineLimit(10)
                                }
                            }
                        }

                    } else {
                        Text("carregando...")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(hex: "#2a2a32"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }

                    // Atalhos
                    VStack(alignment: .leading, spacing: 1) {
                        Text("# atalhos")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#4a9f68"))
                            .padding(.leading, 4)
                            .padding(.bottom, 4)

                        TerminalAction(label: "briefing") {
                            Task { await chatService.sendMessage("briefing") }
                        }
                        TerminalAction(label: "tarefas") {
                            Task { await chatService.sendMessage("tarefas") }
                        }
                        TerminalAction(label: "agenda") {
                            Task { await chatService.sendMessage("agenda") }
                        }
                        TerminalAction(label: "status") {
                            Task { await chatService.sendMessage("status") }
                        }
                    }
                }
                .padding(12)
            }

            // Bottom bar
            Divider()
                .background(Color(hex: "#1a1a20"))

            HStack {
                Text("clear")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#2a2a32"))
                    .onTapGesture { Task { await chatService.clearHistory() } }

                Spacer()

                if let ts = chatService.context?.timestamp {
                    Text("[\(ts)]")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Color(hex: "#1a1a20"))
                }

                Spacer()

                Text("sync")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#2a2a32"))
                    .onTapGesture { Task { await chatService.loadContext() } }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color.clear)
    }
}

// MARK: - Terminal Card

struct TerminalCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(hex: "#0d0d10"))
            .overlay(
                Rectangle()
                    .stroke(Color(hex: "#1a1a20"), lineWidth: 1)
            )
    }
}

// MARK: - Terminal Action Row

struct TerminalAction: View {
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            Text("~$ ")
                .foregroundColor(Color(hex: "#4a9f68").opacity(0.6))
            Text(label)
                .foregroundColor(hovering ? Color(hex: "#e0e0e0") : Color(hex: "#9a9a9a"))
        }
        .font(.system(size: 10, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(hovering ? Color(hex: "#111114") : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { action() }
        .onHover { h in
            withAnimation(.easeOut(duration: 0.08)) { hovering = h }
        }
    }
}

