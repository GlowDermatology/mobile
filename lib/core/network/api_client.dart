import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../device/device_identity.dart';
import '../i18n/tr.dart';
import '../storage/secure_store.dart';
import 'api_exception.dart';

/// HTTP client of the customer API (`backend/docs/api/customer-api-v1.md`).
///
/// * Adds the device headers (§1.2) and `Accept-Language` to every request.
/// * Attaches the bearer only while signed in, refreshing the 15-minute access
///   token first when it is about to expire.
/// * Refresh is **single-flight** (§1.2, §2.1.6): concurrent requests that
///   need a new token wait for one `auth/refresh/` call; the rotated refresh
///   token is persisted before any request is retried.
/// * 401 `SESSION_EXPIRED` / `password_changed`, or a refused refresh, wipe
///   the tokens and report the end of the session through [onSessionEnded].
/// * Every non-2xx answer becomes an [ApiException]; 426
///   `app_update_required` is also reported through [onUpdateRequired].
class ApiClient {
  ApiClient({
    required this.device,
    required this.tokens,
    required this.language,
    this.onSessionEnded,
    this.onUpdateRequired,
    String? baseUrl,
    HttpClientAdapter? adapter,
  }) {
    final base = _resolveBase(baseUrl ?? AppConfig.apiBaseUrl);
    BaseOptions options() => BaseOptions(
          baseUrl: base,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
        );
    _dio = Dio(options());
    _bare = Dio(options());
    for (final dio in [_dio, _bare]) {
      if (adapter != null) dio.httpClientAdapter = adapter;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) => h.next(_withDeviceHeaders(o))));
    }
  }

  final DeviceIdentity device;
  final TokenStore tokens;
  final AppLanguage Function() language;
  void Function(String code, String message)? onSessionEnded;
  void Function(ApiException error)? onUpdateRequired;

  late final Dio _dio;
  late final Dio _bare;
  Future<void>? _refreshing;

  static String _resolveBase(String base) {
    final withSlash = base.endsWith('/') ? base : '$base/';
    if (kIsWeb && withSlash.startsWith('/')) return Uri.base.resolve(withSlash).toString();
    return withSlash;
  }

  RequestOptions _withDeviceHeaders(RequestOptions o) {
    o.headers['X-GD-Device-Id'] = device.id;
    o.headers['X-GD-Platform'] = device.platform;
    o.headers['X-GD-App-Version'] = device.appVersion;
    o.headers['Accept-Language'] = language().code;
    if (o.path == 'auth/login/' && tokens.deviceKey != null) o.headers['X-GD-Device-Key'] = tokens.deviceKey;
    return o;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query, String? idempotencyKey}) =>
      _send('POST', path, body: body ?? const <String, dynamic>{}, query: query, idempotencyKey: idempotencyKey);

  Future<dynamic> patch(String path, {Object? body, String? idempotencyKey}) =>
      _send('PATCH', path, body: body ?? const <String, dynamic>{}, idempotencyKey: idempotencyKey);

  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body ?? const <String, dynamic>{});

  Future<dynamic> delete(String path, {Object? body, Map<String, dynamic>? query, String? idempotencyKey}) =>
      _send('DELETE', path, body: body, query: query, idempotencyKey: idempotencyKey);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
  }) async {
    final isAuthRoute = path.startsWith('auth/');
    for (var attempt = 0; attempt < 2; attempt++) {
      final headers = <String, dynamic>{'Idempotency-Key': ?idempotencyKey};
      String? used;
      if (!isAuthRoute && tokens.hasSession) {
        await _ensureAccess();
        used = tokens.access;
        if (used != null) headers['Authorization'] = 'Bearer $used';
      }
      try {
        final response = await _dio.request<dynamic>(
          path,
          data: body,
          queryParameters: query,
          options: Options(method: method, headers: headers),
        );
        return response.data;
      } on DioException catch (e) {
        final error = _toApiException(e);
        if (error.status == 401 && !isAuthRoute) {
          if (error.code == 'SESSION_EXPIRED' || error.code == 'password_changed') {
            await _end(error.code, error.message);
            throw error;
          }
          if (error.code == 'not_authenticated' && tokens.hasSession && attempt == 0) {
            // Retry once: with the token another request already refreshed,
            // or after refreshing ourselves.
            if (tokens.access == used) tokens.access = null;
            continue;
          }
        }
        if (error.status == 426) onUpdateRequired?.call(error);
        throw error;
      }
    }
    throw ApiException.network;
  }

  Future<void> _ensureAccess() async {
    final exp = tokens.accessExpiresAt;
    if (tokens.access != null && exp != null && exp.isAfter(DateTime.now().add(const Duration(seconds: 30)))) return;
    await refreshTokens();
  }

  /// Rotates the token pair; concurrent callers share one request.
  Future<void> refreshTokens() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<void> _doRefresh() async {
    final refresh = tokens.refresh;
    if (refresh == null) throw const SessionEnded('not_authenticated');
    try {
      final response = await _bare.post<dynamic>('auth/refresh/', data: {'refresh': refresh});
      await tokens.save((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      final error = _toApiException(e);
      if (error.status == 401) {
        await _end(error.code, error.status == 401 && error.code == 'password_changed' ? error.message : '');
        throw SessionEnded(error.code, error.message);
      }
      throw error; // 429, 5xx, offline: keep the tokens and try again later
    }
  }

  Future<void> _end(String code, String message) async {
    await tokens.clear();
    onSessionEnded?.call(code, message);
  }

  /// Signs out on the server (best effort) and wipes the tokens.
  Future<void> logout() async {
    final refresh = tokens.refresh;
    if (refresh != null) {
      try {
        await _bare.post<dynamic>('auth/logout/', data: {'refresh': refresh, 'scope': 'current'});
      } on DioException {
        // a 401 means the session is already over; offline: the token expires
      }
    }
    await tokens.clear();
  }

  ApiException _toApiException(DioException e) {
    final response = e.response;
    if (response == null) return ApiException.network;
    final retryAfter = int.tryParse(response.headers.value('retry-after') ?? '');
    return ApiException.fromEnvelope(response.statusCode ?? 0, response.data, retryAfter: retryAfter);
  }
}
