# Environment configuration

Build-time values for PayPaw, passed to the app with
`--dart-define-from-file`. JSON has no comments, so the explanation lives here.

| File | Committed | Purpose |
| --- | --- | --- |
| `dev.example.json` | yes | The shape of the file, with placeholder values |
| `dev.json` | **no** | Your real development values |
| `prod.json` | **no** | Release values, added at the release sprints |

## Setup

```sh
cp config/dev.example.json config/dev.json
# then fill in the two values from your Supabase project
```

Run with:

```sh
flutter run --dart-define-from-file=config/dev.json
```

In VS Code the **PayPaw (dev)** launch configuration already passes it.

Where the values come from, and what to configure in the Supabase dashboard:
[`docs/supabase_setup.md`](../docs/supabase_setup.md).

## Why a file rather than a `.env`

`--dart-define-from-file` is built into the Flutter tool, so there is no extra
dependency, nothing to load at runtime, and no risk of an `.env` file being
bundled into the APK as an asset. The values are compiled in as constants, which
is also why `AppConfig` can expose them as `const`.

**The publishable key is not a secret** — row level security is what protects the
data, not key secrecy. These files are gitignored anyway, because a project URL
plus a key is still something worth not publishing by accident, and because
`prod.json` will eventually sit next to `dev.json`.
