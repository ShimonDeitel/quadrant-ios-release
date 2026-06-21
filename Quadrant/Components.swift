import SwiftUI

/// One box of the 2x2 matrix on Home. Shows the quadrant title, axis label, a live count and the
/// top few tasks. Tapping the box opens its detail list.
struct QuadrantBox: View {
    let quadrant: Quadrant
    let tasks: [TaskItem]
    let onTap: () -> Void

    private var open: Int { tasks.filter { !$0.done }.count }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: quadrant.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(quadrant.tint)
                    Text(quadrant.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Text("\(open)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(quadrant.tint)
                        .frame(minWidth: 20)
                        .padding(.vertical, 2).padding(.horizontal, 6)
                        .background(quadrant.tint.opacity(0.12), in: Capsule())
                }
                Text(quadrant.axisLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Divider().overlay(Color.appHair)

                if tasks.isEmpty {
                    Text("Empty")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(tasks.prefix(3)) { t in
                            HStack(spacing: 5) {
                                Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(t.done ? quadrant.tint : Color.secondary)
                                Text(t.title)
                                    .font(.caption)
                                    .strikethrough(t.done, color: .secondary)
                                    .foregroundStyle(t.done ? .secondary : .primary)
                                    .lineLimit(1)
                            }
                        }
                        if tasks.count > 3 {
                            Text("+\(tasks.count - 3) more")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(quadrant == .doNow ? quadrant.tint.opacity(0.5) : Color.clear,
                                  lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("box-\(quadrant.rawValue)")
    }
}

/// A small labelled metric tile used on the weekly trend screen.
struct MetricTile: View {
    let value: String
    let label: String
    var tint: Color = .appAccent
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Wraps UIActivityViewController so we can share a text reflection (Pro).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// A compact bar for one day in the weekly trend: win (accent) over trap (grey).
struct DayBar: View {
    let balance: DayBalance
    let maxTotal: Int
    private let cal = Calendar.current

    private var dayLetter: String {
        let f = DateFormatter(); f.dateFormat = "EEEEE"
        return f.string(from: balance.date)
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let h = geo.size.height
                let unit = maxTotal == 0 ? 0 : h / CGFloat(maxTotal)
                VStack(spacing: 2) {
                    Spacer(minLength: 0)
                    if balance.winCount > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.appAccent)
                            .frame(height: max(3, unit * CGFloat(balance.winCount)))
                    }
                    if balance.trapCount > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(uiColor: .systemGray3))
                            .frame(height: max(3, unit * CGFloat(balance.trapCount)))
                    }
                    if balance.total == 0 {
                        Circle().fill(Color.appHair).frame(width: 4, height: 4)
                            .padding(.bottom, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
            Text(dayLetter)
                .font(.caption2)
                .foregroundStyle(cal.isDateInToday(balance.date) ? Color.appAccent : .secondary)
        }
    }
}
