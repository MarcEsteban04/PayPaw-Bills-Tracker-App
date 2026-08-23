# PayPaw — Component Kit

Sprint 8 deliverable. The shared widgets in
[`lib/core/presentation/widgets/`](../lib/core/presentation/widgets/), and the
rules for choosing between them.

Open **Profile > Developer > Components** in the running app to see every one of
them live. The demos are interactive on purpose — a button's busy state and a
dialog's return value can only really be judged by tapping them.

Everything here is built on [`docs/design_system.md`](design_system.md). No
component hard-codes a colour, size, radius or shadow.

---

## What is here, and what is not

The theme already styles `FilledButton`, `TextField`, `Card`, `Chip` and the
rest. A component earns its place in this kit **only if it adds something the
theme cannot**. Where a plain Material widget already looks right, use it — a
wrapper that only forwards arguments is a second way to spell the same thing, and
one of the two will eventually drift.

| Component | What it adds over the themed widget |
| --- | --- |
| `AppPrimaryButton` | The orange glow, and a busy state that blocks repeat taps |
| `AppSecondaryButton` | Matching geometry, so it sits beside the primary without shifting |
| `AppDangerButton` | Red fill for irreversible actions |
| `AppCard` | The soft shadow, and a correctly-clipped tap ripple |
| `AppTextField` | A static label above the field instead of a floating one |
| `AppSearchField` | The reference's magnifier plus filter arrangement |
| `AppAmountField` | Currency keyboard, input filter, peso prefix, tabular figures |
| `AppDropdownField<T>` | Generic over the value, styled to match the text field |
| `AppMetaChip` | The reference's grey fact pill, without Material `Chip`'s baggage |
| `AppStatusChip` | Accessible tint-and-text colour pairs per status |
| `AppFilterPill` | 36dp visual pill inside a 48dp tap target, with applied state |
| `showAppDialog` / `showAppConfirmDialog` | Consistent actions, and a safe return value |
| `showAppBottomSheet` | Keyboard inset, safe area, and scroll-controlled sizing |
| `AppEmptyState` | The shared message layout, framed as an invitation |
| `AppErrorState` | Derives its message from the exception, not the screen |
| `AppLoadingIndicator` | Centred spinner with an optional line |
| `AppSkeleton` | Pulsing placeholder blocks to compose into a row's shape |

---

## Rules worth knowing

### Status chips carry meaning; meta chips carry facts

`AppMetaChip` is grey and says *what something is* — `Monthly`, `Electricity`,
`GCash`. `AppStatusChip` is coloured and says *what state something is in* —
`Paid`, `Overdue`, `Due in 3 days`.

Keep them separate. If everything on a card is a coloured chip, nothing stands
out, and the one chip that actually matters gets lost.

Each `AppStatusTone` carries a **matched pair**: a pale background and a darkened
text colour that clears 4.5:1 on it. Never mix one tone's background with
another's foreground — the status colours are tuned to be legible as fills, and
as small text on a pale tint they land near 2:1.

And the label always spells the state out. Colour is never the only signal, so
the chip still works for a colour-blind user, or in a screenshot printed in grey.

### Spinner, skeleton, or busy button

Three different waits, three different answers:

- **First load, nothing to show yet** → `AppLoadingIndicator`.
- **First load, but the shape is known** → `AppSkeleton`, composed into the
  eventual layout. The screen then does not jump when the data lands, which a
  spinner cannot avoid.
- **Saving or submitting** → `AppPrimaryButton(isBusy: true)`. Never a page
  spinner: the rest of the screen should stay in place and readable, and the busy
  button is what stops a slow save being submitted twice.

`AppSkeleton` pulses opacity rather than sweeping a shimmer gradient. A gradient
sweep needs a repainting shader per element, and across twenty rows that is real
cost for an effect visible for half a second.

### Error messages come from the exception

`AppErrorState` takes the raw error object, not a string, and reads
`AppException.userMessage` off it. A screen does not get to invent its own
wording, and an error that is **not** an `AppException` falls back to a generic
line — so a `toString()` full of internals can never reach the UI.

Its `debugMessage` stays in the logs. Both behaviours are covered by tests, since
this is the boundary where a leak would be invisible until it embarrassed someone.

Give it an `onRetry` wherever there is anything to retry. A dead end with no way
out is worse than a button that occasionally fails again.

### A dismissal is not consent

`showAppConfirmDialog` resolves to `true` **only** on an explicit confirm.
Tapping the barrier, or backing out, resolves to `false`. This is tested,
including the dismissal case, because getting it backwards would delete data the
user never agreed to delete.

Set `isDestructive: true` for anything irreversible; the confirm button turns
red and cancel becomes the visually calmer choice.

### Tap targets can be bigger than they look

`AppFilterPill` is 36dp tall to match the reference, which is under Material's
48dp minimum. Rather than make it visually taller than the design, its *tappable*
area is padded out to 48dp around the visible pill. In a horizontal row that
costs nothing.

Use the same trick anywhere the design asks for a control smaller than 48dp.
Shipping an under-sized tap target is not a fidelity win.

### Labels sit above fields

`AppTextField` puts its label above the field rather than using Material's
floating label. The reference has no form fields to copy, so this is a judgement
call: a static label is easier to scan down a column of inputs than one that
animates and shrinks, and it leaves the field's interior free for a hint.

### Empty and error states share one layout

Both are built on `AppStateMessage`, because an empty list and a failed load are
the same shape of message — *nothing to show, and here is what you can do about
it.* Building them separately would let them drift apart visually for no reason.

Write empty-state copy for the *specific* emptiness. "No bills yet" with "Add
your first bill and PayPaw will remind you before it falls due" tells the user
what to do. "No data" does not.

---

## Adding a component

1. Check the theme first. If `AppTheme` can carry the styling, style it there and
   use the plain Material widget.
2. If it genuinely needs to exist, put it in `lib/core/presentation/widgets/`,
   one public widget per file, named `app_*.dart`.
3. Take tokens from the theme. No literal colours, sizes, radii or shadows.
4. Add it to the components gallery so it can be seen on a device.
5. Test it if it has logic — an input filter, a return value, a state that blocks
   input. Pure layout does not need a test.
6. Add a row to the table above.
