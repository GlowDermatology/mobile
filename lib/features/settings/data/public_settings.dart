import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/json.dart';

/// `GET settings/public/` (contract §2.4): contacts, legal texts and what the
/// shop can do right now (payment providers, delivery, online sales).
class PublicSettings {
  const PublicSettings(this.raw);
  final Json raw;

  String? get supportPhone => asStringOrNull(raw['support_phone']);
  String? get storePhone => asStringOrNull(raw['store_phone']);
  String? get telegramUrl => asStringOrNull(raw['telegram_url']);
  String? get instagramUrl => asStringOrNull(raw['instagram_url']);
  String? get websiteUrl => asStringOrNull(raw['website_url']);
  String get pickupAddress => asString(raw['pickup_address']);
  String get privacyPolicy => asString(raw['privacy_policy']);
  String get terms => asString(raw['terms']);
  String get bookingPolicy => asString(raw['booking_policy']);
  String? get termsVersion => asStringOrNull(raw['terms_version']);
  int get reservationMinutes => asInt(raw['reservation_minutes'], 15);
  List<String> get paymentProviders => asStringList(raw['payment_providers']);
  bool get onlineSalesEnabled => raw['online_sales_enabled'] != false;
  List<String> get fulfilmentMethods => asStringList(raw['fulfilment_methods']);
}

/// Cached for the app session; re-read when the language changes.
final publicSettingsProvider = FutureProvider<PublicSettings>((ref) async {
  ref.watch(languageProvider);
  final api = ref.watch(apiClientProvider);
  return PublicSettings(asJson(await api.get('settings/public/')));
});
