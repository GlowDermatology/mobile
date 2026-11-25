import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import 'auth_models.dart';

/// What a provider SDK gave back.
sealed class SocialAuthResult {
  const SocialAuthResult();
}

/// A token for `auth/social/` (contract §2.1.8).
class SocialCredential extends SocialAuthResult {
  const SocialCredential({
    required this.provider,
    required this.token,
    required this.tokenType,
    this.nonce,
  });
  final SocialProvider provider;
  final String token;

  /// `id_token` (Google, Facebook Limited Login on iOS) or `access_token`
  /// (Facebook on Android).
  final String tokenType;

  /// The raw nonce the ID token carries; null for an access token.
  final String? nonce;
}

/// The person closed the provider's sheet: nothing to say.
class SocialCancelled extends SocialAuthResult {
  const SocialCancelled();
}

/// The provider SDK failed (misconfiguration, no network, …).
class SocialAuthException implements Exception {
  const SocialAuthException(this.detail);
  final String detail;
  @override
  String toString() => 'SocialAuthException($detail)';
}

/// Google and Facebook sign-in behind one interface, so the screens can be
/// tested with a fake. The caller fetches the single-use nonce from the API
/// (`auth/social/nonce/`) before every attempt and passes it in.
abstract class SocialAuth {
  /// Providers whose client ids this build carries (none on the web preview).
  Set<SocialProvider> get configured;

  Future<SocialAuthResult> signIn(
    SocialProvider provider, {
    required String nonce,
  });
}

/// The real SDKs: `google_sign_in` (v7 API) and `flutter_facebook_auth`.
class PluginSocialAuth implements SocialAuth {
  const PluginSocialAuth();

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _android => defaultTargetPlatform == TargetPlatform.android;

  @override
  Set<SocialProvider> get configured {
    if (kIsWeb || !(_ios || _android)) return const {};
    return {
      if (_android
          ? AppConfig.googleServerClientId.isNotEmpty
          : AppConfig.googleIosClientId.isNotEmpty)
        SocialProvider.google,
      if (AppConfig.facebookAppId.isNotEmpty &&
          AppConfig.facebookClientToken.isNotEmpty)
        SocialProvider.facebook,
    };
  }

  @override
  Future<SocialAuthResult> signIn(
    SocialProvider provider, {
    required String nonce,
  }) => switch (provider) {
    SocialProvider.google => _google(nonce),
    SocialProvider.facebook => _facebook(nonce),
  };

  Future<SocialAuthResult> _google(String nonce) async {
    final google = GoogleSignIn.instance;
    try {
      // The nonce is part of the configuration, so it is set again before
      // every attempt (re-initialising only stores the new values).
      await google.initialize(
        clientId: _ios ? AppConfig.googleIosClientId : null,
        serverClientId: AppConfig.googleServerClientId.isEmpty
            ? null
            : AppConfig.googleServerClientId,
        nonce: nonce,
      );
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SocialAuthException('google: no id token');
      }
      // The app keeps no Google session: the next attempt shows the picker.
      google.signOut().ignore();
      return SocialCredential(
        provider: SocialProvider.google,
        token: idToken,
        tokenType: 'id_token',
        nonce: nonce,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const SocialCancelled();
      }
      throw SocialAuthException('google: ${e.code.name}');
    } on SocialAuthException {
      rethrow;
    } on Object catch (e) {
      throw SocialAuthException('google: $e');
    }
  }

  Future<SocialAuthResult> _facebook(String nonce) async {
    try {
      final facebook = FacebookAuth.instance;
      // iOS: Limited Login, an OIDC ID token carrying our nonce. Android: a
      // classic access token, bound to our app id (no nonce).
      final result = await facebook.login(
        permissions: const ['email', 'public_profile'],
        loginTracking: _ios ? LoginTracking.limited : LoginTracking.enabled,
        nonce: _ios ? nonce : null,
      );
      switch (result.status) {
        case LoginStatus.cancelled:
          return const SocialCancelled();
        case LoginStatus.success:
          final token = result.accessToken;
          if (token == null || token.tokenString.isEmpty) {
            throw const SocialAuthException('facebook: no token');
          }
          final limited = token.type == AccessTokenType.limited;
          // Like Google: no Facebook session is kept in the app.
          facebook.logOut().ignore();
          return SocialCredential(
            provider: SocialProvider.facebook,
            token: token.tokenString,
            tokenType: limited ? 'id_token' : 'access_token',
            nonce: limited ? nonce : null,
          );
        case LoginStatus.failed:
        case LoginStatus.operationInProgress:
          throw SocialAuthException('facebook: ${result.status.name}');
      }
    } on SocialAuthException {
      rethrow;
    } on Object catch (e) {
      throw SocialAuthException('facebook: $e');
    }
  }
}

final socialAuthProvider = Provider<SocialAuth>(
  (ref) => const PluginSocialAuth(),
);

/// Providers the server switched off (404 from `auth/social/`): hidden for
/// the rest of the app session.
class SocialDisabledController extends Notifier<Set<SocialProvider>> {
  @override
  Set<SocialProvider> build() => const {};

  void disable(SocialProvider provider) => state = {...state, provider};
}

final socialDisabledProvider =
    NotifierProvider<SocialDisabledController, Set<SocialProvider>>(
      SocialDisabledController.new,
    );

/// The social buttons to show, in the website's order (Google, Facebook).
final socialProvidersProvider = Provider<List<SocialProvider>>((ref) {
  final configured = ref.watch(socialAuthProvider).configured;
  final disabled = ref.watch(socialDisabledProvider);
  return [
    for (final p in SocialProvider.values)
      if (configured.contains(p) && !disabled.contains(p)) p,
  ];
});
