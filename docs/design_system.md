# PayPaw — Design System

Every colour, size, weight, radius and shadow the app is allowed to use, and
where each one came from.

The source of truth is the reference design in
[`design/app_ref_design/`](../design/app_ref_design/) and
[`design/bottom_nav_ference/`](../design/bottom_nav_ference/). These tokens are
that design, translated into Dart. **Screens must not hard-code a colour, size,
radius or shadow.** If a value is missing, name it here first.

Run the app and open **Profile > Developer > Design system** to see all of it
rendered. That gallery is the fastest way to judge contrast, weight and shadow
softness on a real device.

| Token group | File |
| --- | --- |
| Colour, gradients, shadows | [`lib/core/theme/app_palette.dart`](../lib/core/theme/app_palette.dart) |
| Typography | [`lib/core/theme/app_typography.dart`](../lib/core/theme/app_typography.dart) |
| Spacing | [`lib/core/theme/app_spacing.dart`](../lib/core/theme/app_spacing.dart) |
| Radius | [`lib/core/theme/app_radii.dart`](../lib/core/theme/app_radii.dart) |
| Assembled themes | [`lib/core/theme/app_theme.dart`](../lib/core/theme/app_theme.dart) |
| Theme preference | [`lib/core/theme/theme_mode_controller.dart`](../lib/core/theme/theme_mode_controller.dart) |

## How a widget reads a colour

```dart
context.colors.surface      // never a constant
context.colors.cardShadow
context.colors.canvas       // the background gradient
```

Colours, gradients and shadows are a **`ThemeExtension`** — `AppPalette` — with
one instance per theme. Material's `ColorScheme` has no slot for the canvas
gradient, a lime navigation pill, a third text grey, or eight status tints, so
everything lives in the palette and `AppTheme` builds the `ColorScheme` *from*
it. One rule: use `context.colors`.

---

## A note on the reference change

This design system was originally derived from a different reference — a warm
peach canvas with an orange accent. That reference was replaced, and the tokens
were re-derived from the current one: **a cool light-grey canvas carrying white
content sheets, with a lime accent.**

The mechanism is why that was an afternoon's work rather than a week's. Nothing
outside `app_palette.dart` names a colour, so replacing the palette replaced the
app's appearance, and the contrast test re-verified every pair automatically.

---

## Accuracy caveat

Every hex value was sampled by eye from a lossy image. They capture the design's
*intent*, not its exact pixels. If you have the original design file, correct
`AppPalette.light` and the whole app follows.

---

## Colour

### Canvas

The reference is a plain light grey with white content sheets sitting on it, so
the canvas is very nearly flat: `canvasStart → canvasMid → canvasEnd` differ only
slightly.

It stays a gradient rather than becoming a single colour because dark mode uses
the same mechanism, and because a flat token would have to become a gradient
again the first time a screen wants one.

### Brand lime, and why there are two of them

| Token | Use |
| --- | --- |
| `primary` `#D9F94A` | Button and indicator **fills** |
| `primaryPressed` `#C2E035` | Pressed state |
| `primaryText` `#4A5A00` | Lime as **text or an icon on a surface** |
| `primarySoft` `#F6FCDC` | Tinted wash — icons, and the reference's referral cards |

The brand was green until the lime took over. The bottom navigation had used
lime as its active pill from the start, and running two accents meant every new
control needed a ruling on which one it was. There is one now.

**`textOnPrimary` is near-black, not white.** White on lime is about **1.4:1** —
illegible at any size. This is the pairing the navigation pill has always used,
and it is why that pill reads cleanly. A lime button with white text would not.

**The gap between `primary` and `primaryText` is much wider than it was.** Under
the green brand, `primaryText` was a slightly deeper green. Lime as a foreground
on white sits near 1.4:1, so the light-mode text token is a dark **olive** — the
same hue taken far enough down to clear 4.5:1. They no longer read as the same
colour in place, and that is the cost of a brand colour this bright.

In dark mode `primaryText` *is* the lime: on a near-black surface it clears 4.5:1
comfortably, and darkening it would only make it harder to read.

### Bottom navigation: no longer a second accent

The nav reference is a dark floating pill with a lime active pill. That lime is
now the brand colour, so `navActivePill` and `primary` are the same value and the
"two accents with defined jobs" rule is gone with them.

The bar is `navSurface` `#0A0B0D`: **very dark**, close to black.
Unselected destinations are **bare icons**. They sat in recessed `navItemSunken`
circles, from the reference bar — four circles plus a pill made five shapes on a
strip whose whole job is to say which one you are on, and once the bar went
near-black in both themes they were the loudest thing on it. The token remains
for the bills summary card's inner chips.

