import SwiftUI

/// Add task — title + a 2x2 quadrant picker (urgent vs important) and, for Pro, a recurring toggle.
struct AddTaskView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let initialQuadrant: Quadrant

    @State private var title = ""
    @State private var quadrant: Quadrant
    @State private var recurring = false
    @State private var showPaywall = false
    @FocusState private var titleFocused: Bool

    init(initialQuadrant: Quadrant) {
        self.initialQuadrant = initialQuadrant
        _quadrant = State(initialValue: initialQuadrant)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        titleField
                        quadrantPicker
                        recurringRow
                    }
                    .padding()
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { add() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("save-task")
                }
            }
            .tint(.appAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear { titleFocused = true }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TASK").font(.caption.weight(.bold)).foregroundStyle(.secondary).tracking(1)
            TextField("What needs doing?", text: $title, axis: .vertical)
                .font(.title3)
                .focused($titleFocused)
                .submitLabel(.done)
                .padding(14)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("task-title")
        }
    }

    private var quadrantPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHERE DOES IT GO?").font(.caption.weight(.bold))
                .foregroundStyle(.secondary).tracking(1)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Quadrant.gridOrder) { q in
                    Button {
                        Haptics.tap(); quadrant = q
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: q.symbol).font(.system(size: 13, weight: .semibold))
                                Text(q.title).font(.subheadline.weight(.bold))
                            }
                            Text(q.axisLabel).font(.caption2)
                                .foregroundStyle(quadrant == q ? .white.opacity(0.85) : .secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 70)
                        .padding(12)
                        .background(quadrant == q ? Color.appAccent : Color.appCard,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(quadrant == q ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pick-\(q.rawValue)")
                }
            }
            Text(quadrant.advice).font(.caption).foregroundStyle(.secondary).padding(.top, 2)
        }
    }

    private var recurringRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                if store.isPro {
                    Haptics.tap(); recurring.toggle()
                } else {
                    Haptics.tap(); showPaywall = true
                }
            } label: {
                HStack {
                    Image(systemName: recurring ? "checkmark.circle.fill" : "repeat")
                        .foregroundStyle(Color.appAccent)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text("Repeat daily").foregroundStyle(.primary)
                            if !store.isPro {
                                Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("Re-add this task automatically each day.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.isPro {
                        Toggle("", isOn: $recurring).labelsHidden().tint(.appAccent)
                    }
                }
                .padding(14)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recurring-toggle")
        }
    }

    private func add() {
        appModel.addTask(title: title, quadrant: quadrant, recurring: recurring && store.isPro)
        Haptics.success()
        dismiss()
    }
}
