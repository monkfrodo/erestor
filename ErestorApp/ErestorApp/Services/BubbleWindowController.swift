import AppKit
import SwiftUI
import Combine
import UserNotifications
import os

private let logger = Logger(subsystem: "org.integros.erestor", category: "BubbleWindow")

@MainActor
class BubbleWindowController: ObservableObject {
    static let shared = BubbleWindowController()

    @Published var isChatVisible = false

    private(set) var bubblePanel: NSPanel?
    private var chatPanel: KeyablePanel?
    private var contextPollTask: Task<Void, Never>?
    var chatService: ChatService?
    private var actionHandler: ActionHandler?

    // Notification badge on bubble
    private var notificationDot: NSView?

    private var streamCancellable: AnyCancellable?
    private var actionsCancellable: AnyCancellable?
    private let bubbleSize: CGFloat = 64
    private let chatWidth: CGFloat = 320
    private let chatHeight: CGFloat = 540
    private let margin: CGFloat = 12

    private var isDragging = false
    private var dragOffset: NSPoint = .zero
    private var bubbleWatchdogTask: Task<Void, Never>?

    deinit {
        contextPollTask?.cancel()
        bubbleWatchdogTask?.cancel()
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
        observeStreaming()
        startContextPolling()
        startBubbleWatchdog()
        observePushMessages()
    }

    // MARK: - Bubble Panel

