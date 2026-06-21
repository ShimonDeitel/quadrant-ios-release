import SwiftUI

/// Weekly trend (PRO) — how many tasks landed in the win (Schedule) vs trap (Delegate) quadrant over
/// the last 7 days, plus per-quadrant analytics and a shareable reflection. Free users see a locked
/// preview that opens the paywall.
struct WeeklyTrendView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var shareText: String?

    private var trend: [DayBalance] { appModel.weekTrend() }
    private var maxTotal: Int { max(1, trend.map { $0.total }.max() ?? 1) }
    private var winTrap: (win: Int, trap: Int) { appModel.weekWinTrap() }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        if store.isPro {
                            reflection
                            chartCard
                            quadrantAnalytics
                        } else {
                            lockedPreview
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Weekly Trend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                if store.isPro {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { share() } label: { Image(systemName: "square.and.arrow.up") }
                            .accessibilityIdentifier("share-reflection")
                    }
                }
            }
            .tint(.appAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(item: Binding(get: { shareText.map { ShareItem(text: $0) } },
                                 set: { shareText = $0?.text })) { item in
                ShareSheet(items: [item.text])
            }
            .id(appModel.revision)
        }
    }

    // MARK: Reflection (win vs trap)

    private var reflection: some View {
        let w = winTrap.win, t = winTrap.trap
        let verdict: String
        if w == 0 && t == 0 { verdict = "No important-vs-busywork tasks logged this week yet." }
        else if w >= t { verdict = "More planned wins than busywork traps. Strong week." }
        else { verdict = "Busywork is outweighing planned wins. Protect time for what matters." }
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                MetricTile(value: "\(w)", label: "Wins\n(Scheduled)", tint: .appAccent)
                MetricTile(value: "\(t)", label: "Traps\n(Delegated)", tint: Color(uiColor: .systemGray))
            }
            Text(verdict)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: 7-day chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 days").font(.headline)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(trend) { day in
                    DayBar(balance: day, maxTotal: maxTotal)
                }
            }
            .frame(height: 130)
            legend
        }
        .appCard()
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(Color.appAccent).frame(width: 12, height: 12)
                Text("Win").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(Color(uiColor: .systemGray3)).frame(width: 12, height: 12)
                Text("Trap").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: Per-quadrant analytics (this week)

    private var quadrantAnalytics: some View {
        let weekTasks = lastSevenDaysTasks()
        let tallies = MatrixAnalytics.tallies(weekTasks)
        return VStack(alignment: .leading, spacing: 12) {
            Text("This week by quadrant").font(.headline)
            ForEach(tallies) { tally in
                HStack(spacing: 12) {
                    Image(systemName: tally.quadrant.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tally.quadrant.tint)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tally.quadrant.title).font(.subheadline.weight(.semibold))
                        Text("\(tally.done)/\(tally.total) done")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(tally.completionRate * 100))%")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(tally.quadrant.tint)
                }
                if tally.quadrant != Quadrant.gridOrder.last {
                    Divider().overlay(Color.appHair)
                }
            }
        }
        .appCard()
    }

    // MARK: Locked preview (free)

    private var lockedPreview: some View {
        VStack(spacing: 18) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text("See your weekly trend").font(.title2.weight(.bold))
            Text("Quadrant Pro shows how many tasks landed in your win box vs the busywork trap each week, with per-quadrant analytics and sharing.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Haptics.tap(); showPaywall = true
            } label: {
                Text("Unlock Pro · \(store.displayPrice)").frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .prominentButton()
            .accessibilityIdentifier("trend-unlock")
        }
        .padding(.vertical, 40)
        .padding(.horizontal)
    }

    // MARK: Helpers

    private func lastSevenDaysTasks() -> [TaskItem] {
        let cal = Calendar.current
        let earliest = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: appModel.selectedDay))!
        return appModel.allTasks().filter { $0.date >= earliest }
    }

    private func share() {
        let w = winTrap.win, t = winTrap.trap
        shareText = "My week on Quadrant: \(w) planned wins vs \(t) busywork traps. Sorting tasks by urgent vs important keeps me on what matters."
        Haptics.tap()
    }
}

/// Identifiable wrapper so the share sheet can be driven by `.sheet(item:)`.
private struct ShareItem: Identifiable {
    let text: String
    var id: String { text }
}
