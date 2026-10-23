import KnowWhereAmICore
import SwiftUI

/// The report presented after Finish, with a system close button.
struct ReportSheet: View {
    let record: RehearsalRecord
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            RehearsalReportView(record: record)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark", role: .cancel, action: onDone)
                            .accessibilityIdentifier("closeReport")
                    }
                }
        }
    }
}
