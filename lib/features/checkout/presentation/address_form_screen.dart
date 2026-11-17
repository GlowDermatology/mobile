import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/format/geo.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../profile/data/addresses_api.dart';
import '../../profile/presentation/address_map_picker.dart';
import '../../profile/presentation/address_text.dart';
import 'checkout_text.dart';

/// Client-side check of the full address (contract: 5..300 characters).
String? validateAddressText(String value) {
  final v = value.trim();
  return v.length < 5 || v.length > 300 ? 'length' : null;
}

/// A delivery address with its map pin: new (`POST me/addresses/`) or,
/// with [addressId], edited (`PATCH me/addresses/{id}/`). Pops the saved
/// [Address]. Opened from checkout ("add pin" pushes `?id=`) and from
/// «Manzillarim».
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.addressId});

  /// The saved address to edit; null creates a new one.
  final int? addressId;

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
  GeoPin? _pin;

  /// Edit mode: the form was filled from the saved address.
  bool _prefilled = false;
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

  bool get _editing => widget.addressId != null;

  void _prefill(Address a) {
    _prefilled = true;
    _label.text = a.label;
    _text.text = a.text;
    _comment.text = a.comment;
    _region = a.regionCode.isEmpty ? null : a.regionCode;
    _city = a.cityCode.isEmpty ? null : a.cityCode;
    _pin = a.pin;
  }

  /// The chosen region and city, when they are in the reference list.
  ({Region? region, bool cityKnown}) _choice(List<Region> regions) {
    final region = regions.where((r) => r.code == _region).firstOrNull;
    final cityKnown = region?.cities.any((c) => c.code == _city) ?? false;
    return (region: region, cityKnown: cityKnown);
  }

  String? _localError(String field, List<Region> regions) {
    if (!_submitted) return null;
    // Without BTS regions the pin alone makes the address deliverable.
    final choice = _choice(regions);
    return switch (field) {
      'region_code' when regions.isNotEmpty =>
        choice.region == null ? CheckoutText.required.of(context) : null,
      'city_code' when regions.isNotEmpty =>
        choice.cityKnown ? null : CheckoutText.required.of(context),
      'text' =>
        validateAddressText(_text.text) == null
            ? null
            : CheckoutText.textLength.of(context),
      _ => null,
    };
  }

  String? _error(String field, List<Region> regions) =>
      _errors[field] ?? _localError(field, regions);

  /// `latitude` / `longitude` errors (`latlng_pair`) under the map.
  String? get _pinError =>
      _errors.containsKey('latitude') || _errors.containsKey('longitude')
      ? AddressMapText.pinInvalid.of(context)
      : null;

  Future<void> _save(List<Region> regions) async {
    setState(() {
      _submitted = true;
      _errors = const {};
    });
    final choice = _choice(regions);
    if ((regions.isNotEmpty && (choice.region == null || !choice.cityKnown)) ||
        validateAddressText(_text.text) != null) {
      return;
    }
    final keys = ref.read(idempotencyProvider);
    final existing = ref.read(addressesProvider).value;
    final api = ref.read(addressesApiProvider);
    final id = widget.addressId;
    setState(() => _saving = true);
    try {
      final Address address;
      if (id != null) {
        address = await api.update(id, {
          'label': _label.text.trim(),
          'text': _text.text.trim(),
          'region_code': _region ?? '',
          'city_code': _city ?? '',
          'comment': _comment.text.trim(),
          ...pinFields(_pin),
        });
      } else {
        address = await api.create(
          label: _label.text.trim(),
          text: _text.text.trim(),
          regionCode: _region ?? '',
          cityCode: _city ?? '',
          comment: _comment.text.trim(),
          isDefault: existing != null && existing.isEmpty,
          pin: _pin,
          idempotencyKey: keys.keyFor(_intent),
        );
        keys.done(_intent);
      }
      ref.invalidate(addressesProvider);
      if (mounted) context.pop(address);
    } on ApiException catch (e) {
      if (id == null && !e.isNetwork) keys.done(_intent);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = e.fieldErrors;
      });
      final known = {
        'label',
        'text',
        'region_code',
        'city_code',
        'comment',
        'latitude',
        'longitude',
      };
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
    Widget? body;
    var ready = regions != null;
    if (_editing && !_prefilled) {
      ready = false;
      final addressesAsync = ref.watch(addressesProvider);
      final list = addressesAsync.value;
      final address = list?.where((a) => a.id == widget.addressId).firstOrNull;
      if (address != null) {
        _prefill(address);
        ready = regions != null;
      } else if (list != null) {
        body = GdEmptyView(
          icon: Icons.location_off_outlined,
          title: AddressFormText.notFound.of(context),
        );
      } else if (addressesAsync.hasError) {
        body = GdErrorView(
          error: addressesAsync.error!,
          onRetry: () => ref.invalidate(addressesProvider),
        );
      } else {
        body = const GdLoading();
      }
    }
    if (body == null) {
      if (regions == null) {
        body = regionsAsync.hasError
            ? GdErrorView(
                error: regionsAsync.error!,
                onRetry: () => ref.invalidate(regionsProvider),
              )
            : const GdLoading();
      } else {
        body = _form(context, regions);
      }
    }
    return Scaffold(
      appBar: GdHeader(
        title:
            (_editing
                    ? AddressFormText.editTitle
                    : CheckoutText.addressFormTitle)
                .of(context),
      ),
      body: body,
      bottomNavigationBar: !ready
          ? null
          : GdBottomBar(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: GdButton(
                  label: Strings.save.of(context),
                  loading: _saving,
                  semanticsId: 'address.save',
                  onPressed: () => _save(regions ?? const []),
                ),
              ),
            ),
    );
  }

  Widget _form(BuildContext context, List<Region> regions) {
    final choice = _choice(regions);
    final region = choice.region;
    final cities = region?.cities ?? const [];
    String? error(String field) => _error(field, regions);
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
              errorText: error('label'),
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
        if (regions.isNotEmpty) ...[
          gap,
          Semantics(
            identifier: 'address.region',
            button: true,
            child: DropdownButtonFormField<String>(
              key: const ValueKey('address.region'),
              initialValue: region?.code,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: CheckoutText.region.of(context),
                errorText: error('region_code'),
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
              initialValue: choice.cityKnown ? _city : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: CheckoutText.city.of(context),
                helperText: region == null
                    ? CheckoutText.chooseRegionFirst.of(context)
                    : null,
                errorText: error('city_code'),
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
        ],
        gap,
        AddressMapPicker(
          value: _pin,
          needsPin: regions.isEmpty,
          error: _pinError,
          onChanged: (pin) => setState(() {
            _pin = pin;
            _errors = {..._errors}
              ..remove('latitude')
              ..remove('longitude');
          }),
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
              errorText: error('text'),
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
              errorText: error('comment'),
            ),
          ),
        ),
      ],
    );
  }
}
