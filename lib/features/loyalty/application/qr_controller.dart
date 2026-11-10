import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/loyalty_models.dart';

/// What the QR card shows.
@immutable
class QrState {
  const QrState({
    this.token,
    this.secondsLeft = 0,
    this.period = 0,
    this.loading = false,
    this.error,
    this.active = false,
    this.rateLimited = false,
  });

  /// The single-use token; null while hidden, loading the first time or failed.
  final QrToken? token;

  /// Seconds until the next automatic refresh.
  final int secondsLeft;

  /// Length of the current countdown (for the draining bar).
  final int period;
  final bool loading;
  final Object? error;

  /// The screen is visible and the app in the foreground.
  final bool active;

  /// The server throttled us (429): waiting `retry_after` before the next try.
  final bool rateLimited;

  /// 1 → 0 while the countdown runs.
  double get fraction =>
      period <= 0 ? 0 : (secondsLeft / period).clamp(0, 1).toDouble();

  QrState copyWith({
    int? secondsLeft,
    int? period,
    bool? loading,
    bool? rateLimited,
  }) => QrState(
    token: token,
    secondsLeft: secondsLeft ?? this.secondsLeft,
    period: period ?? this.period,
    loading: loading ?? this.loading,
    error: error,
    active: active,
    rateLimited: rateLimited ?? this.rateLimited,
  );
}

/// The QR token lifecycle (contract §2.9.3), independent of widgets so it can
/// be tested with fake time:
/// - a token is fetched when the screen becomes [setActive] (visible + app
///   resumed) and dropped from memory as soon as it is not;
/// - it is refreshed automatically after `refresh_in_seconds`;
/// - a manual [refresh] is throttled client-side ([minManualInterval]);
/// - a 429 waits `retry_after` seconds, then tries again.
class QrController extends ValueNotifier<QrState> {
  QrController({
    required this._fetch,
    DateTime Function()? now,
    this.minManualInterval = const Duration(seconds: 10),
  }) : _now = now ?? DateTime.now,
       super(const QrState());

  final Future<QrToken> Function() _fetch;
  final DateTime Function() _now;
  final Duration minManualInterval;

  Timer? _ticker;
  int _generation = 0;
  bool _inFlight = false;
  bool _disposed = false;
  DateTime? _lastFetch;

  /// Local end of life of the shown token (issue time + `ttl_seconds`; the
  /// phone clock may differ from the server's `expires_at`).
  DateTime? _tokenDiesAt;

  bool get isActive => value.active;

  /// Shows (true) or hides (false) the code. Hiding cancels the timers,
  /// forgets the token and ignores an answer still on its way; showing again
  /// always fetches a fresh token.
  void setActive(bool active) {
    if (_disposed || active == value.active) return;
    _generation++;
    _ticker?.cancel();
    _inFlight = false;
    value = QrState(active: active);
    if (active) unawaited(_load());
  }

  /// The "Yangilash" tap. Returns false when ignored (hidden, a request on its
  /// way, waiting for the server throttle, or less than [minManualInterval]
  /// since the last request while a code is shown).
  Future<bool> refresh() async {
    if (_disposed || !value.active || _inFlight || value.rateLimited) {
      return false;
    }
    final last = _lastFetch;
    if (value.token != null &&
        last != null &&
        _now().difference(last) < minManualInterval) {
      return false;
    }
    await _load();
    return true;
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _ticker?.cancel();
    _inFlight = true;
    _lastFetch = _now();
    value = QrState(
      token: value.token,
      secondsLeft: value.secondsLeft,
      period: value.period,
      loading: true,
      active: true,
    );
    try {
      final token = await _fetch();
      if (_stale(generation)) return;
      final period = math.max(token.refreshInSeconds, 5);
      _tokenDiesAt = _now().add(
        Duration(seconds: math.max(token.ttlSeconds, period)),
      );
      value = QrState(
        token: token,
        secondsLeft: period,
        period: period,
        active: true,
      );
      _startTicker();
    } on ApiException catch (e) {
      if (_stale(generation)) return;
      if (e.status == 429) {
        final wait = math.max(e.retryAfter ?? 10, 1);
        value = QrState(
          token: value.token,
          secondsLeft: wait,
          period: wait,
          active: true,
          rateLimited: true,
        );
        _startTicker();
      } else {
        value = QrState(error: e, active: true);
      }
    } on Object catch (e) {
      if (_stale(generation)) return;
      value = QrState(error: e, active: true);
    } finally {
      if (generation == _generation) _inFlight = false;
    }
  }

  bool _stale(int generation) => _disposed || generation != _generation;

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = value.secondsLeft - 1;
      if (left <= 0) {
        t.cancel();
        value = value.copyWith(secondsLeft: 0);
        unawaited(_load());
      } else {
        final dies = _tokenDiesAt;
        if (value.token != null && dies != null && !_now().isBefore(dies)) {
          // Still waiting (429) past the token's life: the cashier could not
          // use it any more, so stop showing it.
          value = QrState(
            secondsLeft: left,
            period: value.period,
            active: true,
            rateLimited: value.rateLimited,
          );
        } else {
          value = value.copyWith(secondsLeft: left);
        }
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _ticker?.cancel();
    super.dispose();
  }
}
