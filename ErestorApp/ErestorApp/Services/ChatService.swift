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

    private var statusTask: Task<Void, Never>?
    private var pushTask: Task<Void, Never>?

    deinit {
        statusTask?.cancel()
        pushTask?.cancel()
    }

    init() {
        startStatusPolling()
        startPushPolling()
    }

    /// Network call runs completely OFF MainActor — no focus stealing
    private nonisolated static func pollStatus() async -> Bool {
        guard let url = ErestorConfig.url(for: "/api/status") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        ErestorConfig.authorize(&request)
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

        guard let url = ErestorConfig.url(for: "/api/chat/stream") else {
            isLoading = false
            isStreaming = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300  // 5 min
        ErestorConfig.authorize(&request)

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

            for try await line in bytes.lines {
                // SSE format: lines starting with "data: " contain JSON
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))

                guard let jsonData = jsonStr.data(using: .utf8) else { continue }

                // Try to decode as a chunk event
                let chunk: SSEChunk?
                do {
                    chunk = try JSONDecoder().decode(SSEChunk.self, from: jsonData)
                } catch {
                    logger.error("SSE decode failed: \(error.localizedDescription) — raw: \(jsonStr.prefix(200))")
                    chunk = nil
                }
                if let chunk {
                    if let done = chunk.done, done {
                        NSLog("[Erestor] DONE event received, actions count: \(chunk.actions?.count ?? -1)")
                        if let fullResponse = chunk.fullResponse {
                            accumulated = fullResponse
                        }
                        // API sends "responses" array — join if full_response is nil
                        if accumulated.isEmpty, let responses = chunk.responses {
                            accumulated = responses.joined(separator: "\n\n")
                        }
                        // Execute actions IMMEDIATELY inside the loop
                        if let responseActions = chunk.actions, !responseActions.isEmpty {
                            NSLog("[Erestor] Publishing actions NOW: \(responseActions.map { $0.type })")
                            actions = responseActions
                        }
                        break
                    } else if let chunkText = chunk.text {
                        // Intermediate token/response chunk
                        if !accumulated.isEmpty {
                            accumulated += "\n\n"
                        }
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

        } catch {
            logger.error("Streaming failed: \(error.localizedDescription)")
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

        guard let url = ErestorConfig.url(for: "/api/chat") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        ErestorConfig.authorize(&request)

        let body = ["message": text]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            // API returns {"success": true, "responses": ["text1", "text2"]}
            if let apiResponse = try? JSONDecoder().decode(APIResponse.self, from: data),
               !apiResponse.responses.isEmpty {
                let text = apiResponse.responses.joined(separator: "\n\n")
                let botMsg = ChatMessage(
                    role: .assistant,
                    text: text,
                    timestamp: Self.currentTime()
                )
                messages.append(botMsg)
            } else {
                // Fallback: try legacy format
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
            }
        } catch {
            appendErrorMessage()
        }
    }

    // MARK: - Other endpoints

    func loadContext() async {
        guard let url = ErestorConfig.url(for: "/api/context") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        ErestorConfig.authorize(&request)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            context = try JSONDecoder().decode(ContextSummary.self, from: data)
        } catch {
            context = nil
        }
    }

    private var lastSuccessfulRequest: Date = .distantPast
    private var consecutiveFailures = 0

    func checkStatus() async {
        let online = await Self.pollStatus()
        applyStatusResult(online)
    }

    /// Progressive status polling: 5s → 10s → 60s
    private func startStatusPolling() {
        statusTask = Task { [weak self] in
            let intervals: [UInt64] = Array(repeating: 5, count: 6) + Array(repeating: 10, count: 6)
            var idx = 0
            while !Task.isCancelled {
                let seconds = idx < intervals.count ? intervals[idx] : 60
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                guard let self else { break }
                await self.checkStatus()
                idx += 1
            }
        }
    }

    // MARK: - Push polling (replaces SSE push/listen)

    private func startPushPolling() {
        pushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                guard let self else { break }
                await self.pollPushEvents()
            }
        }
    }

    /// Poll /api/push/pending for proactive messages from the gate
    private func pollPushEvents() async {
        guard serverOnline else { return }
        guard let url = ErestorConfig.url(for: "/api/push/pending") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        ErestorConfig.authorize(&request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            struct PushPendingResponse: Codable {
                let success: Bool
                let events: [PushEvent]
            }

            let decoded = try JSONDecoder().decode(PushPendingResponse.self, from: data)
            for event in decoded.events {
                await handlePushEvent(event)
            }
        } catch {
            // Silent — push polling failures are not critical
        }
    }

    /// Handle a single push event on the MainActor
    private func handlePushEvent(_ event: PushEvent) async {
        switch event.type {
        case "message":
            let text = event.text ?? ""
            guard !text.isEmpty else { return }
            let botMsg = ChatMessage(
                role: .assistant,
                text: text,
                timestamp: Self.currentTime()
            )
            messages.append(botMsg)
            streamDelta = StreamDelta(kind: .finished, text: botMsg.text, timestamp: botMsg.timestamp)
            logger.info("Push message received: \(text.prefix(80))")

            NotificationCenter.default.post(
                name: .erestorPushMessageReceived,
                object: nil,
                userInfo: ["text": text, "eventType": "message"]
            )

        case "poll_energy", "poll_quality":
            let text = event.text ?? (event.type == "poll_energy" ? "Como tá tua energia?" : "Como foi esse bloco?")
            logger.info("Push \(event.type) received: \(text.prefix(80))")

            NotificationCenter.default.post(
                name: .erestorPushMessageReceived,
                object: nil,
                userInfo: [
                    "text": text,
                    "eventType": event.type,
                    "options": event.options ?? [],
                ]
            )

        case "gate_inform":
            let text = event.text ?? "Alerta do gate"
            logger.info("Push gate_inform received (\(event.severity ?? "amber")): \(text.prefix(80))")

            NotificationCenter.default.post(
                name: .erestorPushMessageReceived,
                object: nil,
                userInfo: [
                    "text": text,
                    "eventType": "gate_inform",
                    "severity": event.severity ?? "amber",
                ]
            )

        case "reminder":
            let text = event.text ?? "Lembrete"
            logger.info("Push reminder received: \(text.prefix(80))")

            NotificationCenter.default.post(
                name: .erestorPushMessageReceived,
                object: nil,
                userInfo: ["text": text, "eventType": "reminder"]
            )

        case "action":
            if let pushActions = event.actions, !pushActions.isEmpty {
                actions = pushActions
                logger.info("Push actions received: \(pushActions.map { $0.type })")
            }

        case "context_update":
            if let newContext = event.context {
                context = newContext
                logger.info("Push context update received")
            }

        default:
            logger.warning("Unknown push event type: \(event.type)")
        }
    }

    func clearHistory() async {
        // Note: API doesn't have a /reset endpoint — just clear local state
        messages.removeAll()
    }

    // MARK: - Load history from backend

    func loadHistory() async {
        guard let url = ErestorConfig.url(for: "/api/history?source=desktop&limit=10") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        ErestorConfig.authorize(&request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            // API returns {"success": true, "history": [{...}, ...], "text": "..."}
            struct APIHistoryResponse: Codable {
                let history: [[String: String]]?
            }
            // Also try legacy format
            struct LegacyHistoryResponse: Codable {
                let history: [[String: String]]
            }

            if let decoded = try? JSONDecoder().decode(APIHistoryResponse.self, from: data),
               let history = decoded.history, !history.isEmpty {
                var loaded: [ChatMessage] = []
                for entry in history {
                    if let userText = entry["u"] {
                        loaded.append(ChatMessage(role: .user, text: userText, timestamp: ""))
                    }
                    if let botText = entry["b"] {
                        loaded.append(ChatMessage(role: .assistant, text: botText, timestamp: ""))
                    }
                }
                if messages.isEmpty {
                    messages = loaded
                }
            }
        } catch {
            logger.warning("Failed to load history: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func appendErrorMessage() {
        let errorMsg = ChatMessage(
            role: .assistant,
            text: "Erro de conexão com o servidor. Verifica se a API está rodando.",
            timestamp: Self.currentTime()
        )
        messages.append(errorMsg)
        streamDelta = StreamDelta(kind: .finished, text: errorMsg.text, timestamp: errorMsg.timestamp)
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

/// Represents a single SSE data event from /api/chat/stream
private struct SSEChunk: Codable {
    let text: String?
    let done: Bool?
    let fullResponse: String?
    let actions: [ChatAction]?
    let error: String?
    let responses: [String]?  // API format: array of response strings

    enum CodingKeys: String, CodingKey {
        case text, done, actions, error, responses
        case fullResponse = "full_response"
    }
}

private struct ChatResponse: Codable {
    let response: String
    let timestamp: String?
    let actions: [ChatAction]?
}

/// API response format: {"success": true, "responses": ["..."]}
private struct APIResponse: Codable {
    let success: Bool
    let responses: [String]
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
        return lhs.id == rhs.id
    }
}

// MARK: - Push notification name

extension Notification.Name {
    static let erestorPushMessageReceived = Notification.Name("erestorPushMessageReceived")
}
