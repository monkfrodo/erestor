import Foundation
import os

private let logger = Logger(subsystem: "org.integros.erestor", category: "ChatService")

@MainActor
class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var context: ContextSummary?
    @Published var serverOnline = false
    @Published var actions: [ChatAction] = []

    // Streaming state -- observed by ChatWebViewVC to push tokens to WebView
    @Published var isStreaming = false
    @Published var streamDelta: StreamDelta?

    private let baseURL = "http://127.0.0.1:8766"
    private var statusTask: Task<Void, Never>?

    deinit {
        statusTask?.cancel()
    }

    init() {
        // DEBUG: all init activity disabled to isolate focus stealing
    }

    /// Network call runs completely OFF MainActor — no focus stealing
    private nonisolated static func pollStatus(baseURL: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/status") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Only touches MainActor to update state — minimal main thread work
    private func applyStatusResult(_ online: Bool) {
        if online {
            if !serverOnline { serverOnline = true }
            lastSuccessfulRequest = Date()
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
            let recentSuccess = Date().timeIntervalSince(lastSuccessfulRequest) < 30
            if consecutiveFailures >= 3 && !recentSuccess {
                if serverOnline { serverOnline = false }
            }
        }
    }

    // MARK: - Streaming send (SSE)

    func sendMessageStreaming(_ text: String) async {
        let userMsg = ChatMessage(
            role: .user,
            text: text,
            timestamp: Self.currentTime()
        )
        messages.append(userMsg)
        actions = []
        isLoading = true
        isStreaming = true
        streamDelta = StreamDelta(kind: .started, text: "", timestamp: Self.currentTime())

        guard let url = URL(string: "\(baseURL)/chat/stream") else {
            isLoading = false
            isStreaming = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300  // 5 min — keepalives every 15s reset idle timer

        let body = ["message": text]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                appendErrorMessage()
                return
            }

            serverOnline = true
            lastSuccessfulRequest = Date()
            var accumulated = ""
            var pendingActions: [ChatAction] = []

            for try await line in bytes.lines {
                // SSE format: lines starting with "data: " contain JSON
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))

                guard let jsonData = jsonStr.data(using: .utf8) else { continue }

                // Try to decode as a chunk event
                if let chunk = try? JSONDecoder().decode(SSEChunk.self, from: jsonData) {
                    if let done = chunk.done, done {
                        // Final event -- contains full_response and actions
                        if let fullResponse = chunk.fullResponse {
                            accumulated = fullResponse
                        }
                        if let responseActions = chunk.actions {
                            pendingActions = responseActions
                        }
                    } else if let chunkText = chunk.text {
                        // Intermediate token chunk
                        accumulated += chunkText
                        streamDelta = StreamDelta(kind: .delta, text: chunkText, timestamp: "")
                    } else if let error = chunk.error {
                        logger.error("SSE error from server: \(error)")
                        accumulated += "\n[Erro: \(error)]"
                    }
                }
            }

            // Streaming done -- add the complete assistant message
            let finalText = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
            let botMsg = ChatMessage(
                role: .assistant,
                text: finalText.isEmpty ? "..." : finalText,
                timestamp: Self.currentTime()
            )
            messages.append(botMsg)

            // ALWAYS publish .finished BEFORE actions -- this ensures
            // finalizeStream() runs and re-enables the input field before
            // any action (AppleScript, Process, etc.) can block the main thread.
            streamDelta = StreamDelta(kind: .finished, text: botMsg.text, timestamp: Self.currentTime())
            isLoading = false
            isStreaming = false

            // Now publish actions -- observers will execute them after
            // the stream UI has been fully finalized
            if !pendingActions.isEmpty {
                actions = pendingActions
            }

        } catch {
            logger.error("Streaming failed: \(error.localizedDescription)")
            // If the server was recently online, don't show connection error —
            // likely just a slow Claude CLI response that timed out
            let recentlyOnline = Date().timeIntervalSince(lastSuccessfulRequest) < 60
            if recentlyOnline {
                let timeoutMsg = ChatMessage(
                    role: .assistant,
                    text: "A resposta demorou demais e foi interrompida. Tenta de novo com uma mensagem mais curta.",
                    timestamp: Self.currentTime()
                )
                messages.append(timeoutMsg)
                streamDelta = StreamDelta(kind: .finished, text: timeoutMsg.text, timestamp: timeoutMsg.timestamp)
                isLoading = false
                isStreaming = false
            } else {
                appendErrorMessage()
            }
        }
    }

    // MARK: - Non-streaming send (legacy fallback)

    func sendMessage(_ text: String) async {
        let userMsg = ChatMessage(
            role: .user,
            text: text,
            timestamp: Self.currentTime()
        )
        messages.append(userMsg)
        actions = []
        isLoading = true

        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/chat") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body = ["message": text]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(ChatResponse.self, from: data)
            let botMsg = ChatMessage(
                role: .assistant,
                text: response.response,
                timestamp: response.timestamp ?? Self.currentTime()
            )
            messages.append(botMsg)
            if let responseActions = response.actions {
                actions = responseActions
            }
        } catch {
            appendErrorMessage()
        }
    }

    // MARK: - Other endpoints

    func loadContext() async {
        guard let url = URL(string: "\(baseURL)/context") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            context = try JSONDecoder().decode(ContextSummary.self, from: data)
        } catch {
            context = nil
        }
    }

    private var lastSuccessfulRequest: Date = .distantPast
    private var consecutiveFailures = 0

    func checkStatus() async {
        let online = await Self.pollStatus(baseURL: baseURL)
        applyStatusResult(online)
    }

    func clearHistory() async {
        guard let url = URL(string: "\(baseURL)/reset") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try? await URLSession.shared.data(for: request)
        messages.removeAll()
    }

    // MARK: - Load history from backend

    func loadHistory() async {
        guard let url = URL(string: "\(baseURL)/history") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            struct HistoryResponse: Codable {
                let history: [[String: String]]
            }

            let decoded = try JSONDecoder().decode(HistoryResponse.self, from: data)
            guard !decoded.history.isEmpty else { return }

            var loaded: [ChatMessage] = []
            for entry in decoded.history {
                if let userText = entry["u"] {
                    loaded.append(ChatMessage(role: .user, text: userText, timestamp: ""))
                }
                if let botText = entry["b"] {
                    loaded.append(ChatMessage(role: .assistant, text: botText, timestamp: ""))
                }
            }
            // Only populate if messages is still empty (avoid duplicates on re-call)
            if messages.isEmpty {
                messages = loaded
            }
        } catch {
            logger.warning("Failed to load history: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func appendErrorMessage() {
        let errorMsg = ChatMessage(
            role: .assistant,
            text: "Erro de conexao com o servidor local. Verifica se o erestor_local.py ta rodando.",
            timestamp: Self.currentTime()
        )
        messages.append(errorMsg)
        streamDelta = StreamDelta(kind: .finished, text: errorMsg.text, timestamp: errorMsg.timestamp)
        // Respect the 3-consecutive-failures guard instead of instantly marking offline
        consecutiveFailures += 1
        if consecutiveFailures >= 3 {
            serverOnline = false
        }
        isLoading = false
        isStreaming = false
    }

    private static func currentTime() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        return fmt.string(from: Date())
    }
}

// MARK: - SSE Models

/// Represents a single SSE data event from /chat/stream
private struct SSEChunk: Codable {
    let text: String?
    let done: Bool?
    let fullResponse: String?
    let actions: [ChatAction]?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case text, done, actions, error
        case fullResponse = "full_response"
    }
}

private struct ChatResponse: Codable {
    let response: String
    let timestamp: String?
    let actions: [ChatAction]?
}

/// Published to notify the WebView of streaming state changes
struct StreamDelta: Equatable {
    enum Kind: Equatable {
        case started   // stream began -- create the message container
        case delta     // new token chunk arrived
        case finished  // stream complete -- finalize rendering
    }

    let id = UUID()
    let kind: Kind
    let text: String
    let timestamp: String

    static func == (lhs: StreamDelta, rhs: StreamDelta) -> Bool {
        // Always trigger update by using unique id
        return lhs.id == rhs.id
    }
}
