# Configuration reference

## App build options (`--dart-define`, presets in `tool/defines/`)

| Option | Default | Meaning |
|---|---|---|
| `API_BASE_URL` | `https://glowderma.uz/api/v1/` | customer API base, ends with `/api/v1/` |
| `FIREBASE_ENABLED` | `false` | push notifications (needs `flutterfire configure`) |
| `ALLOW_DEV_TOOLS` | `false` | "Simulate payment (dev)" button; only works against a local backend in fake mode |
| `E2E` | `false` | semantics tree on, for the Playwright harness |
| `PLATFORM_OVERRIDE` | empty | `android`/`ios`; the web preview needs `android` |
| `WEBSITE_URL` | `https://glowderma.uz` | public website |
| `MAP_TILE_URL` | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | map tiles of the address pin picker; OpenStreetMap's public server is fine for low volume, set a tile provider here for more |
| `GOOGLE_SERVER_CLIENT_ID` | empty | Google sign-in: the **Web application** OAuth client id (`…apps.googleusercontent.com`); Android requests ID tokens for it. Empty hides the Google button on Android |
| `GOOGLE_IOS_CLIENT_ID` | empty | Google sign-in on iOS: the **iOS** OAuth client id. Empty hides the Google button on iOS |
| `FACEBOOK_APP_ID` | empty | Facebook sign-in: the app id (digits). Empty hides the Facebook button |
| `FACEBOOK_CLIENT_TOKEN` | empty | Facebook client token (App settings → Advanced → Security) |

Presets: `production`, `staging`, `local-phone` (edit the LAN IP), `local-emulator`, `local-web`. None holds a secret:
the four social ids are public identifiers that ship inside the app (the matching secrets stay on the server). The
social buttons are never shown on the web preview.

### Social sign-in ids: where they go

Each id is needed in up to three places. Paste the same value everywhere:

| Id | App (`tool/defines/<preset>.json`) | Android native | iOS native (`ios/Flutter/Social.xcconfig`) | Backend (`backend.env`) |
|---|---|---|---|---|
| Google web client id | `GOOGLE_SERVER_CLIENT_ID` | — | — | in `GOOGLE_APP_CLIENT_IDS` |
| Google iOS client id | `GOOGLE_IOS_CLIENT_ID` | — | `GOOGLE_REVERSED_CLIENT_ID` = the client's "iOS URL scheme" (`com.googleusercontent.apps.…`) | in `GOOGLE_APP_CLIENT_IDS` |
| Facebook app id | `FACEBOOK_APP_ID` | read from the same define by `android/app/build.gradle.kts` | `FACEBOOK_APP_ID` | `FACEBOOK_APP_ID` (+ `FACEBOOK_APP_SECRET` in Vault) |
| Facebook client token | `FACEBOOK_CLIENT_TOKEN` | read from the same define | `FACEBOOK_CLIENT_TOKEN` | — |

- **Android** reads `FACEBOOK_APP_ID` / `FACEBOOK_CLIENT_TOKEN` from the dart-defines of the build (the preset file),
  else from a Gradle property (`-PFACEBOOK_APP_ID=…`, or `~/.gradle/gradle.properties`), else from an environment
  variable, and writes them into the manifest (`com.facebook.sdk.ApplicationId` / `ClientToken`, the `fb<app id>`
  login scheme). Nothing to edit in `android/` itself.
- **iOS** cannot read dart-defines from `Info.plist`, so the ids are build settings in `ios/Flutter/Social.xcconfig`
  (or the git-ignored `ios/Flutter/Social.local.xcconfig`, which overrides it). Set `FACEBOOK_APP_ID` there before
  building for iOS: while it is empty the build registers the bare `fb` URL scheme.
- Google on Android needs no file in the app (no `google-services.json`): the package name `uz.glowderma.app` and the
  **SHA-1 of every signing key** (debug, upload, and Play's app signing key) must be registered on an **Android**
  OAuth client of the same Google Cloud project, see [setup.md](setup.md) §7.
- The server answers 404 on `auth/social/` while social sign-in is off there (fake OAuth under production settings);
  the app then hides the buttons for the rest of the session.

## Server settings the app depends on

Nothing below had to change for this app; these are the go-live switches (see setup.md).

**Backend** — public values in `infra/environments/<env>/backend.env`, secrets in Vault
(`scripts/vault/put-secret.sh <env> django <KEY>`):

| Setting | Where | For |
|---|---|---|
| `FCM_MODE=live`, `FCM_PROJECT_ID` | backend.env | push notifications |
| `FCM_CREDENTIALS_JSON_B64`, `FCM_CREDENTIALS_FILE=/run/secrets/fcm.json` | Vault | Firebase service account |
| `DEVSMS_MODE=live`, `DEVSMS_API_TOKEN` | Vault | SMS codes (sign-up, new device, password reset) |
| `CLICK_MODE=live`, `CLICK_SERVICE_ID`, `CLICK_MERCHANT_ID`, `CLICK_MERCHANT_USER_ID` / `CLICK_SECRET_KEY` | backend.env / Vault | Click payments |
| `PAYME_MODE=live`, `PAYME_MERCHANT_ID` / `PAYME_KEY` | backend.env / Vault | Payme payments |
| `UZUM_MODE=live`, `UZUM_CHECKOUT_BASE_URL`, `UZUM_TERMINAL_ID`, `UZUM_ORDER_PREFIX` / `UZUM_API_KEY`, `UZUM_CALLBACK_TOKEN` | backend.env / Vault | Uzum Bank Checkout payments (card form in the browser) |
| `MIN_APP_VERSION_IOS`, `MIN_APP_VERSION_ANDROID`, `APP_STORE_URL`, `PLAY_STORE_URL` | backend.env | forced updates and store links |
| `PAYMENT_RETURN_URL` | compose (derived from `SITE_DOMAIN`) | where Click/Payme/Uzum send app payers: `https://<domain>/pay/return` |
| `YANDEX_DELIVERY_MODE=live` / `YANDEX_DELIVERY_TOKEN` | backend.env / Vault | Yandex courier delivery (also needs the warehouse, methods and opening hours on the ops console's delivery settings page) |
| `YANDEX_DELIVERY_PILOT_CUSTOMER_IDS` | backend.env | optional: offer Yandex to these customer ids only |
| `OAUTH_MODE=live`, `GOOGLE_APP_CLIENT_IDS`, `FACEBOOK_APP_ID` / `FACEBOOK_APP_SECRET` | backend.env / Vault | Google and Facebook sign-in in the app (`GOOGLE_APP_CLIENT_IDS` lists the web **and** the iOS client id, comma separated) |

`ANDROID_SMS_APP_HASH` is not used by this app (it relies on the system's one-time-code autofill); leave it unset.

**Website** — `infra/environments/<env>/frontend.env` (public values, read at runtime):

| Setting | For |
|---|---|
| `GLOWDERMA_APP_LINKS_APPLE_APP_IDS` | `<TEAM_ID>.uz.glowderma.app` → `/.well-known/apple-app-site-association` |
| `GLOWDERMA_APP_LINKS_ANDROID_PACKAGE` | default `uz.glowderma.app` → `/.well-known/assetlinks.json` |
| `GLOWDERMA_APP_LINKS_ANDROID_SHA256` | signing-certificate fingerprints → `/.well-known/assetlinks.json` |

Until those are set, both files answer 404 and the payment return goes through the `/pay/return` web page and the
`glowderma://` scheme; the app still learns the payment result by polling the order.
