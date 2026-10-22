import AVFoundation
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
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var sheets

    init(model: ReaderModel = ReaderModel()) { _model = State(initialValue: model) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                if model.document.words.isEmpty {
                    BlankPage { openEditor(isNew: true) }
                        .padding(.bottom, 160)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    manuscript.transition(.opacity)
                }
            }
            .overlay(alignment: .top) {
                heading
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            }
            .overlay(alignment: .bottom) {
                ReaderTransport(model: model)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            }
            .calmAnimation(Motion.gentle, value: model.document.words.isEmpty)
            .navigationTitle("KnowWhereAmI")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("KnowWhereAmI")
                        .font(.display(.subheadline, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Script library", systemImage: "books.vertical") {
                        model.pause()
                        showsLibrary = true
                    }
                    .accessibilityIdentifier("scriptLibrary").help("Script library")
                    .matchedTransitionSource(id: "library", in: sheets)
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
            .sheet(isPresented: $showsLibrary, onDismiss: {
                if let isNew = editAfterLibrary {
                    editAfterLibrary = nil
                    openEditor(isNew: isNew)
                }
            }) {
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
                NavigationStack {
                    RehearsalReportView(record: record)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { model.presentedReport = nil }.accessibilityIdentifier("closeReport")
                            }
                        }
                }
                .navigationTransition(.zoom(sourceID: "report", in: sheets))
            }
            .alert(item: $model.alert) { alert in
                if alert.offersSettings {
                    Alert(title: Text(alert.title), message: Text(alert.message),
                          primaryButton: .default(Text("Open Settings")) {
                              if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                          }, secondaryButton: .cancel(Text("Dismiss")))
                } else {
                    Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { model.pause() }
                updateIdleTimer()
            }
            .onChange(of: model.phase) { _, _ in updateIdleTimer() }
            .onChange(of: model.mode) { _, _ in updateIdleTimer() }
            .onAppear(perform: updateIdleTimer)
            .onDisappear {
                model.pause()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.didBecomeInactiveNotification)) { notification in
                let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext
                if context?.source != .app { model.pause() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
                if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                   reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { model.pause() }
            }
            .sensoryFeedback(.selection, trigger: model.mode)
            .sensoryFeedback(.selection, trigger: model.stageLocked)
        }
        .tint(.accentColor)
    }

    private var manuscript: some View {
        ScriptTextView(
            document: model.document, cursor: model.cursor, isTentative: model.isTentative,
            fontSize: model.saved.fontSize, followsPosition: model.followsPosition,
            recenterID: model.recenterID, onSelect: model.selectWord,
            onManualScroll: model.beginManualScroll, onManualScrollEnd: model.endManualScroll,
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

    // MARK: Heading

    private var heading: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                if !typeSize.isAccessibilitySize {
                    Eyebrow(ReadingLength.summary(words: model.document.words.count))
                        .accessibilityLabel(ReadingLength.summary(words: model.document.words.count))
                        .accessibilityIdentifier("scriptSummary")
                }
                Text(model.saved.title)
                    .font(.display(.title, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if model.mode == .rehearsal, let report = model.latestReport {
                lastRun(report)
                    .transition(.scale(scale: 0.8, anchor: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 14)
        .background {
            LinearGradient(stops: [.init(color: Theme.paper, location: 0),
                                   .init(color: Theme.paper, location: 0.62),
                                   .init(color: Theme.paper.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .padding(.bottom, -40)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        .calmAnimation(Motion.gentle, value: model.mode)
        .calmAnimation(Motion.gentle, value: model.latestReport?.id)
    }

    private func lastRun(_ report: RehearsalRecord) -> some View {
        let stats = report.statistics
        return Button { model.showReport(report) } label: {
            HStack(spacing: 8) {
                MatchDial(matched: stats.matchedWords, missed: stats.missedWords, diameter: 22, lineWidth: 3.5, showsValue: false)
                VStack(alignment: .leading, spacing: 0) {
                    Text(stats.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "\u{2014}")
                        .font(.figure(.subheadline, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text("Last run").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 9).padding(.trailing, 13).padding(.vertical, 7)
            .readerGlass(Capsule(), interactive: true)
            .contentShape(Capsule())
        }
        .buttonStyle(ReaderControlStyle(pressedScale: 0.96))
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

/// The marker in the left margin where the spoken line settles.
private struct FocusLaneMark: View {
    let locked: Bool
    let tentative: Bool
    let following: Bool

    var body: some View {
        ZStack {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Capsule()
                    .fill(tentative ? Theme.amber : Theme.accent)
                    .frame(width: 3, height: following ? 22 : 10)
                    .opacity(following ? 0.75 : 0.35)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 14, height: 24)
        .calmAnimation(Motion.snappy, value: locked)
        .calmAnimation(Motion.snappy, value: following)
        .calmAnimation(Motion.snappy, value: tentative)
    }
}

/// Shown when the selected manuscript has no words yet.
private struct BlankPage: View {
    let onAdd: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var settled = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                page.rotationEffect(.degrees(settled ? -9 : -3)).offset(x: settled ? -18 : -6, y: 6).opacity(0.55)
                page.rotationEffect(.degrees(settled ? 7 : 2)).offset(x: settled ? 16 : 5, y: 2).opacity(0.8)
                page.overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach([0.82, 0.64, 0.74, 0.4], id: \.self) { width in
                            Capsule().fill(Theme.track).frame(width: 64 * width, height: 4)
                        }
                    }
                    .padding(14)
                }
            }
            .frame(height: 124)
            .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("A blank page").font(.display(.title2, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("Write, paste, or import the words you plan to say. They stay on this iPhone.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            Button(action: onAdd) {
                Label("Add script", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22).frame(minHeight: 48)
                    .background(Theme.microphone, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(ReaderControlStyle(pressedScale: 0.96))
            .accessibilityIdentifier("addScript")
        }
        .padding(.horizontal, 40)
        .onAppear {
            if reducedMotion { settled = true } else { withAnimation(Motion.morph.delay(0.1)) { settled = true } }
        }
    }

    private var page: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.sheet)
            .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75) }
            .frame(width: 92, height: 118)
            .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
    }
}
