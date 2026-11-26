import 'package:flutter/foundation.dart';

import '../../../core/network/json.dart';

/// `{"slug", "name"}` inside a product.
@immutable
class CategoryRef {
  const CategoryRef({required this.slug, required this.name});

  factory CategoryRef.fromJson(Json j) =>
      CategoryRef(slug: asString(j['slug']), name: asString(j['name']));

  final String slug;
  final String name;
}

/// An entry of `GET catalog/categories/`.
@immutable
class CatalogCategory {
  const CatalogCategory({
    required this.slug,
    required this.name,
    required this.imageUrl,
    required this.productCount,
    this.imageThumbnailUrl,
  });

  factory CatalogCategory.fromJson(Json j) => CatalogCategory(
    slug: asString(j['slug']),
    name: asString(j['name']),
    imageUrl: asStringOrNull(j['image_url']),
    imageThumbnailUrl: asStringOrNull(j['image_thumbnail_url']),
    productCount: asInt(j['product_count']),
  );

  final String slug;
  final String name;
  final String? imageUrl;
  final int productCount;

  /// 400 px variant (null → the original).
  final String? imageThumbnailUrl;
  String? get thumbUrl => imageThumbnailUrl ?? imageUrl;
}

/// One screen-shaped copy of a product image: full size (long side ≤ 2000 px)
/// and its 1000 px / 400 px WebP variants.
@immutable
class ImageRendition {
  const ImageRendition({
    required this.url,
    required this.mediumUrl,
    required this.thumbnailUrl,
  });

  /// Null unless all three URLs are non-empty strings.
  static ImageRendition? fromJson(Object? v) {
    if (v is! Map) return null;
    String? url(Object? s) => s is String && s.isNotEmpty ? s : null;
    final full = url(v['url']);
    final medium = url(v['medium_url']);
    final thumb = url(v['thumbnail_url']);
    if (full == null || medium == null || thumb == null) return null;
    return ImageRendition(url: full, mediumUrl: medium, thumbnailUrl: thumb);
  }

  final String url;
  final String mediumUrl;
  final String thumbnailUrl;
}

/// `renditions` of a product image: a 4:5 [portrait] and a 1:1 [square],
/// each null until staff make it (then the image itself is shown). A missing
/// or malformed object reads as [none].
@immutable
class ImageRenditions {
  const ImageRenditions({this.portrait, this.square});

  factory ImageRenditions.fromJson(Object? v) {
    if (v is! Map) return none;
    final portrait = ImageRendition.fromJson(v['portrait']);
    final square = ImageRendition.fromJson(v['square']);
    return portrait == null && square == null
        ? none
        : ImageRenditions(portrait: portrait, square: square);
  }

  static const none = ImageRenditions();

  final ImageRendition? portrait;
  final ImageRendition? square;
}

enum StockStatus { inStock, outOfStock }

StockStatus _stock(Object? v, int available) => switch (v) {
  'in_stock' => StockStatus.inStock,
  'out_of_stock' => StockStatus.outOfStock,
  _ => available > 0 ? StockStatus.inStock : StockStatus.outOfStock,
};

/// `ProductCard` (contract §2.3), the list item.
@immutable
class ProductCard {
  const ProductCard({
    required this.id,
    required this.slug,
    required this.name,
    required this.volume,
    required this.price,
    required this.promo,
    required this.category,
    required this.mainImageUrl,
    required this.available,
    required this.stockStatus,
    required this.inCartQuantity,
    this.mainImageThumbnailUrl,
    this.mainImageMediumUrl,
    this.mainImageRenditions = ImageRenditions.none,
  });

  factory ProductCard.fromJson(Json j) {
    final available = asInt(j['available']);
    final category = j['category'];
    return ProductCard(
      id: asInt(j['id']),
      slug: asString(j['slug']),
      name: asString(j['name']),
      volume: asString(j['volume']),
      price: asInt(j['price']),
      promo: asBool(j['promo']),
      category: category is Map ? CategoryRef.fromJson(asJson(category)) : null,
      mainImageUrl: asStringOrNull(j['main_image_url']),
      mainImageThumbnailUrl: asStringOrNull(j['main_image_thumbnail_url']),
      mainImageMediumUrl: asStringOrNull(j['main_image_medium_url']),
      mainImageRenditions: ImageRenditions.fromJson(j['main_image_renditions']),
      available: available,
      stockStatus: _stock(j['stock_status'], available),
      inCartQuantity: asInt(j['in_cart_quantity']),
    );
  }

  final int id;
  final String slug;
  final String name;
  final String volume;
  final int price;
  final bool promo;
  final CategoryRef? category;
  final String? mainImageUrl;

