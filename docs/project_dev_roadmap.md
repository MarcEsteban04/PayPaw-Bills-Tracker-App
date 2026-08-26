    # 🐾 PayPaw — Project Development Roadmap

> **Development plan from project initialization to production APK**

PayPaw is a personal financial obligations tracker built with **Flutter/Dart + Supabase**, designed to help users manage bills, subscriptions, debts, recurring payments, reminders, analytics, and upcoming financial obligations.

This roadmap covers the development process from **Sprint 1 through Sprint 85**, ending with a production-ready Android APK.

---

# 📋 Development Overview

| Stage                  | Sprints | Focus                 |
| ---------------------- | ------: | --------------------- |
| Project Foundation     |     1–5 | Setup & architecture  |
| UI/UX Foundation       |    6–10 | Design system         |
| Authentication         |   11–15 | Accounts & security   |
| First-Run Experience   | 11A–11B | Welcome & onboarding  |
| Database               |   16–20 | Supabase backend      |
| Bill Management        |   21–28 | Core bill features    |
| Recurring Bills        |   29–33 | Automation            |
| Dashboard              |   34–38 | Financial overview    |
| Notifications          |   39–43 | Reminders             |
| Calendar               |   44–47 | Payment scheduling    |
| Subscriptions          |   48–51 | Subscription tracking |
| Debt Management        |   52–56 | Utang/debt tracking   |
| Attachments            |   57–59 | Receipts & files      |
| Analytics              |   60–64 | Financial insights    |
| AI Features            |   65–70 | AI assistant          |
| AI Bill Scanner        |   71–74 | OCR & extraction      |
| Shared Bills           |   75–77 | Collaboration         |
| Security & Privacy     |   78–80 | Protection            |
| Testing & Optimization |   81–83 | QA                    |
| Release                |   84–85 | APK deployment        |

---

# 🏗️ Phase 1 — Project Foundation

## Sprint 1 — Project Planning

* Define PayPaw's core purpose
* Define target users
* Define MVP scope
* Define major features
* Define technical requirements
* Establish development milestones
* Create initial project documentation

## Sprint 2 — Flutter Project Initialization

* Create Flutter project
* Configure Dart
* Configure Android project
* Configure package/application ID
* Configure minimum Android SDK
* Initialize Git repository
* Create initial README

## Sprint 3 — Project Architecture

* Establish folder structure
* Define presentation layer
* Define domain layer
* Define data layer
* Define services
* Define models
* Define repositories
* Establish dependency injection strategy

## Sprint 4 — Development Environment

* Configure Android Studio
* Configure VS Code
* Configure Flutter SDK
* Configure Android SDK
* Configure emulator
* Connect physical Android device
* Configure debugging

## Sprint 5 — Dependencies & Infrastructure

* Add Supabase SDK
* Add routing package
* Add state management
* Add local storage
* Add notification dependencies
* Add image/file picker
* Add charting dependencies
* Configure dependency versions

---

# 🎨 Phase 2 — UI/UX Foundation

## Sprint 6 — Design System

* Define colors
* Define typography
* Define spacing
* Define border radius
* Define shadows
* Define button styles
* Define input styles
* Define card styles

## Sprint 7 — App Navigation

* Design bottom navigation
* Define primary screens
* Define navigation hierarchy
* Configure route management
* Add navigation transitions

## Sprint 8 — Reusable Components

Create reusable components for:

* Buttons
* Cards
* Inputs
* Dropdowns
* Chips
* Dialogs
* Bottom sheets
* Empty states
* Loading states
* Error states

## Sprint 9 — Responsive Layout

* Test different Android screen sizes
* Handle small screens
* Handle large screens
* Handle system font scaling
* Improve accessibility
* Prevent overflow issues

## Sprint 10 — Dark Mode

* Create dark theme
* Create light theme
* Theme switching
* Persist theme preference
* Verify all screens in both themes

---

# 🔐 Phase 3 — Authentication

## Sprint 11 — Supabase Project

* Create Supabase project
* Configure database
* Configure authentication
* Configure storage
* Configure environment variables

## Sprint 11A — Welcome Screen

Added after Sprint 21, once the app was run for the first time and dropped
straight onto the dashboard. Numbered 11A rather than inserted as a new Sprint 12
so the remaining seventy-odd sprint numbers keep meaning what they meant when
this roadmap was written and when the commits referencing them were made.

* Register image assets
* Create welcome screen with illustration background
* Value proposition and tagline
* Primary action to sign up
* Secondary action for returning users
* Show once, on first launch only
* Route above the shell, ahead of authentication

## Sprint 11B — Account Onboarding

Deliberately **not** a feature carousel. A three-slide tour of a bills app is the
most-skipped screen in mobile software, and it delays the user without leaving
anything behind. This onboarding does setup work instead, writing to the columns
the schema already has: `profiles.currency`, `profiles.time_zone` and
`reminder_preferences`.

It runs **after** sign-up rather than before, because every one of those writes
needs a session.

* Detect currency and time zone from the device, and confirm rather than assume
* Choose when reminders arrive
* Persist to `profiles` and `reminder_preferences`
* Skippable, with working defaults if skipped
* Run once per account, not once per install
* Progress indication and back navigation

---

## Sprint 12 — Registration

* Create registration screen
* Email validation
* Password validation
* Account creation
* Error handling

## Sprint 13 — Login

* Create login screen
* Email/password authentication
* Session handling
* Login errors
* Loading states

## Sprint 14 — Password Recovery

* Forgot password
* Reset password
* Password validation
* Recovery session handling

## Sprint 15 — Authentication State

* Persist sessions
* Automatic login
* Logout
* Session expiration
* Protected routes
* Authentication guards

---

# 🗄️ Phase 4 — Database Architecture

## Sprint 16 — Database Planning

Design database structure for:

* Users
* Bills
* Categories
* Payments
* Recurring bills
* Subscriptions
* Debts
* Attachments
* Notifications
* Shared bills

## Sprint 17 — User Tables

* Create profiles table
* Configure user relationships
* Add timestamps
* Add profile preferences

## Sprint 18 — Bill Tables

Create bill-related tables:

* Bills
* Bill categories
* Bill statuses
* Recurrence configuration

## Sprint 19 — Payment Tables

* Payment records
* Partial payments
* Payment methods
* Payment timestamps
* Payment references

## Sprint 20 — Supabase Security

* Configure Row Level Security
* Create policies
* Test user isolation
* Secure database queries
* Verify unauthorized access prevention

---

# 💸 Phase 5 — Bill Management

## Sprint 21 — Bill Model

* Create Dart bill model
* Serialization
* Deserialization
* Validation
* Database mapping

## Sprint 22 — Bill Repository

* Create bill repository
* Fetch bills
* Create bills
* Update bills
* Delete bills

## Sprint 23 — Add Bill UI

Create:

* Bill name
* Provider
* Amount
* Due date
* Category
* Notes

## Sprint 24 — Edit Bill

* Edit bill details
* Update amount
* Update due date
* Change category
* Modify notes

## Sprint 25 — Delete Bill — done

* Delete confirmation — an `AppConfirmDialog` that names what else goes with the
  bill, rather than asking "Are you sure?" The payment history is the part the
  user would actually miss.
* Soft delete strategy — archive sets `archived_at`; the list hides those rows by
  default and the app bar's switch brings them back. Without the switch the
  drawer's Restore could not be reached and the undo snackbar was the only route
  back, for four seconds — a soft delete nobody can undo is a hard delete wearing
  a friendlier word.
* Error handling — `BillActionState.errorMessage` reaches the screen. It had been
  recorded and never read, so a refused delete looked exactly like one that
  worked: dialog closed, sheet closed, row still there, no explanation.
* Undo support where appropriate — on archive, which is one reversible column.
  Deliberately not on delete: an Undo button on an operation that cannot be
  undone is a lie, and the confirmation stands in for it.

## Sprint 26 — Bill Details — done, except attachments

Shown in the detail drawer (`bill_detail_sheet.dart`), not a pushed page: a bill
is six fields and three derived numbers, and a drawer keeps the list behind it so
comparing two bills costs a tap each rather than a push and a pop.

* Amount — the outstanding figure is the headline; the full amount appears in the
  split line only when the bill is part paid.
* Due date — with "In 27 days" beneath it, coloured when late or close.
* Provider — the `payee` column.
* Category
* Status — a chip beside the name, where it identifies the bill.
* Payment history — new in this sprint. The `payments` table and its RLS existed
  from Sprint 19; nothing in Dart had ever read it. Rendered only when the view's
  paid total is above zero, which is exact: `amount_minor > 0` is a check
  constraint, so a zero total means there are no rows to fetch.
* Notes — wrapped as prose rather than truncated beside a label.
* Attachments — **not built.** The table and the storage bucket exist, but nothing
  can put a file in either until Sprint 57 builds the upload. A section that is
  permanently empty is furniture, not a feature.

Found while wiring this up: `payments.bill_id` is `on delete restrict`, so a bill
with payments **cannot be deleted**. The delete dialog had been offering exactly
that and explaining that the payments would go with it. It now refuses and offers
archive. See `bill_repository.dart`, whose doc comment claimed the opposite.

## Sprint 27 — Bill Status — done, minus Cancelled

