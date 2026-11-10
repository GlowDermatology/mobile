# AGENTS.md — Glow Derma mobile

Instructions for coding agents working in this repository.

- The API contract is `backend/docs/api/customer-api-v1.md` (sibling repository). Never invent fields or codes:
  check the contract (and, when in doubt, a local backend in fake mode, `docs/running-locally.md`).
- Dev loop, from the repository root; stop at the first failure:
  ```
  flutter pub get
  dart format --output=none --set-exit-if-changed lib test
  flutter analyze --fatal-infos
  flutter test
  ```
- Architecture rules (`docs/architecture.md`):
  - Every request goes through `ApiClient` (`lib/core/network/api_client.dart`): device headers,
    `Accept-Language`, the single-flight token refresh and the error envelope live there only.
  - Writes the contract marks **I** pass an `Idempotency-Key` from `idempotencyProvider` (one key per user intent).
  - Riverpod 3 without code generation; models are hand-written classes with `fromJson` built on
    `lib/core/network/json.dart`.
  - UI strings are `Tr('uz', 'ru', 'en')` constants in the feature's `*_text.dart`; texts the server sends
    (status labels, error messages) are shown as they are. Uzbek uses the U+2018 apostrophe (`so‘m`).
  - Times are shown in Tashkent time (`lib/core/format/dates.dart`), money with `formatMoney`.
  - Tokens: the access token stays in memory; the refresh token, device key and device id are in the
    Keychain/Keystore (`lib/core/storage/secure_store.dart`). Never log them.
- No secrets in the repository. Firebase client files are identifiers (allow-listed in `.gitleaks.toml`);
  signing keys and `android/key.properties` are git-ignored.
- Commits: small, imperative subjects (`feat(cart): …`).
