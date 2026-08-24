# Migrations

Applied in filename order. See [`../README.md`](../README.md) for how, and
[`../../docs/database_schema.md`](../../docs/database_schema.md) for why the
schema looks like this.

| File | Sprint | What it does |
| --- | --- | --- |
| `0001_helpers.sql` | 17 | `set_updated_at()`, used by every table that has the column |
| `0002_profiles.sql` | 17 | `profiles`, the auth trigger that guarantees one, RLS |
| `0003_reminder_preferences.sql` | 17 | Per-user reminder defaults, RLS |

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
