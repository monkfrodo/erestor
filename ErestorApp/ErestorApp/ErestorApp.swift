import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let chatService = ChatService()
    let actionHandler = ActionHandler.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Close any default window SwiftUI may have created
        for window in NSApp.windows {
            window.orderOut(nil)
        }

        // Setup floating bubble + chat panel
        let bubble = BubbleWindowController.shared
        bubble.setup(chatService: chatService, actionHandler: actionHandler)

        // Global hotkey toggles chat
        GlobalHotkey.shared.register {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                BubbleWindowController.shared.toggleChat()
            }
        }

        // Load context
        Task { await chatService.loadContext() }

        // Notification delegate for LSUIElement apps
        UNUserNotificationCenter.current().delegate = self
    }

    // Show notifications even when app is foreground (LSUIElement)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct ErestorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Erestor", image: "MenuBarIcon") {
            MenuBarView()
                .environmentObject(appDelegate.chatService)
                .environmentObject(appDelegate.actionHandler)
        }
        .menuBarExtraStyle(.window)
    }
}
