# 🐾 PayPaw

**Track bills, subscriptions, debts, and recurring payments in one place.**

PayPaw is a personal financial-obligations tracker for Android, built with Flutter and
Supabase. It exists to answer three questions at a glance: *what do I owe, when is it due,
and what have I already paid?*

---

## Status

🚧 **Early development — Phase 2 (UI/UX Foundation) in progress.**
Phase 1 is complete: architecture, dependencies and app identity are in place.
The design system, the four-tab navigation and the shared component kit now
exist. The app opens on the dashboard; the token and component galleries are
under Profile > Developer.

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
| 9 | Responsive layout | ⏳ Next |

---

## Planned features

Bills and due-date tracking · recurring bills · subscriptions · debt ("utang") tracking ·
a payment calendar · reminders and notifications · receipt attachments · spending analytics ·
an AI assistant · AI bill scanning (OCR) · shared bills.

Full feature specification: [`docs/app_full_description.md`](docs/app_full_description.md).

How the code is organised, and why: [`docs/architecture.md`](docs/architecture.md).

Colour, type, spacing, radius and shadow tokens: [`docs/design_system.md`](docs/design_system.md).

The shared widget kit, and when to use each part: [`docs/components.md`](docs/components.md).

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
flutter pub get      # install dependencies
flutter devices      # confirm a target is attached
flutter run          # launch in debug mode
```

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
