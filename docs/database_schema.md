# PayPaw — Database Design

Sprint 16 deliverable: the schema, decided before any of it is created. Sprints
17–19 turn this into tables and Sprint 20 adds Row Level Security.

Nothing here is applied yet. That is the point — a schema is far cheaper to argue
about in a document than to migrate after Phase 5 has been built on top of it.

---

## Conventions

These apply to **every** table, so they are stated once.

### Identity

`id uuid primary key default gen_random_uuid()`

Not `bigint identity`. A sequential id leaks how many rows exist, and more
practically, a UUID can be generated **on the client**, which is what lets a bill
be created optimistically and reconciled later without a round trip for its key.

### Ownership

`user_id uuid not null references auth.users(id) on delete cascade`

On every user-owned table, no exceptions. RLS policies key off
`auth.uid() = user_id`, so a table without this column is a table that cannot be
secured. `on delete cascade` because a deleted account should take its data with
it.

### Timestamps

```sql
created_at timestamptz not null default now(),
updated_at timestamptz not null default now()
```

`timestamptz`, never `timestamp`. A bare timestamp has no timezone and silently
means something different depending on who reads it. `updated_at` is maintained by
a trigger rather than by the client, because a client that forgets is a client
that produces quietly wrong audit data.

### Money: integer minor units

**Every amount is a `bigint` of centavos, and every such column is named with a
`_minor` suffix.**

```sql
amount_minor bigint not null check (amount_minor >= 0)
```

Three reasons, in order of importance:

1. **Exactness.** Binary floating point cannot represent `0.1`. A bills app that
   loses centavos to rounding is broken in the one way its users will notice.
2. **No ambiguity crossing the wire.** Postgres `numeric` is exact, but PostgREST
   serialises it as a JSON *string* to preserve precision, so the client has to
   parse it into a decimal type — and the moment someone reaches for `double.parse`
   the exactness is gone. A `bigint` arrives as a Dart `int` and stays exact with
   no dependency and no parsing decision to get wrong.
3. **The suffix is the safety feature.** `amount_minor` cannot be mistaken for
   pesos the way `amount` can. Formatting to `₱1,234.50` happens once, at display.

The cost is that ad-hoc SQL shows `123450` instead of `1234.50`. That is a fair
trade for arithmetic that is never wrong.

### Currency

`currency char(3) not null default 'PHP'`

Present even though PayPaw is Philippines-first, because subscriptions are the
obvious exception — plenty of Filipino users pay Netflix or Spotify in USD. Adding
the column now costs three bytes; adding it after Phase 5 means migrating every
amount in the app.

### Dates versus instants

- **A due date is a `date`.** A bill is due *on a day*, not at an instant. Stored
  as `timestamptz` it would shift across timezones and a bill due on the 1st could
  read as due on the 31st for someone who travels.
- **A payment is a `timestamptz`.** That genuinely happened at a moment.

This distinction is easy to get backwards and expensive to fix.

### Naming

`snake_case`, plural table names, singular column names. Foreign keys are
`<table_singular>_id`. Booleans read as assertions (`is_active`, not `active`).
Nullable timestamps that record an event read as `<verb>_at` (`archived_at`,
`accepted_at`) — a null then means "has not happened", which is more useful than a
boolean plus a separate date.

---

## How the pieces relate

```
auth.users
   └── profiles                     1:1, created by trigger
         ├── categories             user-owned, plus shared system rows
         ├── recurring_bills        the template for a repeating obligation
         │     ├── subscriptions    1:1 extension, subscription-only fields
         │     └── bills            generated instances
         ├── bills                  one dated obligation
         │     ├── payments         full or partial
         │     ├── attachments      receipts, stored in Supabase Storage
         │     ├── bill_reminders   per-bill reminder overrides
         │     └── bill_shares      who else can see it        (Sprint 75+)
         ├── debts                  money owed, either direction
         │     └── payments         same table, different target
         └── reminder_preferences   1:1, the user's defaults
```

---

## Tables

### `profiles`

The app's own row per account. `auth.users` belongs to Supabase and should not be
extended directly.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | **References `auth.users(id)`** — not a fresh uuid |
| `display_name` | `text` | |
| `avatar_url` | `text` null | Supabase Storage path |
| `currency` | `char(3)` | Default for new bills |
| `locale` | `text` | e.g. `en_PH` |
| `time_zone` | `text` | Needed to decide when "today" starts for reminders |
| `created_at` / `updated_at` | `timestamptz` | |

Created by an `after insert` trigger on `auth.users`, so a profile always exists
by the time the app reads one. Doing it from the client means a crash between
sign-up and profile creation leaves an account with no profile.

