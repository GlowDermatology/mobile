import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/phone.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/presentation/language_sheet.dart';
import '../../settings/data/public_settings.dart';
import '../application/profile_logic.dart';
import '../application/profile_providers.dart';
import 'profile_text.dart';
import 'profile_widgets.dart';

/// The «Sozlamalar» tab (design p.11).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(sessionProvider);
    final signedIn = auth.signedIn;
    final settings = ref.watch(publicSettingsProvider).value;
    final version = ref.watch(appVersionProvider);

    Future<void> open(String location, {VoidCallback? after}) async {
      await context.push(location);
      if (context.mounted) after?.call();
    }

    final ordersCount = signedIn ? ref.watch(ordersCountProvider).value : null;
    final appointmentsCount = signedIn
        ? ref.watch(upcomingAppointmentsCountProvider).value
        : null;
    String? pieces(int? n) =>
        n == null ? null : Strings.pieces.fmt(context, {'n': n});

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(publicSettingsProvider);
            if (signedIn) {
              ref.invalidate(ordersCountProvider);
              ref.invalidate(upcomingAppointmentsCountProvider);
              await ref.read(sessionProvider.notifier).refreshMe();
            }
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              GdSpace.page,
              20,
              GdSpace.page,
              28,
            ),
            children: [
              Semantics(
                header: true,
                child: Text(
                  ProfileText.title.of(context),
                  style: context.gdText.displayLg,
                ),
              ),
              const SizedBox(height: 18),
              if (signedIn) _ProfileCard(me: auth.me) else const _GuestCard(),
              const SizedBox(height: 16),
              SettingsGroup(
                children: [
                  if (signedIn) ...[
                    SettingsRow(
                      icon: Icons.receipt_long_outlined,
                      label: ProfileText.orders.of(context),
                      value: pieces(ordersCount),
                      onTap: () => open(
                        '/orders',
                        after: () => ref.invalidate(ordersCountProvider),
                      ),
                      semanticsId: 'settings.orders',
                    ),
                    SettingsRow(
                      icon: Icons.calendar_today_outlined,
                      label: ProfileText.appointments.of(context),
                      value: pieces(appointmentsCount),
                      onTap: () => open(
                        '/appointments',
                        after: () =>
                            ref.invalidate(upcomingAppointmentsCountProvider),
                      ),
                      semanticsId: 'settings.appointments',
                    ),
                  ],
                  SettingsRow(
                    icon: Icons.medical_services_outlined,
                    label: ProfileText.specialists.of(context),
                    onTap: () => open('/specialists'),
                    semanticsId: 'settings.specialists',
                  ),
                  if (signedIn)
                    SettingsRow(
                      icon: Icons.location_on_outlined,
                      label: ProfileText.addresses.of(context),
                      onTap: () => open('/settings/addresses'),
                      semanticsId: 'settings.addresses',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.language_rounded,
                    label: ProfileText.language.of(context),
                    value: ref.watch(languageProvider).label,
                    onTap: () => showLanguageSheet(context, ref),
                    semanticsId: 'settings.language',
                  ),
                  SettingsRow(
                    icon: Icons.dark_mode_outlined,
                    label: ProfileText.theme.of(context),
                    trailing: const ThemeSegment(),
                    chevron: false,
                    semanticsId: 'settings.theme',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SettingsGroup(
                children: [
                  for (final (doc, icon, label) in [
                    (
                      LegalDoc.privacy,
                      Icons.shield_outlined,
                      ProfileText.privacy,
                    ),
                    (
                      LegalDoc.terms,
                      Icons.description_outlined,
                      ProfileText.terms,
                    ),
                    (
                      LegalDoc.booking,
                      Icons.event_note_outlined,
                      ProfileText.booking,
                    ),
                  ])
                    SettingsRow(
                      icon: icon,
                      label: label.of(context),
                      onTap: () => open(doc.route),
                      semanticsId: 'settings.legal.${doc.name}',
                    ),
                ],
              ),
              if (signedIn) ...[
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.devices_outlined,
                      label: ProfileText.sessions.of(context),
                      onTap: () => open('/settings/sessions'),
                      semanticsId: 'settings.sessions',
                    ),
                    SettingsRow(
                      icon: Icons.lock_outline_rounded,
                      label: ProfileText.changePassword.of(context),
                      onTap: () => open('/settings/password'),
                      semanticsId: 'settings.password',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.delete_outline_rounded,
                      label: ProfileText.deleteAccount.of(context),
                      danger: true,
                      chevron: false,
                      onTap: () => open('/settings/delete'),
                      semanticsId: 'settings.delete',
                    ),
                    SettingsRow(
                      icon: Icons.logout_rounded,
                      label: ProfileText.signOut.of(context),
                      chevron: false,
                      onTap: () => _signOut(context, ref),
                      semanticsId: 'settings.signout',
                    ),
                  ],
                ),
              ],
              if (settings != null) ...[
                const SizedBox(height: 16),
                ContactTiles(settings: settings),
              ],
              const SizedBox(height: 22),
              Center(
                child: Text(
                  'Glow Derma · $version',
                  style: context.gdText.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: ProfileText.signOutTitle.of(context),
      body: ProfileText.signOutBody.of(context),
      confirm: ProfileText.signOutConfirm.of(context),
      semanticsPrefix: 'settings.signout',
    );
    if (!ok) return;
    await ref.read(sessionProvider.notifier).signOut();
    if (context.mounted) context.go('/catalog');
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.me});
  final Me? me;

  @override
  Widget build(BuildContext context) {
    final me = this.me;
    final contact = me == null
        ? ''
        : (me.phone != null ? formatPhone(me.phone) : (me.email ?? ''));
    return GdCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Row(
        children: [
          GdAvatar(
            initials: me?.initials ?? '',
            size: 58,
            imageUrl: me?.imageUrl,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me?.name ?? '',
                  style: context.gdText.heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    contact,
                    style: context.gdText.bodySm.copyWith(fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          Semantics(
            identifier: 'settings.editName',
            button: true,
            child: IconButton(
              tooltip: ProfileText.editName.of(context),
              onPressed: me == null
                  ? null
                  : () => showEditNameSheet(context, me.name),
              icon: Icon(Icons.edit_outlined, color: context.gd.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) => GdCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.gd.goldSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: context.gd.goldInk,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ProfileText.guestTitle.of(context),
                    style: context.gdText.heading,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ProfileText.guestBody.of(context),
                    style: context.gdText.bodySm,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GdButton(
          label: ProfileText.guestAction.of(context),
          semanticsId: 'settings.signin',
          onPressed: () => goSignIn(context, next: '/settings'),
        ),
      ],
    ),
  );
}

/// «Yorug‘ / Qorong‘i» inline segmented control.
class ThemeSegment extends ConsumerWidget {
  const ThemeSegment({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gd;
    final mode = ref.watch(themeModeProvider);
    final dark = switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => Theme.of(context).brightness == Brightness.dark,
    };
    Widget option(String label, bool selected, ThemeMode target, String id) =>
        Semantics(
          identifier: id,
          button: true,
          selected: selected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!selected) ref.read(themeModeProvider.notifier).set(target);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? c.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(GdRadius.md - 2),
              ),
              child: Text(
                label,
                style: context.gdText.label.copyWith(
                  fontSize: 13,
                  color: selected ? c.onGold : c.inkMuted,
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GdRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(
            ProfileText.themeLight.of(context),
            !dark,
            ThemeMode.light,
            'settings.theme.light',
          ),
          option(
            ProfileText.themeDark.of(context),
            dark,
            ThemeMode.dark,
            'settings.theme.dark',
          ),
        ],
      ),
    );
  }
}

/// Telegram · Instagram · Veb-sayt · Telefon square tiles.
class ContactTiles extends StatelessWidget {
  const ContactTiles({super.key, required this.settings});
  final PublicSettings settings;

  @override
  Widget build(BuildContext context) {
    final links = contactLinks(settings);
    if (links.isEmpty) return const SizedBox.shrink();
    final tiles = <Widget>[];
    for (final link in links) {
      if (tiles.isNotEmpty) tiles.add(const SizedBox(width: 10));
      tiles.add(Expanded(child: _ContactTile(link: link)));
    }
    return Row(children: tiles);
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.link});
  final ContactLink link;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (link.kind) {
      ContactKind.telegram => (Icons.send_outlined, ProfileText.telegram),
      ContactKind.instagram => (
        Icons.camera_alt_outlined,
        ProfileText.instagram,
      ),
      ContactKind.website => (Icons.language_rounded, ProfileText.website),
      ContactKind.phone => (Icons.phone_outlined, ProfileText.phone),
    };
    return Semantics(
      identifier: 'settings.contact.${link.kind.name}',
      button: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: GdCard(
          padding: const EdgeInsets.all(6),
          onTap: () async {
            var ok = false;
            try {
              ok = await launchUrl(
                link.uri,
                mode: LaunchMode.externalApplication,
              );
            } on Object {
              ok = false;
            }
            if (!ok && context.mounted) {
              showSnack(context, ProfileText.linkFailed.of(context));
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: context.gd.goldInk),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label.of(context),
                  style: context.gdText.label.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet editing the profile name (`PATCH me/`).
Future<void> showEditNameSheet(BuildContext context, String current) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditNameSheet(initial: current),
    );

class _EditNameSheet extends ConsumerStatefulWidget {
  const _EditNameSheet({required this.initial});
  final String initial;

  @override
  ConsumerState<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<_EditNameSheet> {
  late final _name = TextEditingController(text: widget.initial);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final value = _name.text.trim();
    if (!isValidName(value)) {
      setState(() => _error = ProfileText.nameInvalid.of(context));
      return;
    }
    if (value == widget.initial.trim()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final me = await ref.read(authApiProvider).updateMe(name: value);
      ref.read(sessionProvider.notifier).updateMe(me);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final saved = ProfileText.nameSaved.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(saved)));
    } on Object catch (e) {
      if (!mounted) return;
      final (fields, general) = splitFieldErrors(e, {'name'});
      setState(() => _error = fields['name']);
      if (general != null) showError(context, general);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ProfileText.editName.of(context), style: context.gdText.heading),
          const SizedBox(height: 16),
          Semantics(
            identifier: 'settings.name',
            textField: true,
            child: TextField(
              controller: _name,
              autofocus: true,
              maxLength: 150,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: ProfileText.nameLabel.of(context),
                errorText: _error,
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 16),
          GdButton(
            label: Strings.save.of(context),
            loading: _busy,
            onPressed: _save,
            semanticsId: 'settings.name.save',
          ),
        ],
      ),
    ),
  );
}
