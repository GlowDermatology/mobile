import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keychain / Keystore access with the contract's rules (§6.6): this device
/// only, never synced to iCloud, readable after the first unlock so a push or
/// a background refresh works.
const FlutterSecureStorage secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  ),
  aOptions: AndroidOptions(),
);

abstract final class _Keys {
  static const session = 'gd.session';
  static const deviceKey = 'gd.device_key';
  static const deviceId = 'gd.device_id';
  static const installMarker = 'gd.installed';
}

/// The customer's tokens.
///
/// The short-lived access token lives in memory only; the rotating refresh
/// token is persisted as one JSON value, so writing a new pair is a single
/// atomic replacement. The device key (issued once per verified sign-in) and
/// the device id are separate keys that survive a sign-out.
class TokenStore {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  String? access;
  DateTime? accessExpiresAt;
  String? refresh;
  DateTime? refreshExpiresAt;
  String? deviceKey;

  bool get hasSession => refresh != null;

  /// Reads persisted values. On the first launch after a (re)install the
  /// Keychain may still hold the previous install's session (iOS keeps it):
  /// the session is dropped then, but the device key is kept, so the SMS step
  /// is skipped while the old session is never resumed.
  Future<void> load(SharedPreferences prefs) async {
    if (prefs.getBool(_Keys.installMarker) != true) {
      await _storage.delete(key: _Keys.session);
      await prefs.setBool(_Keys.installMarker, true);
    }
    deviceKey = await _storage.read(key: _Keys.deviceKey);
    final raw = await _storage.read(key: _Keys.session);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      refresh = json['refresh'] as String?;
      refreshExpiresAt = DateTime.tryParse('${json['refresh_expires_at']}');
      if (refreshExpiresAt != null &&
          refreshExpiresAt!.isBefore(DateTime.now())) {
        await clear();
      }
    } on Object {
      await clear();
    }
  }

  /// Stores a token pair from `AuthTokens` or `auth/refresh/`.
  Future<void> save(Map<String, dynamic> tokens) async {
    final newRefresh = tokens['refresh'] as String;
    final newRefreshExp = '${tokens['refresh_expires_at']}';
    // Persist the new refresh token before anything else uses the pair:
    // the old one is useless after a rotation.
    await _storage.write(
      key: _Keys.session,
      value: jsonEncode({
        'refresh': newRefresh,
        'refresh_expires_at': newRefreshExp,
      }),
    );
    refresh = newRefresh;
    refreshExpiresAt = DateTime.tryParse(newRefreshExp);
    access = tokens['access'] as String?;
    accessExpiresAt = DateTime.tryParse('${tokens['access_expires_at']}');
    final key = tokens['device_key'];
    if (key is String && key.isNotEmpty) {
      deviceKey = key;
      await _storage.write(key: _Keys.deviceKey, value: key);
    }
  }

  Future<void> clear() async {
    access = null;
    accessExpiresAt = null;
    refresh = null;
    refreshExpiresAt = null;
    await _storage.delete(key: _Keys.session);
  }

  Future<String?> readDeviceId() => _storage.read(key: _Keys.deviceId);
  Future<void> writeDeviceId(String id) =>
      _storage.write(key: _Keys.deviceId, value: id);
}
