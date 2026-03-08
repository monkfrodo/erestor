import AppKit
import SwiftUI
import WebKit
import Combine
import os

private let logger = Logger(subsystem: "org.integros.erestor", category: "BubbleWindow")

@MainActor
class BubbleWindowController: ObservableObject {
    static let shared = BubbleWindowController()

    @Published var isChatVisible = false

    private(set) var bubblePanel: NSPanel?
    private var chatPanel: KeyablePanel?
    private var timerPanel: NSPanel?
    private var timerLabel: NSTextField?
    private var timerDescLabel: NSTextField?
    private var timerPollTimer: Timer?
    var chatService: ChatService?
    private var actionHandler: ActionHandler?

    var chatWebVC: ChatWebViewController?
    private var streamCancellable: AnyCancellable?
    private var actionsCancellable: AnyCancellable?
    private var contextPollTimer: Timer?
    private var currentEventTitle: String?

    private let bubbleSize: CGFloat = 52
    private let chatWidth: CGFloat = 340
    private let chatHeight: CGFloat = 480
    private let margin: CGFloat = 12

    private var isDragging = false
    private var dragOffset: NSPoint = .zero

    deinit {
        contextPollTimer?.invalidate()
        timerPollTimer?.invalidate()
    }

    private init() {}

    // MARK: - Setup

    private var isSetup = false

    func setup(chatService: ChatService, actionHandler: ActionHandler) {
        guard !isSetup else { return }
        isSetup = true
        self.chatService = chatService
        self.actionHandler = actionHandler
        createBubblePanel()
        createChatPanel()
        createTimerPanel()
        observeStreaming()
        startTimerPolling()
        startContextPolling()
    }

    // MARK: - Bubble Panel

    private func createBubblePanel() {
        guard let chatService else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none

        let bubbleView = FloatingBubbleView(onTap: { [weak self] in
            self?.toggleChat()
        })
        .environmentObject(chatService)

        let hostingView = NSHostingView(rootView: bubbleView)
        hostingView.frame = NSRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        panel.contentView = hostingView

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - bubbleSize - 20
            let y = screenFrame.minY + 120
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        let dragView = BubbleDragView(frame: NSRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize))
        dragView.controller = self
        panel.contentView?.addSubview(dragView)

