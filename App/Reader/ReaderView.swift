import KnowWhereAmICore
import SwiftUI

struct ReaderView: View {
    @State private var model: ReaderModel
    @State private var editorRequest: EditorRequest?
    @State private var showsSettings = false
    @State private var showsLibrary = false
    @State private var editAfterLibrary: Bool?
    @AppStorage(ReaderTypeface.storageKey) private var typeface = ReaderTypeface.serif
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var sheets

    init(model: ReaderModel = ReaderModel()) { _model = State(initialValue: model) }

    var body: some View {
        NavigationStack {
            withLifecycle(withSheets(stage))
        }
        .tint(.accentColor)
    }

    private var stage: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if model.document.words.isEmpty {
                BlankPage { openEditor(isNew: true) }
                    .padding(.bottom, 200)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                // The manuscript runs under the glass bars; the scroll edge
                // effect keeps those bars legible.
                manuscript.ignoresSafeArea().transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            GeometryReader { geometry in
                ScrollEdgeAnchor(edge: .top).frame(height: geometry.safeAreaInsets.top)
            }
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false).accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            ReaderTransport(model: model).dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
        .calmAnimation(Motion.gentle, value: model.document.words.isEmpty)
        .navigationTitle(model.saved.title)
        .navigationSubtitle(ReadingLength.summary(words: model.document.words.count))
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar { toolbar }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Script library", systemImage: "books.vertical") {
                model.pause()
                showsLibrary = true
            }
            .accessibilityIdentifier("scriptLibrary").help("Script library")
            .matchedTransitionSource(id: "library", in: sheets)
        }
        if model.mode == .rehearsal, let report = model.latestReport {
            ToolbarItem(placement: .topBarTrailing) { lastRun(report) }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Edit script", systemImage: "square.and.pencil") {
                openEditor(isNew: model.library.selectedID == nil)
            }
            .accessibilityIdentifier("editScript").help("Edit script")
            .matchedTransitionSource(id: "editor", in: sheets)
            Button("Reader settings", systemImage: "textformat.size") {
                model.pause()
                showsSettings = true
            }
            .accessibilityIdentifier("readerSettings").help("Reader settings")
            .matchedTransitionSource(id: "settings", in: sheets)
        }
    }

    private func withSheets(_ content: some View) -> some View {
        content
            .sheet(item: $editorRequest) { request in
                ScriptEditor(model: model, isNew: request.isNew).id(request.id)
                    .navigationTransition(.zoom(sourceID: "editor", in: sheets))
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showsSettings) {
                ReaderSettings(model: model)
                    .navigationTransition(.zoom(sourceID: "settings", in: sheets))
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showsLibrary, onDismiss: libraryDismissed) {
                ScriptLibraryView(model: model, onChoose: { showsLibrary = false }, onNew: {
                    editAfterLibrary = true
                    showsLibrary = false
                }, onEdit: {
                    editAfterLibrary = false
                    showsLibrary = false
                })
                .navigationTransition(.zoom(sourceID: "library", in: sheets))
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $model.presentedReport) { record in
                ReportSheet(record: record) { model.presentedReport = nil }
                    .navigationTransition(.zoom(sourceID: "report", in: sheets))
            }
    }

    private func withLifecycle(_ content: some View) -> some View {
        content
            .alert(item: $model.alert, content: makeAlert)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { model.pause() }
                updateIdleTimer()
            }
            .onChange(of: model.phase) { _, _ in updateIdleTimer() }
            .onChange(of: model.mode) { _, _ in updateIdleTimer() }
            .onAppear { updateIdleTimer() }
            .onDisappear {
                model.pause()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .modifier(AudioSessionGuard(pause: { model.pause() }))
            .sensoryFeedback(.selection, trigger: model.mode)
            .sensoryFeedback(.selection, trigger: model.stageLocked)
    }

    private func makeAlert(_ alert: ReaderAlert) -> Alert {
        guard alert.offersSettings else {
            return Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        return Alert(title: Text(alert.title), message: Text(alert.message),
                     primaryButton: .default(Text("Open Settings")) {
                         if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                     }, secondaryButton: .cancel(Text("Dismiss")))
    }

    private func libraryDismissed() {
        if let isNew = editAfterLibrary {
            editAfterLibrary = nil
            openEditor(isNew: isNew)
        }
    }

    private var manuscript: some View {
        ScriptTextView(
            document: model.document, cursor: model.cursor, isTentative: model.isTentative,
            fontSize: model.saved.fontSize, followsPosition: model.followsPosition,
            recenterID: model.recenterID, onSelect: { model.selectWord($0) },
            onManualScroll: { model.beginManualScroll() }, onManualScrollEnd: { model.endManualScroll() },
            allowsInteraction: model.mode != .live || !model.stageLocked,
            typeface: typeface
        )
        .overlay(alignment: .leading) {
            GeometryReader { geometry in
                FocusLaneMark(locked: model.mode == .live && model.stageLocked,
                              tentative: model.isTentative, following: model.followsPosition)
                    .position(x: 10, y: geometry.size.height * ReadingFocus.fraction)
            }
            .allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    /// The last rehearsal of this script, as a glass toolbar button.
    private func lastRun(_ report: RehearsalRecord) -> some View {
        let stats = report.statistics
        return Button { model.showReport(report) } label: {
            HStack(spacing: 6) {
                MatchDial(matched: stats.matchedWords, missed: stats.missedWords, diameter: 18, lineWidth: 3, showsValue: false)
                Text(stats.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "\u{2014}")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            .padding(.horizontal, 4)
        }
        .matchedTransitionSource(id: "report", in: sheets)
        .accessibilityLabel("Last rehearsal").accessibilityIdentifier("lastRehearsal").help("Last rehearsal")
    }

    private func openEditor(isNew: Bool) {
        model.pause()
        editorRequest = EditorRequest(isNew: isNew)
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = scenePhase == .active
            && (model.mode == .live || model.phase == .listening || model.phase == .finishing)
    }

    private struct EditorRequest: Identifiable {
        let id = UUID()
        let isNew: Bool
    }
}
