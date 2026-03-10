import Foundation
import UserNotifications
import os
#if os(macOS)
import AppKit
#endif

private let logger = Logger(subsystem: "org.integros.erestor", category: "ChatService")

@MainActor
class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var context: ContextSummary?
    @Published var contextJSON: String?
    @Published var serverOnline = false
    @Published var actions: [ChatAction] = []

    // Streaming state
    @Published var isStreaming = false
    @Published var streamDelta: StreamDelta?

    // SSE event stream state
    @Published var activePolls: [PollSSEEvent] = []
    @Published var activeGates: [GateSSEEvent] = []

    private var eventStreamTask: Task<Void, Never>?
    private var heartbeatTimer: Task<Void, Never>?
    private var lastHeartbeat = Date()
    private var reconnectDelay: UInt64 = 3  // seconds, exponential backoff
    private var lastSuccessfulRequest: Date = .distantPast
    private var consecutiveFailures = 0

    // Token batching for streaming performance
    private var tokenBuffer = ""
    private var tokenFlushTask: Task<Void, Never>?

    deinit {
        eventStreamTask?.cancel()
        heartbeatTimer?.cancel()
        tokenFlushTask?.cancel()
    }

    init() {
        startEventStream()
        startHeartbeatMonitor()
    }

    // MARK: - SSE Event Stream (replaces all polling)

    func stopEventStream() {
        eventStreamTask?.cancel()
        eventStreamTask = nil
    }

    func startEventStream() {
        eventStreamTask?.cancel()
        eventStreamTask = Task { [weak self] in
            guard let self else { return }

            guard let url = ErestorConfig.url(for: ErestorConfig.eventsStreamPath) else {
                logger.error("Invalid SSE URL")
                return
            }

            var request = URLRequest(url: url)
            ErestorConfig.authorize(&request)
            request.timeoutInterval = .infinity

            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    logger.warning("SSE stream returned non-200 status")
                    await self.scheduleReconnect()
                    return
                }

                // Connected successfully -- reset backoff
                self.reconnectDelay = 3
                self.serverOnline = true
                self.lastHeartbeat = Date()

                for try await line in bytes.lines {
                    guard !Task.isCancelled else { break }
                    guard line.hasPrefix("data: ") else { continue }
                    let jsonStr = String(line.dropFirst(6))
                    self.handleSSEEvent(jsonStr)
                }

                // Stream ended normally (server closed)
                if !Task.isCancelled {
                    await self.scheduleReconnect()
                }

            } catch {
                if !Task.isCancelled {
                    logger.error("SSE stream error: \(error.localizedDescription)")
                    await self.scheduleReconnect()
                }
            }
        }

        // Listen for wake notifications to force reconnect
        #if os(macOS)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.startEventStream()
            }
        }
        #endif
    }

    private func scheduleReconnect() async {
        guard !Task.isCancelled else { return }
        logger.info("SSE reconnecting in \(self.reconnectDelay)s...")
        try? await Task.sleep(nanoseconds: reconnectDelay * 1_000_000_000)
        // Exponential backoff: 3 -> 6 -> 12 -> 24 -> 30 (cap)
        reconnectDelay = min(reconnectDelay * 2, 30)
        startEventStream()
    }

    private func handleSSEEvent(_ jsonStr: String) {
        guard let event = SSEEvent.parse(from: jsonStr) else {
            logger.warning("Failed to parse SSE event: \(jsonStr.prefix(200))")
            return
        }

        lastHeartbeat = Date()

        switch event.type {
        case .contextUpdate:
            // Decode full context from the data payload
            if let dataDict = event.rawData["data"] as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: dataDict) {
                if let ctx = try? JSONDecoder().decode(ContextSummary.self, from: jsonData) {
                    context = ctx
                    contextJSON = String(data: jsonData, encoding: .utf8)
                }
            }
            serverOnline = true

        case .pollEnergy, .pollQuality:
            if let jsonData = try? JSONSerialization.data(withJSONObject: event.rawData),
               let poll = try? JSONDecoder().decode(PollSSEEvent.self, from: jsonData) {
                activePolls.append(poll)

                let eventType = event.type == .pollEnergy ? "poll_energy" : "poll_quality"
                let categoryId = event.type == .pollEnergy ? "POLL_ENERGY" : "POLL_QUALITY"

                // Post notification if panel is NOT visible (macOS only check)
                #if os(macOS)
                let panelVisible = BubbleWindowController.shared.isChatVisible
                #else
                let panelVisible = false
                #endif
                if !panelVisible {
                    postPollNotification(
                        pollId: poll.pollId,
                        question: poll.question,
                        categoryIdentifier: categoryId
                    )
                }

                // Schedule a 10-min reminder if poll still unanswered
                scheduleReminderNotification(
                    pollId: poll.pollId,
                    question: poll.question,
                    categoryIdentifier: categoryId
                )

                // Also post internal notification for ContextPanelView push handling
                NotificationCenter.default.post(
                    name: .erestorPushMessageReceived,
                    object: nil,
                    userInfo: [
                        "text": poll.question,
                        "eventType": eventType,
                        "options": poll.options,
                    ]
                )
            }

        case .gateAlert:
            if let jsonData = try? JSONSerialization.data(withJSONObject: event.rawData),
               let gate = try? JSONDecoder().decode(GateSSEEvent.self, from: jsonData) {
                activeGates.append(gate)

                // Gate alerts ALWAYS post notification (urgent, even if panel visible)
                postGateNotification(text: gate.text, severity: gate.severity)

                NotificationCenter.default.post(
                    name: .erestorPushMessageReceived,
                    object: nil,
                    userInfo: [
                        "text": gate.text,
                        "eventType": "gate_inform",
                        "severity": gate.severity,
                    ]
                )
            }

        case .pollExpired:
            if let pollId = event.rawData["poll_id"] as? String {
                activePolls.removeAll { $0.pollId == pollId }
                // Cancel any pending notifications for this poll
                UNUserNotificationCenter.current().removePendingNotificationRequests(
                    withIdentifiers: [pollId, "\(pollId)_reminder"]
                )
            }

        case .pollReminder:
            if let pollId = event.rawData["poll_id"] as? String,
               let text = event.rawData["text"] as? String {
                // Only show reminder if poll is still active (not responded)
                if activePolls.contains(where: { $0.pollId == pollId }) {
                    let categoryId = event.rawData["category"] as? String ?? "POLL_REMINDER"
                    postPollNotification(
                        pollId: "\(pollId)_reminder",
                        question: "Lembrete: \(text)",
                        categoryIdentifier: categoryId
                    )
                }
            } else if let text = event.rawData["text"] as? String {
                NotificationCenter.default.post(
                    name: .erestorPushMessageReceived,
                    object: nil,
                    userInfo: ["text": text, "eventType": "reminder"]
                )
            }

        case .heartbeat:
            serverOnline = true
            consecutiveFailures = 0
        }
    }

    // MARK: - Heartbeat Monitor (detects offline after 60s without heartbeat)

    private func startHeartbeatMonitor() {
        heartbeatTimer?.cancel()
        heartbeatTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // check every 15s
                guard let self else { break }
                let elapsed = Date().timeIntervalSince(self.lastHeartbeat)
                if elapsed > 60 {
                    self.serverOnline = false
                }
            }
        }
    }

    // MARK: - macOS Notification Helpers

    /// Post a macOS notification for a poll (energy or quality)
    private func postPollNotification(pollId: String, question: String, categoryIdentifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "Erestor"
        content.body = question
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = ["poll_id": pollId]
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: pollId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Poll notification failed: \(error.localizedDescription)")
            }
        }
    }

    /// Schedule a reminder notification 10 min after poll creation (if still unanswered)
    private func scheduleReminderNotification(pollId: String, question: String, categoryIdentifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "Erestor — Lembrete"
        content.body = "Ainda pendente: \(question)"
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = ["poll_id": pollId]
        content.sound = .default

        // Fire 10 minutes after poll creation
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)
        let reminderId = "\(pollId)_reminder"
        let request = UNNotificationRequest(identifier: reminderId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Reminder notification scheduling failed: \(error.localizedDescription)")
            }
        }
    }

    /// Post a macOS notification for a gate alert (always, even if panel is visible)
    private func postGateNotification(text: String, severity: String) {
        let content = UNMutableNotificationContent()
        content.title = "Erestor — Alerta"
        content.body = text
        content.categoryIdentifier = "GATE_INFORM"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "gate_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Gate notification failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Streaming send (SSE) -- token-by-token

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

        // Create a streaming placeholder message
        var streamingMsg = ChatMessage.streaming(timestamp: Self.currentTime())
        messages.append(streamingMsg)
        let streamingMsgId = streamingMsg.id

        streamDelta = StreamDelta(kind: .started, text: "", timestamp: Self.currentTime())

        guard let url = ErestorConfig.url(for: ErestorConfig.chatStreamPath) else {
            isLoading = false
            isStreaming = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300  // 5 min
        ErestorConfig.authorize(&request)

        // Build request body with message + conversation history
        let historyPayload = messages
            .filter { $0.id != streamingMsgId }  // exclude the streaming placeholder
            .prefix(20)  // last 20 messages for context
            .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.text] }
        let body: [String: Any] = [
            "message": text,
            "history": Array(historyPayload)
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                finalizeStreamingMessage(id: streamingMsgId, text: "Erro: servidor retornou status inesperado.")
                return
            }

            serverOnline = true
            lastSuccessfulRequest = Date()
            var accumulated = ""

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))

                guard let jsonData = jsonStr.data(using: .utf8) else { continue }

                let chunk: SSEChunk?
                do {
                    chunk = try JSONDecoder().decode(SSEChunk.self, from: jsonData)
                } catch {
                    logger.error("SSE decode failed: \(error.localizedDescription) -- raw: \(jsonStr.prefix(200))")
                    chunk = nil
                }

                if let chunk {
                    if let done = chunk.done, done {
                        if let fullResponse = chunk.fullResponse {
                            accumulated = fullResponse
                        }
                        if accumulated.isEmpty, let responses = chunk.responses {
                            accumulated = responses.joined(separator: "\n\n")
                        }
                        if let responseActions = chunk.actions, !responseActions.isEmpty {
                            actions = responseActions
                        }
                        break
                    } else if let chunkText = chunk.text {
                        accumulated += chunkText
                        // Update the streaming message with accumulated text
                        updateStreamingMessage(id: streamingMsgId, text: accumulated)
                        streamDelta = StreamDelta(kind: .delta, text: chunkText, timestamp: "")
                    } else if let error = chunk.error {
                        logger.error("SSE error from server: \(error)")
                        accumulated += "\n[Erro: \(error)]"
                    }
                }
            }

            // Streaming done -- finalize the message
            let finalText = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
            finalizeStreamingMessage(id: streamingMsgId, text: finalText.isEmpty ? "..." : finalText)

        } catch {
            logger.error("Streaming failed: \(error.localizedDescription)")
            let recentlyOnline = Date().timeIntervalSince(lastSuccessfulRequest) < 60
            if recentlyOnline {
                finalizeStreamingMessage(
                    id: streamingMsgId,
                    text: "A resposta demorou demais e foi interrompida. Tenta de novo com uma mensagem mais curta."
                )
            } else {
                finalizeStreamingMessage(
                    id: streamingMsgId,
                    text: "Erro de conexao com o servidor. Verifica se a API esta rodando."
                )
                consecutiveFailures += 1
                if consecutiveFailures >= 3 {
                    serverOnline = false
                }
            }
        }
    }

    /// Update a streaming message's text in-place (avoids re-creating the array)
    private func updateStreamingMessage(id: UUID, text: String) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].text = text
        }
    }

    /// Finalize a streaming message: set final text, mark not streaming, update deltas
    private func finalizeStreamingMessage(id: UUID, text: String) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].text = text
            messages[idx].isStreaming = false
        }
        streamDelta = StreamDelta(kind: .finished, text: text, timestamp: Self.currentTime())
        isLoading = false
        isStreaming = false
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
            contextJSON = String(data: data, encoding: .utf8)
        } catch {
            context = nil
            contextJSON = nil
        }
    }

    func checkStatus() async {
        let online = await Self.pollStatus()
        if online {
            if !serverOnline { serverOnline = true }
            lastSuccessfulRequest = Date()
            consecutiveFailures = 0
        }
    }

    /// Network call runs completely OFF MainActor
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

    func clearHistory() async {
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

            struct APIHistoryResponse: Codable {
                let history: [[String: String]]?
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
            text: "Erro de conexao com o servidor. Verifica se a API esta rodando.",
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

    static func currentTime() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        return fmt.string(from: Date())
    }
}

// MARK: - SSE Models

/// Represents a single SSE data event from /v1/chat/stream
private struct SSEChunk: Codable {
    let text: String?
    let done: Bool?
    let fullResponse: String?
    let actions: [ChatAction]?
    let error: String?
    let responses: [String]?

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

/// Published to notify views of streaming state changes
struct StreamDelta: Equatable {
    enum Kind: Equatable {
        case started
        case delta
        case finished
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
