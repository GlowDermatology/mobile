import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/notifications/data/unread_count.dart';
import '../../firebase_options.dart';
import '../config/app_config.dart';

bool get pushSupported => AppConfig.firebaseEnabled && !kIsWeb;

/// Firebase is initialised only when push is enabled (FIREBASE_ENABLED) — the
/// app works without any Firebase project.
Future<void> initPush() async {
  if (!pushSupported) return;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } on Object catch (e) {
    debugPrint('Firebase init failed: $e');
  }
}

/// Where a push (FCM `data`, all values strings — contract §2.14.2) leads.
String locationForPush(Map<String, dynamic> data) {
  final type = data['type'];
  int? id(String key) => int.tryParse('${data[key] ?? ''}');
  switch (type) {
    case 'order_status':
      final order = id('order_id');
      return order == null ? '/orders' : '/orders/$order';
    case 'appointment':
      final appointment = id('appointment_id');
      return appointment == null ? '/appointments' : '/appointments/$appointment';
    case 'campaign':
      final product = id('product_id');
      return product == null ? '/notifications' : '/product/$product';
    default:
      return '/notifications';
  }
}

/// Android notification channels of the backend (`android.notification.channel_id`).
const _channels = [
  AndroidNotificationChannel('orders', 'Buyurtmalar', importance: Importance.high),
  AndroidNotificationChannel('appointments', 'Qabullar', importance: Importance.high),
  AndroidNotificationChannel('promo', 'Aksiyalar'),
  AndroidNotificationChannel('general', 'Umumiy', importance: Importance.high),
];

String _channelFor(String? type) => switch (type) {
      'order_status' => 'orders',
      'appointment' => 'appointments',
      'campaign' => 'promo',
      _ => 'general',
    };

/// Push notifications: permission, FCM token registration (`PUT me/device/`),
/// foreground display, tap routing and delivery acknowledgements
/// (`POST me/notifications/ack/`). A no-op unless [pushSupported].
class PushService {
  PushService(this._ref);
  final Ref _ref;
  final _local = FlutterLocalNotificationsPlugin();
  void Function(String location)? _open;
  static const _ackKey = 'gd.pending_acks';

  Future<void> start({required void Function(String location) onOpen}) async {
    _open = onOpen;
    if (!pushSupported) return;
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) _open?.call(locationForPush((jsonDecode(payload) as Map).cast<String, dynamic>()));
        },
      );
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      for (final channel in _channels) {
        await android?.createNotificationChannel(channel);
      }
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        _queueAck(m.data);
        _open?.call(locationForPush(m.data));
      });
      // The backend's FCM HTTP v1 sender targets registration tokens, so the
      // classic token API is used (its replacement returns installation ids).
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((token) => _register(token));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _queueAck(initial.data);
        _open?.call(locationForPush(initial.data));
      }
      await flushAcks();
    } on Object catch (e) {
      debugPrint('Push setup failed: $e');
    }
  }

  /// After a sign-in: ask for permission once and register the token.
  Future<void> onSignedIn() async {
    if (!pushSupported) {
      await _ref.read(sessionProvider.notifier).registerDevice();
      return;
    }
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      // ignore: deprecated_member_use
      final token = granted ? await FirebaseMessaging.instance.getToken() : null;
      await _register(token);
      await flushAcks();
    } on Object catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  Future<void> _register(String? token) =>
      _ref.read(sessionProvider.notifier).registerDevice(fcmToken: token, pushEnabled: token != null);

  Future<void> _onForeground(RemoteMessage message) async {
    _queueAck(message.data);
    unawaited(_ref.read(unreadCountProvider.notifier).refresh());
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      id: message.hashCode & 0x7fffffff,
      title: n.title,
      body: n.body,
      payload: jsonEncode(message.data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(_channelFor(message.data['type'] as String?), _channelFor(message.data['type'] as String?)),
        iOS: const DarwinNotificationDetails(),
      ),
    );
    await flushAcks();
  }

  void _queueAck(Map<String, dynamic> data) {
    final id = int.tryParse('${data['inbox_id'] ?? ''}');
    if (id == null) return;
    final prefs = _ref.read(prefsProvider);
    final ids = {...?prefs.getStringList(_ackKey), '$id'};
    unawaited(prefs.setStringList(_ackKey, ids.toList()));
  }

  /// Sends queued delivery acknowledgements (≤ 50 per call), while signed in.
  Future<void> flushAcks() async {
    if (!_ref.read(sessionProvider).signedIn) return;
    final prefs = _ref.read(prefsProvider);
    final ids = prefs.getStringList(_ackKey) ?? const [];
    if (ids.isEmpty) return;
    try {
      for (var i = 0; i < ids.length; i += 50) {
        final batch = ids.skip(i).take(50).map(int.parse).toList();
        await _ref.read(apiClientProvider).post('me/notifications/ack/', body: {'inbox_ids': batch});
      }
      await prefs.remove(_ackKey);
    } on Object {
      // retried on the next start
    }
  }
}

final pushServiceProvider = Provider<PushService>(PushService.new);
