import SwiftUI

struct NextEventView: View {
    let timeRemaining: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(timeRemaining)
                .font(DS.mono(10))
                .foregroundColor(DS.dim)
                .frame(minWidth: 32, alignment: .leading)

            Text(title)
                .font(DS.body(11))
                .foregroundColor(DS.dim)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
    }
}
