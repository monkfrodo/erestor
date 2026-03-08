import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let chatService = ChatService()
    let actionHandler = ActionHandler.shared
    private var windowCleanupTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        DispatchQueue.main.async {
            self.closeStaleWindows()
            BubbleWindowController.shared.showChat()
        }
        completionHandler()
    }

    private func closeStaleWindows() {
        let bubble = BubbleWindowController.shared
        let managedNumbers: Set<Int> = Set([
            bubble.bubblePanel?.windowNumber,
            bubble.chatWebVC?.webView?.window?.windowNumber
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
