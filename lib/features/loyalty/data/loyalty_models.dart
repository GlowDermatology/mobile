import '../../../core/network/json.dart';

/// `LedgerItem` of `GET me/cashback/ledger/` (contract §2.9.2).
class LedgerItem {
  const LedgerItem({
    required this.id,
    required this.at,
    required this.kind,
    required this.amount,
    required this.balanceAfter,
    required this.title,
    required this.subtitle,
    required this.orderId,
    required this.source,
  });

  factory LedgerItem.fromJson(Json json) => LedgerItem(
    id: asInt(json['id']),
    at: asDate(json['at']),
    kind: asString(json['kind']),
    amount: asInt(json['amount']),
    balanceAfter: asInt(json['balance_after']),
    title: asString(json['title']),
    subtitle: asStringOrNull(json['subtitle']),
    orderId: asIntOrNull(json['order_id']),
    source: asString(json['source']),
  );

  final int id;
  final DateTime? at;

  /// credit | debit | adjustment | reversal
  final String kind;

  /// Signed so‘m.
  final int amount;
  final int balanceAfter;
  final String title;
  final String? subtitle;
  final int? orderId;

  /// online | store | admin
  final String source;

  bool get isStore => source == 'store';
  bool get isDebit => kind == 'debit';
}

/// The personal QR token of `GET me/qr/` (contract §2.9.3). Kept in memory
/// only.
class QrToken {
  const QrToken({
    required this.token,
    required this.expiresAt,
    required this.ttlSeconds,
    required this.refreshInSeconds,
  });

  factory QrToken.fromJson(Json json) => QrToken(
    token: asString(json['token']),
    expiresAt: asDate(json['expires_at']),
    ttlSeconds: asInt(json['ttl_seconds'], 60),
    refreshInSeconds: asInt(json['refresh_in_seconds'], 50),
  );

  final String token;
  final DateTime? expiresAt;
  final int ttlSeconds;
  final int refreshInSeconds;
}

/// "1.00" → "1", "1.50" → "1,5" (the comma rule of the contract; a dot in
/// English).
String percentText(Object? percent, {bool english = false}) {
  final p = asDoubleOrNull(percent);
  if (p == null) return '0';
  var s = p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '');
  return english ? s : s.replaceAll('.', ',');
}
