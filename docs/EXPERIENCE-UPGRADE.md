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

# Interface Redesign: 2026-10-22

## Intent

Rebuild the SwiftUI front end so it feels composed rather than tabulated:
elegant, detailed, and calm on stage. Every number should sit inside a shape
that explains it. The speech pipeline, alignment, storage, and scoring rules
are unchanged.

## Design Language

- **Reading room palette** (`App/Design/Theme.swift`): warm paper, soft ink,
  and receded "spoken ink" for text already read. One evergreen accent, amber
  for provisional or preparing states, terracotta for estimated misses, and red
  only for the Live on-air badge. Light and dark values are defined together.
- **Type**: New York for titles, manuscript excerpts, and missed-word context.
  Rounded figures for measurements, tracked small capitals for section labels.
  The manuscript itself can be set in New York or SF Pro (Reader settings).
- **Motion tokens**: `morph` (layout spring, little bounce), `snappy`
  (selection and numbers), `gentle` (fades), and `reveal` (report ring and map
  drawing in once). `calmAnimation` disables each of them under Reduce Motion.

## Surfaces

- **Reader**: the manuscript runs full-bleed. The title header and the console
  float above it on paper-coloured scrims, so the text dissolves at the edges
  instead of being clipped. The reader frame never changes between modes, so a
  mode switch cannot shift the focus lane. A margin mark at the lane shows
  following (tall), peeking (short), tentative (amber), or locked (lock glyph).
  The word highlight is a rounded pill that glides along a line with a
  critically damped spring.
- **Console**: a camera-style capsule picks Rehearsal or Live. In Rehearsal, a
  watch-style pace subdial (60–220 wpm, conversational band marked) and a
  two-tone match ring flank the microphone, each with a plain-language caption
  ("Conversational", "2 est. missed"). The microphone carries a script-progress
  ring, an amber comet while preparing, and breathing halos while listening.
  Live morphs the same microphone into a rescue dock with a proportional
  paragraph rail and an on-air badge.
- **Library**: manuscripts are paper cards with a folded corner, an "Edited 2
  days ago" line, reading time, and the last run's match ring. Rehearsals form a
  timeline grouped by day. Cards enter with a short stagger.
- **Editor**: a writing surface with a serif title, live word count and
  minutes-aloud, an italic prompt on an empty page, and inline length notices.
- **Settings**: a live preview of a manuscript line at the chosen size and
  typeface, a tick ruler between the size buttons, typeface cards, and the
  on-device privacy promises as a short list.
- **Report**: a self-drawing match ring with a written verdict ("Close to the
  page") and narrative sentence, metric tiles, a coverage map that fills in as a
  wave from first word to last, and each missed word set in its sentence.

## Verification

GitHub's hosted macOS runners provide Xcode 26.6 and iOS 26.5 simulators, not
the Xcode 27 toolchain this app targets. `.github/workflows/ui-screenshots.yml`
therefore swaps in a no-capture speech stub (`scripts/ci/`) and lowers the
deployment target in the CI checkout only, then runs the app and UI suites in
light appearance and the screenshot suites again in dark. `ScreenshotTourUITests`
walks every primary surface. Screenshots are uploaded as the `screenshots`
artifact. Real speech capture still requires Xcode 27 and a physical iPhone.

## Liquid Glass Alignment: 2026-10-23

The user asked for strict adherence to the Liquid Glass HIG and for glass
wherever it belongs. Rules applied:

- **Glass is the control layer, never the content layer.** Navigation bars,
  toolbars, the search field, the console, and sheets use Liquid Glass.
  Manuscript text, library cards, history rows, and report sections stay
  opaque paper content.
- **Content flows under bars.** The manuscript runs edge to edge. Legibility
  comes from the system scroll edge effect, not custom opaque backdrops. The
  UIKit reader is paired with floating glass through
  `UIScrollEdgeElementContainerInteraction` (`ScrollEdgeAnchor`).
- **System bars and controls first.** The script title and reading length are
  the navigation title and subtitle (New York via bar appearance). Toolbar
  groups are separated with `ToolbarSpacer`, and the last run is a glass toolbar
  button. Mode and library sections are system segmented pickers. Text size is
  a system `Slider`. Close and confirm use the xmark and prominent-glass
  checkmark buttons.
- **One container, morphing elements.** The console is one
  `GlassEffectContainer`: a glass panel (mode picker, status, read-outs) plus
  individual interactive glass buttons. Shared `glassEffectID`s let the
  microphone and recenter button flow between Rehearsal and Live while the
  other buttons emerge from or merge into their neighbours.
- **Tint means something.** Only the microphone, the primary action, is tinted
  glass. Lock uses a light tint only while engaged. Finish is plain glass with
  an accent label.
- **No glass on glass.** Nothing inside the glass panel is itself glass.
- **Sheets keep system glass.** Partial-height sheets (Reading settings) show
  the system glass background; no `presentationBackground` overrides.
- **Accessibility.** System glass adapts to Reduce Transparency and Increase
  Contrast, so the custom fallback was removed. Reduce Motion still disables
  every custom animation through `calmAnimation`.
- **Concentric shapes.** The console panel radius (38 pt) is concentric with
  the iPhone display corners at the 16 pt inset.

## Component Layout

Every SwiftUI file holds one component, and no file exceeds 500 lines.

- `App/Design/`: palette (`Theme`), `Motion`, `Typography`, `Surfaces`,
  `ReadingMetrics`, the dials (`PaceDial`, `MatchDial`), `ListeningHalo`,
  `StatusDot`, `FoldedSheet`, `ScrollEdgeAnchor`.
- `App/Reader/Console/`: `ConsolePanel`, `ConsoleStatusRow`,
  `RehearsalReadouts`, `ConsoleControls` (Rehearsal/Live rows), `MicrophoneButton`,
  `GlassIconButton`, `ParagraphRail`, and console state on `ReaderModel`.
- `App/Reader/`: `ReaderView`, `ReaderTransport` (the glass container),
  `FocusLaneMark`, `BlankPage`, `ReaderSettings`, `ReaderTypeface`, and the UIKit
  text surface.
- `App/Library/`: `ScriptLibraryView`, `ScriptGallery`, `ScriptCard`,
  `RehearsalHistoryList`, `HistoryRow`.
- `App/Rehearsal/`: `RehearsalReportView`, `ReportHero`, `ReportMetrics`,
  `CoverageCard`, `MissedWordsSection`, `ManuscriptReviewView`, `ReportSheet`,
  `MatchRing`, `WordCoverageMap`, `CoverageBin`.

## Alignment Rules

- The word highlight is sized from the font's ascender and descender, so it
  has equal room above and below the word. Line-fragment rects carry the line
  spacing below the text.
- The focus lane mark centers on the text (the fragment's center minus half the
  line spacing) and scales with the manuscript size.
- Status rows: indicator and label 7 pt apart; secondary figures grouped on the
  trailing edge with a hairline divider; monospaced digits throughout.
- The console panel uses one 18 pt inset, so the picker, status row, and
  readouts share a leading edge. Secondary buttons, the microphone, and Finish
  share one centerline.
- Badges align optically: the label, not its capsule, lines up with the title.
  Badge rows have a fixed height, so titles align across neighbouring cards.
- Edge glyphs (text-size buttons) sit on the row's text edges; their 44 pt hit
  area extends inward.
- Tile symbols occupy a fixed 20 pt slot, so values align across tiles.
- At accessibility sizes, captions move below their dials instead of wrapping
  mid-word.
