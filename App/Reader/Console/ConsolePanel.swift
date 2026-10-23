import SwiftUI

/// The glass panel: mode picker, status, and the mode's read-outs.
struct ConsolePanel: View {
    let model: ReaderModel
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    var body: some View {
        VStack(spacing: 14) {
            Picker("Reading mode", selection: Binding(get: { model.mode }, set: { mode in
                withAnimation(reducedMotion ? nil : Motion.morph) { model.setMode(mode) }
            })) {
                ForEach(ReaderMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("readingMode")
            .disabled(model.isStopping)
            ConsoleStatusRow(model: model)
            if case .downloading(let value) = model.phase {
                ProgressView(value: value)
                    .tint(Theme.amber)
                    .accessibilityLabel("English speech model")
                    .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
                    .transition(.opacity)
            }
            if model.mode == .rehearsal {
                RehearsalReadouts(model: model).transition(.blurReplace)
            } else {
                ParagraphRail(starts: model.paragraphStarts, wordCount: model.document.words.count, cursor: model.cursor)
                    .padding(.vertical, 4)
                    .transition(.blurReplace)
            }
        }
        .padding(18)
    }
}
