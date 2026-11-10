import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/json.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../../core/widgets/rings.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/presentation/consent_screen.dart';
import '../application/ledger_controller.dart';
import '../application/paged.dart';
import '../application/qr_controller.dart';
import '../data/cashback_summary.dart';
import '../data/loyalty_api.dart';
import '../data/loyalty_models.dart';
import 'loyalty_text.dart';

/// Raises the screen brightness and blocks screenshots while the QR shows.
/// Swappable in tests (the plugins have no implementation there).
class QrScreenEffects {
  const QrScreenEffects();

  /// Returns true when the brightness was raised.
  Future<bool> enter() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await FlutterWindowManagerPlus.addFlags(
          FlutterWindowManagerPlus.FLAG_SECURE,
        );
      } on Object {
        // not fatal
      }
    }
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> leave() async {
    if (kIsWeb) return;
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } on Object {
      // not fatal
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await FlutterWindowManagerPlus.clearFlags(
          FlutterWindowManagerPlus.FLAG_SECURE,
        );
      } on Object {
        // not fatal
      }
    }
  }
}

final qrScreenEffectsProvider = Provider<QrScreenEffects>(
  (ref) => const QrScreenEffects(),
);

/// The QR tab (PDF page 9): the single-use QR token for the cashier, the
/// cashback balance and the ledger.
class QrScreen extends ConsumerStatefulWidget {
  const QrScreen({super.key});

  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> {
  late final QrController _qr;
  late final AppLifecycleListener _lifecycle;
  late final QrScreenEffects _effects;
  bool _appResumed = true;
  bool _tabVisible = true;
  bool _wasActive = false;
  bool _activatedOnce = false;
  bool _brightnessRaised = false;
  bool _handledPhone = false;
  bool _handledTerms = false;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _effects = ref.read(qrScreenEffectsProvider);
    _qr = QrController(fetch: () => ref.read(loyaltyApiProvider).qr());
    _qr.addListener(_onQrChange);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appResumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) {
        _appResumed = s == AppLifecycleState.resumed;
        _scheduleSync();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabVisible = TickerMode.valuesOf(context).enabled;
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    scheduleMicrotask(() {
      _syncScheduled = false;
      if (mounted) _sync();
    });
  }

  void _sync() {
    final signedIn = ref.read(sessionProvider).signedIn;
    final active = _appResumed && _tabVisible && signedIn;
    if (active == _wasActive) return;
    _wasActive = active;
    _qr.setActive(active);
    if (active) {
      if (_activatedOnce) {
        // Back on the screen: a store purchase may have changed the balance.
        ref.invalidate(cashbackSummaryProvider);
        unawaited(ref.read(ledgerProvider.notifier).refresh());
      }
      _activatedOnce = true;
      unawaited(
        _effects.enter().then((raised) {
          if (mounted && _wasActive) setState(() => _brightnessRaised = raised);
        }),
      );
    } else {
      unawaited(_effects.leave());
      setState(() => _brightnessRaised = false);
    }
  }

  Future<void> _onQrChange() async {
    final error = _qr.value.error;
    if (error is! ApiException || !mounted) return;
    if (error.code == 'phone_required' && !_handledPhone) {
      _handledPhone = true;
      final attached = await context.push<bool>('/settings/phone') ?? false;
      if (attached && mounted) await _qr.refresh();
    } else if (error.code == 'terms_update_required' && !_handledTerms) {
      _handledTerms = true;
      if (await askConsent(context) && mounted) await _qr.refresh();
    }
  }

  Future<void> _refreshTap() async {
    tick();
    await _qr.refresh();
  }

