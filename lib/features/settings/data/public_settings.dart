import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/json.dart';

/// Payment providers this app can hand off to (`PaymentProvider`, contract §3).
const knownPaymentProviders = {'click', 'payme', 'uzum'};

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

  /// Online payment providers the shop offers now, in the server's order
  /// (`click`, `payme`, `uzum`). Values this app does not know are dropped,
  /// so a provider added later on the server never reaches the picker or the
  /// checkout body.
  List<String> get paymentProviders {
    final list = asStringList(raw['payment_providers']);
    return <String>{
      for (final p in list)
        if (knownPaymentProviders.contains(p)) p,
    }.toList();
  }

  bool get onlineSalesEnabled => raw['online_sales_enabled'] != false;
  List<String> get fulfilmentMethods => asStringList(raw['fulfilment_methods']);

  /// Home-delivery carriers that can take an order now, preferred first
  /// (`delivery.providers`: `yandex`, `bts`). Unknown values are dropped.
  List<String> get deliveryProviders {
    final list = asStringList(asJson(raw['delivery'])['providers']);
    return <String>{
      for (final p in list)
        if (p == 'yandex' || p == 'bts') p,
    }.toList();
  }

  /// What the checkout offers, delivery first. `fulfilment_methods` still
  /// means BTS only, so delivery is also offered when any carrier is listed
  /// (a Yandex-only deployment).
  List<String> get offeredFulfilments {
    final methods = fulfilmentMethods;
    return [
      if (methods.contains('delivery') || deliveryProviders.isNotEmpty)
        'delivery',
      if (methods.contains('pickup')) 'pickup',
    ];
  }
}

/// Cached for the app session; re-read when the language changes.
final publicSettingsProvider = FutureProvider<PublicSettings>((ref) async {
  ref.watch(languageProvider);
  final api = ref.watch(apiClientProvider);
  return PublicSettings(asJson(await api.get('settings/public/')));
});
