import KnowWhereAmICore
import SwiftUI

struct RehearsalReportView: View {
    let record: RehearsalRecord
    private let document: ScriptDocument
    private let bins: [CoverageBin]
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var revealed = false
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
                    Eyebrow(record.endedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                    Text(record.title)
                        .font(.display(.largeTitle, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                hero
                metrics
                coverage
                omissions
                Label {
                    Text("Estimates use finalized transcription, not pronunciation. Unassessed words are not counted as missed. Paused and preparation time are excluded from pace.")
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 36)
        }
        .background(Theme.paper)
        .navigationTitle("Rehearsal").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("rehearsalReport")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: summary) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share rehearsal summary")
            }
        }
        .onAppear {
            guard !revealed else { return }
            if reducedMotion { revealed = true } else { withAnimation(Motion.reveal.delay(0.15)) { revealed = true } }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 22) {
            MatchRing(matched: stats.matchedWords, missed: stats.missedWords, progress: revealed ? 1 : 0,
                      diameter: typeSize.isAccessibilitySize ? 220 : 196)
            VStack(spacing: 8) {
                Text(verdict)
                    .font(.display(.title2, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(narrative)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(revealed ? 1 : 0).offset(y: revealed ? 0 : 8)
            let legend = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            legend {
                chip("\(stats.matchedWords) matched", color: RehearsalColor.matched)
                chip("\(stats.missedWords) est. missed", color: RehearsalColor.missed)
                chip("\(stats.assessedWords) assessed", color: Color.primary.opacity(0.22))
            }
            .opacity(revealed ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28).padding(.horizontal, 18)
        .sheetSurface(radius: 30)
    }

    private var verdict: String {
        guard let accuracy = stats.accuracy else { return "Nothing scored yet" }
        switch accuracy {
        case 0.95...: return "Nearly word for word"
        case 0.85..<0.95: return "Close to the page"
        case 0.7..<0.85: return "The shape was there"
        default: return "Plenty to revisit"
        }
    }

    private var narrative: String {
        guard stats.assessedWords > 0 else {
            return "No finalized speech was matched to the manuscript in this run."
        }
        var sentence = "Of the \(stats.assessedWords) words you reached, about \(stats.matchedWords) were heard as written"
        if let rate = stats.wordsPerMinute {
            sentence += ", at a \(PaceBand(wordsPerMinute: rate).title.lowercased()) \(Int(rate.rounded())) words a minute"
        }
        return sentence + "."
    }

    private func chip(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(Theme.ink.opacity(0.8))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.paper, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    // MARK: Metrics

    private var metrics: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        return layout {
            tile(symbol: "timer", value: ReaderChrome.time(stats.elapsedSeconds), unit: nil, label: "Active time")
            tile(symbol: "gauge.with.dots.needle.33percent",
                 value: stats.wordsPerMinute.map { "\(Int($0.rounded()))" } ?? "--", unit: "wpm",
                 label: stats.wordsPerMinute.map { PaceBand(wordsPerMinute: $0).title } ?? "Pace")
            tile(symbol: "text.word.spacing", value: "\(stats.spokenWords)", unit: nil, label: "Words spoken")
        }
    }

    private func tile(symbol: String, value: String, unit: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.figure(.title2, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                    if let unit { Text(unit).font(.caption.weight(.medium)).foregroundStyle(.secondary) }
                }
                .lineLimit(1).minimumScaleFactor(0.6)
                Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.75)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheetSurface(radius: 18)
        .accessibilityElement(children: .combine)
    }

    // MARK: Coverage

    private var coverage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Through the manuscript")
                Spacer()
                Text("\(stats.assessedWords) of \(document.words.count)")
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

    // MARK: Missed words

    private var omissions: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Words to revisit")
                Spacer()
                if !stats.omittedWordIndices.isEmpty {
                    Text("\(stats.omittedWordIndices.count)")
                        .font(.caption.weight(.bold)).monospacedDigit()
                        .foregroundStyle(RehearsalColor.missed)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(RehearsalColor.missed.opacity(0.12), in: Capsule())
                }
            }
            if stats.omittedWordIndices.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: stats.assessedWords > 0 ? "checkmark.seal.fill" : "waveform.slash")
                        .font(.title2).foregroundStyle(stats.assessedWords > 0 ? Theme.accent : Color.secondary)
                    Text(stats.assessedWords > 0 ? "None in the text you reached." : "No scored speech in this run.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .sheetSurface(radius: 18)
            } else {
                ForEach(stats.omittedWordIndices, id: \.self) { index in
                    if document.words.indices.contains(index) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Word \(index + 1)")
                                Spacer()
                                Text("\(Int((Double(index + 1) / Double(document.words.count) * 100).rounded()))% through")
                            }
                            .font(.caption2.weight(.medium).monospacedDigit()).foregroundStyle(.tertiary)
                            Text(context(around: index))
                                .font(.display(.body)).lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sheetSurface(radius: 18)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Missed \(document.words[index].text), word \(index + 1)")
                    }
                }
            }
        }
    }

    /// A few words either side, with the missed word set in the miss color.
    private func context(around index: Int) -> AttributedString {
        let words = document.words
        let text = record.scriptText as NSString
        let firstWord = max(0, index - 5)
        let lastWord = min(words.count - 1, index + 6)
        let target = words[index].range
        let before = text.substring(with: NSRange(location: words[firstWord].range.location,
                                                  length: target.location - words[firstWord].range.location))
        let afterStart = NSMaxRange(target)
        let after = text.substring(with: NSRange(location: afterStart, length: NSMaxRange(words[lastWord].range) - afterStart))
        var result = AttributedString((firstWord > 0 ? "\u{2026}" : "") + before.replacingOccurrences(of: "\n", with: " "))
        result.foregroundColor = .secondary
        var word = AttributedString(text.substring(with: target))
        word.foregroundColor = RehearsalColor.missed
        word.font = .display(.body, weight: .semibold)
        word.underlineStyle = Text.LineStyle(pattern: .solid, color: RehearsalColor.missed.opacity(0.5))
        var tail = AttributedString(after.replacingOccurrences(of: "\n", with: " ") + (lastWord < words.count - 1 ? "\u{2026}" : ""))
        tail.foregroundColor = .secondary
        result.append(word)
        result.append(tail)
        return result
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
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    legend("Matched", color: Theme.ink)
                    legend("Est. missed", color: RehearsalColor.missed)
                    legend("Not assessed", color: .secondary)
                }
                Text(reviewText)
                    .font(.display(.body)).lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(24)
        }
        .background(Theme.paper)
        .navigationTitle("Manuscript review").navigationBarTitleDisplayMode(.inline)
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
        }
    }

    private var reviewText: AttributedString {
        let document = ScriptDocument(text: record.scriptText)
        let result = NSMutableAttributedString(string: record.scriptText, attributes: [.foregroundColor: UIColor.spokenInk])
        for index in record.statistics.matchedWordIndices where document.words.indices.contains(index) {
            result.addAttribute(.foregroundColor, value: UIColor.ink, range: document.words[index].range)
        }
        let missed = UIColor.dynamic(light: 0xBE4A2C, dark: 0xF07D5E)
        for index in record.statistics.omittedWordIndices where document.words.indices.contains(index) {
            result.addAttributes([.foregroundColor: missed,
                                  .backgroundColor: missed.withAlphaComponent(0.12),
                                  .underlineStyle: NSUnderlineStyle.single.rawValue,
                                  .underlineColor: missed.withAlphaComponent(0.5)], range: document.words[index].range)
        }
        return AttributedString(result)
    }
}
