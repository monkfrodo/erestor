import SwiftUI

struct FloatingBubbleView: View {
    @EnvironmentObject var chatService: ChatService
    let onTap: () -> Void

    var body: some View {
        ZStack {
            // Erestor face fills the entire bubble
            if let iconURL = Bundle.main.url(forResource: "icon", withExtension: "png"),
               let nsImage = NSImage(contentsOf: iconURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(hex: "#0a0a0c"))
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color(hex: "#a0a0a0"))
            }

            // Subtle border ring
            Circle()
                .strokeBorder(accentColor.opacity(0.5), lineWidth: 1.5)

            // Streaming pulse
            if chatService.isStreaming {
                Circle()
                    .strokeBorder(Color(hex: "#4a9f68").opacity(0.8), lineWidth: 2)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: chatService.isStreaming
                    )
            }

            // Offline indicator
            if !chatService.serverOnline {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .offset(x: 18, y: -18)
            }
        }
        .frame(width: 52, height: 52)
        .contentShape(Circle())
        .onTapGesture { onTap() }
    }

    private var accentColor: Color {
        if chatService.isStreaming {
            return Color(hex: "#4a9f68")
        }
        return chatService.serverOnline ? Color(hex: "#a0a0a0") : Color(hex: "#333333")
    }

    private var pulseScale: CGFloat { chatService.isStreaming ? 1.4 : 1.0 }
    private var pulseOpacity: Double { chatService.isStreaming ? 0.0 : 0.6 }
}
