import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let chatService = ChatService()
    let actionHandler = ActionHandler.shared
    private var windowCleanupTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Singleton guard — prevent multiple instances (KeepAlive can restart while old is still alive)
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        if runningInstances.count > 1 {
            NSLog("[Erestor] Another instance already running — exiting")
            NSApp.terminate(nil)
            return
        }
        // Nuke state restoration completely
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame Main Window")
        UserDefaults.standard.removeObject(forKey: "NSWindowAutosaveFrameMovesToActiveDisplay")

        // Clear any saved window state from previous builds
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: "\(bundleID).savedState")
        }
        // Delete saved application state directory
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let savedState = appSupport.appendingPathComponent("Saved Application State")
                .appendingPathComponent("\(Bundle.main.bundleIdentifier ?? "").savedState")
            try? FileManager.default.removeItem(at: savedState)
        }

        closeStaleWindows()
        NSApp.setActivationPolicy(.accessory)

        let bubble = BubbleWindowController.shared
        bubble.setup(chatService: chatService, actionHandler: actionHandler)

        GlobalHotkey.shared.register {
            DispatchQueue.main.async {
                BubbleWindowController.shared.toggleChat()
            }
        }

        Task { await chatService.loadHistory() }
        Task { await chatService.loadContext() }
        Task { await chatService.checkStatus() }

        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()

        // Periodic cleanup — kill any rogue windows that macOS creates
        windowCleanupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closeStaleWindows()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Prevent macOS from creating/showing default windows on reopen
        closeStaleWindows()
        BubbleWindowController.shared.showChat()
        return false
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        let category = response.notification.request.content.categoryIdentifier

        // Handle notification action buttons
        if actionID != UNNotificationDefaultActionIdentifier && actionID != UNNotificationDismissActionIdentifier {
            sendPushResponse(category: category, action: actionID)
            completionHandler()
            return
        }

        // Default tap — open chat
        DispatchQueue.main.async {
            self.closeStaleWindows()
            BubbleWindowController.shared.showChat()
        }
        completionHandler()
    }

    private func registerNotificationCategories() {
        // Energy poll — 4 buttons (5th option "5-pico" opens panel via default tap)
        let energyActions = ["1-morto", "2-baixa", "3-ok", "4-boa"].map { label in
            UNNotificationAction(identifier: label, title: label, options: [])
        }
        let energyCategory = UNNotificationCategory(
            identifier: "POLL_ENERGY",
            actions: energyActions,
            intentIdentifiers: [],
            options: []
        )

        // Quality poll — 4 buttons
        let qualityActions = ["perdi", "meh", "ok", "flow"].map { label in
            UNNotificationAction(identifier: label, title: label, options: [])
        }
        let qualityCategory = UNNotificationCategory(
            identifier: "POLL_QUALITY",
            actions: qualityActions,
            intentIdentifiers: [],
            options: []
        )

        // Gate inform — Ver + Dispensar
        let gateActions = [
            UNNotificationAction(identifier: "ver", title: "Ver", options: [.foreground]),
            UNNotificationAction(identifier: "dispensar", title: "Dispensar", options: []),
        ]
        let gateCategory = UNNotificationCategory(
            identifier: "GATE_INFORM",
            actions: gateActions,
            intentIdentifiers: [],
            options: []
        )

        // Reminder — Ver + Dispensar
        let reminderCategory = UNNotificationCategory(
            identifier: "REMINDER",
            actions: gateActions,  // same buttons
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            energyCategory, qualityCategory, gateCategory, reminderCategory,
        ])
    }

    private func sendPushResponse(category: String, action: String) {
        // "ver" action opens chat
        if action == "ver" {
            DispatchQueue.main.async {
                self.closeStaleWindows()
                BubbleWindowController.shared.showChat()
            }
            return
        }
        // "dispensar" — just dismiss, no backend call
        if action == "dispensar" { return }

        // Poll responses — send to backend
        guard let url = ErestorConfig.url(for: "/api/push/respond") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        ErestorConfig.authorize(&request)

        let body: [String: String] = ["category": category, "action": action]
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request).resume()
    }

    private func closeStaleWindows() {
        let bubble = BubbleWindowController.shared
        let managedNumbers: Set<Int> = Set([
            bubble.bubblePanel?.windowNumber
        ].compactMap { $0 })

        for window in NSApp.windows {
            // Keep our managed panels and the MenuBarExtra status item window
            if managedNumbers.contains(window.windowNumber) { continue }
            if window is NSPanel { continue }
            // MenuBarExtra creates a small status item — don't close those
            if window.className.contains("StatusBar") || window.className.contains("MenuBar") { continue }

            if window.isVisible {
                NSLog("[Erestor] Closing stale window: \(window.className) #\(window.windowNumber)")
                window.orderOut(nil)
            }
        }
    }
}

@main
struct ErestorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Erestor", image: "MenuBarIcon") {
            Button("Abrir Chat ⌘⇧E") {
                BubbleWindowController.shared.toggleChat()
            }
            Divider()
            Button("Sair") {
                NSApp.terminate(nil)
            }
        }
    }
}