`time_zone` is not decoration: "due today" and a reminder fired at 9am both depend
on it, and it cannot be inferred reliably from the device at scheduling time.

### `categories`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | |
| `user_id` | `uuid` **null** | Null means a system category everyone sees |
| `name` | `text` | |
| `icon_name` | `text` | Material icon identifier, not an image |
| `color_hex` | `char(7)` null | Null falls back to a palette colour |
| `sort_order` | `int` | |

`user_id` is the one nullable ownership column in the schema. Null rows are the
seeded defaults (Electricity, Water, Internet, Rent, Subscription…); a user's own
categories carry their id. The RLS read policy is therefore
`user_id is null or user_id = auth.uid()`, and writes require ownership — so
nobody can edit the shared rows.

Icons are stored as **names**, not images, so the app can render them with the
icon font it already ships and a category list costs no network requests.

### `bills`

One dated obligation. The centre of the schema.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | |
| `user_id` | `uuid` | |
| `category_id` | `uuid` null | `on delete set null` — deleting a category must not delete bills |
| `recurring_bill_id` | `uuid` null | Set when generated from a template |
| `name` | `text` | "Meralco electricity" |
| `payee` | `text` null | |
| `amount_minor` | `bigint` | The amount due |
| `currency` | `char(3)` | |
| `due_on` | `date` | |
| `notes` | `text` null | |
| `archived_at` | `timestamptz` null | |
| `created_at` / `updated_at` | `timestamptz` | |

**Archived, not deleted.** A bill with payment history should not be removable,
because deleting it would take the history with it and quietly change what the
user paid last month. So: `payments.bill_id` is `on delete restrict`, and the UI
offers *archive* for bills that have been paid. A bill with no payments can still
be hard-deleted — that is a mistake being corrected, not history being erased.

### Bill status is **derived**, not stored

Sprint 18's checklist says "bill statuses", and this is the one place the plan
deliberately differs from it.

`upcoming`, `due soon`, `overdue`, `partially paid` and `paid` are all functions
of `due_on`, `amount_minor` and the payments recorded against the bill. Storing
them means two sources of truth, and the stored one is wrong every midnight — a
bill that was "due soon" yesterday is "overdue" today, with no write to trigger an
update. Every app that stores derived status ends up with a nightly job to repair
it.

So a view computes it:

```sql
create view bill_status as
select b.id as bill_id,
       b.user_id,
       coalesce(sum(p.amount_minor), 0) as paid_minor,
       case
         when coalesce(sum(p.amount_minor), 0) >= b.amount_minor then 'paid'
         when b.due_on < current_date                            then 'overdue'
         when coalesce(sum(p.amount_minor), 0) > 0               then 'partially_paid'
         when b.due_on <= current_date + 3                       then 'due_soon'
         else 'upcoming'
       end as status
from bills b
left join payments p on p.bill_id = b.id
group by b.id;
```

What *is* stored is the lifecycle the data cannot derive: `archived_at`. That is
a decision the user made, not a consequence of dates.

The three-day "due soon" window belongs in one place. It lives here and in
`AppStatusTone` on the client; Sprint 18 should make it a single constant.

### `recurring_bills`

The template. Instances live in `bills`.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | |
| `user_id` | `uuid` | |
| `category_id` | `uuid` null | |
| `kind` | `text` check | `bill` or `subscription` |
| `name`, `payee` | `text` | |
| `amount_minor` | `bigint` | The expected amount |
| `currency` | `char(3)` | |
| `frequency` | `text` check | `weekly`, `monthly`, `quarterly`, `yearly` |
| `interval_count` | `int` default 1 | "every 2 months" |
| `day_of_month` | `int` null | 1–31, or `-1` for last day |
| `weekday` | `int` null | 1–7, for weekly |
| `month_of_year` | `int` null | 1–12, for yearly |
| `starts_on` | `date` | |
| `ends_on` | `date` null | |
| `next_due_on` | `date` | The next instance to generate |
| `is_active` | `boolean` | |

**Structured columns, not an RRULE string.** An iCal RRULE handles every case
imaginable, and PayPaw's UI will offer perhaps six — so the flexibility buys
nothing and costs a parser plus a recurrence library. If a genuinely custom rule
is ever needed, an `rrule text` column can be added beside these and take
precedence.

`day_of_month = -1` for "last day of the month" rather than storing 31 and hoping:
February exists.

