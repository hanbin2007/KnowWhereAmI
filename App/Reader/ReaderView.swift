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
    @State private var chromeInsets = EdgeInsets()
    @State private var consoleHeight: CGFloat = 0
    @State private var stageSize = CGSize.zero
    @Namespace private var sheets

    init(model: ReaderModel = ReaderModel()) { _model = State(initialValue: model) }

    var body: some View {
        NavigationStack {
            withLifecycle(withSheets(stage))
        }
        .tint(Theme.accent)
    }

    private var stage: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if model.document.words.isEmpty {
                BlankPage { openEditor(isNew: true) }
                    .padding(.bottom, 200)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                // The manuscript runs under the glass bars and dissolves just
                // before them, like the system soft scroll edge effect.
                manuscript
                    .mask { ManuscriptEdgeFade(insets: chromeInsets, console: consoleHeight) }
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { chromeInsets = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { stageSize = $0 }
        .overlay(alignment: .bottom) {
            ReaderTransport(model: model, compactLive: model.mode == .live && stageSize.height > 0 && stageSize.height < 600)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { consoleHeight = $0 }
        }
        .calmAnimation(Motion.gentle, value: model.document.words.isEmpty)
        .navigationTitle(model.saved.title)
        .navigationSubtitle(ReadingLength.summary(words: model.document.words.count))
        .toolbarTitleDisplayMode(.inline)
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
        ToolbarItemGroup(placement: .topBarTrailing) {
            if model.mode == .rehearsal, let report = model.latestReport { lastRun(report) }
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
                              tentative: model.isTentative, following: model.followsPosition,
                              textHeight: laneMarkHeight)
                    .position(x: 11, y: geometry.size.height * ReadingFocus.fraction
                                  - ReaderTextSurface.lineSpacing(serif: typeface == .serif) / 2)
            }
            .allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    /// Roughly the cap-to-baseline height of the manuscript at its current size.
    private var laneMarkHeight: CGFloat {
        min(64, UIFontMetrics(forTextStyle: .body).scaledValue(for: CGFloat(model.saved.fontSize) * 0.78))
    }

    /// The last rehearsal of this script: its match ring, sized like a toolbar
    /// symbol so the title keeps its room.
    private func lastRun(_ report: RehearsalRecord) -> some View {
        let stats = report.statistics
        let score = stats.accuracy.map { "\(Int(($0 * 100).rounded())) percent match" } ?? "Not assessed"
        return Button { model.showReport(report) } label: {
            MatchDial(matched: stats.matchedWords, missed: stats.missedWords, diameter: 20, lineWidth: 3.5, showsValue: false)
                .frame(width: 24, height: 24)
        }
        .matchedTransitionSource(id: "report", in: sheets)
        .accessibilityLabel("Last rehearsal").accessibilityValue(score)
        .accessibilityIdentifier("lastRehearsal").help("Last rehearsal")
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
