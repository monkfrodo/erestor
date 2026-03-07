import SwiftUI

@main
struct ErestorApp: App {
    @StateObject private var chatService = ChatService()

    var body: some Scene {
        // Main window
        Window("Erestor", id: "main") {
            HSplitView {
                SidebarView()
                    .frame(width: 190)

                ChatWebViewVC()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .environmentObject(chatService)
            .frame(minWidth: 460, minHeight: 550)
            .background(Color(hex: "#0a0a0c").opacity(0.95))
            .transparentWindow()
            .task {
                await chatService.loadContext()
            }
        }
        .defaultSize(width: 560, height: 680)
        .windowStyle(.hiddenTitleBar)

        // Menu bar
        MenuBarExtra("Erestor", systemImage: "brain.head.profile") {
            MenuBarView()
                .environmentObject(chatService)
        }
        .menuBarExtraStyle(.window)
    }
}
