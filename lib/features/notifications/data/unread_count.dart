import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/json.dart';
import '../../auth/application/session_controller.dart';

/// Unread inbox items for the bell dot (`GET me/notifications/unread-count/`),
/// refreshed every minute while the app is open and on demand.
class UnreadCountController extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (!signedIn) return 0;
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    if (!ref.read(sessionProvider).signedIn) return;
    try {
      final json = asJson(
        await ref.read(apiClientProvider).get('me/notifications/unread-count/'),
      );
      state = asInt(json['unread_count']);
    } on Object {
      // keep the last value
    }
  }

  void set(int value) => state = value;
}

final unreadCountProvider = NotifierProvider<UnreadCountController, int>(
  UnreadCountController.new,
);
