import SwiftUI

enum PollType {
    case energy
    case quality
}

struct PollCardView: View {
    let type: PollType
    let question: String
    let onResponse: (String) -> Void

    @State private var selected: String?
    @State private var visible = true

    private let energyOptions = [
        ("1", "morto"), ("2", "baixa"), ("3", "ok"), ("4", "boa"), ("5", "pico")
    ]
    private let qualityOptions = ["perdi", "meh", "ok", "flow"]

    var body: some View {
        if visible {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("erestor \u{00b7} \(type == .energy ? "check-in" : "fim do bloco")")
                        .font(DS.mono(9))
                        .foregroundColor(DS.dim)

                    Text(question)
                        .font(DS.body(12))
                        .foregroundColor(DS.bright)
                        .lineSpacing(1.4)
                }

                if type == .energy {
                    HStack(spacing: 6) {
                        ForEach(energyOptions, id: \.0) { num, label in
                            energyButton(num: num, label: label)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        ForEach(qualityOptions, id: \.self) { label in
                            qualityButton(label: label)
                        }
                    }
                }
            }
            .padding(12)
            .background(DS.s2)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DS.border, lineWidth: 1)
            )
            .cornerRadius(10)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
        }
    }

    private func energyButton(num: String, label: String) -> some View {
        let isSelected = selected == num
        return Button {
            select(num)
        } label: {
            VStack(spacing: 3) {
                Text(num)
                    .font(DS.mono(13, weight: .medium))
                    .foregroundColor(isSelected ? DS.bright : DS.subtle)
                Text(label)
                    .font(DS.body(8))
                    .foregroundColor(isSelected ? DS.dim : DS.muted)
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? DS.greenDim : DS.bg)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? DS.green.opacity(0.15) : DS.border, lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func qualityButton(label: String) -> some View {
        let isSelected = selected == label
        return Button {
            select(label)
        } label: {
            Text(label)
                .font(DS.mono(10))
                .foregroundColor(isSelected ? DS.green : DS.subtle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? DS.greenDim : DS.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? DS.green.opacity(0.15) : DS.border, lineWidth: 1)
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func select(_ value: String) {
        selected = value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.2)) {
                visible = false
            }
            onResponse(value)
        }
    }
}
