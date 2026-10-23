import KnowWhereAmICore
import SwiftUI

/// The whole manuscript as tiles, filling in from the first word to the last.
struct CoverageCard: View {
    let record: RehearsalRecord
    let wordCount: Int
    let bins: [CoverageBin]
    let revealed: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    private var stats: RehearsalStatistics { record.statistics }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Through the manuscript")
                Spacer()
                Text("\(stats.assessedWords) of \(wordCount)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            WordCoverageMap(bins: bins, progress: revealed ? 1 : 0)
            HStack {
                Text("First word")
                Spacer()
                Text("Last word")
            }
            .font(.caption2).foregroundStyle(.tertiary)
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                                     : AnyLayout(HStackLayout(spacing: 14))
            layout {
                key("Matched", color: RehearsalColor.matched)
                key("Est. missed", color: RehearsalColor.missed)
                key("Not assessed", color: Color.primary.opacity(0.16))
            }
            Text("\(stats.assessedWords) words assessed. \(stats.unassessedWords) not assessed.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            NavigationLink { ManuscriptReviewView(record: record) } label: {
                HStack {
                    Label("Review the manuscript", systemImage: "doc.text.magnifyingglass")
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 16).frame(minHeight: 48)
                .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(ReaderControlStyle(pressedScale: 0.98))
        }
        .padding(18)
        .sheetSurface(radius: 24)
    }

    private func key(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color).frame(width: 9, height: 9)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
