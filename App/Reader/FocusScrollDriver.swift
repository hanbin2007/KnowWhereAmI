import KnowWhereAmICore
import UIKit

@MainActor
final class FocusScrollDriver {
    private weak var view: UIScrollView?
    private var spring = FocusSpring()
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private let target = DisplayLinkTarget()

    init(view: UIScrollView) {
        self.view = view
        target.owner = self
    }

    isolated deinit { link?.invalidate() }

    func move(to offset: CGFloat, animated: Bool) {
        guard let view, !view.isTracking, !view.isDragging, !view.isDecelerating else { return }
        if !animated || abs(offset - view.contentOffset.y) > view.bounds.height * 2 {
            cancel()
            spring.jump(to: offset)
            view.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
            return
        }
        if link == nil { spring.jump(to: view.contentOffset.y) }
        spring.retarget(offset)
        guard !spring.isSettled else { return }
        if link == nil {
            let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.advance(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            self.link = link
        }
    }

    func cancel() {
        link?.invalidate()
        link = nil
        lastTimestamp = nil
        if let view { spring.jump(to: view.contentOffset.y) }
    }

    fileprivate func advance(_ link: CADisplayLink) {
        guard let view, view.window != nil, !view.isTracking, !view.isDragging, !view.isDecelerating else {
            cancel(); return
        }
        let elapsed = lastTimestamp.map { link.timestamp - $0 } ?? (link.targetTimestamp - link.timestamp)
        lastTimestamp = link.timestamp
        let offset = spring.step(elapsed: elapsed)
        view.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
        if spring.isSettled {
            view.setContentOffset(CGPoint(x: 0, y: spring.target), animated: false)
            cancel()
        }
    }
}

@MainActor
private final class DisplayLinkTarget: NSObject {
    weak var owner: FocusScrollDriver?
    @objc func advance(_ link: CADisplayLink) { owner?.advance(link) }
}
