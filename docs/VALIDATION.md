# Validation: 0.2.0 (Build 2), 2026-10-20

## Observed Results

| Check | Result | Evidence |
| --- | --- | --- |
| Core behavioral suite | 72 passed, 0 failed | `build/experience-core-final.log` |
| iPhone 17 full app/UI suite, light | 39 passed, 0 failed | `build/Final-Visual-Light.xcresult` |
| Final native/report suite, light | 32 passed, including proportional mosaic correction and AX report | `build/Final-Report-Complete.xcresult` |
| Final full app/UI suite, dark | 40 passed, 0 failed | `build/Final-Visual-Dark.xcresult` |
| Generic iPhone Release, arm64 | Build succeeded, unsigned | `build/device-release-upgrade-final.log` |
| Bundle version | 0.2.0, Build 2 | Release app's processed Info.plist |
| Project / Info.plist | Both pass `plutil -lint` | Generated project and `App/Info.plist` |

Toolchain: Xcode 27.0, Swift 6, iOS Simulator 27.0 (24A434). All tests use the
dedicated `KnowWhereAmI iPhone 17 QA` simulator. No real microphone input was used.
The light full suite predates one added chart-area regression; the later native
suite includes that regression and the reviewed chart/VoiceOver corrections.

## Covered Behavior

- Original UTF-16 token ranges, English normalization, contractions, numbers,
  fillers, skipped words, repeated audio, rereading, global recovery, and revised,
  revoked, overlapping, stale, and final/provisional hypothesis handling.
- Stable first/middle/last-line focus, resize without a new word, rapid cursor
  updates without character replacement, manual peek/recenter, restored same-word
  highlighting, critically damped retargeting, and immediate Reduced Motion focus.
- Multiple manuscripts, non-destructive legacy migration, selected-script
  persistence, duplication/deletion (including the final script),
  corruption protection, atomic saves, and failed-transition recovery.
- Rehearsal rate excludes preparation/explicit pause time. Scoring uses final
  alignment evidence, not cursor distance. Unread tails/manual seeks are not
  invented omissions; rereading can repair coverage. Final flush precedes reports.
- Live does not score or stop at the final word. Paragraph rescue, boundary
  guards, touch lock without intrinsic-size changes, and explicit pause cancelling
  pending resume are tested. Opening prior results stops hidden listening/scoring.
- Reports preserve script snapshots. Deleted unchanged reports do not reappear.
  Donut denominators and AX values are explicit. Mosaic count sums and word-area
  proportions remain correct for long scripts and partial final bins.
- Actual simulator workflows cover editor save/cancel/undo,
  empty scripts, font controls, library switching/relaunch, duplicate/delete,
  locked Live rescue, mode changes, and maximum accessibility text size.
- Actual hosted SwiftUI rendering covers the visual report and longest reader
  status at maximum Dynamic Type. Gallery switches to one column at AX sizes.

## Review And Screenshots

Independent read-only code/UX reviews led to regressions/fixes for stale TextKit
content sizing, hidden highlights, failed-save scoring freezes, external audio
interruption handling, editor identity/draft protection, lock sizing, paragraph
boundaries, hidden listening behind reports, and chart-area/denominator accuracy.

`Preview.png`, `Preview-dark.png`, `Preview-Live.png`, and `Preview-Library.png`
show actual simulator UI/tap-selected positions. Rehearsal/report previews use a
controlled finalized transcript with one known omission. They are real rendered
app views, not an acoustic test, live-recognition proof, or benchmark result.

Passing result bundles contain no runtime warnings. The CLI emits Xcode's
`debugger version lookup failed for path '<nil>'` launch diagnostic; it does not
prevent tests. Failure-diagnostic collection remains disabled to avoid the
previous Xcode collection stall. Intentionally failing runs remain in `build/`.

## Not Established

- No signed installation, TestFlight distribution, or physical-iPhone acceptance.
- No measured accent accuracy, end-to-end word-boundary latency, final-audio flush
  completeness on hardware, Bluetooth routing, battery/thermal behavior, or long
  uninterrupted live-session stability. ASR coverage is not pronunciation quality.
- Physical motion/haptics and comprehensive VoiceOver acceptance remain open.
- Unfinished in-memory rehearsals are not crash-recovery checkpoints. Finish,
  changing modes/scripts, or restarting saves meaningful reports; explicit pause
  alone does not create a persistent checkpoint.

## Next Physical-Device Check

1. Sign/run on the user's iPhone 17; install English assets before an event.
2. Rehearse a real script with pauses, fillers, repetitions, corrections, skips,
   and rereading; compare cursor lag and estimated omissions with spoken words.
3. Check final-utterance scoring, interruption/disconnection/backgrounding, manual
   live rescue, lock, type size, Reduced Motion/Transparency, and VoiceOver.
4. Run both modes for at least 15 minutes with the usual Auto-Lock preference.
