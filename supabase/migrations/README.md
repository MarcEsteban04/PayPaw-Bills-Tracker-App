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
| `0008_debts.sql` | 19 | `debts`, one table with a direction, RLS |
| `0009_payments.sql` | 19 | `payments`, one target enforced by CHECK, RLS |
| `0010_attachments.sql` | 19 | Storage metadata, owner-scoped path CHECK, RLS |
| `0011_bill_reminders.sql` | 19 | Per-bill overrides, RLS |
| `0012_bill_status.sql` | 19 | The derived-status view, `security_invoker` |
| `0013_storage_attachments.sql` | 20 | Private receipts bucket, owner-scoped policies |

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

## Sprint 19 verification

The first two matter more than the rest.

```sql
-- 1. RLS is on for everything new.
select relname, relrowsecurity as rls_enabled
from pg_class
where relname in ('debts', 'payments', 'attachments', 'bill_reminders')
order by relname;
-- expect true for all four

-- 2. THE IMPORTANT ONE. The status view must run as the caller, not its definer.
--    Without security_invoker a view bypasses RLS on the tables underneath and
--    returns every user's bills to anyone — while looking like it works.
select relname, reloptions
from pg_class
where relname = 'bill_status';
-- expect reloptions to contain security_invoker=true

-- 3. A payment must have exactly one target. Both of these must FAIL:
insert into public.payments (user_id, amount_minor) values (auth.uid(), 100);
-- expect: violates check constraint "payments_single_target"  (neither target)

-- 4. An attachment path must start with the owner's id. This must FAIL:
insert into public.attachments
  (user_id, bill_id, storage_path, file_name, mime_type, size_bytes)
values (auth.uid(), '<a bill id>', 'somewhere/else.jpg', 'r.jpg', 'image/jpeg', 100);
-- expect: violates check constraint "attachments_path_is_owner_scoped"

-- 5. A bill with no payments reads as upcoming/due_soon/overdue by its date, and
--    partial payments show up without changing the status to "paid":
select bill_id, amount_minor, paid_minor, outstanding_minor, status, today
from public.bill_status
order by due_on;
```

## Migration count

Twelve files, covering every table in
[`docs/database_schema.md`](../../docs/database_schema.md) except `bill_shares`,
which is deliberately deferred to Sprint 75 — see that document for why.

## Sprint 20: checks, not migrations

Every migration already enables RLS in the file that creates its table, so Sprint
20 adds no policies — it adds proof. Two re-runnable scripts in
[`../checks/`](../checks/):

| Script | What it does |
| --- | --- |
| `rls_audit.sql` | **Raises** if any public table lacks RLS, has RLS but no policies, or any view lacks `security_invoker=true` |
| `user_isolation.sql` | Impersonates two accounts and proves neither can read or write the other's rows |

Run `rls_audit.sql` after every migration. Run `user_isolation.sql` after any
change to a policy, and after adding any table.

The reasoning behind all of it, including the three ways to bypass RLS by
accident, is in [`../../docs/security.md`](../../docs/security.md).
