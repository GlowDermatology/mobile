import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../storage/secure_store.dart';

/// What the API needs to know about this install (contract §1.2).
class DeviceIdentity {
  DeviceIdentity({required this.id, required this.platform, required this.appVersion, required this.model, required this.os});

  /// `X-GD-Device-Id`: generated once per install, kept in secure storage.
  /// The API binds every session to it; it is an identifier, not a secret.
  final String id;

  /// `ios` or `android`.
  final String platform;

  /// `x.y.z` from the app version.
  final String appVersion;
  final String model;
  final String os;

  static Future<DeviceIdentity> load(TokenStore store) async {
    var id = await store.readDeviceId();
    if (id == null || !RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(id)) {
      id = const Uuid().v4().replaceAll('-', '');
      await store.writeDeviceId(id);
    }
    final platform = switch (AppConfig.platformOverride) {
      'ios' || 'android' => AppConfig.platformOverride,
      _ => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    };
    var version = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      final match = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})').firstMatch(info.version);
      if (match != null) version = match.group(0)!;
    } on Object {
      // keep the default
    }
    var model = '', os = '';
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await plugin.webBrowserInfo;
        model = web.browserName.name;
        os = 'Web';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await plugin.iosInfo;
        model = ios.utsname.machine;
        os = 'iOS ${ios.systemVersion}';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await plugin.androidInfo;
        model = '${android.manufacturer} ${android.model}';
        os = 'Android ${android.version.release}';
      }
    } on Object {
      // device facts are informational only
    }
    String cap(String s, int n) => s.length > n ? s.substring(0, n) : s;
    return DeviceIdentity(id: id, platform: platform, appVersion: version, model: cap(model, 80), os: cap(os, 40));
  }
}