    private func createBubblePanel() {
        let dotSizeCalc: CGFloat = 14
        let panelExtra = dotSizeCalc / 2
        let panelSize = bubbleSize + panelExtra

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelSize, height: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none

        // Wrapper view (unclipped) holds the bubble circle + notification dot
        let dotSize: CGFloat = 14
        let padding: CGFloat = dotSize / 2
        let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: bubbleSize + padding, height: bubbleSize + padding))
        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = .clear

        // Pure AppKit bubble — no SwiftUI/NSHostingView to avoid focus stealing
        let container = NSView(frame: NSRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(red: 0.16, green: 0.14, blue: 0.13, alpha: 0.85).cgColor
        container.layer?.cornerRadius = bubbleSize / 2
        container.layer?.masksToBounds = true

        if let iconURL = Bundle.main.url(forResource: "icon", withExtension: "png"),
           let nsImage = NSImage(contentsOf: iconURL) {
            let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize))
            imageView.image = nsImage
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = bubbleSize / 2
            imageView.layer?.masksToBounds = true
            container.addSubview(imageView)
        }

        // Subtle border ring
        let borderLayer = CAShapeLayer()
        borderLayer.path = CGPath(ellipseIn: NSRect(x: 0.75, y: 0.75, width: bubbleSize - 1.5, height: bubbleSize - 1.5), transform: nil)
        borderLayer.fillColor = nil
        borderLayer.strokeColor = NSColor(red: 0.63, green: 0.63, blue: 0.63, alpha: 0.5).cgColor
        borderLayer.lineWidth = 1.5
        container.layer?.addSublayer(borderLayer)

        wrapper.addSubview(container)

        // Notification dot (top-right of bubble, outside clipping mask)
        let notifDot = NSView(frame: NSRect(x: bubbleSize - dotSize / 2, y: bubbleSize - dotSize / 2, width: dotSize, height: dotSize))
        notifDot.wantsLayer = true
        notifDot.layer?.cornerRadius = dotSize / 2
        notifDot.layer?.backgroundColor = NSColor(red: 0.76, green: 0.35, blue: 0.29, alpha: 1).cgColor // #c25a4a
        notifDot.layer?.borderColor = NSColor(red: 0.16, green: 0.14, blue: 0.13, alpha: 1).cgColor
        notifDot.layer?.borderWidth = 2
        notifDot.isHidden = true
        wrapper.addSubview(notifDot)
        self.notificationDot = notifDot

        panel.contentView = wrapper

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - panelSize - 20
            let y = screenFrame.minY + 120
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        let dragView = BubbleDragView(frame: NSRect(x: 0, y: 0, width: panelSize, height: panelSize))
        dragView.controller = self
        wrapper.addSubview(dragView)

        self.bubblePanel = panel
        panel.orderFront(nil)
    }

    // MARK: - Chat Panel (SwiftUI ContextPanelView)

    private var hostingView: NSHostingView<ContextPanelView>?

    private func createChatPanel() {
        guard let chatService else { return }

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: chatWidth, height: chatHeight),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.minSize = NSSize(width: 260, height: 400)
        panel.maxSize = NSSize(width: 600, height: 900)
        panel.isFloatingPanel = true

        let panelView = ContextPanelView(
            chatService: chatService,
            onClose: { [weak self] in self?.hideChat() }
        )
        let hosting = NSHostingView(rootView: panelView)
        hosting.frame = NSRect(x: 0, y: 0, width: chatWidth, height: chatHeight)
        hosting.autoresizingMask = [.width, .height]
        self.hostingView = hosting

        panel.contentView = hosting
        self.chatPanel = panel
    }

    // Header is now managed by ContextPanelView (SwiftUI)
    // Server online state is observed directly by ContextPanelView via ChatService

    // MARK: - Notification dot

    private func showNotificationDot() {
        guard let dot = notificationDot, dot.isHidden else { return }
        dot.alphaValue = 0
        dot.isHidden = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            dot.animator().alphaValue = 1
        }
    }

    private func hideNotificationDot() {
        guard let dot = notificationDot, !dot.isHidden else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            dot.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.notificationDot?.isHidden = true
            self?.notificationDot?.alphaValue = 1
        })
    }

    // MARK: - Stream observation (push tokens to WebView)

    private func observeStreaming() {
        guard let chatService else { return }

        // SwiftUI ContextPanelView handles rendering via @ObservedObject.
        // We only observe here for notification dot + action execution.
        streamCancellable = chatService.$streamDelta
            .receive(on: DispatchQueue.main)
            .sink { [weak self] delta in
                guard let self, let delta else { return }
                if delta.kind == .finished && !self.isChatVisible {
                    self.showNotificationDot()
                }
            }

        actionsCancellable = chatService.$actions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] actions in
                guard !actions.isEmpty else { return }
                NSLog("[Erestor] actions received: \(actions.map { $0.type }), actionHandler nil? \(self?.actionHandler == nil)")
                self?.actionHandler?.execute(actions)
            }
    }

    // MARK: - Push message observation (show notification when chat is closed)

    private func observePushMessages() {
        NotificationCenter.default.addObserver(
            forName: .erestorPushMessageReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if !self.isChatVisible {
                let text = notification.userInfo?["text"] as? String ?? "Nova mensagem do Erestor"
                let eventType = notification.userInfo?["eventType"] as? String ?? "message"
                self.sendPushNotification(text: text, eventType: eventType)
                self.showNotificationDot()
            }
        }
    }

    private func sendPushNotification(text: String, eventType: String = "message") {
        let content = UNMutableNotificationContent()
        content.body = text
        content.sound = .default

        switch eventType {
        case "poll_energy":
            content.title = "Erestor — Enquete"
            content.categoryIdentifier = "POLL_ENERGY"
        case "poll_quality":
            content.title = "Erestor — Enquete"
            content.categoryIdentifier = "POLL_QUALITY"
        case "gate_inform":
            content.title = "Erestor — Alerta"
            content.categoryIdentifier = "GATE_INFORM"
        case "reminder":
            content.title = "Erestor — Lembrete"
            content.categoryIdentifier = "REMINDER"
        default:
            content.title = "Erestor"
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Push notification failed: \(error.localizedDescription)")
            }
        }
    }

    // Message rendering is handled by SwiftUI ContextPanelView via @ObservedObject chatService

    // MARK: - Context polling (feeds WebView)

    private func startContextPolling() {
        contextPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                guard let self else { break }
                await self.chatService?.loadContext()
            }
        }
    }

    // MARK: - Bubble watchdog (ensure bubble never disappears)

    private func startBubbleWatchdog() {
        // Also re-show bubble on workspace/display changes
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.ensureBubbleVisible()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.ensureBubbleVisible()
        }

        // Periodic check every 5s — if bubble is not visible, bring it back
        bubbleWatchdogTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                self?.ensureBubbleVisible()
            }
        }
    }

    private func ensureBubbleVisible() {
        guard let panel = bubblePanel else { return }
        if !panel.isVisible {
            NSLog("[Erestor] Bubble watchdog: panel was hidden, restoring")
            panel.orderFront(nil)
        }
        // Also verify bubble is on-screen (not pushed off by display changes)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let bubbleFrame = panel.frame
            if !screenFrame.intersects(bubbleFrame) {
                NSLog("[Erestor] Bubble watchdog: panel was off-screen, repositioning")
                let dotPadding: CGFloat = 7 // dotSize / 2
                let x = screenFrame.maxX - (bubbleSize + dotPadding) - 20
                let y = screenFrame.minY + 120
                panel.setFrameOrigin(NSPoint(x: x, y: y))
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

        hideNotificationDot()
        positionChatPanel(relativeTo: bubblePanel.frame)

        chatPanel.alphaValue = 0
        chatPanel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            chatPanel.animator().alphaValue = 1
        }

        isChatVisible = true

        // Focus panel — nonactivatingPanel can receive keys without stealing app focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, let chatPanel = self.chatPanel else { return }
            chatPanel.makeKey()
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
        addCursorRect(bounds, cursor: .arrow)
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
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        // Escape → close chat
        if event.keyCode == 53 {
            BubbleWindowController.shared.hideChat()
            return
        }
        // Cmd+K → clear conversation
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
            Task { @MainActor in
                await BubbleWindowController.shared.chatService?.clearHistory()
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

    override func rightMouseUp(with event: NSEvent) {
        let menu = NSMenu()
        let desktopItem = NSMenuItem(title: "Abrir Desktop", action: #selector(openDesktopAction), keyEquivalent: "")
        desktopItem.target = self
        menu.addItem(desktopItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Encerrar Erestor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        menu.addItem(quitItem)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func openDesktopAction() {
        ActionHandler.shared.openDesktop()
    }
}
