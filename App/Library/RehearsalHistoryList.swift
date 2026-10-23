import KnowWhereAmICore
import SwiftUI

/// Saved rehearsals as a timeline grouped by day.
struct RehearsalHistoryList: View {
    let records: [RehearsalRecord]
    let searching: String
    let onDelete: (RehearsalRecord) -> Void

    private var days: [(day: Date, records: [RehearsalRecord])] {
        Dictionary(grouping: records) { Calendar.current.startOfDay(for: $0.endedAt) }
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value.sorted { $0.endedAt > $1.endedAt }) }
    }

    var body: some View {
        List {
            ForEach(days, id: \.day) { day in
                Section {
                    ForEach(day.records) { record in
                        NavigationLink {
                            RehearsalReportView(record: record)
                        } label: {
                            HistoryRow(record: record)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) { onDelete(record) }
                        }
                    }
                } header: {
                    Text(title(for: day.day))
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if records.isEmpty {
                if !searching.isEmpty { ContentUnavailableView.search(text: searching) }
                else {
                    ContentUnavailableView {
                        Label("No Rehearsals", systemImage: "waveform.badge.mic")
                    } description: {
                        Text("Finished rehearsals appear here with their pace, match, and missed words.")
                    }
                }
            }
        }
    }

    private func title(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
