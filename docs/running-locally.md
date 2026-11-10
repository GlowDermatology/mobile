# Running the app

## Install Flutter

Follow <https://docs.flutter.dev/get-started/install> (Flutter **3.47.9**, the version CI uses). For Android you
also need Android Studio (or just the Android SDK) and, for a phone, USB debugging enabled
(Settings → About phone → tap *Build number* seven times → Developer options → USB debugging).

```bash
flutter doctor        # shows what is missing
flutter pub get
```

## Option A — install the APK built by CI (no setup)

GitHub → Actions → latest run of *CI* → artifact **glow-derma-debug-apk** → unzip → copy `app-debug.apk` to the
phone and open it (allow "install unknown apps"). It talks to **staging**.

## Option B — your phone, against staging

```bash
flutter run --dart-define-from-file=tool/defines/staging.json
```

## Option C — everything locally (full flow: sign-up, payment, booking)

1. Start the backend in fake mode (see `backend/README.md`, Docker or `uv`). With `config.settings.local` every SMS
   code is **`123456`** and payments can be simulated. Add to the backend `.env`:
   ```
   FAKE_PAYMENTS_ENABLED=true
   ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2,<your computer's LAN IP>
   PUBLIC_MEDIA_BASE_URL=http://<your computer's LAN IP>:8000/media/
   ```
   and run it on all interfaces: `python manage.py runserver 0.0.0.0:8000` (Docker publishes only 127.0.0.1;
   change the port mapping to `0.0.0.0:8000:8000` for a phone). Seed demo data with `python manage.py seed_demo`.
2. Phone on the same Wi-Fi: put your computer's IP in `tool/defines/local-phone.json`, then
   `flutter run --dart-define-from-file=tool/defines/local-phone.json`.
   Android emulator: `tool/defines/local-emulator.json` (`10.0.2.2` is the emulator's name for your computer).
   Debug builds allow plain `http://`; release builds only HTTPS.
3. In the app: sign up with any number (code `123456`), add products, check out, and on the payment screen use
   **Simulate payment (dev)** (shown only with `ALLOW_DEV_TOOLS=true`).

## Option D — quick look in Chrome

The web build is only a preview (no push, no secure storage); the API has no CORS, so it is served together with
the API by a small proxy:

```bash
flutter build web --release --dart-define-from-file=tool/defines/local-web.json
python3 tool/dev_proxy.py --root build/web --api http://127.0.0.1:8000 --port 8080
# open http://localhost:8080  (routes are under #/, e.g. http://localhost:8080/#/auth)
```

## End-to-end check

`tool/e2e/` drives the web preview with Playwright through the whole customer journey and saves screenshots:

```bash
cd tool/e2e && npm ci && E2E_BASE_URL=http://localhost:8080 npx playwright test
```
