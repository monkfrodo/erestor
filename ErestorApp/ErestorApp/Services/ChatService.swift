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
    private var streamTask: Task<Void, Never>?

    init() {
        Task { await checkStatus() }
    }

    // MARK: - Streaming send (SSE)

    func sendMessageStreaming(_ text: String) async {
        let userMsg = ChatMessage(
            role: .user,
            text: text,
            timestamp: Self.currentTime()
        )
        messages.append(userMsg)
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
        request.timeoutInterval = 120

        let body = ["message": text]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                appendErrorMessage()
                return
            }

            var accumulated = ""

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
                            actions = responseActions
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
                text: finalText,
                timestamp: Self.currentTime()
            )
            messages.append(botMsg)

            streamDelta = StreamDelta(kind: .finished, text: finalText, timestamp: Self.currentTime())
            isLoading = false
            isStreaming = false

        } catch {
            logger.error("Streaming failed: \(error.localizedDescription)")
            appendErrorMessage()
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

    func checkStatus() async {
        guard let url = URL(string: "\(baseURL)/status") else { return }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            serverOnline = (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            serverOnline = false
        }
    }

    func clearHistory() async {
        guard let url = URL(string: "\(baseURL)/reset") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try? await URLSession.shared.data(for: request)
        messages.removeAll()
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
        serverOnline = false
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
