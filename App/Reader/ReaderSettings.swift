import SwiftUI

struct ReaderSettings: View {
    @Bindable var model: ReaderModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading") {
                    LabeledContent("Text size") {
                        HStack(spacing: 12) {
                            Button { model.changeFontSize(by: -2) } label: {
                                Image(systemName: "minus").frame(width: 44, height: 44).contentShape(Rectangle())
                            }
                                .accessibilityLabel("Smaller text")
                                .accessibilityIdentifier("decreaseTextSize")
                                .disabled(model.saved.fontSize <= 18)
                            Text("\(Int(model.saved.fontSize)) pt")
                                .monospacedDigit().frame(minWidth: 48)
                                .accessibilityIdentifier("readerTextSize")
                            Button { model.changeFontSize(by: 2) } label: {
                                Image(systemName: "plus").frame(width: 44, height: 44).contentShape(Rectangle())
                            }
                                .accessibilityLabel("Larger text")
                                .accessibilityIdentifier("increaseTextSize")
                                .disabled(model.saved.fontSize >= 40)
                        }
                        .buttonStyle(.borderless)
                        .labelStyle(.iconOnly)
                        .controlSize(.large)
                    }
                    Toggle("Follow reading position", isOn: Binding(
                        get: { model.saved.followsPosition }, set: model.setFollowPreference
                    ))
                }
                Section("Speech") {
                    LabeledContent("Language", value: "English (US)")
                    LabeledContent("Processing", value: "On device")
                    LabeledContent("Audio storage", value: "Off")
                }
                if !model.heard.isEmpty {
                    Section("Last recognized") {
                        Text(model.heard).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Reader settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("closeSettings")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
