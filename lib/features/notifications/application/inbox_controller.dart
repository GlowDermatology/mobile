import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/network/page.dart';
import '../../loyalty/application/paged.dart';
import '../data/unread_count.dart';
import 'inbox_models.dart';

/// Inbox endpoints of contract §2.12.
class InboxApi {
  const InboxApi(this._api);
  final ApiClient _api;

  static const pageSize = 20;

  Future<Page<InboxItem>> list({int page = 1}) async => Page.fromJson(
    asJson(
      await _api.get(
        'me/notifications/',
        query: {'page': page, 'page_size': pageSize},
      ),
    ),
    InboxItem.fromJson,
  );

  /// → `{id, read_at, unread_count}`
  Future<Json> read(int id) async =>
      asJson(await _api.post('me/notifications/$id/read/'));

  /// → `{updated, unread_count}`
  Future<Json> readAll() async =>
      asJson(await _api.post('me/notifications/read-all/'));
}

final inboxApiProvider = Provider<InboxApi>(
  (ref) => InboxApi(ref.watch(apiClientProvider)),
);

/// The notifications feed, newest first, with the bell count kept in sync.
class InboxController extends PagedNotifier<InboxItem> {
  @override
  Future<Page<InboxItem>> fetchPage(int page) =>
      ref.read(inboxApiProvider).list(page: page);

  @override
  Object keyOf(InboxItem item) => item.id;

  @override
  void onPage(Json extra) {
    if (extra.containsKey('unread_count')) {
      ref.read(unreadCountProvider.notifier).set(asInt(extra['unread_count']));
    }
  }

  void _update(InboxItem Function(InboxItem) change, {int? onlyId}) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final i in current.items)
            onlyId == null || i.id == onlyId ? change(i) : i,
        ],
        moreError: current.moreError,
      ),
    );
  }

  /// Marks one item read (optimistic; `POST {id}/read/` is idempotent).
  Future<void> markRead(int id) async {
    final item = state.value?.items.where((i) => i.id == id).firstOrNull;
    if (item != null && !item.unread) return;
    _update((i) => i.markRead(DateTime.now()), onlyId: id);
    try {
      final json = await ref.read(inboxApiProvider).read(id);
      if (!ref.mounted) return;
      ref.read(unreadCountProvider.notifier).set(asInt(json['unread_count']));
    } on Object {
      // The item stays read locally; the next refresh shows the server's view.
    }
  }

  /// "Hammasini o‘qish". Throws on failure (the caller shows it).
  Future<void> markAllRead() async {
    final json = await ref.read(inboxApiProvider).readAll();
    if (!ref.mounted) return;
    final now = DateTime.now();
    _update((i) => i.markRead(now));
    ref.read(unreadCountProvider.notifier).set(asInt(json['unread_count']));
  }
}

final inboxProvider =
    AsyncNotifierProvider.autoDispose<InboxController, PagedState<InboxItem>>(
      InboxController.new,
    );
