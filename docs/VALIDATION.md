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

## Automatic Tracking Bounds: 2026-10-22

PR #1 was merged as `d18c61c`. The subsequent tracking fix limits automatic
position endpoints to three previous sentences and the current/next paragraph.
Manual selection and Live rescue remain deliberate unrestricted re-anchors.

| Check | Result | Evidence |
| --- | --- | --- |
| Final core behavioral suite | 97 passed, 0 failed | `build/bounded-tracking-final.log` |
| Full native app/UI suite | 42 passed, 0 failed, no runtime warnings | `build/Bounded-Tracking-Final-App.xcresult` |
| Final native app suite after delayed-final refinement | 33 passed, 0 failed, no runtime warnings | `build/Bounded-Tracking-Final-Native.xcresult` |
| Final generic iPhone Release, arm64 | Build succeeded, unsigned | `build/bounded-tracking-device-final.log` |

Toolchain: Xcode 27.0, iOS 27.0 (24A434), dedicated iPhone 17 QA simulator.
These builds use the actual speech pipeline, not the older-toolchain CI stub;
test audio events are controlled, not recorded from a microphone. The full UI
run predates only the final delayed-final alignment refinement; the core and
native suites were rerun after it. Unsigned compilation is not signed-device
installation or real speech acceptance.

Regression coverage includes exact backward/forward boundaries, strong recovery,
abbreviations, CRLF/quoted paragraphs, long predicted anchors, provisional
ratcheting, stale cached results, reset/resume, unrestricted manual re-anchoring,
and failed/revoked results that must not snap outside the visible limits. Delayed
finals with revised, shortened, or extended text retain validated full-segment
coverage without moving the visible cursor. Out-of-window speech cannot finish
a rehearsal or fabricate assessed words. Red-test logs are retained in `build/`.

## Streaming Regression Repair

The user's physical-iPhone test of `573a4b4` failed: speech following was too
sensitive, jumped on a single word, and blocked valid rereading. Earlier passing
synthetic tests were not sufficient acceptance evidence. Replays reproduced a
continuous partial freezing at word 39 of an 80-word, four-paragraph script, plus
old transcript context authorizing a jump from only one new word.

The repair moves the bounds with the displayed matched position, evaluates the
active segment's new/changed tokens, and holds position on recognition noise.
Short fragments can follow adjacent words but cannot authorize a distant move.
Distinctive exact short phrases can recover beyond the old 36-word local limit
while remaining inside three previous sentences and the current/next paragraph.
Audio times, not identity allocation order or maximum script position, order
merged hypotheses and final confirmations. Earlier prefix finals do not revoke
later matched audio; a correction of the active range can still retract a word.

| Check | Result | Evidence |
| --- | --- | --- |
| Final core behavioral suite | 116 passed, 0 failed | `build/streaming-final-core.log` |
| Full app/UI suite during repair | 46 passed, 0 failed, no runtime warnings | `build/Streaming-Final-App.xcresult` |
| Final native suite after all confidence refinements | 37 passed, 0 failed, no runtime warnings | `build/Streaming-Complete-Native.xcresult` |
| Signed generic iPhone Release | Build and strict signature verification succeeded | `build/streaming-signed-device.log` |

The full UI run preceded the last confidence refinements; the final core/native
runs include them. New tests cover the entire practice manuscript before any
final result, distinct unfinalized chunks, one appended/replaced word, noisy
revisions, valid three-word jumps, rereading two long sentences back, merged audio
ranges, backward-reading confirmation, and immediate/delayed final orderings.
Both cursor stability and final-only coverage are asserted. Regression red logs
and result bundles remain in `build/`.

These are controlled transcript replays, not a measured improvement in acoustic
recognition, device latency, CPU usage, or real-microphone acceptance. The speech
model was not replaced. No raw-speech logging or audio recording was added.
The repaired app still needs a physical-iPhone retest before acceptance.
The local signed test bundle uses Build 3 via a build-command override to
distinguish it from the faulty Build 2; repository version metadata is unchanged.
It has not been installed during this repair pass.

## Distance-Adaptive Repair: 2026-10-23

After testing Build 3 on the iPhone, the user reported continued sticking.
New replays reproduced fixed short-fragment gates rejecting a nearby correct
word after two ASR omissions, two-word medium moves, and separate one-word
results that could never satisfy a per-result distant-recovery threshold.

Movement confidence is now centralized in `TrackingSensitivity` and scales with
actual manuscript distance. New unmatched audio can accumulate across distinct
chunks; revisions replace evidence and cannot vote repeatedly. Chunk-boundary
windows let a fresh coherent phrase recover after older unmatched chatter.
Distant ambiguity waits for distinctive context, and stronger pending phrases
can outweigh one coincidental next word. The hard sentence/paragraph bounds are
unchanged; neither elapsed time nor failure count relaxes them.

