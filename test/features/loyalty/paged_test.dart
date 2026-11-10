import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/network/json.dart';
import 'package:glow_derma/core/network/page.dart';
import 'package:glow_derma/features/auth/application/session_controller.dart';
import 'package:glow_derma/features/loyalty/application/paged.dart';

import 'harness.dart';

/// Pages of ints; each request waits for its completer.
class _Numbers extends PagedNotifier<int> {
  static final requests = <(int, Completer<Page<int>>)>[];

  @override
  Future<Page<int>> fetchPage(int page) {
    final c = Completer<Page<int>>();
    requests.add((page, c));
    return c.future;
  }

  @override
  Object keyOf(int item) => item;
}

final _numbers = AsyncNotifierProvider<_Numbers, PagedState<int>>(_Numbers.new);

Page<int> _page(int page, int pageCount) => Page.fromJson({
  'count': pageCount * 2,
  'page': page,
  'page_size': 2,
  'page_count': pageCount,
  'results': [
    {'v': page * 10 + 1},
    {'v': page * 10 + 2},
  ],
}, (j) => asInt(j['v']));

void main() {
  setUp(_Numbers.requests.clear);

  test(
    'a next-page answer that arrives after a pull to refresh is dropped',
    () async {
      final container = ProviderContainer(
        overrides: [sessionProvider.overrideWith(FakeSession.new)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(_numbers, (_, _) {});
      addTearDown(sub.close);
      _Numbers.requests.single.$2.complete(_page(1, 3));
      await container.read(_numbers.future);

      final more = container.read(_numbers.notifier).loadMore();
      final refresh = container.read(_numbers.notifier).refresh();
      expect(_Numbers.requests.map((r) => r.$1), [1, 2, 1]);
      _Numbers.requests[2].$2.complete(_page(1, 3));
      await refresh;
      _Numbers.requests[1].$2.complete(_page(2, 3));
      await more;

      final state = container.read(_numbers).value!;
      expect(state.items, [11, 12]);
      expect(state.page, 1);
      expect(state.loadingMore, isFalse);
    },
  );

  test(
    'a failed refresh during a page load does not leave the spinner on',
    () async {
      final container = ProviderContainer(
        overrides: [sessionProvider.overrideWith(FakeSession.new)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(_numbers, (_, _) {});
      addTearDown(sub.close);
      _Numbers.requests.single.$2.complete(_page(1, 3));
      await container.read(_numbers.future);

      final more = container.read(_numbers.notifier).loadMore();
      final refresh = container.read(_numbers.notifier).refresh();
      _Numbers.requests[2].$2.completeError(Exception('offline'));
      await refresh;
      _Numbers.requests[1].$2.complete(_page(2, 3));
      await more;

      final state = container.read(_numbers).value!;
      expect(state.items, [11, 12]);
      expect(state.loadingMore, isFalse);
      expect(state.hasMore, isTrue);
    },
  );
}
