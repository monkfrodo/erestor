import SwiftUI

enum PollType {
    case energy
    case quality
}

struct PollCardView: View {
    let type: PollType
    let question: String
    let onResponse: (String) -> Void

    // Optional SSE poll data for backend integration
    var pollId: String? = nil
    var options: [String]? = nil
    var expiresAt: Double? = nil

    @State private var selected: String?
    @State private var visible = true
    @State private var timeRemaining: Int = 0
    @State private var expiryTimer: Timer?

    private var energyOptions: [(String, String)] {
        if let opts = options {
            return opts.enumerated().map { (idx, label) in
                ("\(idx + 1)", label)
            }
        }
        return [("1", "morto"), ("2", "baixa"), ("3", "ok"), ("4", "boa"), ("5", "pico")]
    }

    private var qualityOptions: [String] {
        options ?? ["perdi", "meh", "ok", "flow"]
    }

    var body: some View {
        if visible {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("erestor \u{00b7} \(type == .energy ? "check-in" : "fim do bloco")")
                            .font(DS.mono(9))
                            .foregroundColor(DS.dim)

                        Text(question)
                            .font(DS.body(12))
                            .foregroundColor(DS.bright)
                            .lineSpacing(1.4)
                    }

                    Spacer()

                    // Expiry countdown
                    if timeRemaining > 0 {
                        Text("\(timeRemaining / 60)min")
                            .font(DS.mono(9))
                            .foregroundColor(DS.dim)
                    }
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
            .onAppear {
                startExpiryCountdown()
            }
            .onDisappear {
                expiryTimer?.invalidate()
            }
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

    private func startExpiryCountdown() {
        guard let expiresAt else { return }
        let remaining = Int(expiresAt - Date().timeIntervalSince1970)
        guard remaining > 0 else {
            // Already expired -- auto-dismiss
            withAnimation(.easeInOut(duration: 0.2)) { visible = false }
            return
        }
        timeRemaining = remaining

        expiryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let rem = Int(expiresAt - Date().timeIntervalSince1970)
            if rem <= 0 {
                expiryTimer?.invalidate()
                // Auto-dismiss expired poll (backend handles "not_answered")
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.2)) { visible = false }
                }
            } else {
                DispatchQueue.main.async {
                    timeRemaining = rem
                }
            }
        }
    }
}
