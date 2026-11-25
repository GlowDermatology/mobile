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
  static const String platformOverride = String.fromEnvironment(
    'PLATFORM_OVERRIDE',
  );

  /// Public website, used for the legal pages links and app links.
  static const String websiteUrl = String.fromEnvironment(
    'WEBSITE_URL',
    defaultValue: 'https://glowderma.uz',
  );

  /// Raster tile URL template of the address map (`{z}/{x}/{y}`), the
  /// website's `NEXT_PUBLIC_MAP_TILE_URL`. OpenStreetMap's public tiles by
  /// default; their usage policy allows light use only, so a busy production
  /// build should point this at a tile service of its own.
  static const String mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// Google sign-in (customer contract §2.1.8): the **web** OAuth client id
  /// of the Google Cloud project. Android asks Google for ID tokens issued to
  /// it (the backend's `GOOGLE_APP_CLIENT_IDS` must list it). Empty hides
  /// the Google button on Android.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Google sign-in on iOS: the **iOS** OAuth client id (also in
  /// `GOOGLE_APP_CLIENT_IDS`; its reversed form is the URL scheme in
  /// `ios/Flutter/Social.xcconfig`). Empty hides the Google button on iOS.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// Facebook sign-in: the app id (the backend's `FACEBOOK_APP_ID`). The
  /// Android build reads the same define for its manifest; iOS takes it from
  /// `ios/Flutter/Social.xcconfig`. Empty hides the Facebook button.
  static const String facebookAppId = String.fromEnvironment('FACEBOOK_APP_ID');

  /// Facebook client token (App settings → Advanced); a public identifier.
  static const String facebookClientToken = String.fromEnvironment(
    'FACEBOOK_CLIENT_TOKEN',
  );
}
