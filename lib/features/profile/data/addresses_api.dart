import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../auth/application/session_controller.dart';

/// A saved delivery address (contract §2.2.7). Region/city codes are BTS
/// reference codes from `GET delivery/regions/`.
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.text,
    required this.regionCode,
    required this.cityCode,
    required this.comment,
    required this.isDefault,
  });

  factory Address.fromJson(Json j) => Address(
    id: asInt(j['id']),
    label: asString(j['label']),
    text: asString(j['text']),
    regionCode: asString(j['region_code']),
    cityCode: asString(j['city_code']),
    comment: asString(j['comment']),
    isDefault: asBool(j['is_default']),
  );

  final int id;
  final String label;
  final String text;
  final String regionCode;
  final String cityCode;
  final String comment;
  final bool isDefault;

  bool get hasRegion => regionCode.isNotEmpty && cityCode.isNotEmpty;
}

/// A BTS region with its cities (`GET delivery/regions/`).
class Region {
  const Region({required this.code, required this.name, required this.cities});
  factory Region.fromJson(Json j) => Region(
    code: asString(j['code']),
    name: asString(j['name']),
    cities: [
      for (final c in asJsonList(j['cities']))
        (code: asString(c['code']), name: asString(c['name'])),
    ],
  );
  final String code;
  final String name;
  final List<({String code, String name})> cities;
}

class AddressesApi {
  AddressesApi(this._api);
  final ApiClient _api;

  Future<List<Address>> list() async =>
      asJsonList(asJson(await _api.get('me/addresses/'))['results'])
          .map(Address.fromJson)
          .toList();

  /// `POST me/addresses/` needs an Idempotency-Key (one per "Saqlash" tap).
  Future<Address> create({
    required String text,
    required String regionCode,
    required String cityCode,
    String label = '',
    String comment = '',
    bool isDefault = false,
    required String idempotencyKey,
  }) async => Address.fromJson(
    asJson(
      await _api.post(
        'me/addresses/',
        idempotencyKey: idempotencyKey,
        body: {
          'label': label,
          'text': text,
          'region_code': regionCode,
          'city_code': cityCode,
          'comment': comment,
          'latitude': null,
          'longitude': null,
          'is_default': isDefault,
        },
      ),
    ),
  );

  Future<Address> update(int id, Map<String, Object?> fields) async =>
      Address.fromJson(
        asJson(await _api.patch('me/addresses/$id/', body: fields)),
      );

  Future<void> delete(int id) => _api.delete('me/addresses/$id/');

  Future<Address> makeDefault(int id) async =>
      Address.fromJson(asJson(await _api.post('me/addresses/$id/default/')));

  Future<List<Region>> regions() async =>
      asJsonList(asJson(await _api.get('delivery/regions/'))['regions'])
          .map(Region.fromJson)
          .toList();
}

final addressesApiProvider = Provider<AddressesApi>(
  (ref) => AddressesApi(ref.watch(apiClientProvider)),
);

/// The customer's addresses, default first.
final addressesProvider = FutureProvider<List<Address>>((ref) async {
  if (!ref.watch(sessionProvider.select((s) => s.signedIn))) return const [];
  return ref.watch(addressesApiProvider).list();
});

final regionsProvider = FutureProvider<List<Region>>((ref) async {
  ref.watch(languageProvider);
  return ref.watch(addressesApiProvider).regions();
});
