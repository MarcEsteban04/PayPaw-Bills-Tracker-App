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
content sheets, with a green accent.**

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

### Brand green, and why there are two of them

| Token | Use |
| --- | --- |
| `primary` `#16A34A` | Button and indicator **fills** |
| `primaryPressed` `#12833B` | Pressed state |
| `primaryText` `#0F7A38` | Green as **text or an icon on a surface** |
| `primarySoft` `#E8F8EE` | Tinted wash — icons, and the reference's referral cards |

White text on `primary` reaches about **3.3:1**, which satisfies WCAG AA for
large text. That is why button labels are semibold at 15pt and no smaller.

The reference's green is brighter than `#16A34A`. It was darkened to reach even
the large-text threshold — a brighter green put white-on-green near 2.2:1, which
fails everything. This is the one place the design was adjusted for legibility
rather than reproduced exactly, and it stays clearly the same green.

Green *as small text* on a light surface fails at `primary`, so `primaryText` is
the darker sibling that clears 4.5:1. They read as the same colour in place.

### Bottom navigation: the second accent

The nav reference is its own palette — a dark floating pill with a **lime** active
pill. Both accents are kept, with defined jobs:

- `primary` — CTAs and content accents
- `navActivePill` `#D9F94A` — the bottom navigation's active state only

The bar is `navSurface` `#0A0B0D`: **very dark**, close to black.
`navItemSunken` `#1C1F24` is *lighter* than the bar, because on a near-black
surface a darker recess would be invisible.

The bar also **hugs its content and centres itself** rather than stretching edge
to edge. Spread across the full width, four destinations sat too far apart; the
reference bar is a compact pill.

Lime is legible here specifically because it is a **background** carrying
near-black content (about 16:1). Never use it as a foreground on a light surface,
where it sits near 1.1:1.

> Worth knowing: lime and the brand green are now neighbours on the colour wheel
> in a way they were not when the brand was orange. It still reads as a distinct
> accent because it only ever appears on the near-black bar, never beside a green
> button. If the two ever do end up adjacent, that is the moment to revisit it.

### Bill status

The reference shows positive figures in green and negative in red, and PayPaw
follows it. Note that `paid` and `primary` are now the same green — the reference
makes that choice too, and status is always spelled out in words as well.

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
| `primaryGlow` | The soft green glow under the primary CTA |

`primaryGlow` is tinted green rather than black on purpose. It is what stops the
CTA looking pasted onto the page.

---

## Dark mode

The reference is light-only, so the dark palette is derived from it:

- **A near-neutral charcoal canvas**, matching the reference's cool grey rather
  than warming it.
- **The navigation bar inverts.** In light mode a near-black bar floats above a
  light page; in dark mode a darker bar would sink into it, so the bar becomes
  *lighter* than the canvas. A test asserts that relationship in both themes.
- **Shadows get much stronger.** A 5%-black shadow is invisible on charcoal.
- `primary` is the **same green in both themes**; `primaryText` lightens to
  `#4ADE80`, since in dark mode it sits on a dark surface.

### Theme preference

`ThemeMode.system` by default — following the device is the least surprising
behaviour. The choice persists in `SharedPreferences`, and anything unrecognised
in storage falls back to the device setting rather than throwing on launch.

Switch it under **Profile > Appearance**.

### Contrast is tested, not asserted

[`test/core/theme/app_palette_test.dart`](../test/core/theme/app_palette_test.dart)
computes the real WCAG ratio for every text-on-background pair in **both**
palettes and fails below 4.5:1 — 3:1 for icons and for the documented
white-on-green exception.

It has earned its place twice: on its first run it caught three failures that
hand-checking had passed, and when the whole palette was replaced it re-verified
every pair in seconds instead of by eye.

---

## Component styles

Themed centrally in `app_theme.dart`, so a plain widget already looks right and
no call site passes a style:

- **Buttons** — `FilledButton` and `ElevatedButton` share one style: a green
  pill, 48dp tall, flat. `OutlinedButton` matches its geometry with a hairline
  border. `TextButton` uses `primaryText`.
- **Inputs** — filled, borderless, `surfaceInput` fill, green 1.5dp border on
  focus only.
- **Cards** — white, `AppRadii.card`, zero elevation, surface tint off.
- **Chips** — `surfaceMuted` fill, `AppRadii.chip`, `labelMedium`, no border.
- **Tabs** — a 2.5dp green underline under the active label.

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
