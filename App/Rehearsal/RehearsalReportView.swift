import KnowWhereAmICore
import SwiftUI

/// A rehearsal summary in the manner of Fitness and Health: an inset-grouped
/// list, large rounded figures with their units, and the fine print in section
/// footers.
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
                                missed: record.statistics.omittedWordIndices, maximumBins: 48)
    }

    var body: some View {
        List {
            Section {
                ReportSummary(stats: stats, revealed: revealed)
            }
            Section("Details") {
                ReportMetricGrid(stats: stats)
            }
            Section {
                CoverageBar(stats: stats, wordCount: document.words.count)
                CoverageStrip(bins: bins, revealed: revealed)
                NavigationLink("Review Manuscript") { ManuscriptReviewView(record: record) }
            } header: {
                Text("Coverage")
            } footer: {
                Text("Words you didn\u{2019}t reach aren\u{2019}t counted as missed.")
            }
            Section {
                if missedIndices.isEmpty {
                    Label(stats.assessedWords > 0 ? "No Missed Words" : "No Speech Was Scored",
                          systemImage: stats.assessedWords > 0 ? "checkmark.circle" : "waveform.slash")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(missedIndices, id: \.self) { index in
                        MissedWordRow(index: index, document: document, scriptText: record.scriptText)
                    }
                }
            } header: {
                Text("Missed Words")
            } footer: {
                Text("Estimates come from finalized transcription, not pronunciation. Paused and preparation time are excluded from pace.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(record.title)
        .navigationSubtitle(record.endedAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("rehearsalReport")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: summary) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share Summary")
            }
        }
        .onAppear {
            guard !revealed else { return }
            if reducedMotion { revealed = true } else { withAnimation(Motion.reveal.delay(0.15)) { revealed = true } }
        }
    }

    private var missedIndices: [Int] { stats.omittedWordIndices.filter { document.words.indices.contains($0) } }

    private var summary: String {
        let rate = stats.wordsPerMinute.map { "\(Int($0.rounded())) WPM" } ?? "Not available"
        let accuracy = stats.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "Not assessed"
        return "\(record.title)\nActive time: \(ReaderChrome.time(stats.elapsedSeconds))\nAverage pace: \(rate)\nEstimated script match: \(accuracy)\nEstimated missed words: \(stats.missedWords)\nAssessed: \(stats.assessedWords) words"
    }
}
