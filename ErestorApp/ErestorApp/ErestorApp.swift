import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let chatService = ChatService()
    let actionHandler = ActionHandler.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        for window in NSApp.windows {
            window.orderOut(nil)
        }

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
    }

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
