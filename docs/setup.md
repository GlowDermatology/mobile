# What you need to do (owner checklist)

The app works today against a local backend in "fake" mode (no SMS, no real payments). To put it in customers'
hands, a few accounts and settings are needed that only you can create. Nothing here is required to build or test
the app.

## 1. Try it (no accounts needed)

Follow [running-locally.md](running-locally.md): install the debug APK that CI builds on every push (GitHub →
Actions → the run → *glow-derma-debug-apk*), or run it from your computer.

> **Staging limitation.** Staging runs every provider in fake mode under production settings: it sends no SMS and
> lists no payment provider. You can browse the catalog there, but you cannot sign up or pay until step 4 is done.
> The full flow (sign-up with code `123456`, payment simulation) works against a local backend.

## 2. Firebase — push notifications (optional at first)

The app runs without Firebase; push notifications stay off until this is done.

1. Create a project at <https://console.firebase.google.com> named "Glow Derma".
2. Add an **Android** app with package `uz.glowderma.app` and an **iOS** app with bundle id `uz.glowderma.app`.
3. On your computer, in this repository:
   ```bash
   npm install -g firebase-tools && firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure --platforms=android,ios --no-apply-gradle-plugins
   ```
   Always pass `--no-apply-gradle-plugins`: the app initialises Firebase from Dart and CI fails if the Google
   services Gradle plugin is added. Commit `lib/firebase_options.dart` and `ios/Runner/GoogleService-Info.plist`
   (client identifiers, not secrets). `android/app/google-services.json` is not needed and stays ignored.
4. Build with `--dart-define=FIREBASE_ENABLED=true` (add `"FIREBASE_ENABLED": true` to the preset you use).
5. Backend (so it can send pushes): in Firebase → Project settings → Service accounts → *Generate new private
   key*. Then on the server (see [env.md](env.md)):
   - `infra/environments/<env>/backend.env`: `FCM_MODE=live`, `FCM_PROJECT_ID=<project id>`
   - Vault, `scripts/vault/put-secret.sh <env> django FCM_CREDENTIALS_JSON_B64` (base64 of the JSON) **and**
     `scripts/vault/put-secret.sh <env> django FCM_CREDENTIALS_FILE` with the value `/run/secrets/fcm.json`
6. iOS pushes also need an APNs key (Apple Developer → Keys) uploaded in Firebase → Cloud Messaging.

## 3. Google Play (Android)

1. Create a Google Play developer account (one-time fee) and an app "Glow Derma" with package `uz.glowderma.app`.
2. Create an upload key on your computer and keep it safe (never commit it):
   ```bash
   keytool -genkey -v -keystore ~/glowderma-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
   Then create `android/key.properties` (git-ignored):
   ```
   storeFile=/home/you/glowderma-upload.jks
   storePassword=…
   keyAlias=upload
   keyPassword=…
   ```
3. Build and upload (see [release.md](release.md)). Play Console → *App integrity* then shows the **App signing key
   SHA-256** fingerprint.
4. Website: set `GLOWDERMA_APP_LINKS_ANDROID_SHA256` (that fingerprint, plus your upload key's for test builds,
   comma separated) in `infra/environments/<env>/frontend.env` and redeploy. Payment returns then open the app
   directly.
5. Backend: once published, set `PLAY_STORE_URL` in `backend.env`.

## 4. SMS (Eskiz) and payments (Click, Payme)

Without these, nobody can sign up or pay outside local fake mode. Each provider's go-live checklist is in
`backend/docs/integrations/*.md`. In short:

- Eskiz: `ESKIZ_MODE=live`, `ESKIZ_SENDER` in `backend.env`; `ESKIZ_EMAIL`, `ESKIZ_PASSWORD` in Vault.
- Click: `CLICK_MODE=live`, `CLICK_SERVICE_ID`, `CLICK_MERCHANT_ID`, `CLICK_MERCHANT_USER_ID` in `backend.env`;
  `CLICK_SECRET_KEY` in Vault.
- Payme: `PAYME_MODE=live`, `PAYME_MERCHANT_ID` in `backend.env`; `PAYME_KEY` in Vault.

## 5. Apple (iOS)

1. Join the Apple Developer Program. Create the App ID `uz.glowderma.app` with the **Associated Domains** and
   **Push Notifications** capabilities.
2. Website: set `GLOWDERMA_APP_LINKS_APPLE_APP_IDS=<TEAM_ID>.uz.glowderma.app` in `frontend.env` and redeploy.
3. iOS apps are built on a Mac with Xcode: `flutter build ipa` (see [release.md](release.md)). Before submitting,
   change `aps-environment` in `ios/Runner/Runner.entitlements` to `production`.
4. Backend: set `APP_STORE_URL` once published.

## 6. After the first store release

Set `MIN_APP_VERSION_IOS` / `MIN_APP_VERSION_ANDROID` in `backend.env` when an old version must stop working: the
API then answers 426 and the app shows an "update" screen with the store link.