**Instances are generated, not implied.** A template plus a rule could compute
occurrences on the fly, but each occurrence needs to be paid, edited and attached
to independently — so each becomes a real `bills` row. Generation creates the next
instance when the current one is settled or its date passes, driven by the client
on open and later by a scheduled Edge Function. `next_due_on` is the bookmark that
keeps that idempotent.

### `subscriptions`

A 1:1 extension of `recurring_bills where kind = 'subscription'`.

| Column | Type | Notes |
| --- | --- | --- |
| `recurring_bill_id` | `uuid` PK/FK | |
| `provider` | `text` | "Netflix" |
| `plan_name` | `text` null | |
| `trial_ends_on` | `date` null | |
| `auto_renews` | `boolean` | |
| `cancellation_url` | `text` null | |

A subscription **is** a recurring obligation — same recurrence, same amount, same
generation. Making it a separate table would mean a second copy of all of that,
and the day they drift is the day monthly bills work and monthly subscriptions do
not. The extension table holds only what is genuinely subscription-specific.

### `payments`

Full and partial payments, against a bill **or** a debt.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | |
| `user_id` | `uuid` | |
| `bill_id` | `uuid` null | `on delete restrict` |
| `debt_id` | `uuid` null | `on delete cascade` |
| `amount_minor` | `bigint` check > 0 | |
| `currency` | `char(3)` | |
| `paid_at` | `timestamptz` | |
| `method` | `text` null | `gcash`, `maya`, `bank_transfer`, `cash`, … |
| `reference` | `text` null | The reference number from the receipt |
| `note` | `text` null | |

```sql
check (num_nonnulls(bill_id, debt_id) = 1)
```

One table with two nullable targets and that constraint, rather than a polymorphic
`target_type`/`target_id` pair. Text-keyed polymorphism gives up foreign keys
entirely, which means nothing stops a payment pointing at a row that no longer
exists — and RLS on such a table cannot be expressed simply. Two real foreign keys
plus a check keeps referential integrity and keeps the policies readable.

**Partial payments need no special handling.** They are simply payments that sum
to less than `amount_minor`, which the status view already accounts for. A
`is_partial` flag would be another derived value waiting to go stale.

`method` is free text with a documented vocabulary rather than an enum, because
payment methods in the Philippines are a moving target and an enum change is a
migration.

### `debts`

Utang, both directions.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | |
| `user_id` | `uuid` | |
| `direction` | `text` check | `i_owe` or `owed_to_me` |
| `counterparty_name` | `text` | |
| `counterparty_contact` | `text` null | |
| `principal_minor` | `bigint` | |
| `currency` | `char(3)` | |
| `incurred_on` | `date` | |
| `due_on` | `date` null | Debts often have no date |
| `notes` | `text` null | |
| `settled_at` | `timestamptz` null | |

One table with a `direction` rather than two tables. The fields are identical and
the queries are the same shape; two tables would mean every debt feature written
twice.

`counterparty_name` is text, not a reference to a user. The person you owe money
to is usually not a PayPaw user, and requiring them to be would make the feature
useless.

### `attachments`

Metadata for files that live in Supabase Storage.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | |
| `user_id` | `uuid` | |
| `bill_id` | `uuid` null | |
| `payment_id` | `uuid` null | |
| `storage_path` | `text` unique | |
| `file_name` | `text` | The name the user recognises |
| `mime_type` | `text` | |
| `size_bytes` | `bigint` | |
| `created_at` | `timestamptz` | |

```sql
check (num_nonnulls(bill_id, payment_id) >= 1)
```

Files are **not** stored in the database. A receipt photo is a megabyte; putting
it in a row makes every query that touches the table slow and every backup huge.

**The storage path convention is load-bearing:**

```
{user_id}/bills/{bill_id}/{uuid}.{ext}
```

Storage RLS matches on the first path segment, so beginning the path with the
owner's id is what makes "only this user can read this file" expressible as a
policy. A path shaped any other way cannot be secured that way.

### `reminder_preferences` and `bill_reminders`

Notifications are *delivered* by `flutter_local_notifications` on the device. The
database stores the **rules**, so they survive a reinstall and follow the user to
a second device — a reminder that only exists in one device's scheduler is a
reminder that quietly disappears.

`reminder_preferences` — 1:1 with the profile:

| Column | Type | Notes |
| --- | --- | --- |
| `user_id` | `uuid` PK/FK | |
| `days_before` | `int[]` | e.g. `{3,1,0}` |
| `time_of_day` | `time` | Local to `profiles.time_zone` |
| `is_enabled` | `boolean` | |

`bill_reminders` — per-bill overrides only, so the common case stores nothing:

