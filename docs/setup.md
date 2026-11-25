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

## 4. SMS (DevSMS) and payments (Click, Payme, Uzum)

Without these, nobody can sign up or pay outside local fake mode. Each provider's go-live checklist is in
`backend/docs/integrations/*.md`. In short:

- DevSMS: `DEVSMS_MODE=live` and `DEVSMS_API_TOKEN` in Vault (`secret/<env>/django`); codes go through DevSMS's
  universal OTP templates from the shared sender 4546 (backend `docs/integrations/devsms.md`).
- Click: `CLICK_MODE=live`, `CLICK_SERVICE_ID`, `CLICK_MERCHANT_ID`, `CLICK_MERCHANT_USER_ID` in `backend.env`;
  `CLICK_SECRET_KEY` in Vault.
- Payme: `PAYME_MODE=live`, `PAYME_MERCHANT_ID` in `backend.env`; `PAYME_KEY` in Vault.
- Uzum (Uzum Bank Checkout, a card form opened in the browser): `UZUM_CHECKOUT_BASE_URL`, `UZUM_TERMINAL_ID` and
  `UZUM_ORDER_PREFIX` in `backend.env`, `UZUM_API_KEY` and `UZUM_CALLBACK_TOKEN` in Vault, then `UZUM_MODE=live` last
  (`backend/docs/integrations/uzum.md`). The app needs no change; Uzum shows up once the API lists it.
- Yandex courier delivery: `YANDEX_DELIVERY_MODE=live` in `backend.env`, `YANDEX_DELIVERY_TOKEN` in Vault, and the
  warehouse, methods and opening hours filled in on the ops console's delivery settings page
  (`backend/docs/integrations/yandex-delivery.md`). Until then the app offers BTS and pickup only.

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

## 7. Google and Facebook sign-in (optional)

The app shows "Google bilan davom etish" / "Facebook bilan davom etish" only when their ids are in the build; phone
and e-mail sign-in work without them. Where each id goes is summed up in [env.md](env.md) ("Social sign-in ids").

**Google** (<https://console.cloud.google.com>, one project for the app and the website):
1. *APIs & Services → OAuth consent screen*: app name "Glow Derma", support e-mail, the website's domain; publish it.
2. *Credentials → Create credentials → OAuth client ID*, three times:
   - **Web application** (no redirect URI needed for the app). Its client id is `GOOGLE_SERVER_CLIENT_ID`.
   - **Android**: package `uz.glowderma.app` and the **SHA-1** of the signing certificate. Create one Android client
     per key you sign with: the debug key (`keytool -list -v -keystore ~/.android/debug.keystore -alias
     androiddebugkey -storepass android`, also the key of CI's debug APK built on your machine), your upload key
     (`keytool -list -v -keystore ~/glowderma-upload.jks -alias upload`) and Play's **app signing key** (Play
     Console → *App integrity*). Without the right SHA-1, Google answers "developer error" and the button does
     nothing. The Android client id itself is not pasted anywhere.
   - **CI's staging APK** is signed with one fixed key (otherwise every CI run would sign with a new throwaway
     key, whose SHA-1 Google cannot know). Create it once:
     `keytool -genkey -v -keystore glowderma-staging.jks -alias staging -keyalg RSA -keysize 2048 -validity 10000`
     (Windows: `"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`). Register its SHA-1
     (`keytool -list -v -keystore glowderma-staging.jks -alias staging`) on an Android client. Then add the
     repository secrets `ANDROID_STAGING_KEYSTORE_BASE64` (the `.jks` file in base64),
     `ANDROID_STAGING_KEYSTORE_PASSWORD` and `ANDROID_STAGING_KEY_ALIAS` (`staging`). The `build-android` job
     prints the APK's SHA-1 so you can compare it.
   - **iOS**: bundle id `uz.glowderma.app`. Its client id is `GOOGLE_IOS_CLIENT_ID`; its "iOS URL scheme" goes into
     `GOOGLE_REVERSED_CLIENT_ID` in `ios/Flutter/Social.xcconfig`.
3. Paste `GOOGLE_SERVER_CLIENT_ID` and `GOOGLE_IOS_CLIENT_ID` into the preset you build with
   (`tool/defines/staging.json`, `tool/defines/production.json`).
4. Backend: `GOOGLE_APP_CLIENT_IDS=<web client id>,<iOS client id>` in `backend.env` and `OAUTH_MODE=live` (live mode
   also requires the staff OAuth settings, see the backend's `config/settings/production.py`).

**Facebook** (<https://developers.facebook.com> → *My Apps → Create app → Authenticate and request data from users
with Facebook Login*):
1. *App settings → Basic*: the **App ID**; *App settings → Advanced → Security*: the **Client token**. Add the
   privacy policy URL (the website's `/privacy`) and switch the app to *Live*.
2. *Facebook Login → Settings*: add the **Android** platform with package `uz.glowderma.app`, class
   `uz.glowderma.app.MainActivity` and the **key hashes** of the same signing keys as above (base64 of the SHA-1:
   `keytool -exportcert -alias upload -keystore ~/glowderma-upload.jks | openssl sha1 -binary | openssl base64`,
   and Play's app signing SHA-1 converted the same way); add the **iOS** platform with bundle id `uz.glowderma.app`.
3. Paste `FACEBOOK_APP_ID` and `FACEBOOK_CLIENT_TOKEN` into the preset (Android reads them from there too) and into
   `ios/Flutter/Social.xcconfig`.
4. Backend: `FACEBOOK_APP_ID` in `backend.env`, `FACEBOOK_APP_SECRET` in Vault, `OAUTH_MODE=live`.

The ids are public identifiers (they ship inside the app) and may be committed; the app secret never leaves the
server. Rebuild the app after changing them.

