import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/app/providers.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/features/orders/application/orders_list_controller.dart';
import 'package:glow_derma/features/orders/data/order_models.dart';
import 'package:glow_derma/features/orders/data/orders_api.dart';

import 'fakes.dart';

class _Uz extends LanguageController {
  @override
  AppLanguage build() => AppLanguage.uz;
}

void main() {
  late FakeOrdersApi api;
  late ProviderContainer container;

  setUp(() {
    api = FakeOrdersApi(
      pages: {
        OrderScope.active: [
          summaryPage([10, 9], page: 1, pageCount: 2),
          summaryPage([9, 8], page: 2, pageCount: 2),
        ],
      },
    );
    container = ProviderContainer(
      overrides: [
        ordersApiProvider.overrideWithValue(api),
        languageProvider.overrideWith(_Uz.new),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'loads the first page, appends the next without duplicates, then stops',
    () async {
      final sub = container.listen(
        ordersListProvider(OrderScope.active),
        (_, _) {},
      );
      addTearDown(sub.close);
      final first = await container.read(
        ordersListProvider(OrderScope.active).future,
      );
      expect(first.items.map((o) => o.id), [10, 9]);
      expect(first.hasMore, isTrue);

      await container
          .read(ordersListProvider(OrderScope.active).notifier)
          .loadMore();
      final second = container
          .read(ordersListProvider(OrderScope.active))
          .value!;
      expect(second.items.map((o) => o.id), [10, 9, 8]);
      expect(second.hasMore, isFalse);

      await container
          .read(ordersListProvider(OrderScope.active).notifier)
          .loadMore();
      expect(api.listCalls, [(OrderScope.active, 1), (OrderScope.active, 2)]);
    },
  );

  test('a failed next page stays on the state and can be retried', () async {
    final sub = container.listen(
      ordersListProvider(OrderScope.active),
      (_, _) {},
    );
    addTearDown(sub.close);
    await container.read(ordersListProvider(OrderScope.active).future);
    api.listError = Exception('offline');
    await container
        .read(ordersListProvider(OrderScope.active).notifier)
        .loadMore();
    var state = container.read(ordersListProvider(OrderScope.active)).value!;
    expect(state.loadMoreError, isNotNull);
    expect(state.loadingMore, isFalse);
    expect(state.items, hasLength(2));

    api.listError = null;
    await container
        .read(ordersListProvider(OrderScope.active).notifier)
        .loadMore();
    state = container.read(ordersListProvider(OrderScope.active)).value!;
    expect(state.loadMoreError, isNull);
    expect(state.items, hasLength(3));
  });
}
