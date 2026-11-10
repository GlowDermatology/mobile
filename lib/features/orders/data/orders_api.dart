import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/network/page.dart';
import '../../cart/data/cart_models.dart';
import 'order_models.dart';

/// Orders, payment, cancel and reorder (contract §2.7.2–§2.8, §2.15).
class OrdersApi {
  OrdersApi(this._api);
  final ApiClient _api;

  static const pageSize = 10;

  Future<Page<OrderSummary>> list(OrderScope scope, {int page = 1}) async =>
      Page.fromJson(
        asJson(
          await _api.get(
            'me/orders/',
            query: {'scope': scope.code, 'page': page, 'page_size': pageSize},
          ),
        ),
        OrderSummary.fromJson,
      );

  Future<OrderDetail> detail(int id) async =>
      OrderDetail.fromJson(asJson(await _api.get('me/orders/$id/')));

  Future<PayResult> pay(
    int id,
    String? provider, {
    required String idempotencyKey,
  }) async => PayResult.fromJson(
    asJson(
      await _api.post(
        'orders/$id/pay/',
        body: {'provider': provider},
        idempotencyKey: idempotencyKey,
      ),
    ),
  );

  Future<OrderDetail> cancel(int id, {required String idempotencyKey}) async =>
      OrderDetail.fromJson(
        asJson(
          await _api.post('orders/$id/cancel/', idempotencyKey: idempotencyKey),
        ),
      );

  Future<Cart> reorder(int id, {required String idempotencyKey}) async =>
      Cart.fromJson(
        asJson(
          await _api.post(
            'orders/$id/reorder/',
            idempotencyKey: idempotencyKey,
          ),
        ),
      );

  /// Local/test backends only (`AppConfig.allowDevTools`).
  Future<void> simulatePayment(
    int id, {
    String outcome = 'success',
    String? provider,
  }) async => _api.post(
    'dev/payments/$id/simulate/',
    body: {'outcome': outcome, 'provider': provider},
  );
}

final ordersApiProvider = Provider<OrdersApi>(
  (ref) => OrdersApi(ref.watch(apiClientProvider)),
);

/// One order, re-read whenever a screen opens it.
final orderDetailProvider = FutureProvider.autoDispose.family<OrderDetail, int>(
  (ref, id) {
    ref.watch(languageProvider);
    return ref.watch(ordersApiProvider).detail(id);
  },
  retry: (_, _) => null,
);
