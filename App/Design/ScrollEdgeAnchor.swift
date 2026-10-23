import SwiftUI
import UIKit

extension Notification.Name {
    static let readerSurfaceDidAppear = Notification.Name("ReaderSurfaceDidAppear")
}

/// Marks a region of floating glass controls so UIKit draws the system scroll
/// edge effect on the manuscript beneath it. The manuscript is a UITextView,
/// which SwiftUI bars cannot pair with by themselves.
struct ScrollEdgeAnchor: UIViewRepresentable {
    let edge: UIRectEdge

    func makeUIView(context: Context) -> AnchorView { AnchorView(edge: edge) }
    func updateUIView(_ view: AnchorView, context: Context) {}

    final class AnchorView: UIView {
        private let interaction = UIScrollEdgeElementContainerInteraction()
        private var observer: NSObjectProtocol?

        init(edge: UIRectEdge) {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
            interaction.edge = edge
            addInteraction(interaction)
            observer = NotificationCenter.default.addObserver(forName: .readerSurfaceDidAppear, object: nil,
                                                              queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.connect() }
            }
        }

        required init?(coder: NSCoder) { nil }

        isolated deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            connect()
        }

        private func connect() {
            guard let window else { return }
            let reader = Self.reader(in: window)
            if interaction.scrollView !== reader { interaction.scrollView = reader }
        }

        private static func reader(in view: UIView) -> UIScrollView? {
            if let reader = view as? ReaderTextSurface { return reader }
            for subview in view.subviews {
                if let reader = reader(in: subview) { return reader }
            }
            return nil
        }
    }
}
