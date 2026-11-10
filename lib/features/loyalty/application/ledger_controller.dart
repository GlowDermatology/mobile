import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/page.dart';
import '../data/loyalty_api.dart';
import '../data/loyalty_models.dart';
import 'paged.dart';

/// "Cashback tarixi": `GET me/cashback/ledger/`, newest first.
class LedgerController extends PagedNotifier<LedgerItem> {
  @override
  Future<Page<LedgerItem>> fetchPage(int page) =>
      ref.read(loyaltyApiProvider).ledger(page: page);

  @override
  Object keyOf(LedgerItem item) => item.id;
}

final ledgerProvider =
    AsyncNotifierProvider<LedgerController, PagedState<LedgerItem>>(
      LedgerController.new,
    );
