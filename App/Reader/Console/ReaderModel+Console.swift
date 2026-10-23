import SwiftUI

/// Presentation state the console derives from the reader's phase.
extension ReaderModel {
    var isStopping: Bool { phase == .stopping || phase == .finishing }

    var isPreparing: Bool {
        switch phase {
        case .preparing, .downloading: true
        default: false
        }
    }

    var isWorking: Bool { phase == .listening || isPreparing || phase == .finishing }

    var microphoneSymbol: String {
        switch phase {
        case .listening: "pause.fill"
        case .preparing, .downloading: "xmark"
        case .finished: "arrow.counterclockwise"
        default: "mic.fill"
        }
    }

    var primaryActionTitle: String {
        switch phase {
        case .listening: "Pause listening"
        case .preparing, .downloading: "Cancel preparation"
        case .stopping, .finishing: "Stopping microphone"
        case .paused: "Resume listening"
        case .finished: "Read again"
        default: "Start listening"
        }
    }

    var statusColor: Color {
        switch phase {
        case .listening: isFindingPosition ? Theme.amber : Theme.accent
        case .preparing, .downloading, .finishing: Theme.amber
        case .finished: Theme.accent
        default: Color.secondary.opacity(0.6)
        }
    }
}
