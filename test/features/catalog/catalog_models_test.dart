import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/features/catalog/data/catalog_models.dart';

Map<String, dynamic> cardJson({
  int id = 1,
  bool promo = false,
  String stock = 'in_stock',
  int available = 12,
  int inCart = 0,
}) => {
  'id': id,
  'slug': 'p-$id',
  'name': 'Gialuron kislotali serum',
  'content_language': 'uz',
  'sku': '4607012301',
  'volume': '30 ml',
  'price': 185000,
  'promo': promo,
  'category': {'slug': 'serums', 'name': 'Serumlar'},
  'main_image_url': 'https://media.example.uz/products/$id/a.webp',
  'available': available,
  'stock_status': stock,
  'in_cart_quantity': inCart,
  'updated_at': '2026-10-22T18:04:00+05:00',
};

ProductCard card(int id, {bool promo = false}) =>
    ProductCard.fromJson(cardJson(id: id, promo: promo));

void main() {
  group('ProductCard', () {
    test('parses the contract fields', () {
      final p = ProductCard.fromJson(cardJson(inCart: 2));
      expect(p.id, 1);
      expect(p.price, 185000);
      expect(p.category?.name, 'Serumlar');
      expect(p.inStock, isTrue);
      expect(p.inCartQuantity, 2);
      expect(p.subtitle, '30 ml · Serumlar');
      expect(p.artSeed, contains('serums'));
    });

    test('out of stock and missing category', () {
      final json = cardJson(stock: 'out_of_stock', available: 0)
        ..['category'] = null
        ..['volume'] = '';
      final p = ProductCard.fromJson(json);
      expect(p.inStock, isFalse);
      expect(p.category, isNull);
      expect(p.subtitle, '');
    });

    test('unknown stock status falls back to available', () {
      expect(
        ProductCard.fromJson(cardJson(stock: 'weird', available: 3)).inStock,
        isTrue,
      );
      expect(
        ProductCard.fromJson(cardJson(stock: 'weird', available: 0)).inStock,
        isFalse,
      );
    });
  });

  group('ProductDetail', () {
    test('sorts the gallery and reads texts', () {
      final d = ProductDetail.fromJson({
        ...cardJson(),
        'description': ' Tavsif ',
        'ingredients': '',
        'usage': 'Surting',
        'images': [
          {'id': 2, 'url': 'b', 'position': 1},
          {'id': 1, 'url': 'a', 'position': 0},
          {'id': 3, 'url': '', 'position': 2},
        ],
        'max_quantity': 10,
      });
      expect(d.galleryUrls, ['a', 'b']);
      expect(d.description, 'Tavsif');
      expect(d.ingredients, isEmpty);
      expect(d.canAdd, isTrue);
    });

    test('falls back to the main image and cannot add at max_quantity 0', () {
      final d = ProductDetail.fromJson({
        ...cardJson(),
        'images': <Object>[],
        'max_quantity': 0,
      });
      expect(d.galleryUrls, ['https://media.example.uz/products/1/a.webp']);
      expect(d.canAdd, isFalse);
    });
  });

  group('Banner links', () {
    CatalogBanner banner(Map<String, dynamic> link) => CatalogBanner.fromJson({
      'id': 3,
      'title': 'Kuzgi chegirmalar',
      'image_url': null,
      'image_width': null,
      'image_height': null,
      'link': link,
    });

    test('product', () {
      final b = banner({
        'kind': 'product',
        'product_id': 4,
        'category': null,
        'url': null,
      });
      expect(b.link.location, '/product/4');
      expect(b.hasImage, isFalse);
    });

    test('category', () {
      final b = banner({
        'kind': 'category',
        'product_id': null,
        'category': {'slug': 'sun', 'name': 'Quyosh'},
        'url': null,
      });
      expect(b.link.location, '/catalog/list?category=sun');
    });

    test('url opens externally', () {
      final b = banner({
        'kind': 'url',
        'product_id': null,
        'category': null,
        'url': 'https://glowderma.uz/aksiya',
      });
      expect(b.link.location, isNull);
      expect(b.link.externalUri.toString(), 'https://glowderma.uz/aksiya');
    });

    test('none and unknown kinds go nowhere', () {
      for (final kind in ['none', 'other']) {
        final b = banner({
          'kind': kind,
          'product_id': null,
          'category': null,
          'url': null,
        });
        expect(b.link.kind, BannerLinkKind.none);
        expect(b.link.location, isNull);
        expect(b.link.externalUri, isNull);
      }
    });
  });

  group('ProductQuery', () {
    test('builds the API query', () {
      const q = ProductQuery(
        search: ' krem ',
        category: 'serums',
        inStock: true,
        promo: true,
        ordering: ProductOrdering.priceDesc,
      );
      expect(q.toQuery(2), {
        'search': 'krem',
        'category': 'serums',
        'in_stock': 'true',
        'promo': 'true',
        'ordering': '-price',
        'page': '2',
        'page_size': '20',
      });
    });

    test('ignores a one-letter search and cuts long ones', () {
      expect(
        const ProductQuery(search: 'k').toQuery(1).containsKey('search'),
        isFalse,
      );
      expect(ProductQuery(search: 'a' * 80).effectiveSearch.length, 64);
    });

    test('equality uses the effective search', () {
      expect(const ProductQuery(search: 'k'), const ProductQuery());
      expect(
        const ProductQuery(search: 'krem '),
        const ProductQuery(search: 'krem'),
      );
      expect(
        const ProductQuery(search: 'krem') ==
            const ProductQuery(search: 'krem', inStock: true),
        isFalse,
      );
    });

    test('copyWith can clear the category', () {
      const q = ProductQuery(category: 'sun');
      expect(q.copyWith(category: () => null).category, isNull);
      expect(q.copyWith(inStock: true).category, 'sun');
    });
  });

  test('mergePopular puts promo first, dedups and limits', () {
    final merged = mergePopular(
      [card(5, promo: true), card(2, promo: true)],
      [card(9), card(5), card(2), card(7)],
      limit: 4,
    );
    expect(merged.map((p) => p.id), [5, 2, 9, 7]);
    expect(
      mergePopular([], [card(1), card(2), card(3)], limit: 2).map((p) => p.id),
      [1, 2],
    );
  });

  test('cartQuantityFor prefers the loaded cart', () {
    expect(cartQuantityFor(cartQuantity: null, inCartQuantity: 3), 3);
    expect(cartQuantityFor(cartQuantity: 0, inCartQuantity: 3), 0);
    expect(cartQuantityFor(cartQuantity: 2, inCartQuantity: 0), 2);
  });
}