The bar takes a `surfaceBorder` hairline in dark mode for the same reason cards
do: near-black on black has no edge, and lifting the fill to give it one is what
made it a grey slab in the first place.

The bar also **hugs its content and centres itself** rather than stretching edge
to edge. Spread across the full width, four destinations sat too far apart; the
reference bar is a compact pill.

Because it floats *over* the page, the shell paints a **bottom fade** beneath it:
content dissolves into the canvas just above the bar rather than running under it
and being cut off by the screen edge. That was always faintly odd and became a
visible band once cards gained an outline — the card's left and right edges poked
out either side of the pill and read as a second bar. The fade's height is
computed from `PayPawBottomNav.barHeight` and the device's gesture inset, not
guessed, so it reaches full opacity exactly at the bar's top edge.

It carries destinations only. An add button floated beside it until Sprint 40's
follow-up, so that recording a bill worked from every tab; it moved to the Bills
screen's own header, above the list it adds to. The dashboard's "Add bill"
shortcut is the other way in.

Lime is legible as a **background** carrying near-black content (about 16:1).
Never use it as a foreground on a light surface, where it sits near 1.1:1 — that
is what `primaryText` is for.

### Bill status

`paid` is the one place green survives, and that is the whole point of keeping
it: green no longer means "press me", so it can mean *settled* and nothing else.
Under the old palette `paid` and `primary` were the same green and a settled chip
and a button were the same colour.

`dueSoon` moved from amber `#F59E0B` to orange (`#EA7317` light, `#FB8B24` dark).
Beside a lime brand the old amber read as a dimmer version of the same thing, and
a status has to be distinguishable from a button at a glance.

`paid` · `dueSoon` · `overdue` · `info`

### Text greys — the one place the design is corrected

The reference's muted greys sit below WCAG AA. These are darkened to pass while
still reading as de-emphasised:

| Token | Contrast on white | Use |
| --- | --- | --- |
| `textPrimary` `#14161A` | ~17:1 | Headings, amounts |
| `textSecondary` `#5C6167` | ~6:1 | Supporting copy |
| `textTertiary` `#666A72` | ~5:1 | Timestamps, chips, captions |

`textTertiary` is as light as any text in PayPaw gets, and it is checked against
`surfaceMuted` as well as white — a grey that passes on white can fail on a grey
chip.

---

## Typography

**Inter**, via `google_fonts`. Sizes map onto Material's `TextTheme` slots so
stock widgets pick the right style without being told.

| Slot | Size / weight | Role |
| --- | --- | --- |
| `displaySmall` | 28 / 700 | The balance figure |
| `headlineMedium` | 24 / 700 | Screen title |
| `headlineSmall` | 20 / 700 | Card value |
| `titleLarge` | 18 / 700 | Figure inside a card |
| `titleMedium` | 16 / 600 | Card title, section heading |
| `titleSmall` | 14 / 600 | Tab label |
| `bodyLarge` | 15 / 400 | Lead copy |
| `bodyMedium` | 14 / 400 | Default copy |
| `bodySmall` | 12 / 400 | Caption, section label |
| `labelLarge` | 15 / 600 | Button label |
| `labelMedium` | 12 / 500 | Chip label |
| `labelSmall` | 11 / 600 | Nav label |

The styles carry **no colour**; it is applied once in `textTheme(palette)`. A
style with a baked-in colour would be invisible in one of the two themes.

### `AppTypography.amount`

Use this for money, always. It is `titleLarge` plus
`FontFeature.tabularFigures`, so digits occupy equal width and a column of
amounts lines up instead of shifting row to row. The reference is full of stacked
figures; without this they visibly jitter.

### Before release

`google_fonts` fetches Inter over the network on first launch and caches it —
a brief fallback-font flash, and no Inter for a user offline on first run. Bundle
the `.ttf` files under `assets/fonts/` in the release sprints; `google_fonts`
prefers bundled files automatically, with no code change.

---

## Spacing

A 4-point scale: `xxs 2` · `xs 4` · `sm 8` · `md 12` · `lg 16` · `xl 20` ·
`xxl 24` · `xxxl 32` · `huge 40`.

Prefer the semantic aliases where one applies — `screenInset`, `cardInset`,
`cardGap`, `sectionGap`, `bottomNavClearance`. `bottomNavClearance` is not
optional: a scroll view without it ends underneath the floating navigation.

---

## Radius

