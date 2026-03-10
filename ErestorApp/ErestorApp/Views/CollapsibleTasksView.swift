import SwiftUI

struct CollapsibleTasksView: View {
    let tasks: [String]
    @State private var isExpanded = false

    var body: some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("tarefas")
                            .font(DS.mono(9))
                            .foregroundColor(DS.dim)
                        Spacer()
                        Text("\(tasks.count)")
                            .font(DS.mono(9))
                            .foregroundColor(DS.muted)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(DS.muted)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                if isExpanded {
                    TaskListView(tasks: tasks)
                        .transition(.opacity)
                }
            }
        }
    }
}
