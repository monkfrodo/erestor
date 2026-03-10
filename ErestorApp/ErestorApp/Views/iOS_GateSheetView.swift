#if os(iOS)
import SwiftUI

struct iOS_GateSheetView: View {
    let gate: GateSSEEvent
    let onDismiss: () -> Void

    private var severityColor: Color {
        gate.severity == "red" ? DS.red : DS.amber
    }

    var body: some View {
        VStack(spacing: 16) {
            // Severity indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(severityColor)
                    .frame(width: 10, height: 10)
                Text("Alerta")
                    .font(DS.body(16, weight: .medium))
                    .foregroundColor(severityColor)
            }
            .padding(.top, 20)

            // Gate message
            Text(gate.text)
                .font(DS.body(16, weight: .medium))
                .foregroundColor(DS.bright)
                .multilineTextAlignment(.center)

            // Task list
            if let tasks = gate.tasks, !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tasks, id: \.self) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(severityColor.opacity(0.6))
                                .frame(width: 4, height: 4)
                            Text(task)
                                .font(DS.body(13))
                                .foregroundColor(DS.text)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
            }

            // Dismiss button
            Button(action: onDismiss) {
                Text("Dispensar")
                    .font(DS.body(14, weight: .medium))
                    .foregroundColor(DS.bright)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DS.muted)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(DS.bg)
    }
}
#endif
