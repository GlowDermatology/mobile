import '../../../core/network/json.dart';

/// `link` of an inbox item (contract §2.12). Every key is always present.
class InboxLink {
  const InboxLink({
    required this.kind,
    this.productId,
    this.orderId,
    this.appointmentId,
    this.url,
  });

  factory InboxLink.fromJson(Json json) => InboxLink(
    kind: asString(json['kind'], 'none'),
    productId: asIntOrNull(json['product_id']),
    orderId: asIntOrNull(json['order_id']),
    appointmentId: asIntOrNull(json['appointment_id']),
    url: asStringOrNull(json['url']),
  );

  static const none = InboxLink(kind: 'none');

  /// none | product | order | appointment | url
  final String kind;
  final int? productId;
  final int? orderId;
  final int? appointmentId;
  final String? url;
}

/// `InboxItem` of `GET me/notifications/`.
class InboxItem {
  const InboxItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.link,
    required this.createdAt,
    required this.readAt,
    this.imageMediumUrl,
  });

  factory InboxItem.fromJson(Json json) => InboxItem(
    id: asInt(json['id']),
    kind: asString(json['kind'], 'general'),
    title: asString(json['title']),
    body: asString(json['body']),
    imageUrl: asStringOrNull(json['image_url']),
    imageMediumUrl: asStringOrNull(json['image_medium_url']),
    link: json['link'] is Map
        ? InboxLink.fromJson(asJson(json['link']))
        : InboxLink.none,
    createdAt: asDate(json['created_at']),
    readAt: asDate(json['read_at']),
  );

  final int id;

  /// promo | general | order_status | appointment
  final String kind;
  final String title;
  final String body;
  final String? imageUrl;

  /// 1000 px variant (null → the original).
  final String? imageMediumUrl;
  String? get mediumUrl => imageMediumUrl ?? imageUrl;
  final InboxLink link;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  InboxItem markRead(DateTime at) => InboxItem(
    id: id,
    kind: kind,
    title: title,
    body: body,
    imageUrl: imageUrl,
    link: link,
    createdAt: createdAt,
    readAt: readAt ?? at,
  );
}
