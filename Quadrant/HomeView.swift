import SwiftUI

/// Home — the daily 2x2 Eisenhower matrix. The "Do Now" box is highlighted so the most important,
/// most urgent work reads at a glance. Tapping a box opens its task list; the + adds a task.
struct HomeView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showAdd = false
    @State private var addInto: Quadrant = .doNow
    @State private var openQuadrant: Quadrant?
    @State private var showTrend = false
    @State private var showSettings = false

    private let cal = Calendar.current

    private var isToday: Bool { cal.isDateInToday(appModel.selectedDay) }
    private var dayTitle: String {
        if isToday { return "Today" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: appModel.selectedDay)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 12) {
                    header
                    matrix
                    doNowBanner
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
            .navigationTitle("Quadrant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Haptics.tap(); showTrend = true } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    .accessibilityIdentifier("trend-button")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("settings-button")
                }
            }
            .tint(.appAccent)
            .safeAreaInset(edge: .bottom) { addBar }
            .sheet(isPresented: $showAdd) {
                AddTaskView(initialQuadrant: addInto)
            }
            .sheet(item: $openQuadrant) { q in
                QuadrantDetailView(quadrant: q)
            }
            .sheet(isPresented: $showTrend) { WeeklyTrendView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear { appModel.reseedRecurringIfNeeded() }
        }
    }

    // MARK: Header (day + focus)

    private var header: some View {
        let tasks = appModel.tasksForSelectedDay()
        let done = tasks.filter { $0.done }.count
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayTitle).font(.title3.weight(.bold))
                Text(tasks.isEmpty ? "No tasks yet"
                     : "\(done)/\(tasks.count) done · \(Int(appModel.focusScoreForSelectedDay() * 100))% on important")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 2)
    }

    // MARK: The 2x2 matrix

    private var matrix: some View {
        let tasks = appModel.tasksForSelectedDay()
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return VStack(spacing: 8) {
            axisLabel("Important", system: "arrow.up")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Quadrant.gridOrder) { q in
                    QuadrantBox(quadrant: q,
                                tasks: MatrixAnalytics.tasks(tasks, in: q)) {
                        Haptics.tap(); openQuadrant = q
                    }
                    .frame(height: 150)
                }
            }
            axisLabel("Urgent", system: "arrow.left.and.right")
        }
        // revision triggers a re-pull when the store mutates.
        .id(appModel.revision)
    }

    private func axisLabel(_ text: String, system: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: system).font(.system(size: 10, weight: .bold))
            Text(text.uppercased()).font(.system(size: 10, weight: .bold)).tracking(1)
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: Do-Now banner (the at-a-glance call to action)

    @ViewBuilder
    private var doNowBanner: some View {
        let doNow = MatrixAnalytics.tasks(appModel.tasksForSelectedDay(), in: .doNow)
            .filter { !$0.done }
        if let next = doNow.first {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill").foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Do now").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.85))
                    Text(next.title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white).lineLimit(1)
                }
                Spacer()
                Button {
                    Haptics.success(); appModel.toggleDone(next)
                } label: {
                    Image(systemName: "checkmark").font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.white.opacity(0.2), in: Circle())
                }
                .accessibilityIdentifier("donow-complete")
            }
            .padding(14)
            .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .id(appModel.revision)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.appAccent)
                Text("Nothing urgent + important. Nice and clear.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(14)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .id(appModel.revision)
        }
    }

    // MARK: Add bar

    private var addBar: some View {
        Button {
            Haptics.tap(); addInto = .doNow; showAdd = true
        } label: {
            Label("Add task", systemImage: "plus")
                .frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .prominentButton()
        .accessibilityIdentifier("add-task")
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
}
