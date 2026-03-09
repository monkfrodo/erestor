import SwiftUI
import WebKit
import Combine
import os

private let logger = Logger(subsystem: "org.integros.erestor", category: "ChatWebViewVC")

struct ChatWebViewVC: NSViewControllerRepresentable {
    @EnvironmentObject var chatService: ChatService

    func makeCoordinator() -> Coordinator {
        Coordinator(chatService: chatService)
    }

    func makeNSViewController(context: Context) -> ChatWebViewController {
        let vc = ChatWebViewController()
        vc.coordinator = context.coordinator
        return vc
    }

    func updateNSViewController(_ vc: ChatWebViewController, context: Context) {
        guard let webView = vc.webView else { return }
        let coordinator = context.coordinator
        coordinator.webView = webView

        let messages = chatService.messages
        let isLoading = chatService.isLoading

        // --- Pre-check: if a .finished delta is pending, mark streamFinishedMessageCount NOW
        //     to prevent the message rendering loop from duplicating the streamed message ---
        if let delta = chatService.streamDelta, delta.id != coordinator.lastStreamDeltaID, delta.kind == .finished {
            coordinator.streamFinishedMessageCount = messages.count
        }

        // --- Render non-streaming messages (user messages + completed assistant messages) ---
        // During streaming, the assistant message is rendered via streamDelta below,
        // so we skip the last message if we're actively streaming and it hasn't been
        // added to messages yet. The final assistant message gets added to messages[]
        // AFTER streaming finishes, so we need to skip rendering it here because
        // finalizeStream() already handled it in the WebView.
        let renderCount: Int
        if coordinator.streamFinishedMessageCount == messages.count {
            // The last message was just added by streaming completion -- already rendered
            renderCount = messages.count
            coordinator.renderedCount = messages.count
        } else {
            renderCount = messages.count
        }

        let alreadySent = coordinator.renderedCount
        if renderCount > alreadySent {
            for i in alreadySent..<renderCount {
                let msg = messages[i]
                // Skip assistant messages that were/are being rendered by streaming
                if msg.role == .assistant && (chatService.isStreaming || coordinator.streamFinishedMessageCount == i + 1) {
                    coordinator.renderedCount = i + 1
                    continue
                }
                let role = msg.role == .user ? "user" : "assistant"
                let escaped = Self.escapeForJS(msg.text)
                let js = "addMessage(\"\(role)\", \"\(escaped)\", \"\(msg.timestamp)\")"
                webView.evaluateJavaScript(js)
            }
            coordinator.renderedCount = renderCount
        }

        if messages.isEmpty && alreadySent > 0 {
            webView.evaluateJavaScript("clearMessages()")
            coordinator.renderedCount = 0
            coordinator.streamFinishedMessageCount = 0
        }

        // --- Safety: if streaming just ended, always call finalizeStream as cleanup ---
        if coordinator.wasStreaming && !chatService.isStreaming {
            // Streaming transitioned from true → false. Ensure the WebView cursor is removed.
            // This covers cases where the .finished delta was missed or not yet processed.
            let lastMsg = messages.last
            let finalText = lastMsg.flatMap { $0.role == .assistant ? Self.escapeForJS($0.text) : nil } ?? ""
            let finalTs = lastMsg?.timestamp ?? ""
            webView.evaluateJavaScript("finalizeStream(\"\(finalText)\", \"\(finalTs)\")")
            coordinator.streamFinishedMessageCount = messages.count
            coordinator.renderedCount = messages.count
        }
        coordinator.wasStreaming = chatService.isStreaming

        // --- Loading indicator (only for non-streaming requests) ---
        if isLoading != coordinator.lastLoadingState {
            // During streaming, we use the stream cursor instead of the loading indicator
            if !chatService.isStreaming {
                webView.evaluateJavaScript("setLoading(\(isLoading))")
            }
            coordinator.lastLoadingState = isLoading
        }

        // --- Stream delta handling ---
        if let delta = chatService.streamDelta, delta.id != coordinator.lastStreamDeltaID {
            coordinator.lastStreamDeltaID = delta.id

            switch delta.kind {
            case .started:
                // Create the streaming message container in the WebView
                webView.evaluateJavaScript("beginStream(\"\(delta.timestamp)\")") { _, error in
                    if let error = error {
                        logger.error("JS beginStream failed: \(error.localizedDescription)")
                    }
                }
                webView.evaluateJavaScript("setLoading(false)")

            case .delta:
                // Append new token text to the streaming message
                let escaped = Self.escapeForJS(delta.text)
                webView.evaluateJavaScript("appendStreamChunk(\"\(escaped)\")") { _, error in
                    if let error = error {
                        logger.error("JS appendStreamChunk failed: \(error.localizedDescription)")
                    }
                }

            case .finished:
                // Finalize the streamed message with the clean full text
                let escaped = Self.escapeForJS(delta.text)
                webView.evaluateJavaScript("finalizeStream(\"\(escaped)\", \"\(delta.timestamp)\")") { _, error in
                    if let error = error {
                        logger.error("JS finalizeStream failed: \(error.localizedDescription)")
                    }
                }
                // Mark that this message count was handled by streaming
                coordinator.streamFinishedMessageCount = messages.count
                coordinator.renderedCount = messages.count
            }
        }
    }

    // MARK: - JS string escaping (used by BubbleWindowController too)

    static func escapeForJS(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var chatService: ChatService
        var webView: WKWebView?
        var renderedCount = 0
        var lastLoadingState = false
        var lastStreamDeltaID: UUID?
        var streamFinishedMessageCount = 0
        var wasStreaming = false

        init(chatService: ChatService) {
            self.chatService = chatService
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            logger.info("didFinish -- frame: \(webView.frame.debugDescription)")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            logger.error("didFail: \(error.localizedDescription)")
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else { return }

            switch type {
            case "send":
                guard let text = body["text"] as? String else { return }
                Task { @MainActor in
                    await chatService.sendMessageStreaming(text)
                }

            case "timer_stop":
                Task { @MainActor in
                    guard let url = ErestorConfig.url(for: "/api/timer/stop") else { return }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 10
                    ErestorConfig.authorize(&request)
                    _ = try? await URLSession.shared.data(for: request)
                }

            case "poll_response":
                let pollType = body["pollType"] as? String ?? ""
                let value = body["value"] as? String ?? ""
                Task { @MainActor in
                    await chatService.sendMessageStreaming("energia: \(value)")
                }
                logger.info("Poll response: \(pollType) = \(value)")

            default:
                break
            }
        }
    }
}

class ChatWebViewController: NSViewController {
    var coordinator: ChatWebViewVC.Coordinator?
    var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()
        if let coordinator = coordinator {
            config.userContentController.add(coordinator, name: "chat")
        }
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = coordinator
        webView.setValue(false, forKey: "drawsBackground")

        if let htmlURL = Bundle.main.url(forResource: "chat", withExtension: "html"),
           let htmlString = try? String(contentsOf: htmlURL, encoding: .utf8) {
            logger.info("Loading chat.html (\(htmlString.count) chars)")
            webView.loadHTMLString(htmlString, baseURL: htmlURL.deletingLastPathComponent())
        } else {
            logger.error("chat.html not found!")
            webView.loadHTMLString("<html><body style='background:#1a1a1e;color:white;padding:40px;font-size:24px'>chat.html not found</body></html>", baseURL: nil)
        }

        self.view = webView
    }
}
