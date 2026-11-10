import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hosts whose `/pay/return` links open the app (Android App Links / iOS
/// universal links, served by the website's `.well-known` files).
const appLinkHosts = {
  'glowderma.uz',
  'www.glowderma.uz',
  'staging.glowderma.uz',
};

/// Maps an incoming link to an app location, or null to ignore it.
///
/// * `https://glowderma.uz/pay/return?order_id=10248` (payment provider return)
/// * `glowderma://payment/return?order_id=10248` (custom-scheme fallback)
///
/// Only the order id is taken from the link; the order itself is always
/// re-read from the API, so a forged link can do nothing but open a screen.
String? locationForLink(Uri uri) {
  final isHttps =
      uri.scheme == 'https' &&
      appLinkHosts.contains(uri.host) &&
      uri.path.startsWith('/pay/return');
  final isScheme =
      uri.scheme == 'glowderma' &&
      uri.host == 'payment' &&
      uri.path.startsWith('/return');
  if (!isHttps && !isScheme) return null;
  final id = uri.queryParameters['order_id'];
  if (id == null || !RegExp(r'^\d{1,12}$').hasMatch(id)) return '/orders';
  return '/pay/$id?returned=1';
}

class DeepLinks {
  StreamSubscription<Uri>? _sub;
  Uri? _last;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Starts listening. app_links already delivers the link that cold-started
  /// the app on this stream, so `getInitialLink()` is not used (it would
  /// dispatch the same link twice); a repeated link within 2 s is dropped.
  void start(void Function(String location) go) {
    if (kIsWeb || _sub != null) return;
    _sub = AppLinks().uriLinkStream.listen((uri) {
      final now = DateTime.now();
      if (uri == _last &&
          now.difference(_lastAt) < const Duration(seconds: 2)) {
        return;
      }
      _last = uri;
      _lastAt = now;
      final location = locationForLink(uri);
      if (location != null) go(location);
    }, onError: (Object _) {});
  }

  void dispose() => _sub?.cancel();
}

final deepLinksProvider = Provider<DeepLinks>((ref) {
  final links = DeepLinks();
  ref.onDispose(links.dispose);
  return links;
});