The status is computed by the `bill_status` view and never by the app, so this
sprint is mostly a migration: `0015_bill_status_due_today.sql`. **It has to be
applied before the new status appears.** Nothing breaks either way — an
unmigrated database never emits `due_today`, and an old build parses it to null
and shows "Unknown".

* Upcoming — already there.
* Due today — **new.** `due_soon` covered a three-day window, so a bill due this
  afternoon and one due on Friday said the same thing. The list already knew:
  every row's subtitle read "Due today" off the date while its badge said
  "DUE SOON" and it sat in the Due soon group. It now has its own status, its own
  heading above Due soon, and its own badge. It shares the due-soon colour — the
  word carries the difference, and a fourth urgency colour between amber and red
  is a distinction the eye cannot reliably make.
* Paid — already there, shown as "Settled".
* Overdue — already there.
* Partially paid — already there, but **moved below the dates in the view's
  precedence.** It used to outrank `due_soon`, so a half-paid bill due tomorrow
  reported `partially_paid`, lost its date entirely, and got filed with the bills
  nobody has to think about this week. Nothing is lost by demoting it: the UI
  reads partial payment off the amounts (`BillWithStatus.isPartiallyPaid`), not
  the status, so the progress bar still works.
* Cancelled — **not built, deliberately.** This is `archived` under a second
  name. Sprint 25 built archiving as the soft delete: it takes a bill off the
  list, excludes it from every total, and is reversible. A separate "cancelled"
  state would need a second column and a second set of rules, and no screen would
  treat it differently from archived — the summary card already skips both, the
  list already groups both. Two words for one state is how a status column starts
  drifting. Reopen this if cancelled should mean something archived does not.

## Sprint 28 — Bill Search & Filters — done

A search field and a row of filter pills above the list, all of it applied on the
client. One person's bills are tens of rows and already in memory, so a
server-side filter would be a round trip per keystroke and a loading state per
change. Revisit alongside pagination if anyone ever has thousands.

* Search — name and payee, case-insensitive, no debounce (there is no request to
  delay). Notes are deliberately not searched: they hold account numbers and
  reminders to self, and matching them surfaces a bill for a reason invisible on
  the row that came back.
* Category filtering — multi-select. A bill with no category is excluded once any
  category is chosen, rather than treated as a wildcard.
* Status filtering — multi-select over all seven statuses. **This absorbed the
  archive switch** Sprint 25 put in the app bar; two controls for one question was
  one too many. An empty selection means "everything except archived", which is
  the one exception to empty-means-all — archiving means "stop showing me this".
* Date filtering — presets (Past due, Next 7, Next 30, This month) plus a custom
  range. Relative to the user's `today` from the view row, never the device clock.
* Amount filtering — a min/max sheet rather than preset brackets. "Over ₱1,000" is
  a guess about somebody else's bills.
* Sorting — due soonest (default), due latest, largest, smallest, name. In the app
  bar, **not** the pill row: as a fifth pill it sat at x=594 on a 392dp screen,
  reachable only by scrolling to something invisible, and reordering a list
  narrows nothing so it never fitted that row's meaning.

The urgency groups only survive the default order. They *are* a due-date sort, so
largest-first inside "Overdue" then "Upcoming" gives the largest overdue bill —
a different question from the one asked. Any other sort flattens the list under
one heading naming the order.

