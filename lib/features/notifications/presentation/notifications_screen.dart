import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/dates.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../../core/widgets/rings.dart';
import '../../loyalty/application/paged.dart';
import '../application/inbox_controller.dart';
import '../application/inbox_logic.dart';
import '../application/inbox_models.dart';
import '../data/unread_count.dart';
import 'notifications_text.dart';

/// Opens an external https link; swappable in tests.
typedef UrlOpener = Future<bool> Function(Uri url);

final inboxUrlOpenerProvider = Provider<UrlOpener>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

/// The notifications inbox (PDF page 10).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _readingAll = false;

  Future<void> _readAll() async {
    if (_readingAll) return;
    setState(() => _readingAll = true);
    try {
      await ref.read(inboxProvider.notifier).markAllRead();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _readingAll = false);
    }
  }

  Future<void> _open(InboxItem item) async {
    final notifier = ref.read(inboxProvider.notifier);
    if (item.unread) {
      // Marked read right away; the POST finishes in the background.
      notifier.markRead(item.id).ignore();
    }
    final target = targetFor(item.link);
    if (target == null) return;
    if (target.route != null) {
      await context.push(target.route!);
    } else if (target.url != null) {
      try {
        await ref.read(inboxUrlOpenerProvider)(target.url!);
      } on Object {
        // no browser: nothing else to do
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final inbox = ref.watch(inboxProvider);
    final state = inbox.value;
    // Unread rows may sit on pages not loaded yet: the bell count covers them.
    final hasUnread =
        (state?.items.any((i) => i.unread) ?? false) ||
        ref.watch(unreadCountProvider) > 0;
    return Scaffold(
      appBar: GdHeader(
        title: NotificationsText.title.of(context),
        actions: [
          Semantics(
            identifier: 'notifications.readAll',
            button: true,
            child: TextButton(
              onPressed: hasUnread && !_readingAll ? _readAll : null,
              style: TextButton.styleFrom(
                foregroundColor: c.ink,
                disabledForegroundColor: c.inkMuted,
              ),
              child: Text(
                NotificationsText.readAll.of(context),
                style: context.gdText.label.copyWith(
                  color: hasUnread ? c.ink : c.inkMuted,
                  decoration: TextDecoration.underline,
                  decorationColor: c.gold,
                  decorationThickness: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
      body: switch (inbox) {
        _ when state != null => _Feed(state: state, onOpen: _open),
        AsyncValue(:final error?) => GdErrorView(
          error: error,
          onRetry: () => ref.invalidate(inboxProvider),
        ),
        _ => const GdLoading(),
      },
    );
  }
}

/// A flattened row of the grouped list.
sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.label);
  final String label;
}

class _ItemRow extends _Row {
  const _ItemRow(this.item);
  final InboxItem item;
}

class _Feed extends ConsumerWidget {
  const _Feed({required this.state, required this.onOpen});
  final PagedState<InboxItem> state;
  final void Function(InboxItem) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(inboxProvider.notifier);
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: box.maxHeight,
              child: GdEmptyView(
                icon: Icons.notifications_none_rounded,
                title: NotificationsText.empty.of(context),
                body: NotificationsText.emptyBody.of(context),
              ),
            ),
          ),
        ),
      );
    }
    final now = DateTime.now();
    final lang = context.language;
    final rows = <_Row>[
      for (final day in groupByDay(state.items)) ...[
        if (day.day.isNotEmpty) _HeaderRow(dayLabel(day.instant, now, lang)),
        for (final item in day.items) _ItemRow(item),
      ],
    ];
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) notifier.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(GdSpace.page, 4, GdSpace.page, 32),
          itemCount: rows.length + 1,
          itemBuilder: (context, i) {
            if (i == rows.length) {
              if (state.loadingMore) return const GdLoading();
              if (state.moreError != null) {
                return Center(
                  child: TextButton(
                    onPressed: notifier.loadMore,
                    child: Text(NotificationsText.loadMoreFailed.of(context)),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            return switch (rows[i]) {
              _HeaderRow(:final label) => Padding(
                padding: EdgeInsets.only(top: i == 0 ? 4 : 18, bottom: 10),
                child: Text(
                  label,
                  style: context.gdText.overline.copyWith(letterSpacing: 1.0),
                ),
              ),
              _ItemRow(:final item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InboxTile(item: item, onTap: () => onOpen(item)),
              ),
            };
          },
        ),
      ),
    );
  }
}

/// One inbox item: a white card while unread (gold dot), flat once read.
class InboxTile extends StatelessWidget {
  const InboxTile({super.key, required this.item, required this.onTap});
  final InboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final (icon, bg, fg) = inboxIcon(item.kind, c);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 21, color: fg),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: context.gdText.subheading.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (item.createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        formatTime(item.createdAt!),
                        style: context.gdText.caption,
                      ),
                    ),
                  if (item.unread)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 6),
                      child: Semantics(
                        label: NotificationsText.unread.of(context),
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: c.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (item.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.body, style: context.gdText.bodySm),
              ],
              if (item.kind == 'promo' && (item.imageUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                _PromoImage(url: item.imageUrl!),
              ],
            ],
          ),
        ),
      ],
    );
    return Semantics(
      identifier: 'notifications.item.${item.id}',
      button: true,
      child: item.unread
          ? GdCard(
              onTap: onTap,
              padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
              child: content,
            )
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(GdRadius.lg),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
                  child: content,
                ),
              ),
            ),
    );
  }
}

/// Leading icon by inbox kind.
(IconData, Color, Color) inboxIcon(String kind, GdColors c) => switch (kind) {
  'order_status' => (Icons.local_shipping_outlined, c.goldSoft, c.goldInk),
  'promo' => (Icons.local_offer_outlined, c.goldSoft, c.goldInk),
  'appointment' => (Icons.event_available_outlined, c.successSoft, c.success),
  _ => (Icons.info_outline_rounded, c.goldSoft, c.goldInk),
};

class _PromoImage extends StatelessWidget {
  const _PromoImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final placeholder = ColoredBox(
      color: c.banner,
      child: Align(
        alignment: const Alignment(0.75, 0),
        child: SizedBox.square(
          dimension: 110,
          child: GdRings(
            color: c.bannerInk.withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(GdRadius.md),
      child: AspectRatio(
        aspectRatio: 2.65,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, _) => placeholder,
          errorWidget: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}
