import SwiftUI
import AppKit

struct TransparentWindowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TransparentWindowHelper())
    }
}

struct TransparentWindowHelper: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.standardWindowButton(.closeButton)?.superview?.superview?.wantsLayer = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    func transparentWindow() -> some View {
        modifier(TransparentWindowModifier())
    }
}
