# Releasing

1. Bump `version:` in `pubspec.yaml` (`1.0.1+2`: the part after `+` must grow with every store upload).
2. Android (any computer with Flutter and the upload key, see setup.md §3):
   ```bash
   flutter build appbundle --release --dart-define-from-file=tool/defines/production.json
   ```
   Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console (internal testing first).
3. iOS (Mac with Xcode, Apple Developer account):
   ```bash
   flutter build ipa --release --dart-define-from-file=tool/defines/production.json
   ```
   Upload with Xcode Organizer or Transporter. Set `aps-environment` to `production` in
   `ios/Runner/Runner.entitlements` for store builds.
4. If Firebase is configured, add `"FIREBASE_ENABLED": true` to `tool/defines/production.json` first.
5. After the release, consider raising `MIN_APP_VERSION_*` on the backend (setup.md §6).
