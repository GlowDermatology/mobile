import 'json.dart';

/// The pagination envelope `{count, page, page_size, page_count, results}`.
class Page<T> {
  const Page({
    required this.items,
    required this.count,
    required this.page,
    required this.pageCount,
    this.extra = const {},
  });

  factory Page.fromJson(Json json, T Function(Json) item) => Page(
    items: asJsonList(json['results']).map(item).toList(),
    count: asInt(json['count']),
    page: asInt(json['page'], 1),
    pageCount: asInt(json['page_count'], 1),
    extra: json,
  );

  final List<T> items;
  final int count;
  final int page;
  final int pageCount;

  /// The whole envelope, for endpoint-specific keys such as `unread_count`.
  final Json extra;

  bool get hasMore => page < pageCount;
}
