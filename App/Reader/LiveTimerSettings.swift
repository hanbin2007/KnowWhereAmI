import KnowWhereAmICore
import SwiftUI

struct LiveTimerSettings: View {
    let model: ReaderModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsRestart = false

    private var limit: Binding<Int> {
        Binding(get: { model.saved.liveTimeLimitSeconds }, set: { _ = model.setLiveTimeLimit($0) })
    }

    private var presets: [Int] {
        Array(Set([30, 60, 120, 180, 300, 600, 900, 1_800, 3_600, model.saved.liveTimeLimitSeconds])).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Time limit") {
                    Picker("Quick duration", selection: limit) {
                        ForEach(presets, id: \.self) { seconds in
                            Text(seconds % 60 == 0 ? "\(seconds / 60) min" : LiveTimingSnapshot.formatDuration(Double(seconds)))
                                .tag(seconds)
                        }
                    }
                    .accessibilityIdentifier("liveDurationPreset")
                    Stepper(value: limit, in: LiveTimingSession.allowedLimits, step: 15) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(LiveTimingSnapshot.formatDuration(Double(limit.wrappedValue)))
                                .monospacedDigit().foregroundStyle(Theme.instrumentSecondary)
                                .accessibilityIdentifier("liveTimeLimitValue")
                        }
                    }
                    .accessibilityIdentifier("liveTimeLimitStepper")
                }
                Section {
                    Button(model.liveTimer.hasStarted ? "Restart countdown" : "Start countdown",
                           systemImage: model.liveTimer.hasStarted ? "arrow.counterclockwise" : "play.fill") {
                        if model.liveTimer.hasStarted { confirmsRestart = true }
                        else { model.startLiveCountdown(); dismiss() }
                    }
                    .accessibilityIdentifier(model.liveTimer.hasStarted ? "restartLiveCountdown" : "startLiveCountdown")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Live timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                        .buttonStyle(.glassProminent)
                        .accessibilityIdentifier("closeLiveTimerSettings")
                }
            }
            .confirmationDialog("Restart the countdown?", isPresented: $confirmsRestart, titleVisibility: .visible) {
                Button("Restart countdown", role: .destructive) { model.restartLiveCountdown(); dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
