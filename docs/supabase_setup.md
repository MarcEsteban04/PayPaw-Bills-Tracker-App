# PayPaw — Supabase Setup

Sprint 11. Everything on this page that touches the Supabase dashboard **has to
be done by hand** — creating a project needs an account, and no amount of code in
this repository can do it for you.

The app-side half is already done: configuration plumbing, the auth deep link,
and a client that fails with a useful message when configuration is missing. This
page is the other half, plus how to connect the two.

---

## 1. Create the project

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) and create a
   new project.
2. **Name:** `paypaw` (or `paypaw-dev` if you intend a separate production
   project later — recommended, and cheaper to decide now than to split later).
3. **Region:** pick the one closest to your users. For a Philippines-focused app
   that is Singapore (`ap-southeast-1`).
4. **Database password:** generate one and put it in a password manager. It is
   not used by the app — the app authenticates with the publishable key — but you
   need it for direct SQL access and for the Supabase CLI.

---

## 2. Copy the two values the app needs

**Project Settings → API keys**

| Dashboard field | Goes into |
| --- | --- |
| Project URL | `SUPABASE_URL` |
| Publishable key (`sb_publishable_…`) | `SUPABASE_PUBLISHABLE_KEY` |

Then:

```sh
cp config/dev.example.json config/dev.json
# fill in both values
```

`config/dev.json` is gitignored. See [`config/README.md`](../config/README.md).

> **Never put the `service_role` / secret key in this app.** It bypasses row
> level security entirely. It belongs only in an Edge Function or a server, never
> in a client build, no matter how well hidden you think a constant is.

---

## 3. Configure authentication

**Authentication → Sign In / Providers**

- Enable **Email**. That is the only provider PayPaw needs for Phase 3;
  social sign-in is not on the roadmap.
- Leave **Confirm email** on. It is one extra step for the user and it stops
  accounts being created against addresses that do not exist.

**Authentication → URL Configuration → Redirect URLs**

Add exactly this:

```
com.paypaw.app://login-callback
```

This must match `AppConfig.authRedirectUrl` and the intent filter in
`android/app/src/main/AndroidManifest.xml`. Supabase rejects any redirect not on
this list, and the failure is **silent from the app's side** — the email link
simply never returns to the app. If password recovery ever "does nothing", check
this list first.

**Authentication → Sessions**

Defaults are fine. Sessions persist on the device and refresh automatically;
Sprint 15 handles expiry and guards.

---

## 4. Configure the database

**Nothing to do yet, deliberately.**

PayPaw's schema is designed in Phase 4 (Sprints 16–20), and inventing tables now
would mean redesigning them then. Two things to know when you get there:

- Every table gets **row level security enabled** with a policy scoping rows to
  `auth.uid()`. A table without RLS in a Supabase project is a public table, and
  the publishable key is public.
- Prefer **versioned migrations** over clicking in the dashboard, so the schema
  lives in this repository and can be recreated. `supabase init` plus
  `supabase/migrations/*.sql` is the path; worth setting up at the start of
  Sprint 16 rather than retrofitting.

---

## 5. Configure storage

Also **nothing to do yet**. Receipt attachments arrive in Sprints 57–59, and the
bucket's policies depend on the schema. When you get there it will be one private
bucket with per-user path prefixes, not a public bucket.

---

## 6. Check it worked

```sh
flutter run --dart-define-from-file=config/dev.json
```

- **Configured correctly:** the app starts silently, as before.
- **Missing or misspelled values:** the console prints exactly what is missing
  and what to do about it, and the app still runs without a backend.

There is no sign-in screen to test against yet — that is Sprint 12. What this
sprint delivers is that the client comes up, and that a wrong configuration says
so instead of crashing later somewhere unrelated.

---

## Working without a backend

Every sprint so far was built with no Supabase project at all, and that keeps
working: launch without the config file (VS Code's **PayPaw (no backend)**
configuration) and the app runs normally. Anything that reads
`supabaseClientProvider` throws with a message naming the cause.

That is deliberate. A missing backend should be loud at the boundary rather than
producing empty screens with no explanation.
