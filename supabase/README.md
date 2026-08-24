# Supabase

The database schema, as versioned SQL.

The design and the reasoning behind it are in
[`docs/database_schema.md`](../docs/database_schema.md). This directory is where
that design becomes real, one migration at a time.

## Why files and not the dashboard

A schema that exists only in a Supabase dashboard cannot be reviewed in a pull
request, cannot be recreated on a second project, and cannot be rolled back. These
files are the source of truth; the dashboard is just one way to apply them.

## Applying them

The Supabase CLI is not installed on this machine. Either route works, as long as
the files stay authoritative:

**Without installing anything**

```sh
npx supabase link --project-ref <your-project-ref>
npx supabase db push
```

**Or by hand**

Paste each file into the dashboard's SQL editor, **in filename order**. Order
matters: later migrations reference tables earlier ones create.

## Conventions

- `NNNN_short_name.sql`, four digits, applied in order.
- Idempotent wherever it is reasonable — `create table if not exists`,
  `create or replace function`. Applying a file twice by accident should be
  uneventful.
- One concern per file. A migration that creates three unrelated tables is three
  migrations that cannot be reverted separately.
- **Every table gets `enable row level security` in the same migration that
  creates it.** Not in a later one. In a Supabase project the publishable key is
  public, so a table that exists without RLS is a public table — and the window
  between the two migrations is a window where it is readable by anyone.

## Checks

`checks/` holds scripts that verify an applied database rather than change one.
Paste one into the SQL editor and read the result. **Each is written to raise on a
problem rather than to print a report** — a check whose output has to be read
carefully is a check that gets skimmed.

| File | Run it after | What it refuses to let pass |
|------|--------------|------------------------------|
| `rls_audit.sql` | any migration | a table in `public` without row level security, a policy-less table, a view that leaks past one |
| `user_isolation.sql` | any migration touching policies | one user's rows being visible to another |
| `recurrence_dates.sql` | `0016` | the SQL date arithmetic disagreeing with the app's, a missing `bills_occurrence_key`, a timezone name that stopped resolving |

`recurrence_dates.sql` is the one that matters most to keep running. The
recurrence arithmetic exists twice — `Recurrence.occurrenceAfter` in Dart drives
the preview, `next_recurrence_date` drives generation — and nothing in either
language can enforce that they agree. Its cases are deliberately the same cases as
`test/features/recurring/domain/entities/recurrence_generation_test.dart`.

## Status

Applied through `0016_generate_recurring_bills.sql`.

Two things are worth checking rather than assuming:

- **`pg_cron` must be enabled** (Database → Extensions) or `0016` skips scheduling
  the daily run and recurring bills are only generated when someone opens the app.
  The migration raises a `notice` when it skips.
- Run `checks/recurrence_dates.sql` after applying `0016`. It is the only thing
  standing between the two implementations of the date arithmetic.

See [`migrations/README.md`](migrations/README.md) for the list and for queries
that verify an apply.
