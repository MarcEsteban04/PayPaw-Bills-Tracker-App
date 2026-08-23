# PayPaw — Design System

Sprint 6 deliverable. Every colour, size, weight, radius and shadow the app is
allowed to use, and where each one came from.

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
| Colour | [`lib/core/theme/app_colors.dart`](../lib/core/theme/app_colors.dart) |
| Typography | [`lib/core/theme/app_typography.dart`](../lib/core/theme/app_typography.dart) |
| Spacing | [`lib/core/theme/app_spacing.dart`](../lib/core/theme/app_spacing.dart) |
| Radius | [`lib/core/theme/app_radii.dart`](../lib/core/theme/app_radii.dart) |
| Shadows | [`lib/core/theme/app_shadows.dart`](../lib/core/theme/app_shadows.dart) |
| Gradients | [`lib/core/theme/app_gradients.dart`](../lib/core/theme/app_gradients.dart) |
| Assembled theme | [`lib/core/theme/app_theme.dart`](../lib/core/theme/app_theme.dart) |

---

## Accuracy caveat

Every hex value was sampled by eye from a lossy `.webp` and a small `.png`. They
capture the design's *intent*, not its exact pixels. If you have the original
design file, correct `app_colors.dart` and the whole app follows — that is the
point of having one file.

---

## Colour

### Canvas

The reference background is not a flat fill. It is a warm peach fading
diagonally to near-white, and reproducing that gradient is most of what makes a
screen read as "the reference".

`AppGradients.canvas` — `canvasPeach → canvasCream → canvasWhite`, top-left to
bottom-right.

### Brand orange, and why there are two of them

| Token | Use |
| --- | --- |
| `primary` `#F26B21` | Button and indicator **fills** |
| `primaryPressed` `#D95A14` | Pressed state, gradient end |
| `primaryText` `#C2410C` | Orange as **text or icon on a light surface** |
| `primarySoft` `#FFF1E8` | Tinted wash behind icons |

White text on `primary` reaches about **3:1**. That satisfies WCAG AA for large
text only, which is why button labels are semibold at 15pt and no smaller. The
brand orange itself was **not** adjusted — it is the brand, and changing it would
change the design.

But orange *as small text* on white — the reference's active tab label — fails
clearly. Rather than degrade either the design or the accessibility, there are
two tokens: the reference orange for fills, and a darker sibling that clears
4.5:1 for text. They read as the same orange in place.

### Bottom navigation: the second accent

The nav reference is a different palette from the main reference — a dark
floating pill with a **lime** active pill, against the main design's orange. Both
are kept, with defined jobs:

- `primary` — CTAs and content accents
- `navActivePill` `#D9F94A` — the bottom navigation's active state only
- `navSurface` `#17181A` — the floating bar, with `navItemSunken` `#0E0F10` for
  the recessed inactive icon buttons

Lime is legible here specifically because it is a **background** carrying
near-black content (about 15:1). It must never be used as a foreground colour on
a light surface, where it sits near 1.1:1 and is effectively invisible.

### Bill status

Green and amber are lifted from the reference's own progress gauge and rating
star, so status colours stay inside the design's palette instead of importing a
generic traffic-light set.

`paid` · `dueSoon` · `overdue` · `info`

### Text greys — the one place the design was corrected

The reference's muted meta text sits below WCAG AA on white. These are darkened
to pass while still reading as de-emphasised:

| Token | Contrast on white | Use |
| --- | --- | --- |
| `textPrimary` `#1A1A1C` | ~16:1 | Headings, amounts |
| `textSecondary` `#5F5F66` | ~7:1 | Supporting copy |
| `textTertiary` `#757580` | ~4.6:1 | Timestamps, chips, captions |

`textTertiary` is as light as any text in PayPaw gets. Anything lighter is not a
style choice, it is unreadable text.

---

## Typography

**Inter**, via `google_fonts`. The reference uses a geometric-humanist sans with
tight tracking on large text, and Inter is the closest freely available match.

Sizes map onto Material's `TextTheme` slots so stock widgets pick the right style
without being told:

