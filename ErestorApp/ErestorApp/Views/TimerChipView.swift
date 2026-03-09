import SwiftUI

struct TimerChipView: View {
    let elapsed: String
    let label: String
    let onStop: () -> Void

    @State private var stopHovered = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(elapsed)
                .font(DS.mono(14, weight: .medium))
                .foregroundColor(DS.green)
                .tracking(0.5)

            Text(label)
                .font(DS.body(10.5))
                .foregroundColor(Color(hex: "5a7a62"))

            Button(action: onStop) {
                Text("parar")
                    .font(DS.mono(10))
                    .foregroundColor(stopHovered ? DS.red : DS.muted)
            }
            .buttonStyle(.plain)
            .onHover { stopHovered = $0 }
            .padding(.leading, 8)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(DS.greenDim)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DS.green.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(.top, 10)
    }
}
