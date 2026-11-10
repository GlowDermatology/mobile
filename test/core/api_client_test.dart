import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/device/device_identity.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/network/api_client.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/core/storage/secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scripted_adapter.dart';

DeviceIdentity _device() => DeviceIdentity(id: 'device0001', platform: 'android', appVersion: '1.0.0', model: 'Pixel', os: 'Android 15');

Map<String, Object> _tokens(String access, String refresh) => {
      'access': access,
      'access_expires_at': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
      'refresh': refresh,
      'refresh_expires_at': DateTime.now().add(const Duration(days: 60)).toIso8601String(),
    };

Map<String, Object?> _error(String code, [String message = '']) => {'code': code, 'message': message, 'errors': <Object>[], 'details': null, 'request_id': 'r1'};

Future<TokenStore> _signedInStore() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final store = TokenStore(secureStorage);
  await store.load(await SharedPreferences.getInstance());
  await store.save(_tokens('old-access', 'refresh-1'));
  return store;
}

void main() {
  test('sends the device headers, language and bearer', () async {
    final store = await _signedInStore();
    final adapter = ScriptedAdapter((o) => ScriptedAdapter.json(200, {'ok': true}));
    final api = ApiClient(device: _device(), tokens: store, language: () => AppLanguage.ru, baseUrl: 'https://api.test/api/v1/', adapter: adapter);

    await api.get('cart/');

    final h = adapter.requests.single.headers;
    expect(h['X-GD-Device-Id'], 'device0001');
    expect(h['X-GD-Platform'], 'android');
    expect(h['X-GD-App-Version'], '1.0.0');
    expect(h['Accept-Language'], 'ru');
    expect(h['Authorization'], 'Bearer old-access');
    expect(h.containsKey('X-GD-Device-Key'), isFalse);
  });

  test('concurrent 401s trigger exactly one refresh, then every request is retried with the new token', () async {
    final store = await _signedInStore();
    var refreshes = 0;
    final adapter = ScriptedAdapter((o) async {
      if (o.path == 'auth/refresh/') {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return ScriptedAdapter.json(200, _tokens('new-access', 'refresh-2'));
      }
      if (o.headers['Authorization'] == 'Bearer old-access') return ScriptedAdapter.json(401, _error('not_authenticated'));
      return ScriptedAdapter.json(200, {'path': o.path});
    });
    final api = ApiClient(device: _device(), tokens: store, language: () => AppLanguage.uz, baseUrl: 'https://api.test/api/v1/', adapter: adapter);

    final results = await Future.wait([api.get('cart/'), api.get('me/'), api.get('me/orders/')]);

    expect(refreshes, 1);
    expect(results.map((r) => (r as Map)['path']), ['cart/', 'me/', 'me/orders/']);
    expect(store.refresh, 'refresh-2');
    expect(store.access, 'new-access');
  });

  test('a refused refresh ends the session and clears the tokens', () async {
    final store = await _signedInStore();
    String? endedWith;
    final adapter = ScriptedAdapter((o) {
      if (o.path == 'auth/refresh/') return ScriptedAdapter.json(401, _error('SESSION_EXPIRED'));
      return ScriptedAdapter.json(401, _error('not_authenticated'));
    });
    final api = ApiClient(device: _device(), tokens: store, language: () => AppLanguage.uz, baseUrl: 'https://api.test/api/v1/', adapter: adapter)
      ..onSessionEnded = (code, _) => endedWith = code;

    await expectLater(api.get('cart/'), throwsA(isA<SessionEnded>()));
    expect(endedWith, 'SESSION_EXPIRED');
    expect(store.hasSession, isFalse);
  });

  test('password_changed ends the session with the server message, without a refresh', () async {
    final store = await _signedInStore();
    final ended = <String>[];
    final adapter = ScriptedAdapter((o) => ScriptedAdapter.json(401, _error('password_changed', 'Parolingiz o‘zgartirildi.')));
    final api = ApiClient(device: _device(), tokens: store, language: () => AppLanguage.uz, baseUrl: 'https://api.test/api/v1/', adapter: adapter)
      ..onSessionEnded = (code, message) => ended.add('$code|$message');

    await expectLater(api.get('me/'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'password_changed')));
    expect(ended, ['password_changed|Parolingiz o‘zgartirildi.']);
    expect(adapter.requests.where((r) => r.path == 'auth/refresh/'), isEmpty);
    expect(store.hasSession, isFalse);
  });

  test('error envelope becomes an ApiException with field errors and Retry-After', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final store = TokenStore(secureStorage);
    final adapter = ScriptedAdapter((o) => ScriptedAdapter.json(
          429,
          {
            'code': 'otp_resend_too_soon',
            'message': 'Yangi kodni 42 soniyadan so‘ng so‘rashingiz mumkin.',
            'errors': [
              {'field': 'phone', 'code': 'invalid', 'message': 'Telefon raqamini to‘g‘ri kiriting.'},
            ],
            'details': {'retry_after': 42},
            'request_id': 'abc',
          },
          headers: {
            'retry-after': ['42'],
          },
        ));
    final api = ApiClient(device: _device(), tokens: store, language: () => AppLanguage.uz, baseUrl: 'https://api.test/api/v1/', adapter: adapter);

    final error = await api.post('auth/send-code/', body: {'phone': '+998901234567'}).then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);
    expect(error!.status, 429);
    expect(error.code, 'otp_resend_too_soon');
    expect(error.retryAfter, 42);
    expect(error.fieldErrors['phone'], 'Telefon raqamini to‘g‘ri kiriting.');
    expect(error.requestId, 'abc');
    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('device key goes to auth/login/ only; idempotency key is sent', () async {
    final store = await _signedInStore();
    await store.save({..._tokens('a', 'r'), 'device_key': 'k' * 43});
    final adapter = ScriptedAdapter((o) => ScriptedAdapter.json(200, {}));
    final api = ApiClient(device: _device(), tokens: store, language: () => AppLanguage.uz, baseUrl: 'https://api.test/api/v1/', adapter: adapter);

    await api.post('auth/login/', body: {'phone': '+998901234567', 'password': 'x'});
    await api.post('cart/items/', body: {'product_id': 1}, idempotencyKey: 'key-1');

    expect(adapter.requests[0].headers['X-GD-Device-Key'], 'k' * 43);
    expect(adapter.requests[0].headers.containsKey('Authorization'), isFalse);
    expect(adapter.requests[1].headers.containsKey('X-GD-Device-Key'), isFalse);
    expect(adapter.requests[1].headers['Idempotency-Key'], 'key-1');
  });

  test('a reinstall drops the previous session but keeps the device key', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'gd.session': '{"refresh":"old","refresh_expires_at":"2099-01-01T00:00:00Z"}',
      'gd.device_key': 'key',
    });
    final store = TokenStore(secureStorage);
    await store.load(await SharedPreferences.getInstance());
    expect(store.hasSession, isFalse);
    expect(store.deviceKey, 'key');
  });
}
