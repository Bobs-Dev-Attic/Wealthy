# Wealthy

A Flutter **Web** app for **tax & retirement planning**, deployed on **Vercel** and
backed by **Supabase**. You log in with a **QR code access code** (no email),
optionally protected by a password, and enter your financial picture to get
**Monte Carlo** projections, **withdrawal-rate** strategies, **RMD**, **Social
Security**, **healthcare** and **federal tax** estimates.

> This is a re-imagining of the old [TaxesHelper](https://github.com/Bobs-Dev-Attic/TaxesHelper)
> bookkeeping app — Wealthy focuses on *planning*, not transaction recording.
>
> ⚠️ Estimates only — **not tax or financial advice**.

## How it works

### QR-code login
- On sign-up, a Supabase **edge function** (`signup`) provisions a confirmed auth
  user whose login email is `<userId>@wealthy.local` and whose password is a
  generated high-entropy **access code**.
- The app shows that access code as a **QR code** plus a copyable backup key
  (`WLTH1|<userId>|<accessCode>`). Save it — it cannot be recovered.
- To log in, scan the QR or paste the backup key. Login is a plain client-side
  `signInWithPassword`, so all data access is gated by Postgres **Row Level
  Security** (`user_id = auth.uid()`).
- **Optional password** (Security screen) becomes a second factor by changing the
  auth password to `<accessCode>:<password>`; you then need both to log in.

### Planning engine (`lib/services/engine/`)
Pure Dart, unit-tested, shared by the deterministic projection and Monte Carlo:
- `tax.dart` — 2025 federal brackets, standard deduction, capital-gains stacking,
  Social Security taxation via provisional income.
- `rmd.dart` — IRS Uniform Lifetime Table, SECURE 2.0 start age 73.
- `social_security.dart` — claim-age adjustment + COLA.
- `healthcare.dart` — pre-Medicare vs Medicare cost growth.
- `withdrawal.dart` — 4% rule, fixed %, Guyton-Klinger guardrails, VPW.
- `retirement_projection.dart` — year-by-year cash-flow simulator (tax-efficient
  withdrawals: cash → RMD → taxable → traditional → Roth → HSA).
- `monte_carlo.dart` — N random-return paths → success rate + percentile bands.

## Project layout
```
lib/
  core/         config, theme, formatters
  models/       Profile, Account, IncomeSource, Expense, PlanAssumptions, results
  services/     auth_service, data_service, engine/*
  state/        Riverpod providers
  screens/      auth/ (signup, login, security), dashboard/, data/, projections/
  widgets/      shared scaffold + form fields
supabase/
  migrations/   0001_init.sql (schema + RLS), 0002_harden_seed_function.sql
  functions/    signup/ (Deno edge function)
test/           engine unit tests
```

## Supabase backend
- **Project:** `Wealthy` (ref `bdnvnyqvikcaujhjqemr`), region us-west-1.
- **Tables:** `profiles`, `accounts`, `income_sources`, `expenses`,
  `plan_assumptions` — all RLS-scoped to `auth.uid()`. A trigger seeds a profile
  and default assumptions on each new auth user.
- **Edge function:** `signup` (deployed with `--no-verify-jwt`, it's a public
  registration endpoint that uses the service-role key).

Re-apply locally with the Supabase CLI:
```bash
supabase link --project-ref bdnvnyqvikcaujhjqemr
supabase db push                      # applies migrations/
supabase functions deploy signup --no-verify-jwt
```

## Run locally
```bash
flutter pub get
flutter run -d chrome
# or build static assets:
flutter build web --release
```
Config defaults (in `lib/core/config.dart`) point at the live project; override at
build time if needed:
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

## Deploy to Vercel
`vercel.json` clones the Flutter SDK and runs `flutter build web`, serving
`build/web`. Set these Vercel **environment variables** (Build step):
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The anon key is a public client key; security is enforced by RLS.

## Tests
```bash
flutter test      # 21 engine/auth tests
flutter analyze
```

## Notes & limitations
- Federal tax only (state tax not modeled); brackets pinned to tax year 2025 in
  `tax.dart` and easy to update annually.
- Monte Carlo uses a single-factor market return per year (mean/stdev from
  assumptions); cash grows at a fixed 2%.
- Manual data entry only (account aggregation / CSV import is a future addition).
