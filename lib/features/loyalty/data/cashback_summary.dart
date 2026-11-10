import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/json.dart';
import '../../auth/application/session_controller.dart';

/// `GET me/cashback/` (contract §2.9.1).
class CashbackSummary {
  const CashbackSummary(this.raw);
  final Json raw;

  int get balance => asInt(raw['balance']);
  int get held => asInt(raw['held']);
  int get available => asInt(raw['available']);
  int get lifetimeTotal => asInt(raw['lifetime_total']);

  /// Current tier percent as sent ("1.00"), null without a tier.
  String? get percent => asStringOrNull(asJson(raw['tier'])['percent']);

  /// "1" / "1,5" for display.
  String get percentLabel {
    final p = double.tryParse(percent ?? '');
    if (p == null) return '0';
    final s = p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toString();
    return s.replaceAll('.', ',');
  }

  Json get nextTier => asJson(raw['next_tier']);
  List<Json> get tiers => asJsonList(raw['tiers']);
}

/// Null for guests.
final cashbackSummaryProvider = FutureProvider<CashbackSummary?>((ref) async {
  if (!ref.watch(sessionProvider.select((s) => s.signedIn))) return null;
  return CashbackSummary(asJson(await ref.watch(apiClientProvider).get('me/cashback/')));
});
