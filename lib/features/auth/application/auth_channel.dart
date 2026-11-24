import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_models.dart';

/// The "Telefon | E-mail" switch of the auth screens: the last choice is
/// kept for the app session (in memory only).
class AuthChannelController extends Notifier<OtpChannel> {
  @override
  OtpChannel build() => OtpChannel.sms;

  void set(OtpChannel channel) => state = channel;
}

final authChannelProvider = NotifierProvider<AuthChannelController, OtpChannel>(
  AuthChannelController.new,
);