Also fixed here: `AppFilterPill` used `surfaceMuted` (#F1F2F4) on a canvas running
#F3F4F6 to #ECEEF1, so an unapplied pill was invisible by construction — the row
read as four words with carets rather than four controls. It is white with an
outline now, the same contrast every card on these screens uses.

---

# 🔁 Phase 6 — Recurring Bills

## Sprint 29 — Recurrence Model — done

Model, serialization, validation and database mapping, matching Sprint 21's scope
for `Bill`. No repository — nothing reads or writes these rows until Sprint 31.

The `recurring_bills` table has existed since migration 0005 and nothing in Dart
had ever touched it. **No migration was needed**: the six frequencies below map
onto the four the `frequency` check constraint already allows.

* Weekly — `weekly`.
* Bi-weekly — `weekly` with `interval_count` 2. **Not a wire value of its own**,
  because it is an interval, not a frequency. Adding one would be a second way to
  say what the interval already says, and a second branch in every switch that has
  to agree with the others.
* Monthly — `monthly`.
* Quarterly — `quarterly`. Overlaps `monthly` with interval 3, kept because "every
  quarter" is a thing people say and the alternative is a UI offering "Monthly,
  every 3 months".
* Yearly — `yearly`, with a `month_of_year`.
* Custom — any frequency with `interval_count` above 1. The table's own comment
  anticipated this and left room for an `rrule` column if a genuinely arbitrary
  rule is ever needed.

**Occurrences come from the pattern, never from the previous occurrence.** This is
the whole design. A bill due on the 31st gives 31 Jan, 28 Feb, 31 Mar, because each
month asks `day_of_month` afresh and clamps to that month's length. Stepping from
the last occurrence would give 31 Jan, 28 Feb, 28 Mar — and every February would
ratchet the schedule earlier until it stuck on the 28th permanently. Invisible for
a year, then irreversible.

`next_due_on` is a **bookmark, not a derived value**: generation reads it, creates
that one bill, then advances it. Recomputing it from the rule would generate the
same bill twice whenever a run was interrupted. It can therefore disagree with the
rule after an edit, which `RecurringBill.isBookmarkConsistent` reports and Sprint
32 decides what to do about.

Sprint 33 is the dedicated recurrence-testing sprint, but the month-boundary cases
are not something to write this arithmetic without — leap years, century non-leap
years, the last-day sentinel and year rollover are covered here (42 tests).

## Sprint 30 — Recurring Bill UI — done, as a component

* Recurrence selector — `RecurrenceField` (a row, not an input: the value is a
  sentence like "Every 2 weeks on Friday" and no text box holds that) opening
  `showRecurrenceEditor`.
* Custom recurrence settings — **frequency and interval are separate controls.**
  A single list of named presets has to enumerate the product of a unit and a
  count, which is exactly where "custom" comes from as a concept. A unit chip plus
  a stepper covers every combination the model allows, including the ones nobody
  thought to put on the list. Only the fields a frequency uses are shown, matching
  the database's own shape constraint.
* Next occurrence preview — the next three dates, updating as the rule is built.
  This is the point of the control: "every month on the 31st" says nothing about
  February, and without the preview the answer only appears when a bill generates
  months later.

**Not on the bill form yet.** There is no repository for `recurring_bills`, so a
"Repeats" field on Add Bill would take a value and discard it on save — worse than
no field. Sprint 31 adds persistence and generation, and wires it there. Until
then it is live in the Components gallery (Profile → Components), which is where
the project's other interactive components are demoed.

The editor returns a sealed `RecurrenceEditorResult`, not a nullable `Recurrence`:
dismissing the sheet must leave an existing rule alone and tapping "Does not
repeat" must remove it, and one nullable value cannot say both.

## Sprint 31 — Automatic Bill Generation — done

Migration `0016_generate_recurring_bills.sql`. **Apply it, and enable `pg_cron`**
(Supabase → Database → Extensions). Without pg_cron the migration still applies and
generation still works — but only when someone opens the app, which is the thing
this sprint exists to avoid.

* Generate future bills — a Postgres function materialises every occurrence
  falling within a **45-day lead window**, not just overdue ones. A monthly
  template created today has its first occurrence weeks away; a generator that only
  caught up on the past would create nothing and look broken.
* Calculate next due date — `next_recurrence_date` steps whole months from the
  *month* of the current occurrence and re-resolves `day_of_month` against it,
  which is the same rule `Recurrence.occurrenceAfter` follows in Dart. The two are
  duplicated and nothing enforces that they agree; the rule is written out in both
  files.
* Handle recurring status — `is_active` gates the loop, and a bookmark past
  `ends_on` is how a finished template records that it is finished.
* Prevent duplicates — **the unique index, not careful code.** `bills_occurrence_key`
  has existed since migration 0007, so `on conflict do nothing` makes the cron job,
  the client call and any retry all safe to run twice.

**Generation runs in the database, not the app.** The point of a bills tracker is
being reminded before something is due, and a generator that only runs on app open
cannot do that — the user who has not opened PayPaw in three weeks is exactly the
one who needed reminding. It also makes the writer single, so two devices cannot
race.

The client still calls `generate_my_recurring_bills` when the bills list first
loads. Not as the mechanism — as a safety net for an installation whose pg_cron was
never enabled, and so a template saved a moment ago produces its bills now. Cached
for the session, and a failure is swallowed: "no new bills yet" is not "the bills
list is broken".

The Add Bill form now has a **Repeat** field. Saving with one set writes a template
to `recurring_bills` and lets the generator produce the occurrences — writing a
bill as well would be a duplicate the generator then tries to create again. The
form's due date becomes the schedule's *start*, not an occurrence: "due on the 5th,
monthly on the 15th" is two answers to one question.

## Sprint 32 — Recurring Bill Management — partly done, from the bill's edit form

Reached from a bill rather than from a list of schedules: open a repeating bill,
tap Edit, and the Repeat field is the schedule it belongs to. Four outcomes,
decided by what the form had and what it has now:

| had a schedule | wants one | outcome |
|----------------|-----------|---------|
| no  | no  | an ordinary edit |
| no  | yes | **modify** — a schedule is created and this bill joins it |
| yes | yes | **modify** — the rule changes, and resumes if it was stopped |
| yes | no  | **cancel** — the schedule stops |

* Modify recurrence — done. The bookmark moves to the first occurrence after the
  bill being edited, because everything up to and including it already exists.
  Bills generated beyond it under the old rule stay, and the unique index stops
  the generator remaking them.
* Cancel recurrence — done, as `is_active = false` rather than a delete. Deleting
  would null out `recurring_bill_id` on every bill the schedule ever produced —
  `on delete set null` — and the record that those months came from a schedule is
  worth more than the row.
* Resume recurrence — done implicitly: giving a stopped schedule a workable rule
  turns it back on.
* Pause recurrence — **not built as a distinct action.** Pausing and cancelling
  would both be `is_active = false`, so a separate control would be a second word
  for one state. It needs a real difference — a resume date, or a reason — before
  it earns a column.

**Still no screen listing the schedules themselves.** Every one is reachable
through a bill it produced, which covers the case that prompted this, but a
schedule whose bills have all been deleted is unreachable. That screen, and a
`pause` that means something, are what is left of this sprint.

Turning an existing bill into a schedule sets `alreadyCoveredThrough` so the
generator starts *after* it: that bill is the occurrence for its own due date, and
a bookmark on or before it would produce a duplicate. The unique index would catch
it, but only once the bill is linked — and the scheduled job can run in between.

## Sprint 33 — Recurrence Testing — done

Four of the six were already covered by the 42 tests written alongside the
arithmetic in Sprint 29 — writing that code without them would have meant
validating the trickiest dates in the project on faith. This sprint adds what
those did not reach, and closes the risk Sprint 31 created.

* Month boundaries — Sprint 29, plus a **long-run** check here: 60 consecutive
  months of a 31st schedule, asserting the day is always the last possible one in
  that month. The ratchet failure is invisible for a year and permanent after it,
  so a handful of steps does not prove absence.
* Leap years — Sprint 29 (2028), plus the century rule (2100 is not a leap year),
  and a yearly 29 February that **recovers** the 29th in the next leap year. That
  is only possible because the rule is stored rather than the last date used.
* Different month lengths — the last-day sentinel asserted across 60 months.
* Year transitions — weekly, monthly and quarterly each crossing 31 December.
* **Time zones** — new. Every occurrence is local midnight with no time on it; a
  start time is discarded so two templates created the same day at different hours
  are equal; a `DateTime.utc` start is read as the day it names rather than
  shifted; and a weekly schedule keeps its weekday for 52 weeks, which is the
  property a `Duration(days: 7)` implementation loses across a daylight-saving
  boundary. On the SQL side, `checks/recurrence_dates.sql` asserts that Manila,
  UTC and Los Angeles stay ordered and within a day of each other.
* **Duplicate generation** — new. The database half is the unique index, so the
  check asserts `bills_occurrence_key` exists *and is unique*. The client half is
  that the series strictly increases and never repeats, over 40 steps of every
  frequency — a bookmark that could stand still would spin against that index
  forever. Also: resuming from a stored bookmark produces the same series as
  running straight through, and asking twice from the same bookmark gives the same
  answer.

**The real deliverable is `supabase/checks/recurrence_dates.sql`.** Sprint 31 left
the date arithmetic implemented twice — Dart for the preview, SQL for generation —
with nothing able to enforce that they agree, and the symptom of divergence is
bills appearing on dates the preview never promised. The check runs the *same 18
cases* as `recurrence_generation_test.dart` against `next_recurrence_date` and
raises with every disagreement. Run it after applying `0016`.

---

# 🏠 Phase 7 — Dashboard

## Sprint 34 — Dashboard Structure — done

The reference design's dashboard reads top to bottom as: who you are, one big
figure, what you can do about it, then the detail. This follows that order,
because it is the order the questions arrive in — "how much do I owe" before
"what is it made of".

* Header — a time-of-day greeting over the local part of the email, with an
  initial for an avatar. Sprint 54 adds the profile that would carry a real name.
  **The greeting is the one place the device clock is the right source**: every
  date in this app comes from the database because a wrong phone clock would
  disagree with the statuses beside it, but "good evening" is about the person,
  not the bill.
* Financial summary — total outstanding, with chips for what is overdue and what
  is due soon. Sprint 35 adds total paid and monthly obligations.
* Upcoming bills — the next three, soonest first, with "See all" only when
  something is actually being held back. Sprint 36 replaced this with windows —
  Today / Tomorrow / Later this week / Next week — and a counted tail.
* Overdue section — in full, and always **above** upcoming. Something already late
  outranks something that has not happened yet.
* Quick actions — Add bill, All bills, Calendar. Sprint 37's list also has Mark
  paid, Add debt and Add subscription, **none of which exist yet**. A row where
  two of five do nothing teaches the user the row is decoration and they stop
  reading it; each arrives when the thing behind it does.

**No app bar.** Every other screen has one because the shell's tabs do not label
what they switched to — but here the greeting is that label, and a bar reading
"Dashboard" above "Good evening, marc" is two headers.

**Not the bills list with a different header.** Bills answers "show me everything,
let me search it". This answers "what needs me today", which is why upcoming is
windowed and the summary card is not reused — two tabs opening on the same card
would be one tab and a wasted tap.

`BillTotals` came out of the bills summary card on the way, because the dashboard
needed the same figures. Two screens each summing their own way is two definitions
of "total outstanding", and the day they disagree the user is looking at one
believing the other.

## Sprint 35 — Financial Summary — done

One card, "The money", with four figures in a 2×2 grid. It replaced the two
month stat cards from Sprint 34: those answered "when", which the months chart
below already answers in more detail.

* Total upcoming — outstanding that is not yet late, derived as
  `outstanding − overdue` rather than summed separately so it cannot disagree
  with its own two halves.
* Total paid — with the share of everything beside it, because a paid figure
  without a denominator cannot be read as good or bad.
* Total overdue — always shown, including as ₱0.00 and "0 bills late". A grid
  that changes shape depending on whether anything is late makes the reader work
  out which cell went missing.
* Monthly obligations — **the only figure on the screen that is in no bill row**,
  and the one that finally gives `recurringBillsProvider` a reader after four
  sprints of being written and never read.

`RecurringCommitment` normalises every active schedule to occurrences per year and
divides by twelve. A weekly bill is **365.25 / 7 weeks a year, not 52** — the
shortcut loses a week every five years, which on something charged weekly is real
money. Paused and finished templates are excluded: a schedule the user stopped is
not money they have to find. The total is rounded once at the end, because
rounding each template first and summing drifts by up to half a centavo per bill
and shows as a total that does not match its own parts.

**It is an average, not a forecast.** A yearly bill does not arrive in twelfths,
and the month it lands in is the month it hurts. The months chart answers *when*;
this answers *how much, on average*, and they are shown apart because confusing
them makes someone budget wrongly in exactly one direction.

The hero's chips went with this: they carried overdue and due-soon as counts, and
the summary card carries the same thing as amounts one block below. The hero is
now one figure and one ring.

## Sprint 36 — Upcoming Payments — done

`UpcomingSchedule` sorts what is coming into Today / Tomorrow / Later this week /
Next week / Later, and the dashboard draws one labelled section per window.

**Named windows rather than dates.** "Due in 6 days" is a subtraction the reader
has to do before they know whether it matters; "Next week" is the answer. The rows
still carry the exact date — the heading is what makes ten of them scannable in a
single look.

**Weeks are calendar weeks, Monday to Sunday.** A rolling seven days is easier to
compute and quietly wrong: on a Friday it files next Thursday under "this week",
which is not what the words say. The consequence is that on a Sunday there is no
"rest of this week" at all, so that heading simply does not appear — empty windows
are dropped rather than shown as bare headings with nothing under them.

Two orderings matter and neither is obvious. On a Sunday, tomorrow is Monday,
which is also the first day of next week; **tomorrow wins**, because it is the more
useful of the two true answers. And the groups come out in enum order rather than
the order bills happened to arrive in, because a map iterates by insertion and
"Later" above "Today" would be exactly backwards.

**"Later" is counted, not listed.** Everything past next week collapses into one
row — a count, a total and a tap through to Bills. This screen answers "what needs
me now", and a bill six weeks out does not; but pretending it is not there would
be worse, so it gets a line rather than a section. That replaced the Sprint 34
three-deep cap and its "See all", which held bills back by position rather than by
urgency — the fourth-soonest bill is not less urgent for being fourth.

Section headings now carry a count. It was already being passed in Sprint 34 and
never drawn; with up to four headings on screen it earns its place, because
knowing how far a section runs without scrolling it is the point.

Overdue is still excluded and still sits above all of this. A bill that is both
late and due today is late, and the dashboard says so once.

## Sprint 37 — Quick Actions — done

The sprint reads as five buttons. Three of them could not be buttons.

**"Add debt" and "Add subscription" are not here.** Debts are Phase 11 and
subscriptions are Phase 10; neither model exists, so both would be shortcuts to
nothing. The rule from Sprint 34 stands — a row where two of five do nothing
teaches the user the row is decoration, and they stop reading it.

**"Mark paid" was not a button either. It was the missing half of the app.**
`PaymentRepository` was read-only, `PaymentDto` had no `toInsert`, and this
bullet is the *only* place in 85 sprints that asks for recording a bill payment.
Until this sprint PayPaw was a bills tracker in which no bill could ever be
marked paid: "Paid ₱0.00 / 0% settled" on the dashboard was unreachable by
construction. So this sprint built payment recording end to end, and the quick
action is the last two lines of it.

### The sheet

Amount pre-filled with what is owed, date pre-filled with today. The common case
— "I paid this bill" — is one tap on Save, and everything else is optional.

A bare "Mark as paid" button would have served that case in *zero* taps and been
wrong for every other one: a partial payment, a payment made last Tuesday, a
reference number worth keeping. Those are not edge cases in a bills app; they are
the reason `payments` has the columns it has.

**Overpaying warns and does not block.** A surcharge, a rounded-up transfer, a
bill two people in a household both paid. The column permits it, so refusing here
would leave someone unable to record what their statement says — but it is nearly
always a typo, so it is said out loud beside the field with Save still alive.

Partial payments needed no code at all, which is the schema decision from Sprint
19 paying off: they are payments that sum to less than the amount due, and
`bill_status` does the summing.

### What the write invalidates, and why all three

Nothing stores whether a bill is paid. After an insert the app's idea of the bill
is stale in three places, and patching any of them by hand would be guessing at
what the view is about to say: `billsProvider` (the list, its totals, every
dashboard figure), `billDetailProvider(id)` (an open drawer showing an amount
that just changed), and `paymentsForBillProvider(id)` (the history in that
drawer, missing the row that was the point).

### Two entry points, because they are different questions

The **detail drawer** already has a bill in hand, so it goes straight to the
sheet. It is the one filled circle among the four action icons: four equal
circles would claim the four things you can do here are equally likely, and the
reason anyone opens a bill is to deal with it.

The **dashboard** has no bill, so "Mark paid" asks which one first — late first,
then soonest, because the bill somebody has just paid is the one that was
worrying them. That picker is deliberately not a second bills list: no search, no
filters, no sort. And the action is absent entirely for a user with nothing
outstanding — the same rule as the two unbuilt actions, applied per-user, since
an entry point that opens onto an empty sheet is the same broken promise.

### Fixed on the way

The quick action labels were not tappable. Only the 56dp circle carried the
`InkWell`, and a label sitting under a button reads as part of it — that is where
a thumb goes. Found by a test that tapped "Mark paid" and got nothing.

`PaymentRepository` gained `recordPayment` and nothing else. No update: a payment
records something that happened, and the fix for a wrong one is to remove it and
enter what occurred. No delete either, because nothing offers it yet — it arrives
with the confirmation it needs.

## Sprint 38 — Dashboard Polish — done

"Polish" is where a sprint turns into decoration, so this one started with an
audit of the five bullets rather than with a list of effects to add. Two of them
were already done, two were broken, and one was not a problem.

**Empty and error states already existed** and were sound — `AppEmptyState` for a
user with no bills, `_AllClear` for one with nothing pending, `AppErrorState`
with a retry. Nothing to add; adding anyway would have been churn.

**Performance had no defect to fix.** The three aggregates are microseconds over
a list of tens, the one `CustomPainter` already guards `shouldRepaint`, and the
content is bounded. Caching the arithmetic in providers would have been ceremony
dressed as optimisation. The perceived-performance defect was real, and is below.

### The loading state was wrong twice

**It did not look like what was coming.** Three plain rectangles of arbitrary
height, so the screen jumped when the data landed — which is the one thing a
skeleton exists to prevent. Otherwise a spinner would do and cost less. It is now
shaped after the real first screenful: the hero with its figure and ring, the row
of shortcuts, the four-figure money card. And it pulses; the blocks it replaced
were static, which reads as content that finished loading and turned out blank.

**And it replaced live content on every refresh.** This is the serious one. A
refresh is *also* `AsyncLoading`, with the previous value still attached, so
matching on it first meant recording a payment blanked the whole dashboard back
to placeholders and rebuilt it — the user's own action looking like the app
losing its place. Data now outranks loading whenever there is any.

The Bills screen had the identical bug in the identical place: pulling to refresh
replaced the list with a centred spinner, *underneath* the pull gesture's own
spinner. Fixed the same way, because it is the same bug.

A failed refresh now keeps the old figures rather than replacing them with a red
panel. They are still true as of the last fetch, and throwing away good data
because a poll failed is worse than being a minute out of date.

### Refreshing was impossible

There was no way to ask for fresh figures short of killing the app — on the
screen a user opens specifically to check on something. `RefreshIndicator`, with
`AlwaysScrollableScrollPhysics` so the gesture has somewhere to travel on a
dashboard that does not fill the viewport, which is exactly when someone wonders
whether what they are looking at is current.

### Animation only where it carries information

One rule: **animate on change, never on arrival.** A total that counts up from
zero every launch is a loading animation pretending to be information — it
withholds the one number the reader opened the screen for.

So `AnimatedMoney` and the progress ring both settle straight onto their value on
the first build and animate only when it *moves* — which on this screen means the
user did something. Record a payment and the total counts down and the ring
sweeps: the app showing the effect of the action rather than silently redrawing.
`TweenAnimationBuilder` with no `begin` gives exactly that behaviour.

The body crossfades once when the placeholders give way, keyed on the *state*
rather than the data — keyed on the data, every refresh would fade the screen out
and back. And there is no staggered entrance: it would look considered and read
as slow, deliberately withholding every block after the first.

### Found on the way

`AppSkeleton.line` and `.circle` were factories, so no screen could make a
placeholder layout `const`. They are generative and `const` now.

The shortcut row had to be built twice. First it was invisible: `surfaceMuted`
on the canvas, the same token that has now caught out `AppFilterPill`,
`DashboardBlock`, the ring's track and this — found by looking at the screen,
since nothing an analyzer checks can see it. Then, once the circles were laid
out on the real row's 72dp grid so the icons would not slide sideways on load,
four of them came to 336 on a 320dp phone's 328 and the responsive suite caught
the overflow. The real row scrolls sideways; matching its geometry meant matching
that too.

`FakeBillRepository` gained `blockFetch`/`releaseFetch`. With an instant fake the
loading state exists for less than a frame, so a screen that wrongly blanks
itself mid-refresh passes every test — which is precisely how the skeleton flash
shipped in the first place.

---

# 🔔 Phase 8 — Notifications

## Sprint 39 — Notification Infrastructure — done

The machinery, and nothing that uses it. `NotificationService` initialises the
plugin, loads the timezone database, registers the channels and can report
whether PayPaw is allowed to post. **It cannot post or schedule anything** —
those methods arrive in Sprint 40 with the reminders that need them, rather than
sitting here untested.

### No exact alarms, deliberately

Google Play restricts `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` to apps whose
*core* function is alarms or calendars. A bills tracker is neither, and declaring
one risks the listing. So reminders will be scheduled inexactly and may drift by
minutes in Doze.

That is the right trade here: a reminder that a bill is due today arriving at
9:14 instead of 9:00 loses nothing, and an alarm clock doing the same would be
broken — which is exactly the distinction the policy draws. If a user ever
reports a reminder arriving hours late, this is the decision to revisit.

### Timezones are not optional

`package:timezone` defaults its local zone to **UTC**. A reminder scheduled for
"9am on the due date" would arrive at 5pm in Manila — after the working day it
was meant to precede. `flutter_timezone` names the device's IANA zone and the
service points the package at it during startup, before the first frame, because
a schedule written before the database loads is a schedule written in UTC.

A zone *name*, not an offset: an offset cannot survive DST or a flight. If the
lookup fails the app logs and carries on in UTC — reminders hours out is bad,
an app that will not start is worse.

### Two channels, not one per reminder offset

An Android channel is a row in the user's system settings with its own toggle and
its own importance, and its importance can never be raised again from code. So
the set is decided rather than accumulated.

"7 days before" and "1 day before" are the same *kind* of interruption; four
toggles would make turning reminders off a four-tap job. Which offsets fire is
PayPaw's setting (Sprint 42), not Android's. **Overdue is separate** because it
is a different kind of message: a reminder is a courtesy someone might want none
of, while "this is late" is the one thing a bills app exists to say, and
silencing the first is not a request to silence the second.

The ids are pinned by a test. Android keys a channel's settings — the user's own
choices about sound and whether it is on at all — to that string; changing one
silently discards what they chose and leaves a dead row behind.

Both are registered at startup even though nothing posts to them yet: a channel
must exist before its first notification, and a user who wants to silence a
category should be able to find it *before* being interrupted rather than after.

### It does not ask on launch

`initialize()` deliberately does not request permission. A permission dialog on
first launch, before the user has seen what the app is for, is the one most
reliably refused — and on Android 13 a refusal is final: the system swallows
every later request without showing anything. Asking belongs with the screen that
explains why, in Sprint 42.

That finality is why `NotificationPermission` has three states and not a bool.
"Never asked" and "asked and refused" both read as *not enabled* from the
platform, and they need opposite handling — only the first can still be prompted;
the second needs a route into system settings. Android will not tell the two
apart, so the app remembers having asked. `resolve(enabled:hasAsked:)` is a pure
function for exactly that reason: the decision is the substance and it is tested
without a method channel anywhere near it.

`notApplicable` is the fourth, and not a failure: below Android 13 there is no
runtime permission at all, and reporting that as "granted" would be a claim this
app is not in a position to make.

### Found by the tests

`resolvePlatformSpecificImplementation` **throws** a `LateInitializationError`
rather than returning null when no platform implementation is registered. Every
method in the service was written against null and every one of them died on the
first call off-device. Caught by the first host-run test and turned into null in
one place.

### Verified on the device

`dumpsys notification` shows both channels registered at importance 4 with their
names and descriptions, and the app itself at `importance=NONE userSet=false` —
which is precisely the designed state: the channels exist, nothing has been
asked, and no dialog appeared on launch.

## Sprint 40 — Bill Reminders — done

Reminders are scheduled on the device at every offset the user chose, at the time
of day they chose, in their own timezone. The four the roadmap names — 7 days, 3
days, 1 day, the due date — are values in `reminder_preferences.days_before`, not
four code paths: the column already stores a set, onboarding already collects it,
and hard-coding the same four numbers in Dart would be a second definition that
Sprint 42's settings screen would immediately have to fight.

**What was missing was the reading.** The preferences have been collected since
Sprint 11B and stored since Sprint 3, and nothing had ever read them back.

### The schedule is a pure function, not a set of event handlers

`BillReminderSchedule.of(bills, preferences, now)` takes the bills as they are
and says what should currently be scheduled. The caller cancels everything and
lays down the answer.

The alternative — schedule on create, cancel on delete, adjust on edit, and
again on pay, archive, restore and recurring generation — is seven places that
each have to remember the rules, and the one that forgets leaves a reminder
scheduled for a bill that was paid last week. **That failure is invisible until
the morning it fires**, which is exactly why it is not worth being clever about.

So the rebuild hangs off `billsProvider` instead. Every write already invalidates
it; all seven paths are covered without any of them knowing reminders exist.

Replace-don't-merge for the same reason. Reconciling would need an accurate
record of what is scheduled, and the only such record lives in the platform and
is rebuilt from scratch after a reboot.

### What never gets a reminder

Settled bills, above all: paying a bill and then being told about it twice more
is the single most annoying thing a reminder can do. Archived bills. Anything
already in the past — a warning that a bill is due in three days, arriving the
day after it was due, is worse than none. And overdue bills, whose reminders are
all in the past by definition; "this is late" is a different message on a
different channel, and Sprint 41's job.

### Notification ids are FNV-1a, not `String.hashCode`

Ids are 32-bit ints and a bill id is a UUID, so it has to be hashed. Dart makes
no promise that `String.hashCode` is stable across releases — and an id that
changes between app versions is a scheduled reminder that **can never be
cancelled**. It fires anyway, beside its own replacement. FNV-1a is a few lines,
specified, and identical everywhere.

### Tapping one opens the bill

A bill's detail is a sheet over the Bills screen, not a route, so there is
nothing to navigate to. The tap leaves the id behind and a listener above the
router picks it up — a sibling of the session and password-recovery listeners,
for the same reason they are there.

Two states arrive differently and both had to work: a tap with the app running
reaches a callback, and a tap that *starts* the process is only recoverable from
the plugin's launch details, read once in `main()`.

### The permission ask, at the point it means something

Sprint 39 deliberately did not ask on launch — the dialog most reliably refused,
and on Android 13 a refusal is final. Nothing else asked either, so reminders
would have been scheduled and silently blocked.

A card on the dashboard asks instead: only for a user who has bills, only while
permission is missing, and phrased as what they get rather than what the app
needs. After a refusal it does not keep offering — it changes to a route into
system settings, because a button still wired to `requestPermission` is one the
user taps and taps while Android ignores it.

### Signing out clears the schedule

The reminders name the previous account's bills and amounts. The next person to
pick up the phone should not be told about them.

### Two things moved

`ReminderTime` was in the onboarding feature, where it had landed because
onboarding collected it first. It is a reminders concept; it lives with them now.

The notification's title and body moved out of the Android wrapper onto
`BillReminder`. They are properties of the reminder rather than of the platform,
and a private method inside a method-channel wrapper is a string nobody can test.

### Verified on the device

`dumpsys alarm` shows eight alarms against
`ScheduledNotificationReceiver` — two bills at four offsets each, all at 09:00,
each with `window=+1h`, which is the inexact scheduling from Sprint 39 behaving
as designed. Revoking the permission brings the card back; tapping it produces
the system dialog; allowing it makes the card disappear.

## Sprint 41 — Overdue Notifications — done

The channel has existed since Sprint 39 and had nothing to post to it. It does
now: a bill that goes past its due date and stays unpaid gets told about on a
schedule that escalates and then stops.

### Saying it too often is the whole problem

A reminder is easy because it fires once at a known moment. **"This is late" is
true every morning until the bill is paid**, which makes it the one message an
app can send forever. Daily is how a forgotten ₱200 bill becomes a month of
alerts and the user switches the channel off — losing the notification PayPaw
most needed to deliver.

So it decays: **the day after, then three, a week, a fortnight.** Four alerts
across two weeks and then silence. By day fourteen nobody is failing to pay
because they forgot, and a fifth would be the app insisting rather than
informing. The bill is still there, still red, still at the top of the list.

The second spam rule is the one that is easy to miss, and it comes free from the
past filter: **a bill entered when it is already ten days late does not fire
three alerts at once.** Only the steps still ahead of it are scheduled, so it is
announced once rather than in a burst. A bill two months late gets nothing.

Fixed rather than configurable. `reminder_preferences.days_before` covers the
days *before* a due date and has no column for after; inventing one before Sprint
42 has a screen to edit it would be a preference nobody could reach.

### One switch, both kinds

`is_enabled` silences reminders and overdue alerts together. It reads as
"reminders", but it is the user asking PayPaw not to notify them about bills, and
honouring that for the gentler message while overriding it for the blunter one
would be the app deciding it knows better. Android's per-channel toggles are the
finer control for someone who wants only one.

### BillReminder became BillNotice

Two kinds of message, not two settings of one, so the type carries a
`BillNoticeKind` and each kind carries its own channel. `days` counts *back* from
the due date for a reminder and *forward* for an overdue notice — which side it
falls on is the kind's business, not a sign bit's, and a negative number there
would be readable exactly once.

The kind is in the notification id as well as the offset. Without it a reminder
three days before and an overdue notice three days after the same bill hash the
same, and the second silently replaces the first.

**Each notice names its own channel at post time.** Passing the reminders channel
for everything — which the first cut did, inherited from Sprint 40 — would put
overdue alerts behind the reminders toggle, exactly the thing the two channels
exist to prevent.

Sprint 40's exclusion of overdue bills is gone. It was right then: every reminder
for a bill already late is in the past, so nothing was scheduled either way.
Their overdue notices are not.

### Correcting Sprint 40's note on notification ids

That sprint claimed a hash that changed between app versions would leave a
reminder that could never be cancelled. It would not: `replaceScheduledNotices`
cancels *every* pending notification before laying down a new set, so an id only
has to be unique within one pass. FNV-1a is still the right choice — it is
reproducible in a test, and a collision would drop a notice with no sign it
happened — but the reason given was overstated.

### Verified on the device

`dumpsys alarm` shows **sixteen** alarms where there were eight. Rent, due the
18th: reminders on the 11th, 15th, 17th and 18th, then overdue on the 19th, 21st,
25th and 2 October. Converge, due the 20th: the same shape two days later. The
doubled dates are the two kinds interleaving — the 19th carries Converge's "due
tomorrow" and Rent's first overdue.

Both channels are registered and distinct. Which channel a notice actually posts
on is covered by tests but has not been watched firing on a device; the first
real one lands on 11 September.

## Sprint 42 — Notification Settings — done

Onboarding has said "you can change this any time in Profile" since Sprint 11B,
and until now that was not true: the preferences were collected once and then
only ever read. This is the screen that promise was about, plus the per-bill
departure from it.

### Every control saves itself

There is no Save button on the defaults screen. Each control is one complete
decision — a switch, a set of toggles, a time — and a form that collects four of
those and then asks for confirmation is a form that can be abandoned halfway,
leaving the user unsure which half took.

The cost is that a failed write has to be *shown*, because there is no button
left sitting there to retry. It arrives as a toast and the control springs back
to whatever the database still says. A silent failure on a screen like this reads
as the tap never registering.

The per-bill sheet does have one, and that is not an inconsistency: a per-bill
rule is a small set of choices made together, and saving each keystroke would
leave rows in the database for a customisation the user was still assembling and
might abandon.

### Null means inherit

`bill_reminders` has every column nullable, and that is the whole design. An
override that had to restate every setting would drift the moment the defaults
changed: move the reminder time from 9am to 6pm and every bill ever touched would
stay at nine, silently, forever. So a bill that wants a different *time* stores a
time and nothing else.

`BillReminderOverride.resolve` therefore merges **field by field**. Resolving
wholesale — take the override if any field is set, otherwise the defaults —
compiles, reads correctly, and silently drops the other two settings.

Three consequences worth stating:

* **An override that overrides nothing is deleted, not written.** The table has a
  check constraint saying so, and turning the sheet's switch off sends the empty
  override that means the deletion.
* **Turning the switch on copies the defaults in.** Starting empty would produce
  exactly that empty override, so the switch would appear to do nothing.
* **`is_enabled: false` is an override, not an absence.** It is the common case —
  a bill on auto-debit — and reading `false` as unset would delete the row and
  start reminding the user about the one bill they silenced.

### The overdue offsets are not configurable, and the screen says so

`{1, 3, 7, 14} and then stop` is stated on the settings screen rather than
offered. It is the anti-spam rule from Sprint 41, and a screen that lists every
other reminder rule while staying silent about this one invites the reader to
assume it is off. A per-bill override cannot change it either — only silence it,
through the same switch that silences the reminders.

### The bug the sheet's tests found

The first cut seeded its draft from `ref.watch(...).value ?? {}` on the first
build. A bill that *had* an override opened as one following the defaults,
because the query had not come back yet — and Save then wrote the empty override
that deletes its row. Absence and not-yet-known are different answers and only
one of them is safe to act on; the sheet now waits for both providers before it
seeds, and shows a spinner until then.

### The detail sheet states a fact

The way in is a row in the bill's detail drawer, and it says what that bill's
reminders currently *do* — following your settings, set for this bill, or off for
this bill — rather than "tap to change", which is what the chevron already says.
The silenced case is the reason: a bill nobody will be warned about should say so
where somebody might notice.

It goes among the facts rather than as a fifth action icon. The icons are things
you do *to* a bill; four of them is already a row that has to be read rather than
scanned.

### Nothing here reschedules anything

Saving invalidates the provider the schedule is built from, and `ReminderSync` is
listening. That is the same route every bill write has taken since Sprint 40,
which is why the settings controller has no idea notifications exist.

### Verified on the device

Turning "7 days before" off dropped the pending alarms by three — one per bill —
and turning it back on restored them. Silencing Rent through the per-bill sheet
took the schedule from 58 alarm lines to 34 and left Converge's alone; turning
customisation back off restored all of them and reopened the sheet on "follows
your reminder settings", which is the loading-order fix above working against
real data.

### Noticed while testing, not fixed here

Every bottom sheet whose content scrolls paints its primary button's label a
second time at the top of the screen, dimmed under the scrim — "Save" on the
reminder sheet, "Record payment" on the payment sheet built in Sprint 37. The
filter sheets, whose content fits, do not. It is cosmetic, it predates this
sprint, and it belongs to `showAppBottomSheet` rather than to anything here.

## Sprint 43 — Notification Testing — done

A verification sprint. The deliverable is evidence, plus the one fix the evidence
demanded.

Everything below was run on a Pixel emulator against the real account, with the
device schedule read from `dumpsys alarm` and the plugin's own cache read from
`shared_prefs/scheduled_notifications.xml`. Counts are **pending alarms**, not
lines of output — sixteen is two bills times four reminder offsets plus four
overdue steps each.

### App closed — passes

Backgrounded, then `am kill`. The process is gone and all sixteen alarms remain:
they live in `AlarmManager`, not in the app. This is what the whole design rests
on and it had never been checked.

**Force-stop is different, and it is worth knowing.** A user who taps "Force
stop" in system settings loses every alarm — sixteen to zero — and the app cannot
receive broadcasts, including boot, until it is next opened. That is Android's
documented behaviour for a force-stopped package and there is nothing PayPaw can
do about it. Opening the app restores the whole schedule, which is what the
`fireImmediately` rebuild is for.

### Device restarted — passes, but not instantly

`adb reboot`, then nothing: the app was never opened. All sixteen came back.

The first measurement said zero and was wrong — taken twenty-five seconds after
`sys.boot_completed`, when the boot broadcast had not yet reached the app.
Logcat gives the real figure: `completeLatency:36156` across 115 receivers. So
**restoration is not instant**, and a reminder due within a minute of a restart
could be late. Nothing to fix; worth not misreading again.

### Time zone changes — failed, and this is the sprint's fix

The one scenario that was genuinely broken.

`initialize()` reads the device zone once per process, and
`flutter_local_notifications` only re-registers alarms on boot and
package-replaced — not on `TIMEZONE_CHANGED`. So a phone that changes zone keeps
every alarm at the instant it was set. A 9am reminder set in Manila arrives at
1am in London.

Two changes:

* **`NotificationService.refreshTimezone()`**, called on every app resume through
  an `AppLifecycleListener` on `reminderSyncProvider`. It answers a question —
  did the zone move — and the schedule is rebuilt only when it says yes. Resume
  is frequent; cancelling and re-laying a dozen alarms on each one would not be.
* **The scheduled instant is now built from the notice's own fields** rather than
  converted from it. `firesAt` is a wall-clock intention — "nine in the morning,
  three days before it is due" — and `TZDateTime.from` was reading it as an
  instant and re-expressing that same moment in the new zone, which is precisely
  the 1am arrival. Naming the fields says what was meant.

Verified on the device. App running under GMT with the first alarm at
`origWhen 1789117200000` (11 Sep, 09:00 GMT). Backgrounded, zone moved to
Asia/Manila, brought back to the front — same process, no restart — and every
alarm moved by exactly 28,800,000ms to `1789088400000`, which is 11 Sep 09:00 in
Manila. A resume with no move leaves the alarm objects byte-identical, so the
"only when it changed" half holds too.

**What it cannot do:** help a user who never opens PayPaw after landing. That is
the honest limit of doing this without a background receiver of our own, and the
failure it leaves — one day's reminders some hours out — is smaller than the one
it fixes.

### Multiple reminders — passes

Sixteen scheduled, sixteen distinct notification ids in the plugin's cache, split
eight and eight across `bill_reminders` and `overdue_bills`. No collisions, and
each kind on its own channel — which is what keeps switching reminders off from
silencing "this bill is late".

### Recurring bills — passes

Rent is generated from a monthly template, and it carries reminders like any
other bill. That is not a special case anywhere in the code: `billsProvider`
awaits generation before it fetches, and `ReminderSync` listens to
`billsProvider` with `fireImmediately`, so an occurrence the nightly job created
is simply in the set the schedule is built from. Nothing in the recurring feature
knows reminders exist.

### And one thing nobody had ever watched happen

A reminder actually arriving. The clock was moved to a minute before the first
alarm and left to run:

> **PayPaw · now**
> **Rent is due in 7 days**
> ₱4,000.00 · due Fri, Sep 18

On the `bill_reminders` channel, as intended — Sprint 41 left this explicitly
open. It also fired about an hour after its scheduled time, which is the inexact
scheduling from Sprint 39 behaving exactly as designed and as the manifest
promises.

It shows the **Flutter default icon**, which is now a user-facing problem rather
than a launcher-screen one.

### Unresolved

Later firings in the same session consumed their alarm and their cache entry but
posted nothing visible, and logcat shows the app being started with
`SELECT_NOTIFICATION` at the moment the alarm fired rather than a notification
appearing. This may well be an artifact of jumping an emulator's clock forward by
days — which moves the app into a restricted standby bucket and batches its
inexact alarms — rather than anything in PayPaw. It is recorded rather than
explained away: settling it needs a real device left to run, not a clock that
skips.

---

# 📅 Phase 9 — Payment Calendar

## Sprint 44 — Calendar UI — done

The calendar has been a placeholder since Sprint 8 promising "Sprints 44-47".
This is the month view, and the navigation to get around it.

### The question it answers

**Is there a heavy week coming.** The bills list already says what is next; only
a grid shows that the 15th to the 18th carries four bills and the rest of the
month carries none. That is the one thing a list sorted by date cannot do, and
it is the whole reason this screen exists rather than being a third sort order.

### Two of the four bullets were dropped

The roadmap asked for a monthly view, a weekly view, a daily view and
navigation. Two of those were not built, deliberately.

A **weekly** view on a phone is a month grid with one row. It answers a narrower
question than the month does and it cannot answer the one above at all, so it
would cost a mode switch on every visit in order to show strictly less. The case
for it would be that a week has room for bill *names* where a square does not —
and if that case ever holds it will be because Sprint 45 could not fit the
statuses into the squares, which is a decision to take with that sprint's
evidence rather than now.

A **daily** view is "what is due on this date". That is a real need, and it is
exactly what Sprint 46 opens from a tapped square: a list under the month rather
than instead of it. Building it now as a third mode would mean building it twice
and then deleting one.

What is left is a month and a way to move through it, which is a complete thing
rather than a third of three.

### The grid is six rows, always

A month needs five rows or six depending on the weekday it starts on. A grid
that changed height would jump the whole page — heading, summary and all — on
every step forward or back. Six rows costs a row of dimmed dates in the shorter
months and buys a page that stays still.

The days either side are **shown, not blanked**. A grid with holes at both ends
reads as broken, and the last days of the previous month are exactly where a
bill that has just gone overdue sits.

### Dates are built, never stepped

Every cell is `DateTime(year, month, n)` with `n` allowed to run past the end of
the month or below one; the constructor normalises both. Walking with
`Duration(days: 1)` is the obvious alternative and is wrong twice a year — a day
crossing a DST boundary is 23 or 25 hours, and the walk drifts onto the previous
date and stays there for the rest of the grid.

The Philippines has not observed DST since 1978, so this costs nothing today. It
is written this way because a calendar that quietly breaks for anyone who travels
is not worth three saved characters, and because the test that proves it — every
cell is the day after the one before — is the only kind of test that catches a
whole class of off-by-one at once.

### What a square says, and what it does not

The date, whether it is today, and **how many** bills fall on it. Not yet *what*
kind: the paid, overdue, upcoming and partly-paid colours are Sprint 45, and a
badge that means "something" now becomes a badge that means "something overdue"
then without the grid changing shape.

A count rather than one dot per bill. Dots stop being countable at three, and
"how many" is the question being asked of a month view anyway.

**Archived bills are not counted.** They were put away, and a marked square would
be the calendar insisting on something the user has already dismissed. Settled
bills are — "this was paid on time" is part of what a month view is for.

### Today comes from the database, not the phone

`BillWithStatus.today`, like everywhere else. A phone in another zone would light
a different square than the statuses beside it are computed against, and a
calendar disagreeing with the list it came from is worse than either being wrong
alone. An account with no bills has no row to read it from and falls back to the
device clock, which is safe precisely because there is nothing to contradict.

### Navigation

Arrows either side, and a **Today** button that appears only when it would do
something. Stepping four months out and finding no way back but four taps is the
standard way a calendar wastes somebody's time; a permanently visible Today on
today's own month is a control that visibly does nothing, which teaches the user
to stop reading the row.

The month lives in a provider rather than in the screen's state, so stepping
through months survives switching tabs and coming back.

### The month summary

The grid shows the shape of a month; a line under it says the size — how many
bills, and what is still owed. Without it a reader looking at eleven marked
squares has to add them up to answer the question they came with. It counts only
what falls **in** the month, not the dimmed days either side, or the total would
disagree with the heading above it.

### Two things the device caught that the tests could not

* The count badge used `surfaceMuted`, which on a true-black sheet is very
  nearly the sheet — it read as a smudge, which is the whole failure for a mark
  whose only job is to be found. It is the brand tint now. That is the fifth
  time this palette pair has been too faint on a dark surface.
* The badge stretched across the square instead of hugging its number, because a
  `Container` given an `alignment` expands to its constraints. It looked
  identical whether it said 1 or 11.

### Amended the same day: the day detail, and the month total

Marc asked for both before the sprint closed, so they are here rather than in
Sprint 46. Three of that sprint's four bullets are done — see its entry below.

**Tapping a date narrows the list under the grid** to that day. Tapping it again
returns to the month. The panel is never empty: with no day picked it lists
everything due that month, grouped by date, which is the grid's own answer
spelled out and is a better thing to find on arrival than a box waiting to be
filled.

Tapping a dimmed date brings its month into view first. Without that the panel
would name a day that nothing on screen pointed at.

A picked day is **outlined**; today is **filled**. Two marks that can land on the
same square, so they cannot be the same mark — picking today would otherwise look
like picking nothing.

Stepping to another month drops the selection. A day picked in September is not a
day in October, and holding it would leave the panel showing one date while the
grid showed thirty others.

**The month summary now leads with the total** — what the month costs, whether or
not any of it is paid, which is the number somebody budgets against and the one
that does not move under them as they settle things. What is left appears beside
it as a sentence rather than a second labelled figure.

#### The rows are the bills list's own, and so is the drawer

`BillListTile`, so a bill reads the same wherever it is found. Tapping one opens
the same detail drawer the list opens — which meant extracting that drawer's
action handling out of `BillsScreen` into `bill_detail_actions.dart`, because the
alternative was a second copy of the switch. The half that falls behind in a
copied switch is always the warning: the delete dialog that knows a bill with
payments cannot be deleted at all, and offers to archive it instead.

#### And the screen had to start scrolling

A fixed column held the grid, the summary and the day list, and on a real phone
the last of those hung 146 pixels off the bottom. Every widget test here missed
it, because they pump a view tall enough to hide the problem — there is now one
that pumps 392×800 and asserts nothing overflows.

## Sprint 45 — Payment Indicators — done

The count badge on a calendar square meant "something is due here". It now says
what state that something is in.

### One badge, the loudest bill

A day can hold bills in different states, and the square takes the **most urgent**
of them: a day carrying one overdue bill and two settled ones is an overdue day.
A fourth colour meaning "mixed" would say nothing anybody could act on, and one
dot per bill stops being countable at three in a square smaller than a fingertip.

The list under the grid is where each bill gets its own status — the grid gives
the headline, the panel gives the detail.

`BillStatus.urgency` and `BillStatus.mostUrgent` are on the enum rather than in
the calendar, because the ranking is a judgement about **bills** and two screens
now depend on it agreeing with itself. It is the order the bills list groups in
and the `bill_status` view ranks by: overdue, due today, due soon, partly paid,
upcoming, settled, archived.

### The colours are the app's own

`BillStatusDisplay.tone` — the same mapping the list row's rail and the drawer's
chip already use, so a red square here and a red rail there mean the same thing,
learned once. Nothing new was invented for the calendar, and Sprint 45 added no
colours to the palette.

### Colour is never the only carrier

Red-green is the most common way not to see a difference, and a square that meant
"overdue" by being red alone would mean nothing to a good number of people. So:

* the **count** is written on the badge;
* the square's **spoken label** names the status — "Friday, September 18, 2
  bills, overdue";
* the **panel below** lists every bill with its status in words;
* and the **month breakdown** names each colour that is on the grid.

### The breakdown is the legend

Under the month summary, a row of tinted chips: "1 overdue", "2 upcoming". Only
the states actually present — a month with nothing overdue should not carry a
chip reading "0 overdue", which is a reassurance the absence already gives.

It doubles as the key. A separate legend row would be decoration nobody reads;
this one earns its place by answering "what is this month made of" and naming
the colours on the way past.

### A palette fix this forced

`AppStatusTone.neutral` tinted with `surfaceMuted`, which in the dark theme sits
about **eleven levels** off `surface` in every channel. Every other tint is tens
of levels away from the surface it lands on. A neutral chip was a shape you had
to look for, and "upcoming" is the majority state — the indicator most people
would see most of the time was the one that could not be seen.

Neutral is `border` now, in both themes. That is the fifth time this pair has
been too faint on a dark surface, and it is fixed at the token rather than
patched at the call site.

The badge's *number* takes `textPrimary` on the neutral tone rather than the
tone's own secondary grey. A neutral chip elsewhere can afford a grey word
because the word is furniture; here the digit is the answer.

### And a bug three sprints of notes had not fixed

The Profile screen's System / Light / Dark selector rendered stacked vertically
down the middle of the page. `AppFilterPill` wraps its content in a bare
`Center`, which expands to whatever width it is offered — invisible in the bills
filter row, where the row scrolls horizontally and the offer is unbounded, and
fatal in a `Wrap`, where the offer is the screen. Three small toggles became
three full-width tap targets.

Found the honest way: a stray tap during device testing switched the app to light
mode, and it took a screenshot of the Profile screen to work out how. `Center`
takes `widthFactor: 1` now, and the fix is in the shared widget rather than at
the one call site that showed it.

### What is not verified on a device

The red, amber, green and blue squares. The account this was tested against has
two upcoming bills and nothing else, and the alternative was writing invented
overdue rows into real data to photograph them. The mapping is covered by widget
tests; the neutral path and both themes were checked on the emulator.

## Sprint 46 — Calendar Interaction

* ~~Tap date~~ — done in Sprint 44
* ~~View bills~~ — done in Sprint 44
* ~~Open bill details~~ — done in Sprint 44
* Add bill from date

Three of the four landed early, because they were asked for while Sprint 44 was
still open and a calendar you cannot tap is half a feature. What is left is
adding a bill from a chosen date, which needs the add form to accept a due date
it did not collect — a different piece of work from any of the above.

## Sprint 47 — Calendar Optimization

* Smooth navigation
* Large dataset support
* Performance optimization

---

---

# 👤 Out of order — Profile UI

Asked for between Sprints 45 and 47. There was no sprint for it: the placeholder
card promised "built in Sprints 54 and 78-80", and those are debt and security
work with nothing to do with this screen.

## The gap was bigger than the screen

`public.profiles` has existed since migration 0002 with `display_name`,
`avatar_url`, `currency`, `locale` and `time_zone` — and **nothing in `lib/`
read or wrote any of it.** The table was populated by a trigger and consumed
only by SQL. So this is a feature that was missing its entire client half, not a
screen that needed rearranging: entity, DTO, repository, providers and
controller all landed with it.

## What the screen says now

**Identity first.** An avatar initial, the name, the address underneath. Tapping
it edits the name — which is the only thing on this screen a person can put
their own words into, and it had nowhere to go.

Without a name it reads "Add your name" rather than quietly falling back to the
address in the large type. An empty state that asks for something beats one that
makes do.

**Then the settings**, commonest first: reminders, appearance, dates.

**Sign out is last.** It is the only disruptive control here, and putting it
under everything else is the cheapest way to keep a stray thumb off it.

Categories are not here. They are edited where they are used — on the bill form —
and a second place to manage them would be a second place for the two to
disagree.

## The time zone is on the screen because it is not a preference

`bill_status` decides "due today" against `profiles.time_zone` and
`generate_recurring_bills` measures its horizon by it. A wrong zone is wrong
**dates** — a bill reading as due tomorrow when it was due yesterday — and
nothing on any other screen would give the reason.

It defaults to `Asia/Manila` for every account, because migration 0002 had to
choose something. Anybody who is not there has had silently wrong dates since
they signed up.

**No picker.** Four hundred IANA names is a worse control than the one question
worth asking: *is this the zone you are actually in?* The phone already knows, so
the row shows both and offers to match — one tap, and it cannot produce a zone
that does not exist. Somebody who wants a zone their phone is not in is not
served by this; that is a rarer problem than the default being wrong.

It fired on the first device run: the emulator is GMT and the profile says
Asia/Manila.

## Migration 0017: a name is something you choose

`handle_new_user` seeded `display_name` with the local part of the address —
"a usable starting name rather than an empty screen", which was right while
nothing could edit it.

Now that something can, the seed *is* the problem. Every account arrives already
named after its login, so nobody is ever asked, PayPaw presents a string nobody
chose as though they did, and "has this person told us their name" is
unanswerable because a seed and a choice are stored identically.

The trigger inserts the row and leaves the name null. The backfill undoes 0002's,
clearing `display_name` only where it is **exactly** the local part of the
address — the seed and nothing else. A chosen name that merely resembles an
address is left alone. Somebody whose chosen name happens to equal their own
local part loses it and is asked again; that is the one case this gets wrong, it
costs two taps, and the alternative is every account misrepresented forever.

**Not applied.** Until it is, the screen shows the seeded name and the invitation
never appears.

## The dashboard greeting

`DashboardHeader.displayName(email)` became
`DashboardHeader.nameOrAddress(name:, email:)`. The address is still there and
still the fallback — the difference is that it is visibly a fallback now, and
there is a real name to prefer when there is one.

## Not built

**Avatar upload.** `avatar_url` has been in the schema since 0002 and there is
nowhere to put a file until Storage lands in Sprint 57. A picker that could only
fail is worse than an initial.

**Currency.** Changing it converts nothing: every amount already stored would
keep its number and quietly change meaning. That is a data migration wearing a
dropdown, and it does not belong on a settings screen.

# 📺 Phase 10 — Subscription Manager

## Sprint 48 — Subscription Model

Add:

* Subscription name
* Provider
* Amount
* Billing frequency
* Next billing date

## Sprint 49 — Subscription UI

* Subscription list
* Subscription details
* Add/edit/delete

## Sprint 50 — Subscription Analytics

Calculate:

* Monthly subscription cost
* Annual subscription cost
* Most expensive subscriptions

## Sprint 51 — Subscription Alerts

* Upcoming renewal
* Price changes
* Cancellation reminders

---

# 🤝 Phase 11 — Debt / Utang Management

## Sprint 52 — Debt Model

Support:

* Person/company
* Amount
* Due date
* Interest
* Notes
* Direction

## Sprint 53 — Money You Owe

* Create debt
* Record payments
* Track balance
* Track installments

## Sprint 54 — Money Owed to You

* Add borrower
* Track amount
* Partial payments
* Remaining balance

## Sprint 55 — Debt Dashboard

Display:

* Total owed
* Total receivable
* Upcoming debt payments
* Overdue debts

## Sprint 56 — Debt Analytics

* Payment history
* Debt progress
* Outstanding balance
* Debt trends

---

# 📎 Phase 12 — Attachments & Receipts

## Sprint 57 — Supabase Storage

* Create storage buckets
* Configure policies
* Secure file access

## Sprint 58 — Receipt Upload

Support:

* Camera
* Gallery
* PDF
* Images

## Sprint 59 — Receipt Management

* View receipts
* Delete receipts
* Download/open files
* Link files to bills

---

# 📊 Phase 13 — Analytics

## Sprint 60 — Analytics Architecture

* Define metrics
* Create analytics queries
* Optimize aggregation

## Sprint 61 — Monthly Analytics

* Monthly obligations
* Paid vs unpaid
* Overdue amounts

## Sprint 62 — Category Analytics

* Category totals
* Category percentages
* Largest categories

## Sprint 63 — Trends

* Month-to-month comparisons
* Increasing bills
* Decreasing bills
* Recurring expense trends

## Sprint 64 — Analytics UI

* Charts
* Graphs
* Summary cards
* Interactive filtering

---

# 🧠 Phase 14 — AI Financial Assistant

## Sprint 65 — AI Architecture

* Select AI provider
* Configure secure API access
* Create AI service
* Define data access boundaries

## Sprint 66 — AI Bill Queries

Support questions like:

* "What do I owe this week?"
* "What's due tomorrow?"
* "How much do I owe this month?"

## Sprint 67 — AI Financial Summary

Generate:

* Weekly summaries
* Monthly summaries
* Upcoming obligation summaries

## Sprint 68 — AI Insights

Generate insights about:

* Increasing bills
* Expensive subscriptions
* Recurring expenses
* Overdue payments

## Sprint 69 — Natural Language Search

Allow users to ask:

> "Show my bills above ₱2,000."

> "What subscriptions renew next week?"

> "Show overdue payments."

## Sprint 70 — AI Safety & Privacy

* Minimize data sent to AI
* Avoid exposing sensitive information unnecessarily
* Secure API keys
* Validate AI responses
* Add AI disclaimers where appropriate

---

# 📸 Phase 15 — AI Bill Scanner

## Sprint 71 — OCR Integration

* Camera integration
* Image processing
* OCR engine
* Text extraction

## Sprint 72 — Bill Information Extraction

Extract:

* Provider
* Amount
* Due date
* Account number
* Billing period

## Sprint 73 — Review & Confirmation

Before saving:

* Show extracted information
* Allow editing
* Validate fields
* Confirm bill creation

## Sprint 74 — Scanner Improvements

* Improve OCR accuracy
* Handle blurry images
* Handle different bill layouts
* Detect missing fields
* Improve error handling

---

# 👥 Phase 16 — Shared Bills

## Sprint 75 — Sharing Architecture

* Shared bill model
* User relationships
* Permissions
* Access rules

## Sprint 76 — Bill Splitting

Support:

* Equal split
* Custom split
* Percentage split

## Sprint 77 — Shared Payment Tracking

Track:

* Who paid
* Who hasn't paid
* Amount remaining
* Shared bill history

---

# 🔐 Phase 17 — Security & Privacy

## Sprint 78 — App Lock

Implement:

* PIN
* Biometric authentication
* Automatic locking

## Sprint 79 — Sensitive Data Protection

* Hide amounts
* Secure local storage
* Secure sessions
* Protect sensitive files

## Sprint 80 — Security Audit

Review:

* Supabase RLS
* Authentication
* Storage policies
* API security
* AI API security
* Database permissions
* Client-side secrets
* Debug logs

---

# 🧪 Phase 18 — Testing & Optimization

## Sprint 81 — Unit Testing

Test:

* Models
* Repositories
* Bill calculations
* Recurrence logic
* Debt calculations
* Safe-to-spend calculations

## Sprint 82 — Integration Testing

Test:

* Authentication
* Supabase
* Database operations
* File uploads
* Notifications
* AI features

## Sprint 83 — UI & Device Testing

Test on:

* Small Android devices
* Large Android devices
* Different Android versions
* Physical devices
* Emulator

Test:

* Light mode
* Dark mode
* Offline scenarios
* Poor network conditions

---

# 🚀 Phase 19 — Release Preparation

## Sprint 84 — Production Build

* Configure production environment
* Configure release signing
* Update application ID
* Configure app icon
* Configure splash screen
* Remove debug logs
* Optimize assets
* Update version number
* Build release APK

Run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Verify:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Perform final installation testing on a physical Android device.

---

# 🏁 Sprint 85 — Final Release

## Final QA

* Test registration
* Test login
* Test bill creation
* Test bill editing
* Test bill deletion
* Test recurring bills
* Test reminders
* Test calendar
* Test subscriptions
* Test debts
* Test attachments
* Test analytics
* Test AI
* Test OCR
* Test shared bills
* Test app lock
* Test offline behavior

## Production Checklist

* [ ] Production Supabase configured
* [ ] Database migrations complete
* [ ] RLS policies verified
* [ ] Storage policies verified
* [ ] Authentication verified
* [ ] Notifications verified
* [ ] AI API secured
* [ ] Release signing configured
* [ ] App icon finalized
* [ ] Splash screen finalized
* [ ] Version number updated
* [ ] No debug credentials
* [ ] No development URLs
* [ ] No test data
* [ ] No debug logs
* [ ] Flutter analyzer passes
* [ ] Unit tests pass
* [ ] Integration tests pass
* [ ] APK tested on physical device

---

# 📦 Final APK

The final production APK should be generated using:

```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

For multiple architectures:

```bash
flutter build apk --release --split-per-abi
```

For Play Store distribution, generate an Android App Bundle:

```bash
flutter build appbundle --release
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

---

# 🏆 Definition of Done

PayPaw is considered production-ready when:

* Users can securely create accounts
* Users can manage bills
* Recurring bills work automatically
* Payment statuses are accurate
* Reminders work reliably
* Upcoming obligations are clearly displayed
* Subscriptions can be tracked
* Debts can be managed
* Receipts can be attached
* Analytics accurately reflect user data
* AI features work safely
* Bills can be scanned
* Shared bills work correctly
* Sensitive data is protected
* The application performs well
* The application works offline where supported
* The APK installs successfully
* The release build passes final QA

---

# 🐾 PayPaw Release Goal

The final version of PayPaw should feel less like a simple **bill reminder** and more like a personal **financial obligations command center**.

The user should be able to open PayPaw and immediately answer:

> **What have I paid?**
> **What do I owe?**
> **What's due next?**
> **How much should I prepare?**
> **Can I afford to spend this money?**

### Final Product

**PayPaw 🐾**

> **Stay ahead of what you owe.**
