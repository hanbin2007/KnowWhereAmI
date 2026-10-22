import AVFoundation
import SwiftUI

struct ReaderView: View {
    @State private var model: ReaderModel
    @State private var editorRequest: EditorRequest?
    @State private var showsSettings = false
    @State private var showsLibrary = false
    @State private var editAfterLibrary: Bool?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Namespace private var sheets

    init(model: ReaderModel = ReaderModel()) { _model = State(initialValue: model) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                heading
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .fixedSize(horizontal: false, vertical: true)
                if model.document.words.isEmpty {
                    ContentUnavailableView {
                        Label("No script", systemImage: "doc.text")
                    } actions: {
                        Button("Add script", systemImage: "plus") { openEditor(isNew: true) }
                            .accessibilityIdentifier("addScript")
                    }
                } else {
                    ScriptTextView(
                        document: model.document, cursor: model.cursor, isTentative: model.isTentative,
                        fontSize: model.saved.fontSize, followsPosition: model.followsPosition,
                        recenterID: model.recenterID, onSelect: model.selectWord,
                        onManualScroll: model.beginManualScroll, onManualScrollEnd: model.endManualScroll,
                        allowsInteraction: model.mode != .live || !model.stageLocked
                    )
                    .overlay(alignment: .leading) {
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.accentColor.opacity(0.55))
                                .frame(width: 2, height: 24)
                                .position(x: 8, y: geometry.size.height * 0.34)
                        }
                        .allowsHitTesting(false).accessibilityHidden(true)
                    }
                    .layoutPriority(1)
                }
                ReaderTransport(model: model)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("KnowWhereAmI")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Script library", systemImage: "square.stack") {
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

    private var heading: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(model.saved.title)
                    .font(.system(.title, design: .serif, weight: .medium))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if !typeSize.isAccessibilitySize {
                    Text("English (US) \u{00B7} \(model.document.words.count) words")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if model.mode == .rehearsal, let report = model.latestReport {
                Button("Last rehearsal", systemImage: "chart.bar.xaxis") { model.showReport(report) }
                    .frame(width: 44, height: 44)
                    .labelStyle(.iconOnly).accessibilityIdentifier("lastRehearsal").help("Last rehearsal")
            }
        }
        .frame(minHeight: 48)
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 16)
        .animation(reducedMotion ? nil : .smooth(duration: 0.2), value: model.mode)
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