  /// 400 px / 1000 px variants (null → the original).
  final String? mainImageThumbnailUrl;
  final String? mainImageMediumUrl;
  String? get thumbUrl => mainImageThumbnailUrl ?? mainImageUrl;
  String? get mediumUrl => mainImageMediumUrl ?? mainImageUrl;

  /// Portrait / square copies of the main image.
  final ImageRenditions mainImageRenditions;

  /// The (≈ square) card tile: the square copy's 1000 px variant, else
  /// [mediumUrl].
  String? get tileUrl => mainImageRenditions.square?.mediumUrl ?? mediumUrl;
  final int available;
  final StockStatus stockStatus;
  final int inCartQuantity;

  bool get inStock => stockStatus == StockStatus.inStock;

  /// "30 ml · Serumlar" (either part may be missing).
  String get subtitle => [
    volume,
    category?.name ?? '',
  ].where((s) => s.trim().isNotEmpty).join(' · ');

  /// Seed for the illustrated fallback: the category slug says the most.
  String get artSeed => '${category?.slug ?? ''} $name';
}

@immutable
class ProductImage {
  const ProductImage({
    required this.id,
    required this.url,
    required this.position,
    this.thumbnailUrl,
    this.mediumUrl,
    this.renditions = ImageRenditions.none,
  });

  factory ProductImage.fromJson(Json j) => ProductImage(
    id: asInt(j['id']),
    url: asString(j['url']),
    position: asInt(j['position']),
    thumbnailUrl: asStringOrNull(j['thumbnail_url']),
    mediumUrl: asStringOrNull(j['medium_url']),
    renditions: ImageRenditions.fromJson(j['renditions']),
  );

  final int id;
  final String url;
  final int position;
  final String? thumbnailUrl;
  final String? mediumUrl;
  final ImageRenditions renditions;
}

/// One gallery page: the 1000 px variant to show and the original to fall
/// back to. [cover] pages are the 4:5 portrait copy, shown filling the hero;
/// the others are the image itself, shown whole.
typedef GalleryImage = ({String url, String original, bool cover});

/// `ProductDetail` = card + texts, gallery and `max_quantity`.
@immutable
class ProductDetail {
  const ProductDetail({
    required this.card,
    required this.description,
    required this.ingredients,
    required this.usage,
    required this.images,
    required this.maxQuantity,
  });

  factory ProductDetail.fromJson(Json j) {
    final images =
        asJsonList(j['images'])
            .map(ProductImage.fromJson)
            .where((i) => i.url.isNotEmpty)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    return ProductDetail(
      card: ProductCard.fromJson(j),
      description: asString(j['description']).trim(),
      ingredients: asString(j['ingredients']).trim(),
      usage: asString(j['usage']).trim(),
      images: images,
      maxQuantity: asInt(j['max_quantity']),
    );
  }

  final ProductCard card;
  final String description;
  final String ingredients;
  final String usage;
  final List<ProductImage> images;

  /// min(available, per-line limit); 0 = cannot be added.
  final int maxQuantity;

  int get id => card.id;

  /// The gallery URLs, falling back to the main image.
  List<String> get galleryUrls {
    if (images.isNotEmpty) return [for (final i in images) i.url];
    final main = card.mainImageUrl;
    return main == null || main.isEmpty ? const [] : [main];
  }

  /// The gallery as 1000 px pages with their originals as fallbacks: the
  /// portrait copy when there is one, else the image itself.
  List<GalleryImage> get gallery {
    GalleryImage page(String original, String medium, ImageRenditions r) {
      final portrait = r.portrait;
      return portrait != null
          ? (url: portrait.mediumUrl, original: original, cover: true)
          : (url: medium, original: original, cover: false);
    }

    if (images.isNotEmpty) {
      return [
        for (final i in images)
          page(
            i.url,
            (i.mediumUrl?.isNotEmpty ?? false) ? i.mediumUrl! : i.url,
            i.renditions,
          ),
      ];
    }
    final main = card.mainImageUrl;
    if (main == null || main.isEmpty) return const [];
    return [page(main, card.mediumUrl ?? main, card.mainImageRenditions)];
  }

  bool get canAdd => maxQuantity > 0 && card.inStock;
}

enum BannerLinkKind { none, product, category, url }

@immutable
class BannerLink {
  const BannerLink({
    required this.kind,
    this.productId,
    this.categorySlug,
    this.url,
  });

  factory BannerLink.fromJson(Json j) {
    final kind = switch (j['kind']) {
      'product' => BannerLinkKind.product,
      'category' => BannerLinkKind.category,
      'url' => BannerLinkKind.url,
      _ => BannerLinkKind.none,
    };
    final category = j['category'];
    return BannerLink(
      kind: kind,
      productId: asIntOrNull(j['product_id']),
      categorySlug: category is Map
          ? asStringOrNull(category['slug'])
          : (category is String ? category : null),
      url: asStringOrNull(j['url']),
    );
  }

