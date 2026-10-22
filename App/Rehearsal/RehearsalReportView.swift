import KnowWhereAmICore
import SwiftUI

struct RehearsalReportView: View {
    let record: RehearsalRecord
    private let document: ScriptDocument
    private let bins: [CoverageBin]
    @Environment(\.dynamicTypeSize) private var typeSize
    private var stats: RehearsalStatistics { record.statistics }

    init(record: RehearsalRecord) {
        self.record = record
        document = ScriptDocument(text: record.scriptText)
        bins = CoverageBin.make(wordCount: document.words.count, matched: record.statistics.matchedWordIndices,
                                missed: record.statistics.omittedWordIndices)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.endedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                    Text(record.title).font(.system(.title, design: .serif, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                scoreStage
                metricStrip
                Divider()
                coverage
                Divider()
                omissions
                Text("Estimates use finalized transcription, not pronunciation. Unassessed words are not counted as missed. Paused and preparation time are excluded from pace.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Rehearsal").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("rehearsalReport")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: summary) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share rehearsal summary")
            }
        }
    }

    private var scoreStage: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
                                                 : AnyLayout(HStackLayout(alignment: .center, spacing: 24))
        return layout {
            MatchRing(matched: stats.matchedWords, missed: stats.missedWords)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
            VStack(alignment: .leading, spacing: 18) {
                scoreLegend("Matched", value: stats.matchedWords, color: RehearsalColor.matched)
                scoreLegend("Est. missed", value: stats.missedWords, color: RehearsalColor.missed)
                Text("\(stats.assessedWords) assessed words")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func scoreLegend(_ label: String, value: Int, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(color).frame(width: 7, height: 7).padding(.top, 10).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(.system(.title2, design: .rounded, weight: .medium)).monospacedDigit()
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var metricStrip: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 14) {
                    LabeledContent("Active time", value: ReaderChrome.time(stats.elapsedSeconds))
                    LabeledContent("Average pace", value: stats.wordsPerMinute.map { "\(Int($0.rounded())) WPM" } ?? "Not available")
                    LabeledContent("Words spoken", value: "\(stats.spokenWords)")
                }
                .font(.subheadline)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    metric(ReaderChrome.time(stats.elapsedSeconds), label: "Active time")
                    metric(stats.wordsPerMinute.map { "\(Int($0.rounded()))" } ?? "--", label: "Words / min")
                    metric("\(stats.spokenWords)", label: "Words spoken")
                }
            }
        }
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(.title2, design: .rounded, weight: .medium)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var coverage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Manuscript coverage").font(.headline)
                Spacer()
                Text("\(stats.assessedWords) / \(document.words.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            WordCoverageMap(bins: bins)
            HStack {
                Text("Beginning")
                Spacer()
                Text("End")
            }
            .font(.caption2).foregroundStyle(.tertiary)
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                                     : AnyLayout(HStackLayout(spacing: 16))
            layout {
                key("Matched", color: RehearsalColor.matched)
                key("Est. missed", color: RehearsalColor.missed)
                key("Not assessed", color: RehearsalColor.unassessed)
            }
            Text("\(stats.assessedWords) words assessed. \(stats.unassessedWords) not assessed.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            NavigationLink { ManuscriptReviewView(record: record) } label: {
                HStack {
                    Text("Review manuscript")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.medium)).frame(minHeight: 44).contentShape(Rectangle())
            }
        }
    }

    private func key(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 7, height: 7)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var omissions: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            Text("Estimated missed words").font(.headline)
            if stats.omittedWordIndices.isEmpty {
                Label(stats.assessedWords > 0 ? "None in assessed text" : "No scored speech",
                      systemImage: stats.assessedWords > 0 ? "checkmark.circle" : "minus.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(stats.omittedWordIndices, id: \.self) { index in
                    if document.words.indices.contains(index) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(document.words[index].text).font(.title3.weight(.medium)).foregroundStyle(RehearsalColor.missed)
                                Spacer()
                                Text("Word \(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Text(context(around: index)).font(.subheadline).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private func context(around index: Int) -> String {
        let words = document.words
        let first = words[max(0, index - 4)].range.location
        let last = NSMaxRange(words[min(words.count - 1, index + 5)].range)
        return (record.scriptText as NSString).substring(with: NSRange(location: first, length: last - first))
    }

    private var summary: String {
        let rate = stats.wordsPerMinute.map { "\(Int($0.rounded())) WPM" } ?? "Not available"
        let accuracy = stats.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "Not assessed"
        return "\(record.title)\nActive time: \(ReaderChrome.time(stats.elapsedSeconds))\nAverage pace: \(rate)\nEstimated script match: \(accuracy)\nEstimated missed words: \(stats.missedWords)\nAssessed: \(stats.assessedWords) words"
    }
}

private struct ManuscriptReviewView: View {
    let record: RehearsalRecord
    var body: some View {
        ScrollView {
            Text(reviewText).font(.body).lineSpacing(7).frame(maxWidth: .infinity, alignment: .leading).padding(24)
                .textSelection(.enabled)
        }
        .navigationTitle("Manuscript review").navigationBarTitleDisplayMode(.inline)
    }

    private var reviewText: AttributedString {
        let document = ScriptDocument(text: record.scriptText)
        let result = NSMutableAttributedString(string: record.scriptText, attributes: [.foregroundColor: UIColor.secondaryLabel])
        for index in record.statistics.matchedWordIndices where document.words.indices.contains(index) {
            result.addAttribute(.foregroundColor, value: UIColor.label, range: document.words[index].range)
        }
        for index in record.statistics.omittedWordIndices where document.words.indices.contains(index) {
            result.addAttributes([.foregroundColor: UIColor.systemRed,
                                  .backgroundColor: UIColor.systemRed.withAlphaComponent(0.12),
                                  .underlineStyle: NSUnderlineStyle.single.rawValue], range: document.words[index].range)
        }
        return AttributedString(result)
    }
}
