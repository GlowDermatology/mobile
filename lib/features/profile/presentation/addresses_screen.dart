import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../auth/application/session_controller.dart';
import '../data/addresses_api.dart';
import 'profile_text.dart';
import 'profile_widgets.dart';

enum _AddressAction { makeDefault, delete }

/// «Manzillarim»: saved delivery addresses (contract §2.2.7).
class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  final _busy = <int>{};

  /// Reloads the list and `Me.default_address` (every write changes it).
  void _changed() {
    ref.invalidate(addressesProvider);
    ref.read(sessionProvider.notifier).refreshMe();
  }

  Future<void> _add() async {
    final created = await context.push<Object?>('/checkout/address');
    if (!mounted) return;
    _changed();
    if (created is Address) {
      showSnack(context, ProfileText.addressSaved.of(context));
    }
  }

  Future<void> _act(Address a, _AddressAction action) async {
    if (action == _AddressAction.delete) {
      final ok = await confirmAction(
        context,
        title: ProfileText.deleteAddressTitle.of(context),
        body: a.text,
        confirm: ProfileText.deleteConfirm.of(context),
        semanticsPrefix: 'addresses.delete',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy.add(a.id));
    final api = ref.read(addressesApiProvider);
    try {
      switch (action) {
        case _AddressAction.makeDefault:
          await api.makeDefault(a.id);
        case _AddressAction.delete:
          await api.delete(a.id);
          if (mounted) {
            showSnack(context, ProfileText.addressDeleted.of(context));
          }
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) {
        setState(() => _busy.remove(a.id));
        _changed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    return Scaffold(
      appBar: GdHeader(title: ProfileText.addressesTitle.of(context)),
      body: addresses.when(
        skipLoadingOnRefresh: true,
        loading: () => const GdLoading(),
        error: (e, _) => GdErrorView(
          error: e,
          onRetry: () => ref.invalidate(addressesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return GdEmptyView(
              icon: Icons.location_on_outlined,
              title: ProfileText.addressesEmpty.of(context),
              body: ProfileText.addressesEmptyBody.of(context),
            );
          }
          final sorted = [
            ...list.where((a) => a.isDefault),
            ...list.where((a) => !a.isDefault),
          ];
          return RefreshIndicator(
            onRefresh: () => ref.refresh(addressesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                GdSpace.page,
                4,
                GdSpace.page,
                24,
              ),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => AddressTile(
                address: sorted[i],
                busy: _busy.contains(sorted[i].id),
                onMakeDefault: () =>
                    _act(sorted[i], _AddressAction.makeDefault),
                onDelete: () => _act(sorted[i], _AddressAction.delete),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: GdBottomBar(
        child: GdButton(
          label: ProfileText.newAddress.of(context),
          icon: Icons.add_rounded,
          onPressed: _add,
          semanticsId: 'addresses.add',
        ),
      ),
    );
  }
}

/// Label, text, «Asosiy» badge and a menu (make default · delete).
class AddressTile extends StatelessWidget {
  const AddressTile({
    super.key,
    required this.address,
    required this.onMakeDefault,
    required this.onDelete,
    this.busy = false,
  });
  final Address address;
  final VoidCallback onMakeDefault;
  final VoidCallback onDelete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final a = address;
    final title = a.label.trim().isNotEmpty ? a.label.trim() : a.text;
    return GdCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
      border: a.isDefault ? Border.all(color: c.gold, width: 1.2) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              a.isDefault ? Icons.home_outlined : Icons.location_on_outlined,
              color: a.isDefault ? c.goldInk : c.inkMuted,
              size: 22,
            ),
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
                      title,
                      style: context.gdText.label.copyWith(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (a.isDefault)
                      GdStatusChip(
                        label: ProfileText.addressDefault.of(context),
                        tone: GdTone.gold,
                        uppercase: false,
                        dot: false,
                      ),
                  ],
                ),
                if (title != a.text) ...[
                  const SizedBox(height: 4),
                  Text(a.text, style: context.gdText.bodySm),
                ],
                if (a.comment.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(a.comment, style: context.gdText.caption),
                ],
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Semantics(
              identifier: 'addresses.menu.${a.id}',
              button: true,
              child: PopupMenuButton<_AddressAction>(
                tooltip: ProfileText.addressActions.of(context),
                icon: Icon(Icons.more_vert_rounded, color: c.inkMuted),
                color: c.surfaceRaised,
                onSelected: (v) => v == _AddressAction.makeDefault
                    ? onMakeDefault()
                    : onDelete(),
                itemBuilder: (context) => [
                  if (!a.isDefault)
                    PopupMenuItem(
                      value: _AddressAction.makeDefault,
                      child: Semantics(
                        identifier: 'addresses.makeDefault',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 20,
                              color: c.ink,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                ProfileText.makeDefault.of(context),
                                style: context.gdText.bodyMd,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  PopupMenuItem(
                    value: _AddressAction.delete,
                    child: Semantics(
                      identifier: 'addresses.delete',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: c.danger,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              ProfileText.delete.of(context),
                              style: context.gdText.bodyMd.copyWith(
                                color: c.danger,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