        panel.orderFrontRegardless()
        self.bubblePanel = panel
    }

    // MARK: - Chat Panel (native, no SwiftUI wrapper)

    private func createChatPanel() {
        guard let chatService else { return }

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: chatWidth, height: chatHeight),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = NSColor(red: 0.165, green: 0.141, blue: 0.133, alpha: 0.98) // #2a2422
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.minSize = NSSize(width: 280, height: 320)
        panel.maxSize = NSSize(width: 600, height: 900)
        panel.isFloatingPanel = true

        // Container view with rounded corners
        let container = NSView(frame: NSRect(x: 0, y: 0, width: chatWidth, height: chatHeight))
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.layer?.borderColor = NSColor(red: 0.29, green: 0.247, blue: 0.235, alpha: 0.6).cgColor
        container.layer?.borderWidth = 1
        container.autoresizingMask = [.width, .height]

        // Header bar
        let headerHeight: CGFloat = 32
        let header = createHeaderView(width: chatWidth, height: headerHeight)
        header.frame = NSRect(x: 0, y: chatHeight - headerHeight, width: chatWidth, height: headerHeight)
        header.autoresizingMask = [.width, .minYMargin]
        container.addSubview(header)

        // WebView (persistent — created once, never destroyed)
        let vc = ChatWebViewController()
        vc.coordinator = ChatWebViewVC.Coordinator(chatService: chatService)
        vc.loadView()

        guard let webView = vc.webView else { return }
        webView.frame = NSRect(x: 0, y: 0, width: chatWidth, height: chatHeight - headerHeight)
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)

        vc.coordinator?.webView = webView
        self.chatWebVC = vc

        // Resize handle (bottom-right corner)
        let resizeHandle = ResizeHandleView(frame: NSRect(x: chatWidth - 20, y: 0, width: 20, height: 20))
        resizeHandle.autoresizingMask = [.minXMargin, .maxYMargin]
        container.addSubview(resizeHandle)

        panel.contentView = container
        self.chatPanel = panel
    }

    private func createHeaderView(width: CGFloat, height: CGFloat) -> NSView {
        let header = DraggableHeaderView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor(red: 0.208, green: 0.180, blue: 0.173, alpha: 1).cgColor // #352e2c

        // Title label
        let title = NSTextField(labelWithString: "Erestor")
        title.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        title.textColor = NSColor(red: 0.831, green: 0.769, blue: 0.722, alpha: 1) // #d4c4b8
        title.frame = NSRect(x: 12, y: 6, width: 100, height: 20)
        title.autoresizingMask = [.maxXMargin]
        header.addSubview(title)

        // Close button
        let closeBtn = NSButton(frame: NSRect(x: width - 30, y: 6, width: 20, height: 20))
        closeBtn.bezelStyle = .inline
        closeBtn.isBordered = false
        closeBtn.title = ""
        closeBtn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeBtn.contentTintColor = NSColor(red: 0.478, green: 0.431, blue: 0.400, alpha: 1) // #7a6e66
        closeBtn.target = self
        closeBtn.action = #selector(closeChatAction)
        closeBtn.autoresizingMask = [.minXMargin]
        header.addSubview(closeBtn)

        return header
    }

    @objc private func closeChatAction() {
        hideChat()
    }

    // MARK: - Stream observation (push tokens to WebView)

    private func observeStreaming() {
        guard let chatService else { return }

        streamCancellable = chatService.$streamDelta
            .receive(on: DispatchQueue.main)
            .sink { [weak self] delta in
                guard let self, let delta, let webView = self.chatWebVC?.webView else { return }
                guard let coord = self.chatWebVC?.coordinator, delta.id != coord.lastStreamDeltaID else { return }
                coord.lastStreamDeltaID = delta.id

                switch delta.kind {
                case .started:
                    webView.evaluateJavaScript("beginStream(\"\(delta.timestamp)\")")
                    webView.evaluateJavaScript("setLoading(false)")
                case .delta:
                    let escaped = ChatWebViewVC.escapeForJS(delta.text)
                    webView.evaluateJavaScript("appendStreamChunk(\"\(escaped)\")")
                case .finished:
                    let escaped = ChatWebViewVC.escapeForJS(delta.text)
                    webView.evaluateJavaScript("finalizeStream(\"\(escaped)\", \"\(delta.timestamp)\")")
                    coord.streamFinishedMessageCount = chatService.messages.count
                    coord.renderedCount = chatService.messages.count
                }
            }

        actionsCancellable = chatService.$actions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] actions in
                guard !actions.isEmpty else { return }
                self?.actionHandler?.execute(actions)
            }

        // Also observe messages for non-streaming additions (user messages, errors)
        chatService.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.renderMessages(messages)
            }
            .store(in: &messageCancellables)
    }

    private var messageCancellables = Set<AnyCancellable>()

    private func renderMessages(_ messages: [ChatMessage]) {
        guard let webView = chatWebVC?.webView, let coord = chatWebVC?.coordinator else { return }

        if messages.isEmpty && coord.renderedCount > 0 {
            webView.evaluateJavaScript("clearMessages()")
            coord.renderedCount = 0
            coord.streamFinishedMessageCount = 0
            return
        }

        let alreadySent = coord.renderedCount
        if messages.count > alreadySent {
            for i in alreadySent..<messages.count {
                let msg = messages[i]
                // Skip if this message was rendered by streaming
                if msg.role == .assistant && coord.streamFinishedMessageCount == i + 1 {
                    coord.renderedCount = i + 1
                    continue
                }
                let role = msg.role == .user ? "user" : "assistant"
                let escaped = ChatWebViewVC.escapeForJS(msg.text)
                webView.evaluateJavaScript("addMessage(\"\(role)\", \"\(escaped)\", \"\(msg.timestamp)\")")
            }
            coord.renderedCount = messages.count
        }

        // Loading state
        let isLoading = chatService?.isLoading ?? false
        if isLoading != coord.lastLoadingState {
            if !(chatService?.isStreaming ?? false) {
                webView.evaluateJavaScript("setLoading(\(isLoading))")
            }
            coord.lastLoadingState = isLoading
        }
    }

    // MARK: - Timer indicator (below bubble)

    private func createTimerPanel() {
        let w: CGFloat = 140
        let h: CGFloat = 72  // time + desc
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        // Time label (MM:SS or H:MM:SS)
        let timeLabel = NSTextField(labelWithString: "")
        timeLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        timeLabel.textColor = NSColor(red: 0.29, green: 0.62, blue: 0.41, alpha: 1)
        timeLabel.backgroundColor = .clear
        timeLabel.isBezeled = false
        timeLabel.isEditable = false
        timeLabel.alignment = .center
        timeLabel.frame = NSRect(x: 0, y: 20, width: w, height: 16)
        container.addSubview(timeLabel)

        // Desc label (one word)
        let descLabel = NSTextField(labelWithString: "")
        descLabel.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        descLabel.textColor = NSColor(red: 0.6, green: 0.55, blue: 0.50, alpha: 1)
        descLabel.backgroundColor = .clear
        descLabel.isBezeled = false
        descLabel.isEditable = false
        descLabel.alignment = .center
        descLabel.frame = NSRect(x: 0, y: 4, width: w, height: 16)
        container.addSubview(descLabel)

        panel.contentView = container
        self.timerLabel = timeLabel
        self.timerDescLabel = descLabel
        self.timerPanel = panel
    }

    private func startTimerPolling() {
        timerPollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.updateTimerDisplay() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.updateTimerDisplay()
        }
    }

    private func startContextPolling() {
        // Poll /context every 30s to get current calendar event
        contextPollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fetchCurrentEvent() }
        }
        // Initial fetch
        Task { @MainActor in fetchCurrentEvent() }
    }

    private func fetchCurrentEvent() {
        guard let url = URL(string: "http://127.0.0.1:8766/context") else { return }
        Task.detached { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let ctx = try JSONDecoder().decode(ContextSummary.self, from: data)
                await MainActor.run {
                    self?.currentEventTitle = ctx.currentEvent?.title
                    self?.updateTimerDisplay()
                }
            } catch {
                // Silently ignore — context is optional
            }
        }
    }

    private func updateTimerDisplay() {
        guard let timerPanel, let timerLabel, let bubblePanel else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser

        var found = false
        for (_, file) in [("work", ".work_timer"), ("content", ".content_timer"), ("tech", ".ocio_timer")] {
            let path = home.appendingPathComponent(file)
            guard FileManager.default.fileExists(atPath: path.path) else { continue }
            do {
                let tsStr = try String(contentsOf: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let ts = Double(tsStr) else { continue }
                let elapsed = Int(Date().timeIntervalSince1970 - ts)
                let hours = elapsed / 3600
                let mins = (elapsed % 3600) / 60
                let secs = elapsed % 60
                if hours > 0 {
                    timerLabel.stringValue = String(format: "%d:%02d:%02d", hours, mins, secs)
                } else {
                    timerLabel.stringValue = String(format: "%02d:%02d", mins, secs)
                }

                let descPath = home.appendingPathComponent(file.replacingOccurrences(of: "_timer", with: "_desc"))
                let desc = (try? String(contentsOf: descPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
                // Pick shortest meaningful word (skip "&", "e", "de", etc.)
                let words = desc.split(separator: " ").map(String.init)
                    .filter { $0.count > 2 && $0 != "&" }
                let shortWord = words.min(by: { $0.count < $1.count }) ?? words.first ?? desc
                let label = shortWord.count > 8
                    ? String(shortWord.prefix(6)) + "…"
                    : shortWord
                timerDescLabel?.stringValue = label.lowercased()

                // Position below bubble, centered
                let bubbleFrame = bubblePanel.frame
                let x = bubbleFrame.midX - 70
                let y = bubbleFrame.minY - 44
                timerPanel.setFrameOrigin(NSPoint(x: x, y: y))
                if !timerPanel.isVisible {
                    timerPanel.order(.above, relativeTo: bubblePanel.windowNumber)
                }
                found = true
                break
            } catch { continue }
        }

        // No active timer — show current calendar event if available
        if !found {
            if let eventTitle = currentEventTitle, !eventTitle.isEmpty {
                timerLabel.stringValue = ""
                // Truncate long event names to fit below the bubble
                let truncated = eventTitle.count > 18
                    ? String(eventTitle.prefix(16)) + "…"
                    : eventTitle
                timerDescLabel?.stringValue = truncated.lowercased()

                let bubbleFrame = bubblePanel.frame
                let x = bubbleFrame.midX - 70
                let y = bubbleFrame.minY - 44
                timerPanel.setFrameOrigin(NSPoint(x: x, y: y))
                if !timerPanel.isVisible {
                    timerPanel.order(.above, relativeTo: bubblePanel.windowNumber)
                }
            } else {
                timerPanel.orderOut(nil)
            }
        }
    }

    // MARK: - Toggle

    func toggleChat() {
        if isChatVisible {
            hideChat()
        } else {
            showChat()
        }
    }

    func showChat() {
        guard let chatPanel, let bubblePanel else { return }

        positionChatPanel(relativeTo: bubblePanel.frame)

        chatPanel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        chatPanel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            chatPanel.animator().alphaValue = 1
        }

        isChatVisible = true

        // Focus textarea
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, let webView = self.chatWebVC?.webView else { return }
            self.chatPanel?.makeFirstResponder(webView)
            webView.evaluateJavaScript("document.getElementById('msg-input').focus()")
        }
    }

    func hideChat() {
        guard let chatPanel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            chatPanel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            chatPanel.orderOut(nil)
            chatPanel.alphaValue = 1
            self?.isChatVisible = false
        })
    }

    // MARK: - Positioning

    private func positionChatPanel(relativeTo bubbleFrame: NSRect) {
        guard let chatPanel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = chatPanel.frame.size

        var x = bubbleFrame.minX - panelSize.width - margin
        var y = bubbleFrame.minY

        if x < screenFrame.minX {
            x = bubbleFrame.maxX + margin
        }
        if y + panelSize.height > screenFrame.maxY {
            y = screenFrame.maxY - panelSize.height
        }
        if y < screenFrame.minY {
            y = screenFrame.minY
        }

        chatPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Drag handling

    func bubbleDragBegan(at point: NSPoint) {
        guard let bubblePanel else { return }
        isDragging = true
        let windowOrigin = bubblePanel.frame.origin
        dragOffset = NSPoint(x: point.x - windowOrigin.x, y: point.y - windowOrigin.y)
    }

    func bubbleDragged(to point: NSPoint) {
        guard isDragging, let bubblePanel else { return }
        let newOrigin = NSPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y)
        bubblePanel.setFrameOrigin(newOrigin)

        if isChatVisible {
            positionChatPanel(relativeTo: bubblePanel.frame)
        }
        updateTimerDisplay()
    }

    func bubbleDragEnded() {
        isDragging = false
    }

    // MARK: - Chat panel drag handling (reposition bubble to stay connected)

    func chatPanelDragged() {
        guard let chatPanel, let bubblePanel else { return }
        let chatFrame = chatPanel.frame

        // Place bubble to the right of chat panel (or left if no space)
        let screen = NSScreen.main?.visibleFrame ?? .zero
        var bubbleX = chatFrame.maxX + margin
        if bubbleX + bubbleSize > screen.maxX {
            bubbleX = chatFrame.minX - bubbleSize - margin
        }
        let bubbleY = chatFrame.minY

        bubblePanel.setFrameOrigin(NSPoint(x: bubbleX, y: bubbleY))
        updateTimerDisplay()
    }
}

