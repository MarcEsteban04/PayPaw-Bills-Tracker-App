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
    domain/    money.dart       value objects more than one feature needs
    presentation/app_assets.dart   every bundled asset path, in one place
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
/forgot-password                    above the shell
/reset-password                     above the shell, reached by the deep link
/welcome                            first install only, ahead of auth
/onboarding                         after sign-up, once per account
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

## Authentication state

The session is a **stream**, not a value read at startup: it can end without the
user asking — a refresh token rejected, or revoked from another device — and the
app has to notice. `currentUserProvider` yields the session the SDK already
restored, then every change to it.

Sessions persist on the device because `supabase_flutter` stores them, so
"automatic login" is not code we wrote: it is the stored session arriving before
the first frame, which is also what lets the guard decide immediately instead of
flashing a sign-in screen at someone already signed in.

### First run

Two gates sit in front of the app, answering different questions.

**Welcome** is per *install*. It runs before there is an account to attach it to,
and someone who signs out should not be pitched the app a second time.

**Onboarding** is per *account*, keyed by user id. Two accounts on one phone are
asked separately, so the second does not silently inherit the first one's
currency and time zone.

Both flags live in `SharedPreferences` rather than a column, because this is
navigation state, and a screen that waits on the network to decide whether to
show itself is a screen that flickers. The preferences onboarding *collects* are
stored server-side; only "have we asked yet" is local.

Onboarding is deliberately not a feature tour. A three-slide carousel explaining
that a bills app tracks bills is the most-skipped screen in mobile software, and
skipping it is the correct response — it costs the user time and leaves nothing
behind. These two steps write `profiles.currency`, `profiles.time_zone` and
`reminder_preferences`, so the user finishes with a configured account instead of
a vague sense of what the app does. That is also why it runs *after* sign-up:
every one of those writes is checked against `auth.uid()`.

Skipping still writes the defaults, which are the column defaults. A skipped
account and a completed one that changed nothing end up identical, so no later
feature has to handle a third kind of account.

### The guard

`authRedirect` in [`lib/app/router/auth_guard.dart`](../lib/app/router/auth_guard.dart)
is a pure function, deliberately — a route guard is painful to test through a
widget tree and trivial to test directly. Five rules, and the **order of the last
three is load-bearing**:

1. **No backend, no guarding.** Without Supabase configuration there is no
   session and never will be, so guarding would trap the user on a sign-in screen
   that cannot work. The first-run gates are off in this mode too: the welcome
   screen's only two actions both lead to auth.
2. **Never decide before the answer is known.** While the session is loading it
   returns null.
3. **An error counts as signed out.** A guard that fails open is not a guard. A
   first install still gets its welcome screen.
4. **`/reset-password` beats everything below.** Opening a reset link *creates* a
   session, so by the time that screen appears the user is signed in. Checked
   before the onboarding rule, not after: someone resetting their password on a
   new device arrives signed in with onboarding unfinished, and sending them to a
   setup form instead of the field they came to fill in would strand them — the
   recovery session is the only thing that lets the password be changed.
   Recovery outranks setup.
5. **Then onboarding, then the auth-screen bounce.** An account that has not been
   set up goes to `/onboarding` from wherever it landed; otherwise a signed-in
   user is bounced off the public routes to the dashboard.

Signed out, the order is: welcome if it has never been shown, then public routes
are left alone and everything else goes to `/sign-in`.

The router gets a `refreshListenable` rather than watching the session directly.
Watching it inside the router provider would rebuild the whole `GoRouter` on every
auth change and discard the navigation stack; a listenable lets the router stay
put and re-run its guard.

### Two global listeners

Both wrap the app in `PayPawApp`, because both react to things that can happen on
any screen:

- **Password recovery** — a reset link navigates to the new-password screen.
- **Session expiry** — an unasked-for sign-out shows a message saying so. Only
  for sessions that ended on their own; announcing an explicit sign-out would be
  telling the user what they just did.

Both providers **count** events rather than emitting `void`. `ref.listen` compares
states with `==`, and two `AsyncData<void>` values are equal, so a second event
would never reach a listener.

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
| No code generation, yet | `freezed` and `json_serializable` are in dev_dependencies but unused. Models are hand-written, and DTOs map columns explicitly — a column name has to match a migration exactly, and a mismatch is a runtime failure rather than a compile error, so having the names spelled out where a reviewer can compare the two files is worth the boilerplate. A build step must earn its place the same way a layer does. Revisit at roughly a dozen DTOs. If it is ever adopted, generated files get committed so a fresh clone builds without running `build_runner`. |
| Relative imports inside `lib/` | Enforced by `prefer_relative_imports`. Mixing `package:paypaw/...` and relative paths for the same file makes imports unreadable. |
| Config via `--dart-define` | Keeps credentials out of the repository with no extra dependency and no `.env` file to leak. |
| `flutter analyze` must be clean | An objective gate. "Readable" is a judgement call; zero warnings is not. |
| A data source class only when it earns its place | The layers above are a default, not a ritual. `SupabaseAuthRepository` wraps one typed SDK call, so a data source would be a pass-through whose only job is to be a layer. Add one when there is JSON to map or more than one source to coordinate — the repository is still the only place importing `supabase_flutter`. |
| Reads come from a view, writes go to the table | `bill_status` carries the derived status and payment totals a list row needs, so a list is one round trip instead of two queries and a client-side join. A status is not something a client gets to write, so there is nothing lost. The view is `security_invoker`, which is the only thing standing between a view over `bills` and one that returns everybody's. |
| A separate draft type for creation | `NewBill` has no `id`, no timestamps and no `userId`. Reusing `Bill` for an insert would mean inventing all four, and an invented timestamp is a lie some later code believes. It also makes the two write paths honest: create from a draft, update from a bill that exists. |
| Repositories are tested at the HTTP layer | A repository over PostgREST is almost entirely request-building — which columns, which filters, what order, and what is left out of a body. None of it is reachable by testing pure functions and all of it fails at runtime, so `SupabaseClient` is handed a recording `http.Client` and the assertions are about what the *database* would receive. Mocking the SDK instead would only assert that the code calls the methods the test expects. This found `order()` defaulting to descending. |
| Writes never filter on `user_id` | The RLS policy already restricts every statement to the caller's rows. Adding the filter would state the same constraint twice, in a place that can drift from the policy, and would read as though the query were doing the securing. |
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
