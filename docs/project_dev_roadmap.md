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
  something is actually being held back. Sprint 36 groups them by Today /
  Tomorrow / This week.
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
capped and the summary card is not reused — two tabs opening on the same card
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

## Sprint 36 — Upcoming Payments

* Today
* Tomorrow
* This week
* Next week
* Later

## Sprint 37 — Quick Actions

Add:

* Add bill
* Mark paid
* Add debt
* Add subscription
* View calendar

## Sprint 38 — Dashboard Polish

* Animations
* Loading states
* Empty states
* Error states
* Performance optimization

---

# 🔔 Phase 8 — Notifications

## Sprint 39 — Notification Infrastructure

* Configure local notifications
* Android notification channels
* Notification permissions

## Sprint 40 — Bill Reminders

Implement:

* 7-day reminder
* 3-day reminder
* 1-day reminder
* Due-date reminder

## Sprint 41 — Overdue Notifications

* Detect overdue bills
* Notify users
* Prevent notification spam

## Sprint 42 — Notification Settings

* Global reminder settings
* Per-bill settings
* Enable/disable notifications
* Custom reminder times

## Sprint 43 — Notification Testing

Test:

* App closed
* Device restarted
* Time zone changes
* Multiple reminders
* Recurring bills

---

# 📅 Phase 9 — Payment Calendar

## Sprint 44 — Calendar UI

* Monthly calendar
* Weekly view
* Daily view
* Navigation

## Sprint 45 — Payment Indicators

Display:

* Paid
* Upcoming
* Overdue
* Partially paid

## Sprint 46 — Calendar Interaction

* Tap date
* View bills
* Open bill details
* Add bill from date

## Sprint 47 — Calendar Optimization

* Smooth navigation
* Large dataset support
* Performance optimization

---

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
