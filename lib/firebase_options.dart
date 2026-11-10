// Placeholder. `flutterfire configure --platforms=android,ios --no-apply-gradle-plugins`
// overwrites this file with the real Firebase options (docs/setup.md). The
// values it writes are client identifiers, not secrets.
import 'package:firebase_core/firebase_core.dart';

abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('Firebase is not configured yet: run `flutterfire configure` (docs/setup.md).');
}
