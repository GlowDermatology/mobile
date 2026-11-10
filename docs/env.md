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

Presets: `production`, `staging`, `local-phone` (edit the LAN IP), `local-emulator`, `local-web`. None holds a secret.

## Server settings the app depends on

Nothing below had to change for this app; these are the go-live switches (see setup.md).

**Backend** — public values in `infra/environments/<env>/backend.env`, secrets in Vault
(`scripts/vault/put-secret.sh <env> django <KEY>`):

| Setting | Where | For |
|---|---|---|
| `FCM_MODE=live`, `FCM_PROJECT_ID` | backend.env | push notifications |
| `FCM_CREDENTIALS_JSON_B64`, `FCM_CREDENTIALS_FILE=/run/secrets/fcm.json` | Vault | Firebase service account |
| `ESKIZ_MODE=live`, `ESKIZ_SENDER` / `ESKIZ_EMAIL`, `ESKIZ_PASSWORD` | backend.env / Vault | SMS codes (sign-up, new device, password reset) |
| `CLICK_MODE=live`, `CLICK_SERVICE_ID`, `CLICK_MERCHANT_ID`, `CLICK_MERCHANT_USER_ID` / `CLICK_SECRET_KEY` | backend.env / Vault | Click payments |
| `PAYME_MODE=live`, `PAYME_MERCHANT_ID` / `PAYME_KEY` | backend.env / Vault | Payme payments |
| `MIN_APP_VERSION_IOS`, `MIN_APP_VERSION_ANDROID`, `APP_STORE_URL`, `PLAY_STORE_URL` | backend.env | forced updates and store links |
| `PAYMENT_RETURN_URL` | compose (derived from `SITE_DOMAIN`) | where Click/Payme send app payers: `https://<domain>/pay/return` |

`ANDROID_SMS_APP_HASH` is not used by this app (it relies on the system's one-time-code autofill); leave it unset.

**Website** — `infra/environments/<env>/frontend.env` (public values, read at runtime):

| Setting | For |
|---|---|
| `GLOWDERMA_APP_LINKS_APPLE_APP_IDS` | `<TEAM_ID>.uz.glowderma.app` → `/.well-known/apple-app-site-association` |
| `GLOWDERMA_APP_LINKS_ANDROID_PACKAGE` | default `uz.glowderma.app` → `/.well-known/assetlinks.json` |
| `GLOWDERMA_APP_LINKS_ANDROID_SHA256` | signing-certificate fingerprints → `/.well-known/assetlinks.json` |

Until those are set, both files answer 404 and the payment return goes through the `/pay/return` web page and the
`glowderma://` scheme; the app still learns the payment result by polling the order.