// MARK: - Draggable header (move chat panel by dragging the header bar)

class DraggableHeaderView: NSView {
    private var dragOffset: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        dragOffset = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let screenPoint = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: screenPoint.x - dragOffset.x,
            y: screenPoint.y - dragOffset.y
        )
        window.setFrameOrigin(newOrigin)

        // Reposition bubble relative to the new chat panel position
        BubbleWindowController.shared.chatPanelDragged()
    }
}

// MARK: - Resize handle (visual grip at bottom-right)

class ResizeHandleView: NSView {
    private var initialMouseLocation: NSPoint = .zero
    private var initialFrame: NSRect = .zero

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let color = NSColor(red: 0.35, green: 0.30, blue: 0.28, alpha: 0.6)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1)
        // Draw 3 diagonal lines (resize grip)
        for i in 0..<3 {
            let offset = CGFloat(i) * 5
            ctx.move(to: CGPoint(x: bounds.maxX - 4 - offset, y: bounds.minY + 2))
            ctx.addLine(to: CGPoint(x: bounds.maxX - 2, y: bounds.minY + 4 + offset))
            ctx.strokePath()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        initialFrame = window?.frame ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - initialMouseLocation.x
        let dy = currentMouse.y - initialMouseLocation.y

        // Resize: width grows right, height grows down (origin moves)
        var newFrame = initialFrame
        newFrame.size.width = max(window.minSize.width, min(window.maxSize.width, initialFrame.width + dx))
        newFrame.size.height = max(window.minSize.height, min(window.maxSize.height, initialFrame.height - dy))
        // Recalculate origin.y based on actual clamped height to prevent drift
        newFrame.origin.y = initialFrame.origin.y + (initialFrame.height - newFrame.size.height)

        window.setFrame(newFrame, display: true)
    }
}

