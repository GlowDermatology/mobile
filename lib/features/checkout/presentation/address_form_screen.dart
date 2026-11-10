import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../profile/data/addresses_api.dart';
import 'checkout_text.dart';

/// Client-side check of the full address (contract: 5..300 characters).
String? validateAddressText(String value) {
  final v = value.trim();
  return v.length < 5 || v.length > 300 ? 'length' : null;
}

/// New delivery address from checkout (`POST me/addresses/`); pops the
/// created [Address].
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key});

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  static const _intent = 'address.create';

  final _label = TextEditingController();
  final _text = TextEditingController();
  final _comment = TextEditingController();
  String? _region;
  String? _city;
  bool _saving = false;
  bool _submitted = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _label.dispose();
    _text.dispose();
    _comment.dispose();
    super.dispose();
  }

  String? _localError(String field) {
    if (!_submitted) return null;
    return switch (field) {
      'region_code' =>
        _region == null ? CheckoutText.required.of(context) : null,
      'city_code' => _city == null ? CheckoutText.required.of(context) : null,
      'text' =>
        validateAddressText(_text.text) == null
            ? null
            : CheckoutText.textLength.of(context),
      _ => null,
    };
  }

  String? _error(String field) => _errors[field] ?? _localError(field);

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _errors = const {};
    });
    if (_region == null ||
        _city == null ||
        validateAddressText(_text.text) != null) {
      return;
    }
    final keys = ref.read(idempotencyProvider);
    final existing = ref.read(addressesProvider).value;
    setState(() => _saving = true);
    try {
      final address = await ref
          .read(addressesApiProvider)
          .create(
            label: _label.text.trim(),
            text: _text.text.trim(),
            regionCode: _region!,
            cityCode: _city!,
            comment: _comment.text.trim(),
            isDefault: existing != null && existing.isEmpty,
            idempotencyKey: keys.keyFor(_intent),
          );
      keys.done(_intent);
      ref.invalidate(addressesProvider);
      if (mounted) context.pop(address);
    } on ApiException catch (e) {
      if (!e.isNetwork) keys.done(_intent);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = e.fieldErrors;
      });
      final known = {'label', 'text', 'region_code', 'city_code', 'comment'};
      if (!e.fieldErrors.keys.any(known.contains)) showError(context, e);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showError(context, e);
    }
  }

  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() => _errors = {..._errors}..remove(field));
    }
  }

  @override
  Widget build(BuildContext context) {
    final regionsAsync = ref.watch(regionsProvider);
    final regions = regionsAsync.value;
    final Widget body;
    if (regions == null) {
      body = regionsAsync.hasError
          ? GdErrorView(
              error: regionsAsync.error!,
              onRetry: () => ref.invalidate(regionsProvider),
            )
          : const GdLoading();
    } else if (regions.isEmpty) {
      body = GdEmptyView(
        icon: Icons.local_shipping_outlined,
        title: CheckoutText.noRegions.of(context),
      );
    } else {
      body = _form(context, regions);
    }
    return Scaffold(
      appBar: GdHeader(title: CheckoutText.addressFormTitle.of(context)),
      body: body,
      bottomNavigationBar: regions == null || regions.isEmpty
          ? null
          : GdBottomBar(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: GdButton(
                  label: Strings.save.of(context),
                  loading: _saving,
                  semanticsId: 'address.save',
                  onPressed: _save,
                ),
              ),
            ),
    );
  }

  Widget _form(BuildContext context, List<Region> regions) {
    final c = context.gd;
    final region = regions.where((r) => r.code == _region).firstOrNull;
    final cities = region?.cities ?? const [];
    const gap = SizedBox(height: 16);
    return ListView(
      padding: const EdgeInsets.fromLTRB(GdSpace.page, 8, GdSpace.page, 24),
      children: [
        Semantics(
          identifier: 'address.label',
          textField: true,
          child: TextField(
            controller: _label,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              _clearError('label');
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: CheckoutText.labelField.of(context),
              errorText: _error('label'),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final l in [
              CheckoutText.labelHome.of(context),
              CheckoutText.labelWork.of(context),
            ])
              Semantics(
                identifier: 'address.label.$l',
                button: true,
                child: GdFilterChip(
                  label: l,
                  selected: _label.text.trim() == l,
                  onTap: () => setState(() => _label.text = l),
                ),
              ),
          ],
        ),
        gap,
        Semantics(
          identifier: 'address.region',
          button: true,
          child: DropdownButtonFormField<String>(
            key: const ValueKey('address.region'),
            initialValue: _region,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: CheckoutText.region.of(context),
              errorText: _error('region_code'),
            ),
            items: [
              for (final r in regions)
                DropdownMenuItem(
                  value: r.code,
                  child: Text(r.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() {
              if (v != _region) _city = null;
              _region = v;
              _errors = {..._errors}
                ..remove('region_code')
                ..remove('city_code');
            }),
          ),
        ),
        gap,
        Semantics(
          identifier: 'address.city',
          button: true,
          child: DropdownButtonFormField<String>(
            // A new region rebuilds the field so the city starts empty.
            key: ValueKey('address.city.$_region'),
            initialValue: _city,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: CheckoutText.city.of(context),
              helperText: region == null
                  ? CheckoutText.chooseRegionFirst.of(context)
                  : null,
              errorText: _error('city_code'),
            ),
            items: [
              for (final city in cities)
                DropdownMenuItem(
                  value: city.code,
                  child: Text(city.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: region == null
                ? null
                : (v) => setState(() {
                    _city = v;
                    _errors = {..._errors}..remove('city_code');
                  }),
          ),
        ),
        gap,
        Semantics(
          identifier: 'address.text',
          textField: true,
          child: TextField(
            controller: _text,
            maxLength: 300,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              _clearError('text');
              if (_submitted) setState(() {});
            },
            decoration: InputDecoration(
              labelText: CheckoutText.addressText.of(context),
              hintText: CheckoutText.addressTextHint.of(context),
              errorText: _error('text'),
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          identifier: 'address.comment',
          textField: true,
          child: TextField(
            controller: _comment,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _clearError('comment'),
            decoration: InputDecoration(
              labelText: CheckoutText.comment.of(context),
              hintText: CheckoutText.commentHint.of(context),
              errorText: _error('comment'),
            ),
          ),
        ),
        Row(
          children: [
            Icon(Icons.local_shipping_outlined, size: 16, color: c.inkMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                CheckoutText.deliveryHint.of(context),
                style: context.gdText.caption,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