| Column | Type | Notes |
| --- | --- | --- |
| `bill_id` | `uuid` PK/FK | |
| `days_before` | `int[]` null | |
| `time_of_day` | `time` null | |
| `is_enabled` | `boolean` null | Null means "inherit" |

No `notification_log` table for now. Nothing would read it, and a log nobody
queries is a table nobody maintains.

### `bill_shares` — designed now, enforced later

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | |
| `bill_id` | `uuid` | |
| `owner_id` | `uuid` | Denormalised, so policies need no join to `bills` |
| `shared_with_user_id` | `uuid` null | Null until the invite is accepted |
| `invited_email` | `text` | |
| `role` | `text` check | `viewer` or `editor` |
| `invited_at` / `accepted_at` | `timestamptz` | |

**Recommendation: create this table in Sprint 75, not now.**

Sharing is the one feature that changes the shape of every policy in the database.
Owner-only RLS is `auth.uid() = user_id` — one line, obviously correct, trivially
testable. Share-aware RLS needs a `can_access_bill(bill_id)` helper consulted by
bills, payments, attachments and reminders, and every one of those policies gets
harder to reason about.

Paying that cost in Sprint 20 for a feature arriving in Sprint 75 means fifty-five
sprints of harder policies protecting nothing. The design is recorded here so the
extension is planned rather than improvised; the table and the policy change land
together when the feature does.

---

## Indexes

Beyond the primary keys:

```sql
create index on bills (user_id, due_on);              -- the dashboard's main query
create index on bills (user_id, archived_at);
create index on bills (recurring_bill_id);
create index on payments (bill_id);
create index on payments (debt_id);
create index on payments (user_id, paid_at desc);     -- payment history
create index on debts (user_id, settled_at);
create index on attachments (bill_id);
create index on categories (user_id, sort_order);
```

Every one is `user_id`-leading where a user-scoped query exists, because RLS adds
`user_id = auth.uid()` to *every* query — an index that ignores it cannot be used.

---

## Row Level Security (Sprint 20)

**Enable RLS on every table.** In a Supabase project the publishable key is
public, so a table without RLS is a public table. This is the single most
important line in this document.

The shape for every user-owned table:

```sql
alter table bills enable row level security;

create policy "own bills" on bills
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

`using` governs which rows are visible; `with check` governs what may be written.
Both are needed — `using` alone would let a user insert a row belonging to someone
else, then lose sight of it.

`categories` is the exception, because of the shared system rows:

```sql
create policy "read own and system categories" on categories
  for select using (user_id is null or user_id = auth.uid());

create policy "write only own categories" on categories
  for insert with check (user_id = auth.uid());
```

Storage gets a matching policy keyed on the first path segment, which is why the
path convention above starts with the owner's id.

Sprint 20 also has to **test** this, not just write it: a second account must be
unable to read the first account's bills. That is a test, not an inspection.

---

## Applying migrations

Migrations are **versioned SQL files in this repository**, not clicks in the
dashboard. A schema that exists only in a dashboard cannot be reviewed, cannot be
recreated, and cannot be rolled back.

```
supabase/migrations/
  0001_profiles.sql
  0002_categories.sql
  ...
```

The Supabase CLI is not installed on this machine. Either option works:

- `npx supabase link` then `npx supabase db push` — no global install.
- Or paste each file into the dashboard's SQL editor **in order**. The files stay
  the source of truth either way.

Every migration must be idempotent where it reasonably can be
(`create table if not exists`, `create or replace function`), because the second
time a file is applied by accident should be uneventful.

---

## Decisions deferred

| Question | Deferred to | Why |
| --- | --- | --- |
| Share-aware RLS policies | Sprint 75 | Fifty-five sprints of harder policies for a feature not yet built |
| `notification_log` | When something reads it | A log nobody queries is a table nobody maintains |
| Soft delete on every table | Not planned | `archived_at` on bills covers the case that matters; the rest can be deleted |
| Multi-currency conversion | Post-1.0 | Storing `currency` is enough for now; rates and conversion are a feature, not a column |
| An `rrule` column | If a user needs a custom rule | The structured columns cover every option the UI will offer |

---

## What Sprints 17–20 do with this

| Sprint | Tables |
| --- | --- |
| 17 | `profiles` (+ the auth trigger), `reminder_preferences` |
| 18 | `categories` (+ seed rows), `bills`, `recurring_bills`, `subscriptions`, the `bill_status` view |
| 19 | `payments`, `debts`, `attachments`, `bill_reminders` |
| 20 | RLS on all of it, plus a cross-account isolation test |
