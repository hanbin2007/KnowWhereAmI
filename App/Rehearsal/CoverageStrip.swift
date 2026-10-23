import SwiftUI

/// Where in the manuscript the matches and misses fell, as stacked columns
/// from the first word to the last, in the manner of Screen Time.
struct CoverageStrip: View {
    let bins: [CoverageBin]
    let revealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Canvas { context, size in
                guard !bins.isEmpty else { return }
                let gap = 2.0
                let width = max(1, (size.width - gap * Double(bins.count - 1)) / Double(bins.count))
                for (index, bin) in bins.enumerated() {
                    let x = Double(index) * (width + gap)
                    let column = CGRect(x: x, y: 0, width: width, height: size.height)
                    let shape = Path(roundedRect: column, cornerRadius: min(2, width / 2), style: .continuous)
                    context.fill(shape, with: .color(RehearsalColor.unassessed))
                    var colored = context
                    colored.clip(to: shape)
                    let total = Double(max(1, bin.total))
                    let matched = size.height * Double(bin.matched) / total
                    let missed = size.height * Double(bin.missed) / total
                    colored.fill(Path(CGRect(x: x, y: size.height - matched, width: width, height: matched)),
                                 with: .color(RehearsalColor.matched))
                    colored.fill(Path(CGRect(x: x, y: size.height - matched - missed, width: width, height: missed)),
                                 with: .color(RehearsalColor.missed))
                }
            }
            .frame(height: 28)
            .scaleEffect(y: revealed ? 1 : 0.05, anchor: .bottom)
            HStack {
                Text("Start")
                Spacer()
                Text("End")
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .accessibilityHidden(true)
    }
}