| Check | Result | Evidence |
| --- | --- | --- |
| Final core suite | 133 passed, 0 failed | `build/distance-sensitivity-final.log` |
| Full app/UI suite during repair | 50 passed, 0 failed, no runtime warnings | `build/Distance-Adaptive-Reviewed-App.xcresult` |
| Final native suite after recovery-window refinement | 41 passed, 0 failed, no runtime warnings | `build/Distance-Adaptive-Final-Native.xcresult` |
| Signed iPhone Release, local Build 4 | Build and strict signature verification succeeded | `build/distance-adaptive-signed-device.log` |

Coverage includes monotonic distance thresholds, nearby omissions/noisy tokens,
two-word medium recovery, three-word distant recovery, duplicate/overlapping and
out-of-order audio, ambiguous phrases, old chatter, manual reset, exact-path
backward safeguards, and older finals excluded from future provisional evidence.
The full UI run predates only the last recovery-window refinement; final core
and native runs include it. Red replays/result bundles remain in `build/`.

Rehearsal coverage rules were not changed. The integration tests distinguish
matched final words from the existing estimated gap between finalized endpoints;
provisional recovery does not become finalized coverage or finish a rehearsal.
No speech/audio recording or additional model download was added. Build 4 was
prepared, not installed, in this pass. Real-microphone retesting and measured
device latency/accuracy remain acceptance gaps, not established improvements.

## Live Deadline And Pace: 2026-10-23

Live now has a prominent three-minute countdown, per-manuscript duration
presets and 15-second adjustments (30 seconds through 60 minutes), a remaining
budget bar, estimated reading time, and spare/short time. Countdown controls
never start the microphone. First actual listening starts an unstarted clock;
microphone pauses, backgrounding, and mode changes do not stop the event
deadline. Limit changes preserve elapsed time. Countdown restart preserves
recent pace; explicit reader restart or a different manuscript resets the run.
Only the duration preference is stored; an active deadline is not crash recovery.

Pace uses actual recognized words over the trailing 30 seconds, including
silence. Word audio ranges are retained when complete; otherwise a chunk's words
are distributed over its audio interval. Revisions replace overlapping samples
without double counting, and earlier finals preserve later provisional audio.
The first capture input calibrates the audio timeline to the monotonic clock,
not recognition-result delivery time. Manual rescue changes remaining script
words but cannot invent speech speed. Forecasts wait for 5 words/5 seconds and
are withheld for uncertain position or a paused microphone. WPM is capped at
360 to avoid implausibly optimistic estimates from short recognition bursts.

| Check | Result | Evidence |
| --- | --- | --- |
| Core behavioral suite | 152 passed, 0 failed | `build/live-timing-core-final-confirmed.log` |
| Focused timer model/layout/UI suite | 12 passed, 0 failed, no runtime warnings | `build/Live-Timing-Focused.xcresult` |
| Full app/UI regression suite | 62 passed, 0 failed, no runtime warnings | `build/Live-Timing-Final-App.xcresult` |
| Final timer settings/ticking UI rerun | 1 passed, 0 failed | `build/Live-Timing-Final-Interaction.xcresult` |
| Signed iPhone Release, local Build 5 | Build and strict signature verification succeeded | `build/live-timing-signed-device-final.log` |

Regression checks cover legacy duration migration, invalid stored values,
transactional preference updates, pause/background-equivalent elapsed time,
manual start without capture, clock reset boundaries, resumed audio sessions,
host-time input, delayed recognition, word-level revisions, and unknown position.
Screenshots cover on-track/behind/overtime, light/dark, 320-point compact
geometry, and an AX5 environment with the existing AX2 console cap. The timer's
forecast reflows below its clock at accessibility sizes. Simulated wide geometry
does not add landscape support; this remains a portrait iPhone application.
Rendered ETA/detail contrast was reviewed in both appearances. Final VoiceOver
interaction and physical-device readability still require user acceptance.
The final UI rerun includes the last duration-value contrast adjustment and
asserts that the on-screen countdown advances without starting the microphone.

These are controlled text/audio-time events, not live microphone recordings.
Build 5 is prepared, not installed. Real capture-clock calibration, acoustic
recognition, forecast responsiveness to real speed changes/silence, and the
existing automatic jump limits still need a physical-iPhone retest. No tracking
scoring rules or jump bounds changed for this feature. No audio retention,
network transcription, or extra model download was added.

Device acceptance: use a real manuscript with the 3-minute default, read at
different speeds, pause for 10 seconds, and verify the deadline keeps counting
while ETA is withheld. Resume and compare the estimate after new speech. Set a
shorter limit to exercise Behind pace and overtime, adjust it without resetting
elapsed time, and test explicit countdown restart. Confirm paragraph rescue does
not spike WPM and uncertain tracking does not promise an on-time finish.
