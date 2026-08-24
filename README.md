# 🐾 PayPaw

**Track bills, subscriptions, debts, and recurring payments in one place.**

PayPaw is a personal financial-obligations tracker for Android, built with Flutter and
Supabase. It exists to answer three questions at a glance: *what do I owe, when is it due,
and what have I already paid?*

---

## Status

🚧 **Early development — Phases 1 to 3 complete**, covered by 176 tests.

Architecture, app identity, the design system, four-tab navigation, the shared
component kit, responsive layout, dark mode and the full authentication flow are
all in place.

**Once a Supabase project is configured the app requires sign-in** — protected
routes, automatic login from a stored session, sign-out, and session-expiry
handling. Without configuration it runs unguarded, as every earlier sprint did.

Switch themes under Profile > Appearance; browse the token and component
galleries under Profile > Developer.

The Supabase dashboard steps still need doing by hand — see
[`docs/supabase_setup.md`](docs/supabase_setup.md).

Progress is tracked sprint-by-sprint in [`docs/project_dev_roadmap.md`](docs/project_dev_roadmap.md)
(85 sprints, ending at a production APK).

| Sprint | Focus | State |
| -----: | ----- | ----- |
| 1 | Project planning | ✅ Complete |
| 2 | Flutter initialization & app identity | ✅ Complete |
| 3 | Project architecture | ✅ Complete |
| 4 | Development environment | ✅ Complete |
| 5 | Dependencies & infrastructure | ✅ Complete |
| 6 | Design system | ✅ Complete |
| 7 | App navigation | ✅ Complete |
| 8 | Reusable components | ✅ Complete |
| 9 | Responsive layout & accessibility | ✅ Complete |
| 10 | Dark mode | ✅ Complete |
| 11 | Supabase project | ⚙️ App side done — dashboard steps are yours |
| 12 | Registration | ✅ Complete — needs your project to run end to end |
| 13 | Login | ✅ Complete — needs your project to run end to end |
| 14 | Password recovery | ✅ Complete — needs your project to run end to end |
| 15 | Authentication state | ✅ Complete — Phase 3 done |
| 16 | Database planning | ✅ Complete |
| 17 | User tables | ✅ Complete — migrations applied |
| 18 | Bill tables | ✅ Complete — migrations applied |
| 19 | Payment tables | ✅ Complete — migrations applied |
| 20 | Supabase security | ✅ Phase 4 done — run the checks in supabase/checks/ |
| 21 | Bill model | ✅ Complete |
| 11A | Welcome screen | ✅ Complete |
| 11B | Account onboarding | ✅ Complete |

11A and 11B are listed last because that is when they were built — inserting them
as new numbers would renumber seventy sprints and break every commit that
references one.

---

## Planned features

Bills and due-date tracking · recurring bills · subscriptions · debt ("utang") tracking ·
a payment calendar · reminders and notifications · receipt attachments · spending analytics ·
an AI assistant · AI bill scanning (OCR) · shared bills.

Full feature specification: [`docs/app_full_description.md`](docs/app_full_description.md).

How the code is organised, and why: [`docs/architecture.md`](docs/architecture.md).

Colour, type, spacing, radius and shadow tokens: [`docs/design_system.md`](docs/design_system.md).

The shared widget kit, and when to use each part: [`docs/components.md`](docs/components.md).

Screen sizes, font scaling and accessibility: [`docs/responsive.md`](docs/responsive.md).

Connecting the backend, and what to configure by hand: [`docs/supabase_setup.md`](docs/supabase_setup.md).

The database schema, and why it is shaped that way: [`docs/database_schema.md`](docs/database_schema.md).

How one account is kept out of another's data, and how to prove it: [`docs/security.md`](docs/security.md).

---

## Tech stack

| Layer | Choice |
| ----- | ------ |
| Framework | Flutter 3.47 · Dart 3.13 |
| State management | Riverpod |
| Backend | Supabase — Postgres, Auth, Storage, Edge Functions |
| Architecture | Feature-first (`lib/features/<feature>/{data,domain,presentation}`) |
| Target | Android (API 24+) |

---

## App identity

| Property | Value |
| -------- | ----- |
| Display name | PayPaw |
| Dart package | `paypaw` |
| Android application ID | `com.paypaw.app` |
| iOS / macOS bundle ID | `com.paypaw.app` |
| Minimum Android SDK | 24 (Android 7.0) |
| Version | `0.1.0+1` |

`minSdk` is pinned rather than inherited from the Flutter SDK so that a Flutter upgrade
cannot silently move the supported-device floor.

---

## Getting started

**Prerequisites:** Flutter 3.47+ (Dart 3.13+), Android SDK, and an emulator or a physical
device with USB debugging enabled.

```bash
flutter pub get                                     # install dependencies
cp config/dev.example.json config/dev.json          # then fill in your Supabase values
flutter run --dart-define-from-file=config/dev.json # launch in debug mode
```

Plain `flutter run` also works — the app starts without a backend and prints what
is missing. In VS Code, use the **PayPaw (dev)** launch configuration.

Useful during development:

```bash
flutter analyze                   # must be clean before any sprint is considered done
flutter test                      # run the test suite
flutter build apk --release       # release build
```

---

## Repository layout

```
lib/
  app/              root widget and navigation graph
  core/             config, errors, shared providers, theme
  features/         one folder per feature, each with data/domain/presentation
test/                tests, mirroring lib/
docs/                feature spec, development roadmap, architecture contract
design/              UI design references — the visual spec for all screens
android/ ios/ web/   platform projects
linux/ macos/ windows/
```

`design/` holds the reference design that PayPaw's UI is built to match — see
[`design/app_ref_design/`](design/app_ref_design/) for the screen designs and
[`design/bottom_nav_ference/`](design/bottom_nav_ference/) for the bottom navigation.

---

## License

Not yet licensed. All rights reserved.
