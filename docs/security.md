# PayPaw — Data Security

Sprint 20 deliverable. How one account's data is kept away from another's, and how
to prove it rather than assume it.

---

## The one fact everything follows from

**The publishable key is public.** It ships inside the APK. Anyone can extract it
in a couple of minutes, and it is *designed* to be extractable — that is what a
publishable key is for.

So a table in the `public` schema without Row Level Security is not "protected by
the app". It is a public table with a slightly inconvenient URL.

Every other rule here is a consequence of that.

---

## The model

Every user-owned table carries `user_id uuid not null references auth.users(id)`,
and every policy is a comparison against `auth.uid()`:

```sql
alter table public.bills enable row level security;

create policy "bills belong to their owner"
  on public.bills for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
```

### `using` and `with check` are different questions

- `using` — which existing rows can I see and modify?
- `with check` — what am I allowed to write?

Both, always. A policy with only `using` lets a client **insert a row belonging to
someone else** and then lose sight of it: data written into a stranger's account,
invisible to the person who wrote it. `supabase/checks/user_isolation.sql` case 3
is that exact attempt.

### RLS is created with the table, never after

Every migration enables RLS in the same file that creates its table. Splitting
them leaves a window — however short — in which the table exists and is readable
by anyone with the key. There is no reason to accept that window.

### Explicit grants

Each migration also does:

```sql
revoke all on public.<table> from anon;
grant select, insert, update, delete on public.<table> to authenticated;
```

RLS decides *which rows*; grants decide whether the role may reach the table at
all. Being explicit rather than relying on the project's default privileges means
these files behave identically on a fresh project.

---

## The three ways to bypass RLS

All three are easy to do by accident and none of them looks like a mistake.

### 1. A secret key in the client

A `service_role` or `sb_secret_` key **bypasses every policy in the database**. It
is one line away from the publishable key in the dashboard, and two lines away in
a `.env` file.

The app refuses to start Supabase with one. `AppConfig.keyLooksSecret` recognises
both the `sb_secret_` prefix and a legacy JWT claiming `role: service_role`, and a
secret key is reported as *unconfigured* — so the app takes the no-backend path
every screen already handles instead of connecting with credentials that defeat
the entire schema. Covered by
[`test/core/config/secret_key_guard_test.dart`](../test/core/config/secret_key_guard_test.dart).

The guard is conservative: a key it cannot decode is treated as *not proven
secret*, because refusing to launch on a valid-but-unfamiliar key would be its own
outage. It catches the obvious mistake; it is not a substitute for care.

Secret keys belong in an Edge Function or a server. Nowhere else.

### 2. A view without `security_invoker`

A Postgres view runs with its **definer's** privileges by default, which means it
ignores RLS on the tables underneath. A view over `bills` will happily return
every user's bills to any caller — and look like it is working perfectly, because
it is doing exactly what it was told.

```sql
create or replace view public.bill_status
with (security_invoker = true) as ...
```

`rls_audit.sql` fails on any view in `public` missing that setting, and
`user_isolation.sql` case 4 checks the view specifically — separately from the
table — because this is the failure where direct queries are correctly empty while
the view leaks.

### 3. A `security definer` function

Sometimes necessary: `handle_new_user` has to insert into `profiles` from a
sign-up that has no rights to write there. When it is necessary, the function
pins its search path:

```sql
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$ ... $$;
```

Without `set search_path = ''` a definer function can be made to resolve an
unqualified name against a schema the caller controls, running the caller's code
with elevated privileges. With it, every name must be fully qualified — which is
why these functions read verbosely.

---

## Storage

Receipts live in a **private** bucket. Objects are reachable only through policies,
and the policies match on the first path segment:

```
{user_id}/bills/{bill_id}/{uuid}.{ext}
```

`(storage.foldername(name))[1] = auth.uid()::text`

This is why the path convention is not a style preference. A path shaped any other
way **cannot be secured this way**, and the failure is silent — the metadata row
looks fine and the file is readable by the wrong person.

Two things keep that from happening:

- `public.attachments` has a CHECK requiring `storage_path` to start with the
  owner's id, so a row can never record an unprotectable path.
- The bucket migration uses `on conflict do update`, so re-running it re-asserts
  `public = false`. If the bucket is ever flipped public by hand, applying
  migrations puts it back.

Every storage policy is scoped `to authenticated`. Without that a policy also
applies to `anon`, whose `auth.uid()` is null — it still fails, but by accident
rather than by design.

---

## Verifying it

Two scripts, both re-runnable, in [`supabase/checks/`](../supabase/checks/).

### `rls_audit.sql`

Run after every migration. It **raises** rather than reports — a security check
whose output has to be read carefully is a check that gets skimmed. It fails on:

- any table in `public` with RLS disabled;
- any table with RLS on but no policies (safe, but unreachable — usually a
  half-applied migration);
- any view without `security_invoker=true`.

### `user_isolation.sql`

The one that actually matters. RLS being *enabled* and RLS being *correct* are
different claims, and only the second one matters to a user.

It sets `request.jwt.claims` and the `authenticated` role by hand, which is
precisely what PostgREST does for a signed-in request — so it reproduces what a
real client sees without a second device or a second app build. Six cases, each
wrapped in `begin`/`rollback`:

1. Each account sees only its own bills.
2. B cannot read a specific bill of A's, **even knowing its id**. The result is
   empty rather than an error, because an error would itself confirm the row
   exists.
3. B cannot write a row owned by A. This is what `with check` is for.
4. B cannot reach A's bills through the status view.
5. The shared categories are readable and not writable.
6. An anonymous caller — the state anyone who decompiles the app can reach — sees
   nothing.

Run it after any change to a policy, and after adding any table.

---

## Deliberately deferred

**Share-aware policies.** `bill_shares` is designed in
[`docs/database_schema.md`](database_schema.md) but not created. Owner-only RLS is
one line that is obviously correct and trivially testable. Share-aware RLS needs a
`can_access_bill()` helper consulted by bills, payments, attachments and
reminders, and every one of those policies becomes harder to be sure of.

Sharing arrives in Sprint 75. Paying that complexity now would mean fifty-five
sprints of harder-to-verify policies guarding a feature that does not exist. The
table and the policy change land together.

**Rate limiting and abuse controls** are Supabase's, configured in the dashboard,
not schema. Worth reviewing before release rather than now.

---

## If a key leaks

1. Rotate it in **Project Settings → API keys**. A publishable key rotation is
   low-drama; a *secret* key rotation is urgent, because that key ignores every
   policy in this document.
2. Rebuild `config/dev.json` and any release config.
3. If the leaked key was a secret one, assume every row was readable and act
   accordingly.

`config/*.json` and `.env*` are both gitignored, and GitHub's push protection has
already caught one commit that would have published third-party keys — which is
the reason the ignore rules exist rather than a hypothetical.
