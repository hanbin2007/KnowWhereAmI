import KnowWhereAmICore
import SwiftUI

struct RehearsalReportView: View {
    let record: RehearsalRecord
    private let document: ScriptDocument
    private let bins: [CoverageBin]
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
                ReportHero(stats: stats, revealed: revealed)
                ReportMetrics(stats: stats)
                CoverageCard(record: record, wordCount: document.words.count, bins: bins, revealed: revealed)
                MissedWordsSection(record: record, document: document)
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

    private var summary: String {
        let rate = stats.wordsPerMinute.map { "\(Int($0.rounded())) WPM" } ?? "Not available"
        let accuracy = stats.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "Not assessed"
        return "\(record.title)\nActive time: \(ReaderChrome.time(stats.elapsedSeconds))\nAverage pace: \(rate)\nEstimated script match: \(accuracy)\nEstimated missed words: \(stats.missedWords)\nAssessed: \(stats.assessedWords) words"
    }
}
