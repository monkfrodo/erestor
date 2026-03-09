import SwiftUI

struct ChatInputView: View {
    let onSend: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            TextField("pergunte algo...", text: $text)
                .textFieldStyle(.plain)
                .font(DS.body(11.5))
                .foregroundColor(DS.bright)
                .focused($isFocused)
                .onSubmit { send() }

            Button(action: send) {
                Text("\u{2191}")
                    .font(.system(size: 13))
                    .foregroundColor(text.isEmpty ? DS.muted : DS.subtle)
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(DS.s2)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isFocused ? DS.muted : DS.border, lineWidth: 1)
        )
        .cornerRadius(10)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSend(trimmed)
        text = ""
    }
}
