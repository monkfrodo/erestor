import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let chatService = ChatService()
    let actionHandler = ActionHandler.shared
    private var windowCleanupTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Singleton guard — kill stale instances instead of exiting
        // (KeepAlive can restart us while old process is still in the process table)
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        let others = runningInstances.filter { $0 != NSRunningApplication.current }
        if !others.isEmpty {
            NSLog("[Erestor] Found \(others.count) other instance(s) — terminating them")
            for other in others {
                other.terminate()
            }
            // Give the OS a moment to clean up the old processes
            Thread.sleep(forTimeInterval: 0.5)
            // Force-kill any that didn't terminate gracefully
            let stillRunning = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
                .filter { $0 != NSRunningApplication.current }
            for stale in stillRunning {
                stale.forceTerminate()
            }
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
        let userInfo = response.notification.request.content.userInfo

        // Handle notification action buttons
        if actionID != UNNotificationDefaultActionIdentifier && actionID != UNNotificationDismissActionIdentifier {
            // Poll responses — parse poll_id from userInfo and POST to backend
            if let pollId = userInfo["poll_id"] as? String {
                let value = parsePollResponseValue(category: category, action: actionID)
                respondToPollBackend(pollId: pollId, value: value)
            } else {
                sendPushResponse(category: category, action: actionID)
            }
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
        // Energy poll — 5 action buttons (1-5 scale)
        let energyActions = (1...5).map { n in
            UNNotificationAction(identifier: "ENERGY_\(n)", title: "\(n)", options: [])
        }
        let energyCategory = UNNotificationCategory(
            identifier: "POLL_ENERGY",
            actions: energyActions,
            intentIdentifiers: [],
            options: []
        )

        // Quality poll — 4 action buttons
        let qualityActions = ["perdi", "meh", "ok", "flow"].map { opt in
            UNNotificationAction(identifier: "QUALITY_\(opt)", title: opt, options: [])
        }
        let qualityCategory = UNNotificationCategory(
            identifier: "POLL_QUALITY",
            actions: qualityActions,
            intentIdentifiers: [],
            options: []
        )

        // Gate inform — informational, Ver + Dispensar
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

        // Poll reminder — same action buttons as original poll type (energy default)
        let reminderEnergyActions = (1...5).map { n in
            UNNotificationAction(identifier: "ENERGY_\(n)", title: "\(n)", options: [])
        }
        let reminderCategory = UNNotificationCategory(
            identifier: "POLL_REMINDER",
            actions: reminderEnergyActions,
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            energyCategory, qualityCategory, gateCategory, reminderCategory,
        ])
    }

    /// Parse the selected value from a notification action identifier
    private func parsePollResponseValue(category: String, action: String) -> String {
        // "ENERGY_3" -> "3", "QUALITY_flow" -> "flow"
        if action.hasPrefix("ENERGY_") {
            return String(action.dropFirst("ENERGY_".count))
        }
        if action.hasPrefix("QUALITY_") {
            return String(action.dropFirst("QUALITY_".count))
        }
        return action
    }

    /// POST poll response to /v1/polls/{poll_id}/respond
    private func respondToPollBackend(pollId: String, value: String) {
        guard let url = ErestorConfig.url(for: "\(ErestorConfig.pollsPath)/\(pollId)/respond") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        ErestorConfig.authorize(&request)

        let body: [String: String] = ["value": value]
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let error {
                NSLog("[Erestor] Poll respond failed: \(error.localizedDescription)")
                return
            }
            // On success: remove poll from activePolls
            DispatchQueue.main.async {
                guard let self else { return }
                self.chatService.activePolls.removeAll { $0.pollId == pollId }
                // Cancel any pending reminder notification
                UNUserNotificationCenter.current().removePendingNotificationRequests(
                    withIdentifiers: [pollId, "\(pollId)_reminder"]
                )
            }
        }.resume()
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

        // Legacy push responses (non-poll)
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
