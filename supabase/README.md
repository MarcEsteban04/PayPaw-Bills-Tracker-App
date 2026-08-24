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

## Status

Sprint 17 **written, not yet applied**: `profiles`, `reminder_preferences` and the
shared `set_updated_at` helper. Nothing exists in the database until someone runs
them. See [`migrations/README.md`](migrations/README.md) for the
list and for queries that verify an apply.
