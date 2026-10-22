import Foundation
import KnowWhereAmICore

extension ReaderModel {
    @discardableResult
    func createScript(title: String, text: String) -> Bool {
        guard prepareScriptTransition() else { return false }
        let content = SavedReaderState(title: cleanTitle(title), text: text, fontSize: saved.fontSize,
                                       followsPosition: saved.followsPosition)
        let manuscript = Manuscript(content: content)
        var next = library
        next.manuscripts.append(manuscript)
        next.selectedID = manuscript.id
        return commitLibrary(next, reloadSelection: true)
    }

    @discardableResult
    func selectManuscript(_ id: UUID) -> Bool {
        guard library.manuscripts.contains(where: { $0.id == id }) else { return false }
        if library.selectedID == id { return true }
        guard prepareScriptTransition() else { return false }
        var next = library
        next.selectedID = id
        return commitLibrary(next, reloadSelection: true)
    }

    @discardableResult
    func duplicateManuscript(_ id: UUID) -> Bool {
        guard let original = library.manuscripts.first(where: { $0.id == id }), prepareScriptTransition() else { return false }
        var content = original.content
        content.title = String(content.title.prefix(73)) + " copy"
        let copy = Manuscript(content: content)
        var next = library
        next.manuscripts.append(copy)
        next.selectedID = copy.id
        return commitLibrary(next, reloadSelection: true)
    }

    @discardableResult
    func deleteManuscript(_ id: UUID) -> Bool {
        guard library.manuscripts.contains(where: { $0.id == id }) else { return false }
        let selected = library.selectedID == id
        if selected, !prepareScriptTransition() { return false }
        var next = library
        next.manuscripts.removeAll { $0.id == id }
        if selected { next.selectedID = next.manuscripts.first?.id }
        return commitLibrary(next, reloadSelection: selected)
    }

    @discardableResult
    func saveScript(title: String, text: String) -> Bool {
        guard let selected = library.selectedID,
              let index = library.manuscripts.firstIndex(where: { $0.id == selected }) else {
            return createScript(title: title, text: text)
        }
        let changedText = text != saved.text
        if changedText, !prepareScriptTransition() { return false }
        var next = library
        next.manuscripts[index].content.title = cleanTitle(title)
        next.manuscripts[index].content.text = text
        next.manuscripts[index].modifiedAt = Date()
        return commitLibrary(next, reloadSelection: changedText)
    }

    func changeFontSize(by delta: Double) {
        guard let index = library.manuscripts.firstIndex(where: { $0.id == library.selectedID }) else { return }
        var next = library
        next.manuscripts[index].content.fontSize = min(40, max(18, saved.fontSize + delta))
        if commitLibrary(next) { recenter() }
    }

    func setFollowPreference(_ follows: Bool) {
        guard let index = library.manuscripts.firstIndex(where: { $0.id == library.selectedID }) else { return }
        var next = library
        next.manuscripts[index].content.followsPosition = follows
        if commitLibrary(next) {
            followsPosition = follows
            if follows { recenter() }
        }
    }

    private func cleanTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled script" : trimmed
    }
}
