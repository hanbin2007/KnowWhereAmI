// CI-only replacement for App/Speech/AudioSessionGuard.swift. The runner SDK
// predates AVAudioSession deactivation contexts; the CI build never records.
import SwiftUI

struct AudioSessionGuard: ViewModifier {
    let pause: () -> Void
    func body(content: Content) -> some View { content }
}
