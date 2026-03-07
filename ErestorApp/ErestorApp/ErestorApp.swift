import SwiftUI

@main
struct ErestorApp: App {
    @StateObject private var chatService = ChatService()
    @StateObject private var actionHandler = ActionHandler.shared

    var body: some Scene {
        // Invisible settings window (required — SwiftUI needs at least one Scene)
        Window("Erestor", id: "main") {
            Color.clear
                .frame(width: 0, height: 0)
                .task {
                    await chatService.loadContext()

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

                    // Hide the invisible placeholder window
                    DispatchQueue.main.async {
                        for window in NSApp.windows where window.identifier?.rawValue == "main" {
                            window.orderOut(nil)
                        }
                    }
                }
        }
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("Erestor", image: "MenuBarIcon") {
            MenuBarView()
                .environmentObject(chatService)
                .environmentObject(actionHandler)
        }
        .menuBarExtraStyle(.window)
    }
}
