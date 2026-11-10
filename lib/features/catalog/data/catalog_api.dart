import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/network/page.dart';
import 'catalog_models.dart';

/// Public catalog endpoints (contract §2.3).
class CatalogApi {
  CatalogApi(this._api);
  final ApiClient _api;

  Future<List<CatalogBanner>> banners() async =>
      asJsonList(asJson(await _api.get('catalog/banners/'))['results'])
          .map(CatalogBanner.fromJson)
          .toList();

  Future<List<CatalogCategory>> categories() async =>
      asJsonList(asJson(await _api.get('catalog/categories/'))['results'])
          .map(CatalogCategory.fromJson)
          .toList();

  Future<Page<ProductCard>> products(
    ProductQuery query, {
    int page = 1,
  }) async => Page.fromJson(
    asJson(await _api.get('catalog/products/', query: query.toQuery(page))),
    ProductCard.fromJson,
  );

  Future<ProductDetail> product(int id) async =>
      ProductDetail.fromJson(asJson(await _api.get('catalog/products/$id/')));
}

final catalogApiProvider = Provider<CatalogApi>(
  (ref) => CatalogApi(ref.watch(apiClientProvider)),
);