  Future<void> _pullToRefresh() async {
    ref.invalidate(cashbackSummaryProvider);
    await Future.wait([
      ref.read(ledgerProvider.notifier).refresh(),
      if (_qr.value.token == null) _qr.refresh(),
    ]);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _qr.removeListener(_onQrChange);
    _qr.dispose();
    if (_wasActive) unawaited(_effects.leave());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sign-out while the tab is kept alive hides the code at once.
    ref.listen(
      sessionProvider.select((s) => s.signedIn),
      (_, _) => _scheduleSync(),
    );
    final ledger = ref.watch(ledgerProvider);
    final items = ledger.value?.items ?? const <LedgerItem>[];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 400) {
              ref.read(ledgerProvider.notifier).loadMore();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: _pullToRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(brightnessRaised: _brightnessRaised),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: GdSpace.page),
                  sliver: SliverList.list(
                    children: [
                      ValueListenableBuilder<QrState>(
                        valueListenable: _qr,
                        builder: (context, state, _) => _QrCard(
                          state: state,
                          onRefresh: _refreshTap,
                          onPhone: _attachPhone,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _BalanceCard(),
                      const SizedBox(height: 26),
                      Text(
                        LoyaltyText.historyTitle.of(context),
                        style: context.gdText.heading.copyWith(fontSize: 21),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                ...switch (ledger) {
                  AsyncValue(:final error?) when !ledger.hasValue => [
                    SliverToBoxAdapter(
                      child: GdErrorView(
                        error: error,
                        onRetry: () => ref.invalidate(ledgerProvider),
                      ),
                    ),
                  ],
                  _ when !ledger.hasValue => [
                    const SliverToBoxAdapter(child: GdLoading()),
                  ],
                  _ when items.isEmpty => [
                    const SliverToBoxAdapter(child: _LedgerEmpty()),
                  ],
                  _ => [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GdSpace.page,
                      ),
                      sliver: SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) => _LedgerRow(
                          item: items[i],
                          first: i == 0,
                          last: i == items.length - 1,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _LedgerFooter(state: ledger.value!),
                    ),
                  ],
                },
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _attachPhone() async {
    final attached = await context.push<bool>('/settings/phone') ?? false;
    if (attached && mounted) await _qr.refresh();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.brightnessRaised});
  final bool brightnessRaised;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Padding(
      padding: const EdgeInsets.fromLTRB(GdSpace.page, 18, GdSpace.page, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              LoyaltyText.title.of(context),
              style: context.gdText.displayLg.copyWith(fontSize: 30),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (brightnessRaised) ...[
            Icon(Icons.wb_sunny_outlined, size: 17, color: c.ink),
            const SizedBox(width: 6),
            Text(
              LoyaltyText.brightness.of(context),
              style: context.gdText.caption.copyWith(color: c.ink),
            ),
          ],
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.state,
    required this.onRefresh,
    required this.onPhone,
  });
  final QrState state;
  final VoidCallback onRefresh;
  final VoidCallback onPhone;

  static const _qrInk = Color(0xFF2A2418);

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final error = state.error;
    if (error is ApiException && error.code == 'phone_required') {
      return GdCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(Icons.phone_iphone_rounded, size: 40, color: c.goldInk),
            const SizedBox(height: 12),
            Text(
              LoyaltyText.phoneTitle.of(context),
              textAlign: TextAlign.center,
              style: context.gdText.heading,
            ),
            const SizedBox(height: 6),
            Text(
              LoyaltyText.phoneBody.of(context),
              textAlign: TextAlign.center,
              style: context.gdText.bodySm,
            ),
            const SizedBox(height: 16),
            GdButton(
              label: LoyaltyText.phoneAction.of(context),
              onPressed: onPhone,
              semanticsId: 'qr.phone',
            ),
          ],
        ),
      );
    }
    final token = state.token;
    return GdCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        children: [
          Text(
            LoyaltyText.showAtCheckout.of(context),
            style: context.gdText.overline.copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: AspectRatio(
              aspectRatio: 1,
              child: token != null
                  ? Semantics(
                      identifier: 'qr.code',
                      label: LoyaltyText.qrAlt.of(context),
                      image: true,
                      child: ColoredBox(
                        color: Colors.white,
                        child: QrImageView(
                          key: ValueKey(token.token),
                          data: token.token,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                          semanticsLabel: LoyaltyText.qrAlt.of(context),
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: _qrInk,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: _qrInk,
                          ),
                        ),
                      ),
                    )
                  : _QrPlaceholder(state: state, onRetry: onRefresh),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  end: token == null && !state.rateLimited ? 0 : state.fraction,
                ),
                duration: const Duration(milliseconds: 950),
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  color: c.gold,
                  backgroundColor: c.goldSoft,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            identifier: 'qr.refresh',
            button: true,
            label: LoyaltyText.refresh.of(context),
            child: InkWell(
              borderRadius: BorderRadius.circular(GdRadius.sm),
              onTap: state.active ? onRefresh : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    state.loading
                        ? SizedBox.square(
                            dimension: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.inkMuted,
                            ),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: c.inkMuted,
                          ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        state.secondsLeft > 0
                            ? LoyaltyText.refreshesIn.fmt(context, {
                                'n': state.secondsLeft,
                              })
                            : LoyaltyText.refresh.of(context),
                        style: context.gdText.bodySm.copyWith(
                          color: c.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({required this.state, required this.onRetry});
  final QrState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final Widget content;
    if (state.error != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 48, color: c.inkMuted),
          const SizedBox(height: 10),
          Text(
            errorMessage(context, state.error!),
            textAlign: TextAlign.center,
            style: context.gdText.bodySm,
          ),
          const SizedBox(height: 12),
          GdOutlineButton(
            label: LoyaltyText.refresh.of(context),
            onPressed: onRetry,
            semanticsId: 'qr.retry',
          ),
        ],
      );
    } else if (state.rateLimited && state.active) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_top_rounded, size: 40, color: c.inkMuted),
          const SizedBox(height: 10),
          Text(
            LoyaltyText.throttled.of(context),
            textAlign: TextAlign.center,
            style: context.gdText.bodySm,
          ),
        ],
      );
    } else if (!state.active) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off_outlined, size: 40, color: c.inkMuted),
          const SizedBox(height: 10),
          Text(
            LoyaltyText.hidden.of(context),
            textAlign: TextAlign.center,
            style: context.gdText.bodySm,
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: c.gold),
          ),
          const SizedBox(height: 12),
          Text(LoyaltyText.loading.of(context), style: context.gdText.bodySm),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.imageWell,
        borderRadius: BorderRadius.circular(GdRadius.md),
      ),
      child: Center(
        child: Padding(padding: const EdgeInsets.all(16), child: content),
      ),
    );
  }
}

