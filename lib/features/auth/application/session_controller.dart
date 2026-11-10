import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/json.dart';
import '../../../core/push/push_service.dart';
import '../data/auth_models.dart';

/// Who is using the app.
@immutable
class AuthState {
  const AuthState({required this.signedIn, this.me, this.notice});

  /// The session exists (tokens stored). [me] may still be loading.
  final bool signedIn;
  final Me? me;

  /// A message to show once (e.g. the server's `password_changed` text).
  final String? notice;

  AuthState copyWith({Me? me, String? notice}) =>
      AuthState(signedIn: signedIn, me: me ?? this.me, notice: notice);
}

/// Owns the signed-in state; everything else reacts to it.
class SessionController extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.listen(sessionEventsProvider, (_, end) {
      if (end == null) return;
      ref.read(sessionEventsProvider.notifier).consumed();
      state = AuthState(
        signedIn: false,
        notice: end.message.isEmpty ? null : end.message,
      );
    });
    final signedIn = ref.read(tokenStoreProvider).hasSession;
    if (signedIn) Future.microtask(refreshMe);
    return AuthState(signedIn: signedIn);
  }

  /// Called with the body of a successful sign-in (`AuthTokens`).
  Future<void> signedIn(Json tokens) async {
    await ref.read(tokenStoreProvider).save(tokens);
    final me = Me.fromJson(asJson(tokens['customer']));
    state = AuthState(signedIn: true, me: me);
    unawaited(_afterSignIn(me));
  }

  Future<void> _afterSignIn(Me me) async {
    // Follow the account's language unless the user picked one on this device
    // before signing in (then tell the server instead).
    final current = ref.read(languageProvider);
    if (me.language != current.code) {
      try {
        state = state.copyWith(
          me: await ref.read(authApiProvider).updateMe(language: current),
        );
      } on Object {
        // not important enough to bother the user
      }
    }
    // Device registration (`PUT me/device/`) is done by the push service,
    // which the app runs after every sign-in (lib/app/app.dart).
  }

  /// `PUT me/device/` — on every cold start and after every sign-in.
  Future<void> registerDevice({
    String? fcmToken,
    bool pushEnabled = false,
  }) async {
    if (!state.signedIn) return;
    final device = ref.read(deviceProvider);
    try {
      await ref
          .read(authApiProvider)
          .registerDevice(
            fcmToken: fcmToken,
            pushEnabled: pushEnabled && fcmToken != null,
            model: device.model,
            os: device.os,
            locale: ref.read(languageProvider).code,
          );
    } on Object {
      // retried on the next start
    }
  }

  Future<void> refreshMe() async {
    if (!ref.read(tokenStoreProvider).hasSession) return;
    try {
      final me = await ref.read(authApiProvider).me();
      if (state.signedIn) state = state.copyWith(me: me);
      // On every cold start: register the device (and the push token).
      unawaited(ref.read(pushServiceProvider).onSignedIn());
    } on SessionEnded {
      // handled by the session events listener
    } on ApiException {
      // offline or a server hiccup: keep the session, try again later
    }
  }

  void updateMe(Me me) {
    if (state.signedIn) state = state.copyWith(me: me);
  }

  Future<void> setLanguage(AppLanguage language) async {
    await ref.read(languageProvider.notifier).set(language);
    if (state.signedIn) {
      try {
        updateMe(await ref.read(authApiProvider).updateMe(language: language));
      } on Object {
        // the next sign-in syncs it
      }
    }
  }

  Future<void> signOut() async {
    await ref.read(apiClientProvider).logout();
    state = const AuthState(signedIn: false);
  }

  /// After `DELETE me/` succeeded: the server already revoked every session.
  Future<void> accountDeleted() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AuthState(signedIn: false);
  }

  void clearNotice() =>
      state = AuthState(signedIn: state.signedIn, me: state.me);
}

final sessionProvider = NotifierProvider<SessionController, AuthState>(
  SessionController.new,
);
