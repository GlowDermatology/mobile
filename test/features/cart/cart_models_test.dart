import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/features/cart/data/cart_models.dart';

Map<String, dynamic> lineJson([Map<String, dynamic> extra = const {}]) => {
  'product_id': 1,
  'name': 'Serum',
  'volume': '30 ml',
  'main_image_url': 'https://m.uz/a.webp',
  'main_image_thumbnail_url': 'https://m.uz/a_400.webp',
  'main_image_medium_url': 'https://m.uz/a_1000.webp',
  'unit_price': 92500,
  'promo': false,
  'quantity': 1,
  'line_total': 92500,
  'available': 5,
  'max_quantity': 5,
  'max_reached': false,
  'status': 'ok',
  'price_changed': false,
  'previous_price': null,
  ...extra,
};

void main() {
  group('CartLine image renditions', () {
    const square = {
      'url': 'https://m.uz/a_sq.webp',
      'medium_url': 'https://m.uz/a_sq_1000.webp',
      'thumbnail_url': 'https://m.uz/a_sq_400.webp',
    };

    test('present: the thumbnail is the square 400 px copy', () {
      final line = CartLine.fromJson(
        lineJson({
          'main_image_renditions': {'portrait': null, 'square': square},
        }),
      );
      expect(line.imageRenditions.square?.url, 'https://m.uz/a_sq.webp');
      expect(line.thumbUrl, 'https://m.uz/a_sq_400.webp');
      expect(
        line.withQuantity(3).imageRenditions.square?.thumbnailUrl,
        'https://m.uz/a_sq_400.webp',
      );
    });

    test('absent, null or malformed: the image\'s own thumbnail', () {
      for (final extra in <Map<String, dynamic>>[
        {},
        {'main_image_renditions': null},
        {'main_image_renditions': 'square'},
        {'main_image_renditions': <Object>[]},
        {
          'main_image_renditions': {'portrait': 1, 'square': <Object>[]},
        },
        {
          'main_image_renditions': {
            'square': {...square, 'thumbnail_url': null},
          },
        },
      ]) {
        final line = CartLine.fromJson(lineJson(extra));
        expect(line.imageRenditions.square, isNull, reason: '$extra');
        expect(line.thumbUrl, 'https://m.uz/a_400.webp', reason: '$extra');
      }
      final noThumb = CartLine.fromJson(
        lineJson({'main_image_thumbnail_url': null}),
      );
      expect(noThumb.thumbUrl, 'https://m.uz/a.webp');
    });
  });
}
