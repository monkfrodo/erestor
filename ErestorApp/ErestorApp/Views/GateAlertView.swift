import SwiftUI

enum GateSeverity {
    case amber
    case red

    var textColor: Color {
        switch self {
        case .amber: return Color(hex: "c9a84c")
        case .red: return Color(hex: "d4756a")
        }
    }

    var bgColor: some ShapeStyle {
        switch self {
        case .amber: return Color(hex: "c9a84c").opacity(0.08)
        case .red: return Color(hex: "c25a4a").opacity(0.08)
        }
    }

    var borderColor: Color {
        switch self {
        case .amber: return Color(hex: "c9a84c").opacity(0.15)
        case .red: return Color(hex: "c25a4a").opacity(0.18)
        }
    }
}

struct GateAlertAction {
    let label: String
    let action: () -> Void
}

struct GateAlertView: View {
    let text: String
    let severity: GateSeverity
    var actions: [GateAlertAction] = []
    var tasks: [String]? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("erestor \u{00b7} gate")
                    .font(DS.mono(9))
                    .foregroundColor(DS.dim)

                Spacer()

                if let onDismiss {
                    Button(action: onDismiss) {
                        Text("\u{00d7}")
                            .font(.system(size: 12))
                            .foregroundColor(DS.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)

            Text(text)
                .font(DS.body(12))
                .foregroundColor(severity.textColor)
                .lineSpacing(1.5)

            // Task list (from GateSSEEvent)
            if let tasks, !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(tasks.enumerated()), id: \.offset) { _, task in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(severity.textColor.opacity(0.6))
                                .frame(width: 4, height: 4)
                                .padding(.top, 5)
                            Text(task)
                                .font(DS.body(11))
                                .foregroundColor(severity.textColor.opacity(0.8))
                                .lineSpacing(1.2)
                        }
                    }
                }
                .padding(.top, 6)
            }

            if !actions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { idx, action in
                        Button(action.label) {
                            action.action()
                        }
                        .buttonStyle(.plain)
                        .font(DS.mono(10))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .foregroundColor(idx == 0 ? DS.amber : DS.dim)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(idx == 0 ? DS.amber.opacity(0.25) : DS.border, lineWidth: 1)
                        )
                        .cornerRadius(6)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(severity.bgColor)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(severity.borderColor, lineWidth: 1)
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
