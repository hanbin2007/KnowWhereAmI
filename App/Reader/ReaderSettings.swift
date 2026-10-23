import SwiftUI

/// Reading preferences. A partial-height sheet, so it keeps the system Liquid
/// Glass background; every control is a standard one that adopts glass itself.
struct ReaderSettings: View {
    @Bindable var model: ReaderModel
    @AppStorage(ReaderTypeface.storageKey) private var typeface = ReaderTypeface.serif
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ReadingPreview(size: model.saved.fontSize, typeface: typeface)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                Section {
                    TextSizeControl(model: model)
                    Picker("Typeface", selection: $typeface) {
                        ForEach(ReaderTypeface.allCases) { face in
                            Text(face.title).tag(face)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("typeface")
                } header: {
                    Text("Text")
                }
                Section {
                    Toggle("Follow my voice", isOn: Binding(get: { model.saved.followsPosition },
                                                           set: { model.setFollowPreference($0) }))
                        .accessibilityIdentifier("followPosition")
                } footer: {
                    Text("Keeps the spoken line in the focus lane. Scrolling by hand pauses following for a moment.")
                }
                Section("Speech") {
                    Label("Recognized on this iPhone", systemImage: "iphone.gen3")
                    Label("Audio is never recorded", systemImage: "waveform.slash")
                    Label("English (US)", systemImage: "character.bubble")
                }
                if !model.heard.isEmpty {
                    Section("Last heard") {
                        Text(model.heard)
                            .font(.display(.body)).italic()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                        .buttonStyle(.glassProminent)
                        .accessibilityIdentifier("closeSettings")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .calmAnimation(Motion.snappy, value: model.saved.fontSize)
        .calmAnimation(Motion.snappy, value: typeface)
    }
}

/// A line of the manuscript as it will look on stage, current word and all.
private struct ReadingPreview: View {
    let size: Double
    let typeface: ReaderTypeface

    var body: some View {
        Text("\(Text("Every").foregroundStyle(Color.secondary)) \(Text("good").foregroundStyle(Theme.ink).underline(color: Theme.accent)) idea starts with a question.")
            .font(.system(size: min(size, 30), design: typeface.design))
            .foregroundStyle(Theme.ink)
            .lineSpacing(6)
            .lineLimit(2, reservesSpace: true)
            .minimumScaleFactor(0.6)
            .contentTransition(.interpolate)
            .padding(.horizontal, 20).padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Smaller and larger buttons around a stepped system slider.
private struct TextSizeControl: View {
    let model: ReaderModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Size")
                Spacer()
                Text("\(Int(model.saved.fontSize)) pt")
                    .monospacedDigit().foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: model.saved.fontSize))
                    .accessibilityIdentifier("readerTextSize")
            }
            HStack(spacing: 0) {
                step("Smaller text", symbol: "textformat.size.smaller", id: "decreaseTextSize", delta: -2, edge: .leading)
                    .disabled(model.saved.fontSize <= 18)
                Slider(value: Binding(get: { model.saved.fontSize }, set: { value in
                    let delta = value.rounded() - model.saved.fontSize
                    if delta != 0 { model.changeFontSize(by: delta) }
                }), in: 18...40, step: 2)
                .tint(Theme.accent)
                .accessibilityLabel("Text size")
                .accessibilityValue("\(Int(model.saved.fontSize)) points")
                step("Larger text", symbol: "textformat.size.larger", id: "increaseTextSize", delta: 2, edge: .trailing)
                    .disabled(model.saved.fontSize >= 40)
            }
        }
        .sensoryFeedback(.selection, trigger: model.saved.fontSize)
    }

    /// The glyph sits on the row's text edge; the 44 pt target extends toward the slider.
    private func step(_ title: String, symbol: String, id: String, delta: Double, edge: Alignment) -> some View {
        Button { model.changeFontSize(by: delta) } label: {
            Image(systemName: symbol).frame(width: 44, height: 44, alignment: edge).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title).accessibilityIdentifier(id)
    }
}
