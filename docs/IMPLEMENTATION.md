# KnowWhereAmI: English Script Following

This document records the original v0.1 scope. The multi-manuscript, rehearsal,
Live, visual-report, and interaction redesign is specified in
`EXPERIENCE-UPGRADE.md`; current verification is in `VALIDATION.md`.

## Brief

Build a native iPhone app that highlights the position reached in a supplied
English manuscript. The user has an iPhone 17 on the latest iOS. The previous
research recommendation (SwiftUI, Apple SpeechTranscriber, manuscript alignment)
was accepted with an explicit request to start implementation.

## Decisions

- Target iOS 27.0 and Xcode 27, both available in this workspace.
- Use SpeechAnalyzer / SpeechTranscriber only; no cloud recognizer, third-party
  account, analytics, audio upload, or audio recording to disk.
- Use iOS 27 CaptureInputSequenceProvider for microphone capture and conversion.
- Download Apple's English model only after an explicit start action.
- Keep the original manuscript and UTF-16 word ranges separate from normalized
  matching units. Expand common contractions and numbers for matching.
- Use constrained local sequence alignment, with stronger evidence for global
  repositioning. Silence/unrelated speech must not advance the cursor.
- Replace provisional results by audio range; never append every partial result.
- Show a provisional cursor separately from confirmed position. Permit rereading,
  skipped words, local jumps, explicit word selection, and tentative retraction.
- Persist manuscript and reader settings locally. Editing is transactional.
- Reader, editor, import, type size, follow-position, pause/resume, and reset make
  up the first release. No accounts, library, PDF import, recording, or sharing.

## Execution

- [x] Test tokenizer, alignment, partial replacement, and local persistence.
- [x] Implement the platform-independent core and pass the complete Swift suite.
- [x] Implement cancellable on-device model preparation and speech capture.
- [x] Implement the native reader, transactional editor, and text-file import.
- [x] Generate an Xcode project and build simulator + unsigned device targets.
- [x] Run UI workflow tests and inspect simulator screenshots.
- [x] Review the implementation and record remaining device-only validation.

Final observed results and the physical-device boundary are in `VALIDATION.md`.

## Validation Boundaries

Core alignment tests do not prove acoustic accuracy. A simulator build does not
prove on-device speech model availability. A device build does not mean an app
has been installed. Actual microphone latency, accent accuracy, thermal behavior,
Bluetooth routing, and long-session stability require an available physical
iPhone. The initial implementation could not access a connected iPhone; hardware
availability has not been rechecked for this upgrade.