/// The dark "CASHBACK BALANSI" card.
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gd;
    final lang = context.language;
    final summary = ref.watch(cashbackSummaryProvider);
    final s = summary.value;
    final next = s?.nextTier ?? const <String, dynamic>{};
    final progress = (asDoubleOrNull(next['progress']) ?? 0).clamp(0.0, 1.0);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.banner,
        borderRadius: BorderRadius.circular(GdRadius.lg),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -60,
            width: 240,
            height: 240,
            child: GdRings(
              color: c.bannerInk.withValues(alpha: 0.35),
              count: 4,
              strokeWidth: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        LoyaltyText.balanceTitle.of(context),
                        style: context.gdText.overline.copyWith(
                          color: c.bannerInk,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    if (s != null && s.percent != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: c.gold,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${s.percentLabel}%',
                          style: context.gdText.label.copyWith(color: c.onGold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (s == null)
                  SizedBox(
                    height: 40,
                    child: summary.hasError
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () =>
                                  ref.invalidate(cashbackSummaryProvider),
                              child: Text(
                                LoyaltyText.loadMoreFailed.of(context),
                                style: context.gdText.bodySm.copyWith(
                                  color: c.bannerInkSoft,
                                ),
                              ),
                            ),
                          )
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.bannerInk,
                              ),
                            ),
                          ),
                  )
                else ...[
                  Semantics(
                    identifier: 'qr.balance',
                    child: Text(
                      formatMoney(s.available, language: lang),
                      style: context.gdText.displayLg.copyWith(
                        color: c.bannerInkSoft,
                        fontSize: 36,
                        height: 1.15,
                      ),
                    ),
                  ),
                  if (s.held > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      LoyaltyText.held.fmt(context, {
                        'amount': formatMoney(s.held, language: lang),
                      }),
                      style: context.gdText.caption.copyWith(
                        color: c.bannerInkSoft.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  if (asBool(s.raw['negative'])) ...[
                    const SizedBox(height: 6),
                    Text(
                      LoyaltyText.negative.of(context),
                      style: context.gdText.caption.copyWith(
                        color: c.bannerInkSoft,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (next.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        color: c.gold,
                        backgroundColor: c.bannerInkSoft.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LoyaltyText.nextTier.fmt(context, {
                        'remaining': formatMoney(
                          asInt(next['remaining']),
                          language: lang,
                        ),
                        'percent': percentText(
                          next['percent'],
                          english: lang == AppLanguage.en,
                        ),
                      }),
                      style: context.gdText.caption.copyWith(
                        color: c.bannerInkSoft.withValues(alpha: 0.8),
                      ),
                    ),
                  ] else if (s.percent != null)
                    Text(
                      LoyaltyText.topTier.of(context),
                      style: context.gdText.caption.copyWith(
                        color: c.bannerInkSoft.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One ledger row, drawn as a segment of a single white card.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.item,
    required this.first,
    required this.last,
  });
  final LedgerItem item;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final lang = context.language;
    final (icon, bg, fg) = ledgerIcon(item, c);
    final radius = Radius.circular(GdRadius.lg);
    final date = item.at == null ? null : formatDayMonth(item.at!, lang);
    final sub = [
      ?date,
      if (item.subtitle != null && item.subtitle!.isNotEmpty) item.subtitle!,
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.vertical(
          top: first ? radius : Radius.zero,
          bottom: last ? radius : Radius.zero,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.line)),
        ),
        padding: EdgeInsets.only(top: first ? 16 : 13, bottom: last ? 16 : 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: context.gdText.label.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: context.gdText.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatSigned(item.amount, language: lang),
              style: context.gdText.label.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: item.amount > 0 ? c.success : c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Leading icon of a ledger row: storefront for store purchases, a bag for
/// online orders; green for money in, gold for money spent.
(IconData, Color, Color) ledgerIcon(LedgerItem item, GdColors c) {
  final icon = switch (item.kind) {
    'adjustment' => Icons.card_giftcard_rounded,
    'reversal' => Icons.undo_rounded,
    _ => item.isStore ? Icons.storefront_outlined : Icons.shopping_bag_outlined,
  };
  final spent = item.isDebit || item.amount < 0;
  return spent
      ? (icon, c.goldSoft, c.goldInk)
      : (icon, c.successSoft, c.success);
}

class _LedgerFooter extends ConsumerWidget {
  const _LedgerFooter({required this.state});
  final PagedState<LedgerItem> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loadingMore) return const GdLoading();
    if (state.moreError != null) {
      return Center(
        child: TextButton(
          onPressed: () => ref.read(ledgerProvider.notifier).loadMore(),
          child: Text(LoyaltyText.loadMoreFailed.of(context)),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _LedgerEmpty extends StatelessWidget {
  const _LedgerEmpty();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: GdSpace.page),
    child: GdCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.gd.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 20,
              color: context.gd.goldInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              LoyaltyText.historyEmpty.of(context),
              style: context.gdText.bodySm,
            ),
          ),
        ],
      ),
    ),
  );
}