// MARK: - KeyablePanel

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape → close chat
        if event.keyCode == 53 {
            BubbleWindowController.shared.hideChat()
            return
        }
        // Cmd+K → clear conversation
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
            Task { @MainActor in
                try? await BubbleWindowController.shared.chatService?.clearHistory()
                try? await BubbleWindowController.shared.chatWebVC?.webView?.evaluateJavaScript("clearMessages()")
            }
            return
        }
        super.keyDown(with: event)
    }

    override func resignKey() {
        super.resignKey()
        // Close chat when clicking outside — but not if clicking the bubble (toggle handles that)
        DispatchQueue.main.async {
            let bubble = BubbleWindowController.shared
            guard bubble.isChatVisible else { return }
            // Check if the bubble panel became key (user clicked the bubble)
            if bubble.bubblePanel?.isKeyWindow == true { return }
            bubble.hideChat()
        }
    }
}

// MARK: - Drag tracking NSView

class BubbleDragView: NSView {
    weak var controller: BubbleWindowController?
    private var dragStartPoint: NSPoint = .zero
    private let dragThreshold: CGFloat = 4 // pixels before it counts as drag

    override func mouseDown(with event: NSEvent) {
        dragStartPoint = NSEvent.mouseLocation
        controller?.bubbleDragBegan(at: dragStartPoint)
    }

    override func mouseDragged(with event: NSEvent) {
        let currentPoint = NSEvent.mouseLocation
        let dx = currentPoint.x - dragStartPoint.x
        let dy = currentPoint.y - dragStartPoint.y
        let distance = sqrt(dx * dx + dy * dy)

        // Only start dragging after threshold to avoid accidental drags
        if distance > dragThreshold {
            controller?.bubbleDragged(to: currentPoint)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let currentPoint = NSEvent.mouseLocation
        let dx = currentPoint.x - dragStartPoint.x
        let dy = currentPoint.y - dragStartPoint.y
        let distance = sqrt(dx * dx + dy * dy)

        controller?.bubbleDragEnded()

        // Only toggle if mouse barely moved (click, not drag)
        if distance <= dragThreshold {
            controller?.toggleChat()
        }
    }
}