`xs 8` chips · `sm 12` inputs · `md 20` list cards · `lg 24` panels ·
`xl 28` sheets and dialogs · `pill` buttons and the nav bar.

Rounder than the previous design at every size above `sm` — the reference's cards
and sheets are noticeably softer.

Ready-made `BorderRadius` constants exist per role (`AppRadii.chip`, `.input`,
`.card`, `.panel`, `.sheet`, `.round`) so no widget writes
`BorderRadius.circular(20)` by hand.

---

## Shadows

Wide, very soft and almost colourless — cards read as lifted off the canvas
rather than outlined. Material's default `elevation` shadows are tighter and
darker, so **component elevation is zero everywhere** and PayPaw paints these:

| Token | Use |
| --- | --- |
| `subtleShadow` | Chips, inline controls |
| `cardShadow` | The default card |
| `floatingShadow` | Bottom navigation, sheets, menus |
| `primaryGlow` | The soft lime glow under the primary CTA |

`primaryGlow` is tinted lime rather than black on purpose. It is what stops the
CTA looking pasted onto the page.

---

## Dark mode

The reference is light-only, so the dark palette is derived from it:

- **The navigation bar is the same near-black in both themes.** It used to
  invert: against the old charcoal canvas a darker bar would have sunk into the
  page, so dark mode lifted it to #22252A. On a true black canvas that stopped
  reading as a floating bar and became a grey slab — the lightest thing on the
  screen after the lime pill. It is #0A0B0D in both now, still a hair above the
  canvas, and its own contents give it shape: the sunken circles are lighter
  again and the active pill is lime. A test still asserts it clears the canvas.
- **Cards get an edge two different ways.** In light mode the shadow lifts them
  off the page. On black a shade of black does nothing, so the card shadows are
  transparent and a hairline does the job instead — `AppPalette.cardBorder` is a
  border in dark mode and null in light, so neither theme pays for the other's
  solution.
- `primary` is the **same lime in both themes**; `primaryText` is that lime in
  dark mode and a dark olive in light, since one has to survive white behind it
  and the other does not.
- **The dark canvas is true black** — all three gradient stops are `#000000`.
  The cards carry the depth instead, and are *lighter* than the ground they sit
  on, which is the reverse of light mode.

### Theme preference

`ThemeMode.system` by default — following the device is the least surprising
behaviour. The choice persists in `SharedPreferences`, and anything unrecognised
in storage falls back to the device setting rather than throwing on launch.

Switch it under **Profile > Appearance**.

### Contrast is tested, not asserted

[`test/core/theme/app_palette_test.dart`](../test/core/theme/app_palette_test.dart)
computes the real WCAG ratio for every text-on-background pair in **both**
palettes and fails below 4.5:1 — 3:1 for icons and for the documented
documented near-black-on-lime pairing.

It has earned its place twice: on its first run it caught three failures that
hand-checking had passed, and when the whole palette was replaced it re-verified
every pair in seconds instead of by eye.

---

## Component styles

Themed centrally in `app_theme.dart`, so a plain widget already looks right and
no call site passes a style:

- **Buttons** — `FilledButton` and `ElevatedButton` share one style: a lime
  pill, 48dp tall, flat. `OutlinedButton` matches its geometry with a hairline
  border. `TextButton` uses `primaryText`.
- **Inputs** — filled, borderless, `surfaceInput` fill, lime 1.5dp border on
  focus only.
- **Cards** — `surface`, `AppRadii.card`, zero elevation, surface tint off.
- **Chips** — `surfaceMuted` fill, `AppRadii.chip`, `labelMedium`, no border.
- **Tabs** — a 2.5dp lime underline under the active label.

`ColorScheme` is built member by member rather than with `ColorScheme.fromSeed`,
because a seed generates its own tonal palette and would override the sampled
colours.

### Tap targets

`AppTheme.minTapTarget` is 48dp and buttons are 48dp. Some controls in the
reference look smaller; the *visual* size can match the design while the tappable
area stays 48dp. Do that rather than shipping a target nobody can hit.

---

## Still to come

The reference's screens — the balance header with its greeting and avatar, wallet
cards, the donut and multi-line charts, the referral cards, the transaction
table — are built in their own sprints (dashboard 34–38, analytics 60–64). What
exists today is the token layer they will be assembled from, plus the component
kit in [`docs/components.md`](components.md).

Two things deserve another look when those screens arrive: the multi-colour chart
palette the reference uses (four distinct series colours, not yet tokenised), and
whether the near-flat canvas gradient earns its three stops.