  static const none = BannerLink(kind: BannerLinkKind.none);

  final BannerLinkKind kind;
  final int? productId;
  final String? categorySlug;
  final String? url;

  /// The in-app location the banner opens, or null (none / external url).
  String? get location => switch (kind) {
    BannerLinkKind.product when productId != null => '/product/$productId',
    BannerLinkKind.category
        when categorySlug != null && categorySlug!.isNotEmpty =>
      Uri(
        path: '/catalog/list',
        queryParameters: {'category': categorySlug},
      ).toString(),
    _ => null,
  };

  /// The external https address for kind `url`.
  Uri? get externalUri {
    if (kind != BannerLinkKind.url || url == null) return null;
    final uri = Uri.tryParse(url!);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
        ? uri
        : null;
  }
}

/// An entry of `GET catalog/banners/`.
@immutable
class CatalogBanner {
  const CatalogBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.imageWidth,
    required this.imageHeight,
    required this.link,
    this.imageMediumUrl,
  });

  factory CatalogBanner.fromJson(Json j) => CatalogBanner(
    id: asInt(j['id']),
    title: asString(j['title']),
    imageUrl: asStringOrNull(j['image_url']),
    imageMediumUrl: asStringOrNull(j['image_medium_url']),
    imageWidth: asIntOrNull(j['image_width']),
    imageHeight: asIntOrNull(j['image_height']),
    link: j['link'] is Map
        ? BannerLink.fromJson(asJson(j['link']))
        : BannerLink.none,
  );

  final int id;
  final String title;
  final String? imageUrl;
  final int? imageWidth;
  final int? imageHeight;
  final BannerLink link;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// 1000 px variant (null → the original).
  final String? imageMediumUrl;
  String? get mediumUrl => imageMediumUrl ?? imageUrl;
}

/// `ordering` of `GET catalog/products/`.
enum ProductOrdering {
  newest('default'),
  priceAsc('price'),
  priceDesc('-price'),
  name('name');

  const ProductOrdering(this.apiValue);
  final String apiValue;
}

/// A product list request (filters without the page). Value-equal, so it can
/// key a provider family.
@immutable
class ProductQuery {
  const ProductQuery({
    this.search = '',
    this.category,
    this.inStock = false,
    this.promo = false,
    this.ordering = ProductOrdering.newest,
  });

  /// The API ignores searches shorter than this.
  static const minSearchLength = 2;
  static const maxSearchLength = 64;
  static const pageSize = 20;

  final String search;
  final String? category;
  final bool inStock;
  final bool promo;
  final ProductOrdering ordering;

  /// The search the API will actually apply ('' when too short).
  String get effectiveSearch {
    final s = search.trim();
    if (s.length < minSearchLength) return '';
    return s.length > maxSearchLength ? s.substring(0, maxSearchLength) : s;
  }

  Map<String, dynamic> toQuery(int page) => {
    if (effectiveSearch.isNotEmpty) 'search': effectiveSearch,
    if (category != null && category!.isNotEmpty) 'category': category,
    if (inStock) 'in_stock': 'true',
    if (promo) 'promo': 'true',
    'ordering': ordering.apiValue,
    'page': '$page',
    'page_size': '$pageSize',
  };

  ProductQuery copyWith({
    String? search,
    String? Function()? category,
    bool? inStock,
    bool? promo,
    ProductOrdering? ordering,
  }) => ProductQuery(
    search: search ?? this.search,
    category: category != null ? category() : this.category,
    inStock: inStock ?? this.inStock,
    promo: promo ?? this.promo,
    ordering: ordering ?? this.ordering,
  );

  @override
  bool operator ==(Object other) =>
      other is ProductQuery &&
      other.effectiveSearch == effectiveSearch &&
      other.category == category &&
      other.inStock == inStock &&
      other.promo == promo &&
      other.ordering == ordering;

  @override
  int get hashCode =>
      Object.hash(effectiveSearch, category, inStock, promo, ordering);

  @override
  String toString() => 'ProductQuery(${toQuery(1)})';
}

/// "Mashhur mahsulotlar": the API has no popularity, so promo products come
/// first, then the newest, without duplicates, at most [limit].
List<ProductCard> mergePopular(
  List<ProductCard> promo,
  List<ProductCard> newest, {
  int limit = 20,
}) {
  final seen = <int>{};
  final out = <ProductCard>[];
  for (final p in [...promo, ...newest]) {
    if (out.length >= limit) break;
    if (seen.add(p.id)) out.add(p);
  }
  return out;
}

/// The quantity of a product in the cart: the loaded cart wins, else the
/// `in_cart_quantity` the list was fetched with.
int cartQuantityFor({
  required int? cartQuantity,
  required int inCartQuantity,
}) => cartQuantity ?? inCartQuantity;
