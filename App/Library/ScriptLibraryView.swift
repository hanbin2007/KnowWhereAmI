import KnowWhereAmICore
import SwiftUI

struct ScriptLibraryView: View {
    let model: ReaderModel
    let onChoose: () -> Void
    let onNew: () -> Void
    let onEdit: () -> Void
    @State private var section = LibrarySection.scripts
    @State private var search = ""
    @State private var deletingScript: Manuscript?
    @State private var deletingRecord: RehearsalRecord?
    @State private var failure: String?
    @State private var appeared = false
    @Namespace private var tabs
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    private enum LibrarySection: String, CaseIterable, Identifiable {
        case scripts = "Scripts", rehearsals = "Rehearsals"
        var id: String { rawValue }
    }

    private var scripts: [Manuscript] {
        model.library.manuscripts.filter {
            search.isEmpty || $0.content.title.localizedCaseInsensitiveContains(search) || $0.content.text.localizedCaseInsensitiveContains(search)
        }.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    private var records: [RehearsalRecord] {
        model.history.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }
    private var days: [(day: Date, records: [RehearsalRecord])] {
        Dictionary(grouping: records) { Calendar.current.startOfDay(for: $0.endedAt) }
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value.sorted { $0.endedAt > $1.endedAt }) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if section == .scripts {
                    scriptGallery
                        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    historyList
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .trailing).combined(with: .opacity)))
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { sectionSwitch }
            .background(Theme.paper)
            .calmAnimation(Motion.morph, value: section)
            .searchable(text: $search, prompt: section == .scripts ? "Search scripts" : "Search rehearsals")
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("closeLibrary")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New script", systemImage: "plus", action: onNew)
                        .accessibilityIdentifier("newScript")
                }
            }
            .confirmationDialog("Delete script?", isPresented: Binding(get: { deletingScript != nil }, set: { if !$0 { deletingScript = nil } }), titleVisibility: .visible) {
                Button("Delete script", role: .destructive) {
                    if let deletingScript { perform { model.deleteManuscript(deletingScript.id) } }
                    deletingScript = nil
                }
            } message: { Text(deletingScript?.content.title ?? "") }
            .confirmationDialog("Delete rehearsal?", isPresented: Binding(get: { deletingRecord != nil }, set: { if !$0 { deletingRecord = nil } }), titleVisibility: .visible) {
                Button("Delete rehearsal", role: .destructive) {
                    if let deletingRecord { perform { model.deleteRehearsal(deletingRecord.id) } }
                    deletingRecord = nil
                }
            }
            .alert("Couldn't update library", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(failure ?? "") }
        }
        .presentationBackground(Theme.paper)
        .onAppear {
            if reducedMotion { appeared = true } else { withAnimation(Motion.gentle) { appeared = true } }
        }
    }

    // MARK: Sections

    private var sectionSwitch: some View {
        HStack(spacing: 2) {
            ForEach(LibrarySection.allCases) { item in
                let selected = section == item
                let count = item == .scripts ? model.library.manuscripts.count : model.history.count
                Button { section = item } label: {
                    HStack(spacing: 6) {
                        Text(item.rawValue).font(.subheadline.weight(.semibold))
                        Text("\(count)")
                            .font(.caption2.weight(.bold)).monospacedDigit()
                            .padding(.horizontal, 6).padding(.vertical, 1.5)
                            .background(selected ? Theme.accent.opacity(0.14) : Theme.track, in: Capsule())
                            .contentTransition(.numericText(value: Double(count)))
                    }
                    .foregroundStyle(selected ? Theme.ink : .secondary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background {
                        if selected {
                            Capsule().fill(Theme.sheet)
                                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                                .matchedGeometryEffect(id: "tab", in: tabs)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.rawValue)
                .accessibilityValue("\(count)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.track, in: Capsule())
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 10)
        .background(Theme.paper)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("librarySection")
    }

    // MARK: Scripts

    private var scriptGallery: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14),
                                     count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                ForEach(Array(scripts.enumerated()), id: \.element.id) { index, script in
                    scriptCard(script)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)
                        .animation(reducedMotion ? nil : Motion.gentle.delay(Double(min(index, 8)) * 0.05), value: appeared)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 24)
            .calmAnimation(Motion.morph, value: scripts.map(\.id))
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            if scripts.isEmpty {
                if !search.isEmpty { ContentUnavailableView.search(text: search) }
                else {
                    ContentUnavailableView {
                        Label("No scripts yet", systemImage: "text.page")
                    } description: {
                        Text("Your manuscripts live here, ready for rehearsal or the stage.")
                    } actions: { Button("New script", systemImage: "plus", action: onNew) }
                }
            }
        }
    }

    private func scriptCard(_ script: Manuscript) -> some View {
        let selected = model.library.selectedID == script.id
        let words = ScriptDocument.wordCount(in: script.content.text)
        let lastRun = model.history.first { $0.manuscriptID == script.id }
        return ZStack(alignment: .bottomTrailing) {
            Button {
                perform { model.selectManuscript(script.id) }
                if failure == nil { onChoose() }
            } label: {
                VStack(alignment: .leading, spacing: 9) {
                    if selected {
                        Label("Reading", systemImage: "book.pages.fill")
                            .font(.caption2.weight(.bold)).tracking(0.6).textCase(.uppercase)
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.accent.opacity(0.12), in: Capsule())
                    } else {
                        Text("Edited \(Text(script.modifiedAt, format: .relative(presentation: .named)))")
                            .font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    }
                    Text(script.content.title)
                        .font(.display(.title3, weight: .semibold)).foregroundStyle(Theme.ink)
                        .lineLimit(3)
                    Text(String(script.content.text.prefix(220)).replacingOccurrences(of: "\n", with: " "))
                        .font(.display(.footnote)).foregroundStyle(.secondary)
                        .lineSpacing(2).lineLimit(4)
                    Spacer(minLength: 8)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(ReadingLength.summary(words: words))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        if let lastRun {
                            HStack(spacing: 6) {
                                MatchDial(matched: lastRun.statistics.matchedWords, missed: lastRun.statistics.missedWords,
                                          diameter: 14, lineWidth: 2.5, showsValue: false)
                                Text(lastRun.statistics.accuracy.map { "\(Int(($0 * 100).rounded()))% last run" } ?? "Rehearsed")
                                    .font(.caption.weight(.medium)).foregroundStyle(Theme.ink.opacity(0.75))
                            }
                        }
                    }
                    .padding(.trailing, 34)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 236, alignment: .topLeading)
                .padding(16)
                .background { FoldedSheet().fill(Theme.sheet).shadow(color: .black.opacity(selected ? 0.08 : 0.05), radius: selected ? 18 : 12, y: 6) }
                .overlay {
                    FoldedSheet().strokeBorder(selected ? Theme.accent.opacity(0.6) : Theme.hairline, lineWidth: selected ? 1.25 : 0.75)
                }
                .overlay(alignment: .topTrailing) { FoldFlap().fill(Theme.raised).frame(width: FoldedSheet.fold, height: FoldedSheet.fold) }
            }
            .buttonStyle(ReaderControlStyle(pressedScale: 0.975))
            .accessibilityIdentifier("manuscript-\(script.id.uuidString)")
            .accessibilityAddTraits(selected ? .isSelected : [])
            Menu {
                Button("Edit", systemImage: "square.and.pencil") {
                    perform { model.selectManuscript(script.id) }
                    if failure == nil { onEdit() }
                }
                Button("Duplicate", systemImage: "plus.square.on.square") { perform { model.duplicateManuscript(script.id) } }
                Button("Delete", systemImage: "trash", role: .destructive) { deletingScript = script }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Theme.track, in: Circle())
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .padding(6).accessibilityLabel("Actions for \(script.content.title)")
        }
    }

    // MARK: Rehearsals

    private var historyList: some View {
        List {
            ForEach(days, id: \.day) { day in
                Section {
                    ForEach(day.records) { record in
                        NavigationLink {
                            RehearsalReportView(record: record)
                        } label: {
                            HistoryRow(record: record)
                        }
                        .listRowBackground(Theme.sheet)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) { deletingRecord = record }
                        }
                    }
                } header: {
                    Text(title(for: day.day))
                        .font(.footnote.weight(.semibold)).tracking(1).textCase(.uppercase)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            if records.isEmpty {
                if !search.isEmpty { ContentUnavailableView.search(text: search) }
                else {
                    ContentUnavailableView {
                        Label("No rehearsals yet", systemImage: "waveform.badge.mic")
                    } description: {
                        Text("Finish a rehearsal to keep its pace, match, and missed words here.")
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

    private func perform(_ action: () -> Bool) {
        if !action() {
            failure = model.alert?.message ?? "The change could not be saved."
            model.alert = nil
        }
    }
}

private struct HistoryRow: View {
    let record: RehearsalRecord
    private var stats: RehearsalStatistics { record.statistics }

    var body: some View {
        HStack(spacing: 14) {
            MatchDial(matched: stats.matchedWords, missed: stats.missedWords, diameter: 46, lineWidth: 3.5, showsValue: false)
                .overlay {
                    Text(stats.accuracy.map { "\(Int(($0 * 100).rounded()))" } ?? "\u{2014}")
                        .font(.figure(.footnote, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(stats.accuracy == nil ? .tertiary : .primary)
                        .minimumScaleFactor(0.6)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.display(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text(details)
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var details: String {
        var parts = [record.endedAt.formatted(date: .omitted, time: .shortened), ReaderChrome.time(stats.elapsedSeconds)]
        if let rate = stats.wordsPerMinute { parts.append("\(Int(rate.rounded())) wpm") }
        if stats.assessedWords > 0 { parts.append(stats.missedWords == 0 ? "nothing missed" : "\(stats.missedWords) missed") }
        return parts.joined(separator: " \u{00B7} ")
    }
}

/// A sheet of paper with its top-right corner folded down.
struct FoldedSheet: InsettableShape {
    static let fold: CGFloat = 22
    var radius: CGFloat = 20
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let fold = Self.fold - inset
        var path = Path()
        path.move(to: CGPoint(x: r.minX + radius, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - fold, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + fold))
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX - radius, y: r.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY - radius), radius: radius)
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.minX + radius, y: r.minY), radius: radius)
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> FoldedSheet {
        var shape = self
        shape.inset += amount
        return shape
    }
}

/// The underside of the folded corner.
struct FoldFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 4))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 4, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