| Slot | Size / weight | Role in the reference |
| --- | --- | --- |
| `displaySmall` | 28 / 700 | Hero amount |
| `headlineMedium` | 24 / 700 | Screen title |
| `headlineSmall` | 20 / 700 | Card value |
| `titleLarge` | 18 / 700 | Figure inside a card |
| `titleMedium` | 16 / 600 | Card title, section heading |
| `titleSmall` | 14 / 600 | Tab label |
| `bodyLarge` | 15 / 400 | Lead copy |
| `bodyMedium` | 14 / 400 | Default copy |
| `bodySmall` | 12 / 400 | Caption, "2h ago" |
| `labelLarge` | 15 / 600 | Button label |
| `labelMedium` | 12 / 500 | Chip label |
| `labelSmall` | 11 / 600 | Nav label |

### `AppTypography.amount`

Use this for money, always. It is `titleLarge` plus `FontFeature.tabularFigures`,
so digits occupy equal width and a column of amounts lines up instead of
shifting from row to row. A bills app that fails this looks broken in a way users
notice without being able to name.

### Before release

`google_fonts` fetches Inter over the network on first launch and caches it. That
means a brief fallback-font flash, and no Inter at all for a user who is offline
on first run. Bundle the Inter `.ttf` files under `assets/fonts/` in the release
sprints — `google_fonts` prefers bundled files automatically, with no code change.

---

## Spacing

A 4-point scale, because every gap measured in the reference lands on a multiple
of 4.

`xxs 2` · `xs 4` · `sm 8` · `md 12` · `lg 16` · `xl 20` · `xxl 24` · `xxxl 32` ·
`huge 40`

Prefer the semantic aliases where one applies — `screenInset`, `cardInset`,
`cardGap`, `sectionGap`, `bottomNavClearance` — because they say *why* a gap is
that size. `bottomNavClearance` in particular is not optional: a scroll view
without it ends underneath the floating navigation bar.

---

## Radius

`xs 8` chips · `sm 12` inputs · `md 16` list cards · `lg 20` feature cards ·
`xl 24` sheets and dialogs · `pill` primary buttons and the nav bar.

Ready-made `BorderRadius` constants exist for each role (`AppRadii.chip`,
`.input`, `.card`, `.panel`, `.sheet`, `.round`) so no widget writes
`BorderRadius.circular(16)` by hand.

---

## Shadows

The reference's shadows are wide, very soft and almost colourless — cards read as
lifted off the peach canvas rather than outlined. Material's default `elevation`
shadows are tighter and darker than that.

So **component elevation is zero everywhere**, and PayPaw paints these instead:

| Token | Use |
| --- | --- |
| `subtle` | Chips, inline controls |
| `card` | The default list card |
| `floating` | Bottom navigation, sheets, menus |
| `primaryGlow` | The warm orange glow under the primary CTA |

`primaryGlow` is orange rather than black on purpose. It is what stops the CTA
looking pasted onto the page.

---

## Component styles

Themed centrally in `app_theme.dart`, so a plain widget already looks right and
no call site passes a style:

- **Buttons** — `FilledButton` and `ElevatedButton` share one style: an orange
  pill, 52dp tall, flat. There is only one primary button in this design.
  `OutlinedButton` matches its geometry with a hairline border so the two can sit
  side by side without jumping. `TextButton` uses `primaryText`.
- **Inputs** — filled, borderless, `surfaceInput` fill, orange 1.5dp border on
  focus only.
- **Cards** — white, `AppRadii.card`, zero elevation, no margin, surface tint
  off. Material 3's tinting would otherwise push a warm cast over every card.
- **Chips** — `surfaceMuted` fill, `AppRadii.chip`, `labelMedium`, no border, no
  checkmark.
- **Tabs** — a 2.5dp orange underline under the active label. No pill, no
  background, no divider.

`ColorScheme` is built member by member rather than with `ColorScheme.fromSeed`,
because a seed generates its own tonal palette and would quietly override the
sampled reference colours.

### Tap targets

`AppTheme.minTapTarget` is 48dp and buttons are 52dp. Some controls in the
reference look smaller than 48dp; the *visual* size can match the design while
the tappable area stays 48dp. Do that rather than shipping a target nobody can
hit.

---

## Still to come

| Sprint | Work |
| --- | --- |
| 8 | Reusable components — buttons, cards, chips, sheets, empty/loading/error states |
| 9 | Responsive layout, font scaling, overflow |
| 10 | Dark theme, theme switching, persistence |

Dark mode is Sprint 10, so there is one theme today and it is light — matching
the reference, which is light-only. The gallery screen exists partly so that
Sprint 10 can check both themes against each other quickly.
