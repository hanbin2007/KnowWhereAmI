# Experience Upgrade: 2026-10-20

## Accepted Intent

Improve the existing native English script follower, not replace it. The user
reported unstable scrolling and requested fluid motion, multiple saved scripts,
rehearsal with rate/accuracy/missed-word statistics, and a live emergency mode.

## Design Decisions

- Stabilize UIKit text layout: build text once per document/style change; update
  word styling in place, never reset attributedText/contentOffset per hypothesis.
- Keep the current line in a fixed focus lane. Recompute on actual viewport
  layout, including first/last lines, resize, large type, and mode changes.
- Retarget a critically damped display-link spring from its current position and
  velocity. User dragging interrupts it immediately. Reduced Motion jumps without
  animated travel. An enabled follower resumes after a temporary manual peek.
- Use restrained, short button/highlight/numeric transitions; no decorative loops
  or bouncy text. The microphone action never waits for an animation.
- Add a local manuscript library with create/edit/duplicate/delete/search and
  selected-script persistence. Migrate the old single-script file without deleting
  it. Mutations are applied to memory only after an atomic save succeeds.
- Default to Rehearsal mode. Measure active listening time (not preparing/paused
  time), actual finalized recognized word count, and estimated script coverage.
- Derive omission evidence from final alignment, not cursor distance alone.
  Future unread words remain unassessed; manual seeks do not invent omissions;
  corrected rereading can repair earlier missed-word estimates. ASR-derived
  accuracy is not a pronunciation score or ground-truth acoustic accuracy.
- Persist rehearsal reports with a manuscript snapshot and time/date so later
  edits/deletions do not change past results. Keep report/history accessible.
- Live mode removes score/transcript clutter, retains a large reading surface,
  and provides previous/next paragraph rescue, recentering, and a position lock.
  An explicit live rescue can re-anchor and resume listening; backgrounding or
  interruption must always cancel any pending resume.
- Switching scripts or modes saves a meaningful ongoing rehearsal without
  presenting a blocking report over a live emergency action.
- No accounts, network services, audio files, uploads, or automatic microphone
  starts on launch. Keep the Apple on-device speech engine.

## Responsibilities

1. Parent: focus physics/layout, UIKit reader, app state integration, library UI,
   mode controls, rehearsal/live surfaces, reports, workflow tests and QA.
2. Storage worker: library models, atomic persistence, migration and core tests.
3. Rehearsal worker: final alignment evidence, metric accumulation/history and
   core tests, while preserving existing cursor contracts.

## Visual Refinement

The user explicitly requested a bolder redesign, unrestricted by the old layout.
The new reading stage uses an editorial New York title and unframed manuscript.
Mode controls move to the thumb zone, with a shared moving underline. A centered
microphone and actual script-progress ring sit between pace and coverage; Live
mode morphs that microphone into a compact native Liquid Glass rescue dock and
returns the extra space to the manuscript. The manuscript library becomes a
two-column document gallery, falling back to one column at accessibility sizes.
Sheets originate from their toolbar controls with native zoom transitions.

Motion is short and causal: shared geometry, symbol/numeric transitions, and
velocity-preserving focus; no looping decoration, text reflow animation, or
per-word haptics. Explicit mode/lock/rescue actions get selection feedback.
Preserve Reduce Motion, provide a solid Reduce Transparency fallback, and cap
only compact chrome at accessibility2 while the manuscript, editor, and reports
continue to use the user's full Dynamic Type setting.

The final rehearsal report is a visual debrief, not a settings-style text list:
a native Swift Charts match/omission donut, a manuscript coverage mosaic, a
compact rate/time/word strip, and contextual missed-word review. The donut uses
only assessed words; the separate coverage map retains the unread tail as
unassessed. Long scripts aggregate into at most 240 proportional bins without
losing matched/missed/unassessed counts. Do not invent pace curves from an
aggregate average or imply pronunciation accuracy.

## Verification

- Red/green tests for scroll geometry/retargeting, evidence and migration.
- Core suite plus model tests for pause/prepare time, seeks, stale callbacks,
  script/mode transitions, saved history and library mutation failures.
- Actual UIKit tests for stable focus across many word updates and resizing,
  no full-text rebuild on a cursor change, and reduced-motion behavior.
- Simulator workflows for multiple scripts, persistence, report/history, live
  rescue/lock, and large text; inspect light/dark screenshots.
- Simulator and unsigned iPhone Release builds. Do not claim physical acoustic
  accuracy, motion acceptance or timing until verified on the user's iPhone.
