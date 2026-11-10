# Glow Derma — mobile app

The customer app for iOS and Android, built with [Flutter](https://flutter.dev) (one Dart codebase, two native
apps). It talks to the same Django API as the website, through the customer contract
[`backend/docs/api/customer-api-v1.md`](https://github.com/GlowDermatology/backend/blob/main/docs/api/customer-api-v1.md).

| Tab | What it does |
|---|---|
| **Katalog** | banners, categories, search, products, product page, add to cart |
| **QR** | the in-store cashback QR (new code every 50 s), cashback balance and history |
| **Savat** | server cart → checkout (pickup or BTS delivery, cashback) → Click / Payme → order tracking |
| **AI** | placeholder ("Tez orada") — the backend has no AI endpoints yet |
| **Sozlamalar** | profile, orders, appointments, specialists and booking, language, theme, legal texts, sessions, sign-out, account deletion |

Guests can browse the catalog, specialists and legal texts; everything else asks to sign in (phone + SMS code +
password).

## New to mobile development? Start here

- **[docs/setup.md](docs/setup.md)** — what *you* need to do: Firebase, Google Play, Apple, signing keys, and every
  setting the servers need.
- **[docs/running-locally.md](docs/running-locally.md)** — run the app on your Android phone, an emulator or in
  Chrome, against the staging server or a backend on your computer.
- **[docs/architecture.md](docs/architecture.md)** — how the code is organised and why.
- **[docs/release.md](docs/release.md)** — building and publishing to the stores.
- **[docs/env.md](docs/env.md)** — every build option and every server variable the app depends on.

## Commands

```bash
flutter pub get                       # install dependencies
flutter analyze                       # static checks (must say "No issues found!")
flutter test                          # unit and widget tests
dart format lib test                  # format the code
flutter run --dart-define-from-file=tool/defines/staging.json      # run on a connected phone, against staging
flutter build apk --debug --dart-define-from-file=tool/defines/staging.json   # an installable Android file
```

Build options come from `tool/defines/*.json` (`--dart-define-from-file`); nothing in them is secret.

## Repository layout

```
lib/
  main.dart            boot: storage, device id, optional Firebase, providers
  app/                 app widget, router (all routes), tab shell, theme (design tokens), app-wide providers
  core/                HTTP client, errors, storage, device identity, push, deep links, formatting, widgets
  features/<area>/     data (API + models) · application (state) · presentation (screens)
test/                  unit and widget tests, mirroring lib/
tool/defines/          build presets (production, staging, local-phone, local-emulator, local-web)
tool/dev_proxy.py      serves the web preview and the local API from one origin
tool/e2e/              Playwright end-to-end flow against a local backend (docs/running-locally.md)
android/ ios/ web/     platform projects (web is only a local preview, never shipped)
```

CI (`.github/workflows/ci.yml`) runs secret, SAST, dependency and workflow scans, then format, analyze and tests,
then builds a debug APK (downloadable from the run) and the web preview.
