# PayPaw — Responsive Layout & Accessibility

Sprint 9 deliverable. How PayPaw behaves on a screen it was not drawn for, and
what it does for users who need it to behave differently.

The reference design is one phone at one font size. Everything here is about the
cases it does not cover.

---

## Window sizes

Classified by the width the app was handed, not by device type — "phone" and
"tablet" stop meaning anything once a foldable is half-open or the app is in a
split-screen pane.

| Class | Width | What it is |
| --- | --- | --- |
| `compact` | < 600dp | Phone portrait, narrow split-screen pane. The design's baseline. |
| `medium` | 600–839dp | Small tablet, phone landscape, unfolded foldable. |
| `expanded` | ≥ 840dp | Tablet landscape, desktop window. |

`context.windowSize` reads this from `MediaQuery.sizeOf`, so a widget using it
rebuilds on rotation, resize, or a foldable opening.

### Large screens: cap, do not stretch

Content is capped at **560dp** and centred; the bottom navigation at **480dp**.

Letting a bill list stretch to 1200dp does not use the space, it wastes it: every
row becomes a long horizontal scan between a name on the far left and an amount
on the far right, and four navigation destinations spread across a tablet are
further apart than a thumb wants to travel.

`AppContentWidth` does this once, around the shell. Below the cap it is invisible
in the layout, so a screen written for a phone is automatically fine on a wide
window without knowing it is on one.

### Small screens: give up the least important thing

The bottom navigation is the widest thing in the app relative to its container —
four destinations, one of them a labelled pill. On a 320dp screen, or at a large
system font, the label stops fitting.

It **drops the label and shows icons only**, rather than truncating to `Calend…`.
A clipped word reads as a bug; an icon-only bar reads as a design. The width
threshold is multiplied by the user's text scale, so the switch happens when the
text actually stops fitting rather than at a width guessed for one font size.

The destination stays reachable and stays labelled for a screen reader — only the
visible text goes.

---

## System font scaling

Clamped to **0.85–1.6** in `PayPawApp`.

This is a real accessibility trade-off, taken deliberately. Android allows up to
2.0, and at 2.0 an amount, a due date and a status chip cannot share a row on a
narrow screen. The honest alternative is a per-screen layout that reflows into a
column at large scales — worth building when the real screens exist, and worth
revisiting the ceiling then.

Below 0.85 nothing is gained; Android's smallest setting is already legible.

**Everything below the clamp is honoured exactly.** Text is never shrunk to make
something fit — that would undo the setting the user chose. Where content stops
fitting, it scrolls:

- `AppStateMessage` centres itself when there is room and scrolls when there is
  not, so an empty state in a short container never overflows.
- Button labels **wrap** rather than ellipsise. A user who turned the font up
  needs the whole label, not the first two thirds of it.

---

## Overflow

Overflow is the failure mode that hides best. It does not crash, it does not fail
a unit test, and on the developer's own phone it often does not appear at all.

So it is tested rather than eyeballed. [`test/app/responsive_test.dart`](../test/app/responsive_test.dart)
walks **every destination, in five window sizes, at three font scales**, and fails
if Flutter reports a single layout error. `tester.takeException()` is what does
the work: a `RenderFlex overflowed` surfaces there, and would otherwise only ever
be a yellow stripe in a screenshot nobody took.

The two developer galleries get their own pass at 320dp and scale 2, scrolled end
to end — they are the densest screens in the app, and the ones where a regression
would be noticed last.

That suite found two real defects on its first run:

1. **The navigation pill overflowed mid-transition.** A destination's flex share
   changes the instant selection moves, while its label takes 260ms to animate
   away — so for those 260ms the outgoing item was drawing a label in a slot
   already narrowed to icon width. Fixed by making the label shrinkable.
2. **A button with an icon and a long label overflowed at large font sizes.**
   Fixed by making the label flexible, so it wraps and grows the button.

Neither was visible at the default font size on a normal phone.

### Rules

- A `Row` containing text needs a `Flexible` or `Expanded` around that text.
  Anything else is an overflow waiting for a long string or a large font.
- Fixed heights are suspect. If a box has one, its contents must be able to
  scroll.
- Any scrollable inside the shell pads its bottom by
  `AppSpacing.bottomNavClearance`, because the navigation floats over content.

---

## Accessibility

### Tap targets

48dp minimum everywhere, and the *visual* size may be smaller than the
*tappable* one. `AppFilterPill` is a 36dp pill inside a 48dp target — the design
gets the size it asked for, the user gets a target they can hit. Use the same
trick anywhere the reference wants something under 48dp.

### Screen readers

- Every navigation destination carries a `Semantics` label, and the tests tap
  **by semantics label** rather than by icon — so a destination that loses its
  label fails the test, not just an audit.
- Icon-only controls carry a label or a tooltip.
- Decorative visuals are wrapped in `ExcludeSemantics`: state-message icons,
  placeholder-screen icons, and every `AppSkeleton`. A screen reader announcing a
  row of empty placeholder boxes is worse than silence.
- The navigation pill uses `excludeSemantics` on its own subtree, because the
  label is both a semantics label and visible text — without it, each destination
  is announced twice.

### Reduced motion

Android's "Remove animations" setting is honoured via
`MediaQuery.disableAnimationsOf`:

- Route transitions return their child directly — no slide, no fade.
- The navigation pill snaps to its new shape instead of growing into it.

Motion sensitivity is a real condition, and an app that animates anyway is one
the setting does not work on.

One implementation note: with motion reduced, `AnimatedSize` is **dropped**
rather than given a zero duration. A zero-duration `RenderAnimatedSize`
re-dirties itself during layout and asserts.

### Colour and contrast

Covered in [`docs/design_system.md`](design_system.md). In short: every text
colour clears 4.5:1, status is always spelled out in words as well as coloured,
and the one place the reference was corrected was its muted greys.

---

## Still to come

Phase 2 is complete.

Two things here deserve another look when the real screens arrive: the 1.6 text
scale ceiling, and whether dense rows should reflow into a column at large scales
rather than relying on the clamp.

### A caution learned the hard way

`AppContentWidth` shipped in this sprint with a bug that its own tests missed. It
was wrapped around `Scaffold.bottomNavigationBar`, and because that slot is
measured with **loose** constraints, the height-filling `Align` inside expanded to
the whole screen and pinned the bar to the top of it. The navigation rendered at
the top of the display, and an invisible full-screen box swallowed every tap.

The width assertions passed the entire time, because the width was never wrong.
Sprint 10 found it, `AppContentWidth.hugHeight` fixes it, and there is now a test
asserting the bar sits at the bottom and is under 120dp tall.

The lesson: a layout test that checks size but never position is half a test.
