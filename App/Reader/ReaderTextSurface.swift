import KnowWhereAmICore
import SwiftUI
import UIKit

@MainActor
final class ReaderTextSurface: UITextView, UITextViewDelegate {
    var onSelect: ((Int) -> Void)?
    var onManualScroll: (() -> Void)?
    var onManualScrollEnd: (() -> Void)?
    private var document = ScriptDocument(text: "")
    private var cursor: Int?
    private var tentative = false
    private var dark = false
    private var follows = true
    private var reducedMotion = false
    private var recenter = 0
    private var handledRecenter = -1
    private var style: Style?
    private var hasPlacedFocus = false
    private var previousPrefix = 0
    private var geometrySize = CGSize.zero
    private var changingGeometry = false
    private var selectionAllowed = true
    private let highlight = UIView()
    private let underline = UIView()
    private lazy var driver = FocusScrollDriver(view: self)
    private var highlightFrame = CGRect.null

    init() {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: .zero)
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)
        backgroundColor = .clear
        isEditable = false
        isSelectable = false
        alwaysBounceVertical = true
        alwaysBounceHorizontal = false
        contentInsetAdjustmentBehavior = .never
        textContainerInset = UIEdgeInsets(top: 12, left: 26, bottom: 12, right: 26)
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = true
        delegate = self
        accessibilityIdentifier = "scriptReader"
        highlight.isUserInteractionEnabled = false
        highlight.accessibilityElementsHidden = true
        highlight.accessibilityIdentifier = "currentWordHighlight"
        highlight.layer.cornerRadius = 7
        highlight.layer.cornerCurve = .continuous
        highlight.clipsToBounds = true
        underline.isUserInteractionEnabled = false
        underline.layer.cornerRadius = 1.25
        highlight.addSubview(underline)
        insertSubview(highlight, at: 0)
        highlight.alpha = 0
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap(_:))))
    }

    required init?(coder: NSCoder) { nil }

    func configure(document: ScriptDocument, cursor: Int?, tentative: Bool, pointSize: Double,
                   dark: Bool, typeSize: DynamicTypeSize, follows: Bool, recenter: Int,
                   reducedMotion: Bool, allowsInteraction: Bool, serif: Bool = false) {
        let nextStyle = Style(text: document.text, size: pointSize, dark: dark, type: typeSize, serif: serif)
        let rebuild = style != nextStyle
        let cursorChanged = self.cursor != cursor || self.tentative != tentative
        self.document = document
        self.cursor = cursor
        self.tentative = tentative
        self.dark = dark
        if self.follows && !follows { driver.cancel() }
        self.follows = follows
        self.recenter = recenter
        self.reducedMotion = reducedMotion
        selectionAllowed = allowsInteraction
        // Disabling UITextView scrolling changes its intrinsic sizing in SwiftUI.
        panGestureRecognizer.isEnabled = allowsInteraction
        showsVerticalScrollIndicator = allowsInteraction
        if rebuild {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = serif ? 11 : 10
            paragraph.paragraphSpacing = 6
            var base = UIFont.systemFont(ofSize: CGFloat(pointSize))
            if serif, let descriptor = base.fontDescriptor.withDesign(.serif) {
                base = UIFont(descriptor: descriptor, size: CGFloat(pointSize))
            }
            let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: base, compatibleWith: traitCollection)
            textStorage.setAttributedString(NSAttributedString(string: document.text, attributes: [
                .font: font, .foregroundColor: UIColor.ink, .paragraphStyle: paragraph, .kern: serif ? 0.1 : 0
            ]))
            if style?.text != nextStyle.text { hasPlacedFocus = false }
            style = nextStyle
            previousPrefix = 0
            geometrySize = .zero
            highlightFrame = .null
        }
        if rebuild || cursorChanged { paintProgress() }
        setNeedsLayout()
        if bounds.width > 0, bounds.height > 0 { layoutIfNeeded() }
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Previous word") { [weak self] _ in
                guard let self, self.selectionAllowed else { return false }
                self.onSelect?(max(0, (self.cursor ?? 0) - 1)); return true
            },
            UIAccessibilityCustomAction(name: "Next word") { [weak self] _ in
                guard let self, self.selectionAllowed, !self.document.words.isEmpty else { return false }
                self.onSelect?(min(self.document.words.count - 1, (self.cursor ?? -1) + 1)); return true
            }
        ]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !changingGeometry, bounds.height > 0, bounds.width > 0, textStorage.length > 0 else { return }
        changingGeometry = true
        defer { changingGeometry = false }
        layoutManager.ensureLayout(for: textContainer)
        let geometryChanged = geometrySize != bounds.size
        if geometryChanged {
            geometrySize = bounds.size
            let first = layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
            let inset = ReadingFocus.insets(viewportHeight: bounds.height, lineHeight: first.height,
                                            textInset: textContainerInset.top)
            contentInset = UIEdgeInsets(top: inset.top, left: 0, bottom: inset.bottom, right: 0)
        }
        placeHighlight()
        let word = cursor ?? 0
        guard document.words.indices.contains(word), !isTracking, !isDragging, !isDecelerating,
              follows || recenter != handledRecenter else { return }
        let glyph = layoutManager.glyphIndexForCharacter(at: document.words[word].range.location)
        let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let offset = ReadingFocus.offset(lineMidY: line.midY + textContainerInset.top,
                                         viewportHeight: bounds.height, contentHeight: contentSize.height,
                                         topInset: contentInset.top, bottomInset: contentInset.bottom)
        handledRecenter = recenter
        driver.move(to: offset, animated: hasPlacedFocus && !geometryChanged && !reducedMotion && window != nil)
        hasPlacedFocus = true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { driver.cancel() } else { setNeedsLayout() }
    }

    private func paintProgress() {
        let nextPrefix = cursor.flatMap { document.words.indices.contains($0) ? document.words[$0].range.location : nil } ?? 0
        textStorage.beginEditing()
        if previousPrefix > nextPrefix {
            textStorage.addAttribute(.foregroundColor, value: UIColor.ink,
                                     range: NSRange(location: nextPrefix, length: previousPrefix - nextPrefix))
        } else if nextPrefix > previousPrefix {
            textStorage.addAttribute(.foregroundColor, value: UIColor.spokenInk,
                                     range: NSRange(location: previousPrefix, length: nextPrefix - previousPrefix))
        }
        textStorage.endEditing()
        previousPrefix = nextPrefix
    }

    private func placeHighlight() {
        guard let cursor, document.words.indices.contains(cursor) else {
            highlight.alpha = 0
            highlightFrame = .null
            return
        }
        let glyphs = layoutManager.glyphRange(forCharacterRange: document.words[cursor].range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        rect.origin.x += textContainerInset.left
        rect.origin.y += textContainerInset.top
        rect = rect.insetBy(dx: -5, dy: -1)
        let accent = UIColor(named: "AccentColor") ?? tintColor!
        let color: UIColor = tentative ? .dynamic(light: 0xE9B44C, dark: 0xF0B653) : accent
        highlight.backgroundColor = color.withAlphaComponent(dark ? 0.24 : 0.15)
        underline.backgroundColor = tentative ? .dynamic(light: 0xB7791A, dark: 0xF0B653) : accent
        guard rect != highlightFrame else { return }
        let sameLine = !highlightFrame.isNull && abs(rect.midY - highlightFrame.midY) < rect.height / 2
        let underlineFrame = CGRect(x: 5, y: rect.height - 2.5, width: max(0, rect.width - 10), height: 2.5)
        if reducedMotion || !sameLine {
            highlight.layer.removeAllAnimations()
            highlight.frame = rect
            underline.frame = underlineFrame
            highlight.alpha = reducedMotion ? 1 : 0.3
            if !reducedMotion { UIView.animate(withDuration: 0.18) { self.highlight.alpha = 1 } }
        } else {
            // The pill glides along the line to the next word.
            UIView.animate(springDuration: 0.24, bounce: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.highlight.frame = rect
                self.underline.frame = underlineFrame
                self.highlight.alpha = 1
            }
        }
        highlightFrame = rect
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { driver.cancel(); onManualScroll?() }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { onManualScrollEnd?() }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { onManualScrollEnd?() }

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        selectionAllowed && super.accessibilityScroll(direction)
    }

    @objc private func didTap(_ gesture: UITapGestureRecognizer) {
        guard selectionAllowed else { return }
        var point = gesture.location(in: self)
        point.x -= textContainerInset.left
        point.y -= textContainerInset.top
        let offset = layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        guard let word = document.wordIndex(atUTF16Offset: offset) else { return }
        let glyphs = layoutManager.glyphRange(forCharacterRange: document.words[word].range, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        if rect.insetBy(dx: -4, dy: -4).contains(point) { onSelect?(word) }
    }

    private struct Style: Equatable {
        let text: String
        let size: Double
        let dark: Bool
        let type: DynamicTypeSize
        let serif: Bool
    }
}
