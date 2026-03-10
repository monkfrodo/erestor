#if os(iOS)
import SwiftUI

struct iOS_PollSheetView: View {
    let poll: PollSSEEvent
    let onResponse: (String) -> Void

    @State private var tappedOption: String?

    private var energyOptions: [(String, String)] {
        [("1", "morto"), ("2", "baixa"), ("3", "ok"), ("4", "boa"), ("5", "pico")]
    }

    private var qualityOptions: [String] {
        ["perdi", "meh", "ok", "flow"]
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(poll.question)
                .font(DS.body(18, weight: .semibold))
                .foregroundColor(DS.text)
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            if poll.pollType == "energy" {
                HStack(spacing: 8) {
                    ForEach(energyOptions, id: \.0) { num, label in
                        energyButton(num: num, label: label)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(qualityOptions, id: \.self) { label in
                        qualityButton(label: label)
                    }
                }
            }

            Button(action: { onResponse("remind_10") }) {
                Text("Lembrar em 10min")
                    .font(DS.body(13))
                    .foregroundColor(DS.muted)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(DS.bg)
    }

    private func energyButton(num: String, label: String) -> some View {
        let isSelected = tappedOption == num
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                tappedOption = num
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onResponse(num)
            }
        } label: {
            VStack(spacing: 4) {
                Text(num)
                    .font(DS.body(16, weight: .semibold))
                    .foregroundColor(isSelected ? DS.bright : DS.subtle)
                Text(label)
                    .font(DS.body(10))
                    .foregroundColor(isSelected ? DS.text : DS.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? DS.greenDim : DS.s2)
            .cornerRadius(8)
            .scaleEffect(isSelected ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func qualityButton(label: String) -> some View {
        let isSelected = tappedOption == label
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                tappedOption = label
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onResponse(label)
            }
        } label: {
            Text(label)
                .font(DS.body(14, weight: .medium))
                .foregroundColor(isSelected ? DS.green : DS.subtle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSelected ? DS.greenDim : DS.s2)
                .cornerRadius(8)
                .scaleEffect(isSelected ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
#endif
