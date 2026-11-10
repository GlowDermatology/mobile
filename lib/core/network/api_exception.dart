import 'json.dart';

/// Any non-2xx answer of the API, or a transport failure.
///
/// The app branches on [code] only, never on [message]; [message] is already
/// localized by the server (Accept-Language) and is what the user sees.
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.fieldErrors = const {},
    this.fieldCodes = const {},
    this.details = const {},
    this.requestId,
    this.retryAfter,
  });

  /// Builds the exception from the error envelope
  /// `{code, message, errors[{field, code, message}], details, request_id}`.
  factory ApiException.fromEnvelope(int status, Object? body, {int? retryAfter}) {
    final json = asJson(body);
    final fields = <String, String>{};
    final fieldCodes = <String, String>{};
    for (final e in asJsonList(json['errors'])) {
      final field = asString(e['field']);
      fields.putIfAbsent(field, () => asString(e['message']));
      fieldCodes.putIfAbsent(field, () => asString(e['code']));
    }
    final details = asJson(json['details']);
    return ApiException(
      status: status,
      code: asString(json['code'], 'http_$status'),
      message: asString(json['message']),
      fieldErrors: fields,
      fieldCodes: fieldCodes,
      details: details,
      requestId: asStringOrNull(json['request_id']),
      retryAfter: retryAfter ?? asIntOrNull(details['retry_after']),
    );
  }

  /// No answer (offline, timeout, DNS…).
  static const network = ApiException(status: 0, code: 'network_error', message: '');

  final int status;
  final String code;
  final String message;
  final Map<String, String> fieldErrors;
  final Map<String, String> fieldCodes;
  final Json details;
  final String? requestId;

  /// Seconds to wait, from `Retry-After` or `details.retry_after`.
  final int? retryAfter;

  bool get isNetwork => status == 0;
  bool get isConflict => status == 409;

  /// The first field error, or the top-level message.
  String get displayMessage => message.isNotEmpty ? message : (fieldErrors.values.isEmpty ? '' : fieldErrors.values.first);

  @override
  String toString() => 'ApiException($status $code)';
}

/// The session ended on the server (`SESSION_EXPIRED`, `password_changed`, a
/// refused refresh). Requests fail with this after the app signed out.
class SessionEnded implements Exception {
  const SessionEnded(this.code, [this.message = '']);
  final String code;
  final String message;
  @override
  String toString() => 'SessionEnded($code)';
}
