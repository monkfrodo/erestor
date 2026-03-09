import SwiftUI

#if os(iOS)
@main
struct ErestorIOSApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Erestor")
                .font(.title)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
