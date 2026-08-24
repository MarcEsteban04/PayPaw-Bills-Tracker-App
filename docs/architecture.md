# PayPaw — Architecture

Sprint 3 deliverable. This is the contract for where code goes and what may
depend on what. If a change requires breaking a rule here, change this document
in the same commit rather than making a quiet exception.

---

## Folder structure

PayPaw is organised **feature-first**. Each feature owns its three layers, so a
sprint that adds a feature touches one folder rather than scattering edits
across the tree.

```
lib/
  main.dart                     startup: async init, then runApp
  app/                          the frame every feature renders inside
    paypaw_app.dart             root widget — router, theme, canvas gradient
    router/
      app_routes.dart           every path and route name, in one enum
      app_router.dart           the go_router graph, as a provider
      app_page_transitions.dart the two route transitions, and when to use each
    shell/
      app_destination.dart      the four primary destinations
      app_shell.dart            scaffold hosting the tabs and the nav bar
      paypaw_bottom_nav.dart    the floating pill navigation
  core/                         cross-feature code only
    config/    app_config.dart  compile-time config from --dart-define
    error/     app_exception.dart   the one error hierarchy
    data/      supabase_error_mapper.dart   Supabase errors -> AppException
    providers/                  shared providers (Supabase client, storage)
    presentation/widgets/       widgets more than one feature uses
    theme/                      design tokens and both themes
                                see docs/design_system.md
  features/
    <feature>/
      data/
        datasources/            talks to Supabase or the device
        dtos/                   wire models, JSON in and out
        repositories/           repository implementations
      domain/
        entities/               what the app reasons about
        repositories/           abstract repository contracts
      presentation/
        controllers/            Riverpod notifiers — screen state
        screens/                one file per screen
        widgets/                widgets used by this feature only
test/                           mirrors lib/
```

`core/` is for code at least two features need. A helper used by one feature
lives in that feature. "It might be shared later" is not a reason to put it in
`core/` now.

---

## Layers

### Domain — what PayPaw means

Entities and repository contracts. **Pure Dart:** no `package:flutter`, no
`package:supabase_flutter`, no JSON. An entity models a bill as the app thinks
about one, not as Postgres stores one.

Repository contracts are declared here as abstract classes, and implemented in
`data/`. This inversion is the point: `domain/` never learns that Supabase
exists, so replacing the backend touches `data/` only.

### Data — how PayPaw talks to the outside

Data sources call Supabase or the device. DTOs handle JSON and convert to and
from entities. Repository implementations coordinate the two and translate every
error through `mapSupabaseError`.

Nothing outside `data/` may import `supabase_flutter`, catch a
`PostgrestException`, or see a DTO. A DTO crossing into `presentation/` is a bug.

### Presentation — what the user sees

Screens, feature widgets, and Riverpod controllers. Controllers hold screen
state and call repositories through their domain contracts; they never touch a
data source directly.

Widgets stay dumb: they render what they are given and report what the user did.
A widget that formats currency, decides whether a bill is overdue, or filters a
list is doing a controller's job.

### Services

Wrappers around a platform or plugin API that is not a data source —
notification scheduling, biometric prompts, file pickers. They live in
`core/services/` when shared, or in the owning feature otherwise, and are exposed
as providers so tests can replace them.

---

## Navigation

Four primary destinations — Dashboard, Bills, Calendar, Profile — as branches of
one `StatefulShellRoute.indexedStack`.

```
StatefulShellRoute.indexedStack     each branch keeps its own stack
  /            dashboard
  /bills       bills
  /calendar    calendar
  /profile     profile
/sign-in                            above the shell, covers the nav bar
/sign-up                            above the shell, covers the nav bar
/design-system                      developer gallery
/components                         developer gallery
```

Four because the reference navigation has four. PayPaw has more feature areas
than that, so the rule is: **a tab is for something opened daily.** Subscriptions
and debts live under Bills; analytics and streaks under Dashboard; settings under
Profile.

Where a route goes:

- **Inside a branch** — anything that should keep the bottom navigation visible.
  A bill detail belongs in the Bills branch, below its root.
- **Above the shell** — anything that should cover the navigation entirely: a
  full-screen form, the auth flow, the design system gallery.

Branches, not four top-level routes, because each branch keeps its own
navigation stack. Open a bill detail in Bills, switch to Calendar and back, and
the detail is still there.

Two transition rules, in `app_page_transitions.dart`: switching tabs does not
animate, because the destinations are siblings and sliding between peers implies
a direction that does not exist; pushing a detail slides in from the right,
because that is a move deeper and the motion is what says a back gesture undoes
it.

The navigation bar **floats over** content, so every scrollable screen inside the
shell must pad its bottom by `AppSpacing.bottomNavClearance`.

---

## Dependency injection

Riverpod, exclusively. There is no service locator and no singleton registry.

- **Constructing a dependency** — a `Provider`.
- **Screen state** — a notifier, exposed as a provider.
- **Async initialisation** — resolved in `main()` and injected with
  `overrideWithValue`, as `sharedPreferencesProvider` shows. A synchronous
  `Provider` that throws when read without its override fails loudly and
  immediately, which beats an `AsyncValue` every caller has to unwrap.
- **Tests** — override the provider. No mocking framework needed for wiring.

Feature controllers use `@riverpod` code generation (`riverpod_generator`); the
few core providers are written by hand because at this size the generated
indirection costs more clarity than the boilerplate it removes.

---

## Error handling

One hierarchy: `AppException` in `core/error/`. The data layer converts
everything — `SocketException`, `PostgrestException`, `AuthException` — into an
`AppException` before returning, via `mapSupabaseError`. Above that boundary
nothing knows which backend failed.

Each exception carries a `userMessage` safe to display and an optional
`debugMessage` for logs only.

Errors reach the UI through Riverpod's `AsyncValue`, which already models
loading, data, and error states. There is deliberately **no** `Result<T>` type
and no parallel `Failure` hierarchy: a second error channel alongside
`AsyncValue` is duplication that has to be kept in sync forever.

---

## Decisions and their reasons

| Decision | Reason |
| --- | --- |
| No use-case / interactor layer | The roadmap's Sprint 3 lists presentation, domain, data, services, models and repositories — not use cases. For an app this size they would mostly be one-line pass-throughs to a repository. |
| No `Result<T>` wrapper | `AsyncValue` is already the error channel. See above. |
| Generated code is committed | A fresh clone builds without running `build_runner` first. Generated files are excluded from analysis instead. |
| Relative imports inside `lib/` | Enforced by `prefer_relative_imports`. Mixing `package:paypaw/...` and relative paths for the same file makes imports unreadable. |
| Config via `--dart-define` | Keeps credentials out of the repository with no extra dependency and no `.env` file to leak. |
| `flutter analyze` must be clean | An objective gate. "Readable" is a judgement call; zero warnings is not. |
| A data source class only when it earns its place | The layers above are a default, not a ritual. `SupabaseAuthRepository` wraps one typed SDK call, so a data source would be a pass-through whose only job is to be a layer. Add one when there is JSON to map or more than one source to coordinate — the repository is still the only place importing `supabase_flutter`. |
| Domain entities avoid SDK names | The first auth entity was called `AuthUser`, which Supabase also exports, so every data-layer file would have had to hide one or prefix the other. It is `AuthenticatedUser`. |

---

## Adding a feature

1. Create `lib/features/<feature>/{data,domain,presentation}/`.
2. Define entities and the abstract repository in `domain/`.
3. Implement the data source, DTOs, and repository in `data/`; funnel errors
   through `mapSupabaseError`.
4. Expose the repository implementation as a provider.
5. Build controllers, then screens and widgets, in `presentation/`.
6. Register the route in `app_routes.dart` and `app_router.dart`.
7. Mirror the structure under `test/`.
8. `flutter analyze` must be clean, and `flutter test` green.
