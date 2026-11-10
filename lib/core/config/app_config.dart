/// Build-time configuration, passed with `--dart-define` or
/// `--dart-define-from-file=tool/defines/<preset>.json`. Nothing here is a
/// secret: every value ends up inside the app binary.
abstract final class AppConfig {
  /// Base URL of the customer API, always ending with `/api/v1/`.
  /// A relative value (`/api/v1/`) is used by the local web preview, which is
  /// served from the same origin as the API by `tool/dev_proxy.py`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://glowderma.uz/api/v1/',
  );

  /// Push notifications through Firebase Cloud Messaging. Off until the
  /// Firebase project exists and `flutterfire configure` has been run
  /// (docs/setup.md).
  static const bool firebaseEnabled = bool.fromEnvironment('FIREBASE_ENABLED');

  /// Developer helpers (the "simulate payment" button). Only useful against a
  /// local backend running `config.settings.local` with FAKE_PAYMENTS_ENABLED.
  static const bool allowDevTools = bool.fromEnvironment('ALLOW_DEV_TOOLS');

  /// End-to-end test build: turns on the semantics tree so the Playwright
  /// harness can find widgets by their identifiers.
  static const bool e2e = bool.fromEnvironment('E2E');

  /// `ios` or `android`; empty means "detect". The web preview must claim a
  /// mobile platform because the API reserves `web` for the website server.
  static const String platformOverride = String.fromEnvironment('PLATFORM_OVERRIDE');

  /// Public website, used for the legal pages links and app links.
  static const String websiteUrl = String.fromEnvironment(
    'WEBSITE_URL',
    defaultValue: 'https://glowderma.uz',
  );
}
