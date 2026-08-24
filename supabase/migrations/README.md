# Migrations

Applied in filename order. See [`../README.md`](../README.md) for how, and
[`../../docs/database_schema.md`](../../docs/database_schema.md) for why the
schema looks like this.

| File | Sprint | What it does |
| --- | --- | --- |
| `0001_helpers.sql` | 17 | `set_updated_at()`, used by every table that has the column |
| `0002_profiles.sql` | 17 | `profiles`, the auth trigger that guarantees one, RLS |
| `0003_reminder_preferences.sql` | 17 | Per-user reminder defaults, RLS |
| `0004_categories.sql` | 18 | `categories`, 13 seeded system rows, RLS |
| `0005_recurring_bills.sql` | 18 | The repeating-obligation template, RLS |
| `0006_subscriptions.sql` | 18 | 1:1 extension for subscription-only fields |
| `0007_bills.sql` | 18 | `bills`, the idempotent-generation index, RLS |

## Verifying an apply

After applying, these should all hold. Run them in the SQL editor.

```sql
-- 1. Every account has a profile.
select count(*) as accounts_without_profiles
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);
-- expect 0

-- 2. RLS is on. A row here with rls_enabled = false is a public table.
select relname, relrowsecurity as rls_enabled
from pg_class
where relname in ('profiles', 'reminder_preferences');
-- expect true for both

-- 3. The trigger fires. Sign up a throwaway account in the app, then:
select id, display_name, currency, time_zone from public.profiles;
-- expect a row for the new account, display_name from the email local part
```

The real isolation test — proving one account cannot read another's rows — is
Sprint 20's job, once there is something worth isolating.

## Sprint 18 verification

```sql
-- 1. The shared categories are there exactly once.
select count(*) as system_categories
from public.categories where user_id is null;
-- expect 13

-- 2. Every new table has RLS on. A false here is a public table.
select relname, relrowsecurity as rls_enabled
from pg_class
where relname in ('categories', 'recurring_bills', 'subscriptions', 'bills')
order by relname;
-- expect true for all four

-- 3. The recurrence shape constraint bites. This must FAIL:
insert into public.recurring_bills
  (user_id, kind, name, amount_minor, frequency, starts_on, next_due_on)
values (auth.uid(), 'bill', 'broken', 100, 'monthly', current_date, current_date);
-- expect: violates check constraint "recurring_bills_recurrence_shape"
-- (monthly needs day_of_month)

-- 4. Generation cannot duplicate an occurrence. Insert the same
--    (recurring_bill_id, due_on) twice — the second must fail on
--    "bills_occurrence_key".
```

Re-running any of these files is safe: the tables use `if not exists`, the
policies are dropped before being created, and the category seed skips rows that
already exist.
