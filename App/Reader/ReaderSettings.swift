import SwiftUI

enum ReaderTypeface: String, CaseIterable, Identifiable {
    case serif, sans
    static let storageKey = "readerTypeface"
    var id: String { rawValue }
    var title: String { self == .serif ? "New York" : "SF Pro" }
    var detail: String { self == .serif ? "Editorial" : "Neutral" }
    var design: Font.Design { self == .serif ? .serif : .default }
}

struct ReaderSettings: View {
    @Bindable var model: ReaderModel
    @AppStorage(ReaderTypeface.storageKey) private var typeface = ReaderTypeface.serif
    @Environment(\.dismiss) private var dismiss
    private static let sizes = Array(stride(from: 18.0, through: 40.0, by: 2.0))

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    preview
                    sizeControl
                    typefacePicker
                    followRow
                    privacy
                    if !model.heard.isEmpty { lastHeard }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 32)
            }
            .background(Theme.paper)
            .navigationTitle("Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("closeSettings")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.paper)
        .calmAnimation(Motion.snappy, value: model.saved.fontSize)
        .calmAnimation(Motion.snappy, value: typeface)
        .sensoryFeedback(.selection, trigger: model.saved.fontSize)
    }

    /// A line of the manuscript as it will look on stage, current word and all.
    private var preview: some View {
        let size = min(model.saved.fontSize, 30)
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(Text("Every").foregroundStyle(Color.secondary)) \(Text("good").foregroundStyle(Theme.ink).underline(color: Theme.accent)) idea starts with a question.")
                .font(.system(size: size, design: typeface.design))
                .foregroundStyle(Theme.ink)
                .lineSpacing(6)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.6)
                .contentTransition(.interpolate)
                .accessibilityHidden(true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheetSurface()
    }

    private var sizeControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Text size")
                Spacer()
                Text("\(Int(model.saved.fontSize)) pt")
                    .font(.figure(.subheadline, weight: .semibold)).monospacedDigit()
                    .contentTransition(.numericText(value: model.saved.fontSize))
                    .accessibilityIdentifier("readerTextSize")
            }
            HStack(spacing: 12) {
                stepButton("Smaller text", symbol: "textformat.size.smaller", id: "decreaseTextSize", delta: -2)
                    .disabled(model.saved.fontSize <= 18)
                ruler
                stepButton("Larger text", symbol: "textformat.size.larger", id: "increaseTextSize", delta: 2)
                    .disabled(model.saved.fontSize >= 40)
            }
        }
    }

    /// Tick marks for every available size; the current one stands tall.
    private var ruler: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Self.sizes, id: \.self) { size in
                let current = size == model.saved.fontSize
                Capsule()
                    .fill(current ? Theme.accent : size < model.saved.fontSize ? Theme.accent.opacity(0.35) : Color.primary.opacity(0.16))
                    .frame(width: current ? 3 : 2, height: current ? 26 : 10 + (size - 18) / 2.5)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 30)
        .accessibilityHidden(true)
    }

    private func stepButton(_ title: String, symbol: String, id: String, delta: Double) -> some View {
        Button { model.changeFontSize(by: delta) } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 48, height: 48)
                .background(Theme.sheet, in: Circle())
                .overlay { Circle().strokeBorder(Theme.hairline, lineWidth: 0.75) }
                .contentShape(Circle())
        }
        .buttonStyle(ReaderControlStyle())
        .foregroundStyle(Theme.ink)
        .accessibilityLabel(title).accessibilityIdentifier(id)
    }

    private var typefacePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Typeface")
            HStack(spacing: 12) {
                ForEach(ReaderTypeface.allCases) { face in
                    let selected = typeface == face
                    Button { typeface = face } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Aa").font(.system(size: 34, weight: .regular, design: face.design))
                                .foregroundStyle(selected ? Theme.accent : Theme.ink)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(face.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                Text(face.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sheetSurface(radius: 18, highlighted: selected)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body).foregroundStyle(Theme.accent)
                                .padding(12)
                                .scaleEffect(selected ? 1 : 0.4).opacity(selected ? 1 : 0)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(ReaderControlStyle(pressedScale: 0.97))
                    .accessibilityLabel(face.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("typeface-\(face.rawValue)")
                }
            }
        }
    }

    private var followRow: some View {
        Toggle(isOn: Binding(get: { model.saved.followsPosition }, set: model.setFollowPreference)) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Follow my voice").font(.body.weight(.medium)).foregroundStyle(Theme.ink)
                Text("Keep the spoken line in the focus lane. Scrolling by hand pauses following for a moment.")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.accent)
        .padding(18)
        .sheetSurface(radius: 18)
        .accessibilityIdentifier("followPosition")
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Speech")
            VStack(spacing: 0) {
                promise("iphone.gen3", "On this iPhone", "Recognition runs with Apple's on-device model.")
                Divider().padding(.leading, 52)
                promise("waveform.slash", "Never recorded", "Audio is processed live and not stored.")
                Divider().padding(.leading, 52)
                promise("character.bubble", "English (US)", "Contractions and numbers are matched in common forms.")
            }
            .sheetSurface(radius: 18)
        }
    }

    private func promise(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    private var lastHeard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Last heard")
            HStack(alignment: .top, spacing: 12) {
                Capsule().fill(Theme.accent.opacity(0.5)).frame(width: 3)
                Text(model.heard)
                    .font(.display(.body)).italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
    }
}
