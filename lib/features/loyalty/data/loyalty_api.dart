import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/network/page.dart';
import 'loyalty_models.dart';

/// Loyalty endpoints of contract §2.9.
class LoyaltyApi {
  const LoyaltyApi(this._api);
  final ApiClient _api;

  static const pageSize = 20;

  Future<Page<LedgerItem>> ledger({int page = 1}) async => Page.fromJson(
    asJson(
      await _api.get(
        'me/cashback/ledger/',
        query: {'page': page, 'page_size': pageSize},
      ),
    ),
    LedgerItem.fromJson,
  );

  Future<QrToken> qr() async =>
      QrToken.fromJson(asJson(await _api.get('me/qr/')));
}

final loyaltyApiProvider = Provider<LoyaltyApi>(
  (ref) => LoyaltyApi(ref.watch(apiClientProvider)),
);
