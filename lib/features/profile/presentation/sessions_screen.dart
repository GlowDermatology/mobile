import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/dates.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../auth/application/session_controller.dart';
import '../application/profile_providers.dart';
import 'profile_text.dart';
import 'profile_widgets.dart';

/// «Faol seanslar» (contract §2.2.10).
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  final _busy = <String>{};
  bool _othersBusy = false;

  Future<void> _revoke(CustomerSession s) async {
    final ok = await confirmAction(
      context,
      title: ProfileText.oneTitle.of(context),
      body: s.current
          ? ProfileText.oneCurrentBody.of(context)
          : ProfileText.oneBody.fmt(context, {'device': s.device}),
      confirm: ProfileText.signOutConfirm.of(context),
      semanticsPrefix: 'sessions.revoke',
    );
    if (!ok || !mounted) return;
    if (s.current) {
      // Signing out of this phone is a normal logout (auth/logout/).
      final router = GoRouter.of(context);
      await ref.read(sessionProvider.notifier).signOut();
      router.go('/catalog');
      return;
    }
    setState(() => _busy.add(s.id));
    try {
      await ref.read(sessionsApiProvider).revoke(s.id);
      if (!mounted) return;
      showSnack(context, ProfileText.revoked.of(context));
      ref.invalidate(customerSessionsProvider);
    } on Object catch (e) {
      if (!mounted) return;
      showError(context, e);
      ref.invalidate(customerSessionsProvider);
    } finally {
      if (mounted) setState(() => _busy.remove(s.id));
    }
  }

  Future<void> _revokeOthers() async {
    final ok = await confirmAction(
      context,
      title: ProfileText.othersTitle.of(context),
      body: ProfileText.othersBody.of(context),
      confirm: ProfileText.signOutConfirm.of(context),
      semanticsPrefix: 'sessions.others',
    );
    if (!ok || !mounted) return;
    setState(() => _othersBusy = true);
    try {
      final n = await ref.read(sessionsApiProvider).revokeOthers();
      if (!mounted) return;
      showSnack(context, ProfileText.revokedOthers.fmt(context, {'n': n}));
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) {
        setState(() => _othersBusy = false);
        ref.invalidate(customerSessionsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(customerSessionsProvider);
    final hasOthers = sessions.value?.any((s) => !s.current) ?? false;
    return Scaffold(
      appBar: GdHeader(title: ProfileText.sessions.of(context)),
      body: sessions.when(
        skipLoadingOnRefresh: true,
        loading: () => const GdLoading(),
        error: (e, _) => GdErrorView(
          error: e,
          onRetry: () => ref.invalidate(customerSessionsProvider),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(customerSessionsProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              GdSpace.page,
              4,
              GdSpace.page,
              24,
            ),
            children: [
              Text(
                ProfileText.sessionsLead.of(context),
                style: context.gdText.bodySm,
              ),
              const SizedBox(height: 16),
              for (final s in list) ...[
                SessionTile(
                  session: s,
                  busy: _busy.contains(s.id),
                  onSignOut: () => _revoke(s),
                ),
                const SizedBox(height: 10),
              ],
              if (!list.any((s) => !s.current))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      ProfileText.noOthers.of(context),
                      style: context.gdText.bodySm,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: hasOthers
          ? GdBottomBar(
              child: _othersBusy
                  ? const SizedBox(
                      height: 52,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : GdOutlineButton(
                      label: ProfileText.signOutOthers.of(context),
                      icon: Icons.logout_rounded,
                      color: context.gd.danger,
                      onPressed: _revokeOthers,
                      semanticsId: 'sessions.revokeOthers',
                    ),
            )
          : null,
    );
  }
}

/// One session: device, location, «Joriy» badge, last activity, «Chiqish».
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.session,
    required this.onSignOut,
    this.busy = false,
  });
  final CustomerSession session;
  final VoidCallback onSignOut;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final s = session;
    final icon = switch (s.platform) {
      'web' => Icons.laptop_mac_outlined,
      'ios' || 'android' => Icons.smartphone_outlined,
      _ => Icons.devices_other_outlined,
    };
    final lang = context.language;
    final updated = s.updatedAt ?? s.createdAt;
    return GdCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: c.goldInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      s.device,
                      style: context.gdText.label.copyWith(fontSize: 15),
                    ),
                    if (s.current)
                      GdStatusChip(
                        label: ProfileText.sessionCurrent.of(context),
                        tone: GdTone.success,
                        uppercase: false,
                      ),
                  ],
                ),
                if (s.hasLocation) ...[
                  const SizedBox(height: 4),
                  Text(s.location, style: context.gdText.bodySm),
                ],
                if (updated != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    ProfileText.sessionUpdated.fmt(context, {
                      'date': formatDateTime(updated, lang),
                    }),
                    style: context.gdText.caption,
                  ),
                ],
              ],
            ),
          ),
          Semantics(
            identifier: 'sessions.signout.${s.current ? 'current' : s.id}',
            button: true,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: onSignOut,
                    style: TextButton.styleFrom(foregroundColor: c.danger),
                    child: Text(ProfileText.signOut.of(context)),
                  ),
          ),
        ],
      ),
    );
  }
}
