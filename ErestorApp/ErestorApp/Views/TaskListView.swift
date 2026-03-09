import SwiftUI

struct TaskListView: View {
    let tasks: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(tasks.enumerated()), id: \.offset) { _, task in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(DS.red)
                        .frame(width: 4, height: 4)
                        .padding(.top, 5)

                    Text(task)
                        .font(DS.body(11.5))
                        .foregroundColor(Color(hex: "8a7d73"))
                        .lineSpacing(1.4)
                }
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
    }
}
