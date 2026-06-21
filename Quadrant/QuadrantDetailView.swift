import SwiftUI

/// The task list for a single quadrant. Tasks can be completed, deleted, and — the core interaction
/// of the app — moved to another quadrant as priorities shift, via a context menu / move menu.
struct QuadrantDetailView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let quadrant: Quadrant

    private var tasks: [TaskItem] {
        MatrixAnalytics.tasks(appModel.tasksForSelectedDay(), in: quadrant)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if tasks.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(tasks) { task in
                                row(task)
                            }
                        } header: {
                            Text(quadrant.advice)
                                .font(.footnote).foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(quadrant.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(.appAccent)
            .id(appModel.revision)
        }
    }

    private func row(_ task: TaskItem) -> some View {
        HStack(spacing: 12) {
            Button {
                Haptics.success(); appModel.toggleDone(task)
            } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.done ? Color.appAccent : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("toggle-\(task.id.uuidString)")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.done, color: .secondary)
                    .foregroundStyle(task.done ? .secondary : .primary)
                if task.recurring {
                    Label("Repeats daily", systemImage: "repeat")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()

            Menu {
                Section("Move to") {
                    ForEach(Quadrant.gridOrder.filter { $0 != quadrant }) { q in
                        Button {
                            Haptics.tap(); appModel.move(task, to: q)
                        } label: {
                            Label(q.title, systemImage: q.symbol)
                        }
                    }
                }
                Button(role: .destructive) {
                    Haptics.soft(); appModel.delete(task)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("menu-\(task.id.uuidString)")
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { appModel.delete(task) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: quadrant.symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(quadrant.tint.opacity(0.6))
            Text("Nothing here yet").font(.headline)
            Text(quadrant.advice).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding()
    }
}
