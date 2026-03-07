import SwiftUI

// ContentView kept as backup — main layout is now in ErestorApp.swift
struct ContentView: View {
    @EnvironmentObject var chatService: ChatService

    var body: some View {
        HSplitView {
            SidebarView()
                .frame(width: 260)

            ChatWebViewVC()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
