import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/features/auth/data/auth_models.dart';
import 'package:glow_derma/features/cart/data/cart_models.dart';
import 'package:glow_derma/features/catalog/data/catalog_models.dart';
import 'package:glow_derma/features/orders/data/order_models.dart';
import 'package:glow_derma/features/profile/data/addresses_api.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';

// Parsing of the customer API additions on backend main f085416:
// image variants, delivery providers, map pins, order delivery, cart recovery;
// later the image renditions (portrait / square copies).

Map<String, dynamic> _order({
  String status = 'awaiting_payment',
  Map<String, dynamic>? delivery,
}) => {
  'id': 10261,
  'created_at': '2026-11-17T19:48:39+05:00',
  'status': status,
  'status_label': 'To‘lov kutilmoqda',
  'fulfilment': 'delivery',
  'total': 236000,
  'item_count': 1,
  'preview_images': ['https://m.uz/p/1.webp', 'https://m.uz/p/2.webp'],
  'preview_thumbnail_images': ['https://m.uz/p/1_400.webp'],
  'payment': {
    'status': 'pending',
    'status_label': 'To‘lov kutilmoqda',
    'provider': 'click',
    'in_progress': false,
  },
  'pay_by': '2026-11-17T20:03:39+05:00',
  'tracking_number': null,
  'delivery': delivery,
  'fulfilment_label': 'Yetkazib berish',
  'items': [
    {
      'product_id': 1,
      'name': 'Serum',
      'image_url': 'https://m.uz/p/1.webp',
      'image_thumbnail_url': 'https://m.uz/p/1_400.webp',
      'image_medium_url': 'https://m.uz/p/1_1000.webp',
      'quantity': 2,
      'unit_price': 92500,
      'promo': false,
      'line_total': 185000,
    },
  ],
  'items_subtotal': 185000,
  'promo_subtotal': 0,
  'delivery_fee': 51000,
  'cashback_used': 0,
  'actions': {'pay': true, 'cancel': true, 'reorder': false},
  'progress': [],
  'timeline': [],
};

void main() {
  group('image variants', () {
    test(
      'product card prefers the variants and falls back to the original',
      () {
        final card = ProductCard.fromJson({
          'id': 1,
          'main_image_url': 'https://m.uz/a.webp',
          'main_image_thumbnail_url': 'https://m.uz/a_400.webp',
          'main_image_medium_url': null,
        });
        expect(card.thumbUrl, 'https://m.uz/a_400.webp');
        expect(card.mediumUrl, 'https://m.uz/a.webp');
      },
    );

    test(
      'gallery pages are the 1000 px variants with the originals as fallback',
      () {
        final detail = ProductDetail.fromJson({
          'id': 1,
          'main_image_url': 'https://m.uz/a.webp',
          'images': [
            {
              'id': 1,
              'url': 'https://m.uz/a.webp',
              'thumbnail_url': 'https://m.uz/a_400.webp',
              'medium_url': 'https://m.uz/a_1000.webp',
              'position': 0,
            },
            {'id': 2, 'url': 'https://m.uz/b.webp', 'position': 1},
          ],
        });
        expect(detail.gallery, [
          (
            url: 'https://m.uz/a_1000.webp',
            original: 'https://m.uz/a.webp',
            cover: false,
          ),
          (
            url: 'https://m.uz/b.webp',
            original: 'https://m.uz/b.webp',
            cover: false,
          ),
        ]);
      },
    );

    test('cart lines, order items, previews and the profile photo', () {
      final line = CartLine.fromJson({
        'product_id': 1,
        'main_image_url': 'o',
        'main_image_thumbnail_url': 't',
      });
      expect(line.thumbUrl, 't');
      expect(line.withQuantity(2).thumbUrl, 't');
      final order = OrderDetail.fromJson(_order());
      expect(order.items.single.thumbUrl, 'https://m.uz/p/1_400.webp');
      // A shorter thumbnail list falls back to the original for the rest.
      expect(order.previewTiles, [
        (url: 'https://m.uz/p/1_400.webp', original: 'https://m.uz/p/1.webp'),
        (url: 'https://m.uz/p/2.webp', original: 'https://m.uz/p/2.webp'),
      ]);
      expect(
        Me.fromJson({'id': 5, 'image_url': 'o', 'image_thumbnail_url': null})
            .imageThumbUrl,
        'o',
      );
    });
  });

  group('image renditions', () {
    Map<String, String> shape(String name) => {
      'url': 'https://m.uz/$name.webp',
      'medium_url': 'https://m.uz/${name}_1000.webp',
      'thumbnail_url': 'https://m.uz/${name}_400.webp',
    };

    test('product card: the tile takes the square copy', () {
      final card = ProductCard.fromJson({
        'id': 1,
        'main_image_url': 'https://m.uz/a.webp',
        'main_image_medium_url': 'https://m.uz/a_1000.webp',
        'main_image_renditions': {'portrait': null, 'square': shape('a_sq')},
      });
      expect(card.tileUrl, 'https://m.uz/a_sq_1000.webp');
      expect(card.mediumUrl, 'https://m.uz/a_1000.webp');
    });

    test('gallery: portrait copies fill the page, the rest as before', () {
      final detail = ProductDetail.fromJson({
        'id': 1,
        'main_image_url': 'https://m.uz/a.webp',
        'images': [
          {
            'id': 1,
            'url': 'https://m.uz/a.webp',
            'medium_url': 'https://m.uz/a_1000.webp',
            'position': 0,
            'renditions': {'portrait': shape('a_45'), 'square': shape('a_sq')},
          },
          {
            'id': 2,
            'url': 'https://m.uz/b.webp',
            'medium_url': 'https://m.uz/b_1000.webp',
            'position': 1,
            'renditions': {'portrait': null, 'square': shape('b_sq')},
          },
          {
            'id': 3,
            'url': 'https://m.uz/c.webp',
            'position': 2,
            'renditions': 'broken',
          },
        ],
      });
      expect(
        detail.images.first.renditions.square?.url,
        'https://m.uz/a_sq.webp',
      );
      expect(detail.gallery, [
        (
          url: 'https://m.uz/a_45_1000.webp',
          original: 'https://m.uz/a.webp',
          cover: true,
        ),
        (
          url: 'https://m.uz/b_1000.webp',
          original: 'https://m.uz/b.webp',
          cover: false,
        ),
        (
          url: 'https://m.uz/c.webp',
          original: 'https://m.uz/c.webp',
          cover: false,
        ),
      ]);
    });

    test('gallery without images: the portrait copy of the main image', () {
      final detail = ProductDetail.fromJson({
        'id': 1,
        'main_image_url': 'https://m.uz/a.webp',
        'main_image_renditions': {'portrait': shape('a_45'), 'square': null},
        'images': <Object>[],
      });
      expect(detail.gallery, [
        (
          url: 'https://m.uz/a_45_1000.webp',
          original: 'https://m.uz/a.webp',
          cover: true,
        ),
      ]);
    });

    test('cart line: the square 400 px copy, kept through a local preview', () {
      final line = CartLine.fromJson({
        'product_id': 1,
        'main_image_url': 'o',
        'main_image_thumbnail_url': 't',
        'main_image_renditions': {'portrait': null, 'square': shape('a_sq')},
      });
      expect(line.thumbUrl, 'https://m.uz/a_sq_400.webp');
      expect(line.withQuantity(2).thumbUrl, 'https://m.uz/a_sq_400.webp');
      expect(line.imageUrl, 'o');
    });
  });

  test('delivery is offered when a carrier is listed even if fulfilment_methods lacks it', () {
    const yandexOnly = PublicSettings({
      'fulfilment_methods': ['pickup'],
      'delivery': {
        'providers': ['yandex', 'unknown', 'yandex'],
        'default_provider': 'yandex',
      },
    });
    expect(yandexOnly.deliveryProviders, ['yandex']);
    expect(yandexOnly.offeredFulfilments, ['delivery', 'pickup']);
    const released = PublicSettings({
      'fulfilment_methods': ['delivery', 'pickup'],
    });
    expect(released.deliveryProviders, isEmpty);
    expect(released.offeredFulfilments, ['delivery', 'pickup']);
    const none = PublicSettings({
      'fulfilment_methods': ['pickup'],
      'delivery': {'providers': [], 'default_provider': null},
    });
    expect(none.offeredFulfilments, ['pickup']);
  });

  test('payment providers: Uzum is kept, unknown values are dropped', () {
    const all = PublicSettings({
      'payment_providers': ['click', 'payme', 'uzum'],
    });
    expect(all.paymentProviders, ['click', 'payme', 'uzum']);
    const future = PublicSettings({
      'payment_providers': ['octo', 'uzum', 'uzum', 'click'],
    });
    expect(future.paymentProviders, ['uzum', 'click']);
    const unknownOnly = PublicSettings({
      'payment_providers': ['octo'],
    });
    expect(unknownOnly.paymentProviders, isEmpty);
    expect(const PublicSettings({}).paymentProviders, isEmpty);
  });

  test('an Uzum pay link: a web form, no app link', () {
    final link = PayResult.fromJson({
      'order_id': 10261,
      'provider': 'uzum',
      'amount': 236000,
      'pay_by': '2026-11-17T19:58:39+05:00',
      'web_url': 'https://checkout.example.uz/pay/abc',
      'app_url': null,
      'return_url': 'https://glowderma.uz/pay/return?order_id=10261',
    });
    expect(link.provider, 'uzum');
    expect(link.webUrl, 'https://checkout.example.uz/pay/abc');
    expect(link.appUrl, isNull);
    expect(link.payBy, isNotNull);
    expect(providerName(link.provider), 'Uzum');
  });

  test('address pins: both coordinates or none', () {
    expect(
      Address.fromJson({'id': 1, 'latitude': 41.36, 'longitude': 69.28}).pin,
      (latitude: 41.36, longitude: 69.28),
    );
    expect(
      Address.fromJson({'id': 1, 'latitude': 41.36, 'longitude': null}).hasPin,
      isFalse,
    );
    expect(pinFields(null), {'latitude': null, 'longitude': null});
    expect(pinFields((latitude: 41.5, longitude: 69.25)), {
      'latitude': 41.5,
      'longitude': 69.25,
    });
  });

  group('order delivery', () {
    test(
      'a Yandex order right after checkout: no stage, a promised window',
      () {
        final d = OrderDetail.fromJson(
          _order(
            delivery: {
              'provider': 'yandex',
              'method': 'express',
              'method_label': 'Ekspress',
              'stage': null,
              'stage_label': null,
              'eta_from': '2026-11-17T20:48:31+05:00',
              'eta_to': '2026-11-17T21:48:31+05:00',
              'courier_name': null,
              'courier_vehicle': null,
              'tracking_url': null,
            },
          ),
        ).delivery!;
        expect(d.isYandex, isTrue);
        expect(d.stage, isNull);
        expect(d.isFinished, isFalse);
        expect(d.etaShown, isTrue);
        expect(d.courierLine, isNull);
      },
    );

    test('courier shown while on the way; only https tracking pages', () {
      final d = OrderDelivery.fromJson({
        'provider': 'yandex',
        'stage': 'in_transit',
        'stage_label': 'Yo‘lda',
        'courier_name': 'Aziz',
        'courier_vehicle': 'Cobalt 01A777AA',
        'tracking_url': 'https://t.ya/x',
      });
      expect(d.courierLine, 'Aziz · Cobalt 01A777AA');
      expect(d.trackingUrl, 'https://t.ya/x');
      expect(
        OrderDelivery.fromJson({
          'provider': 'yandex',
          'tracking_url': 'javascript:alert(1)',
        }).trackingUrl,
        isNull,
      );
      expect(
        OrderDelivery.fromJson({
          'provider': 'yandex',
          'stage': 'delivered',
          'courier_name': 'Aziz',
        }).courierLine,
        isNull,
      );
      expect(
        OrderDelivery.fromJson({
          'provider': 'yandex',
          'stage': 'returned',
          'eta_from': '2026-11-17T20:48:31+05:00',
          'eta_to': '2026-11-17T21:48:31+05:00',
        }).etaShown,
        isFalse,
      );
    });

    test('a BTS order carries only its provider; pickup has none', () {
      final bts = OrderSummary.fromJson({
        ..._order(),
        'delivery': {'provider': 'bts', 'method': null, 'stage': null},
      });
      expect(bts.delivery!.isYandex, isFalse);
      expect(
        OrderSummary.fromJson({..._order(), 'delivery': null}).delivery,
        isNull,
      );
    });
  });

  group('cart recovery', () {
    test('an unpaid checkout order is parsed, kept through a local preview, and counted on the badge', () {
      final cart = Cart.fromJson({
        'items': [
          {
            'product_id': 7,
            'quantity': 1,
            'unit_price': 1000,
            'line_total': 1000,
            'status': 'ok',
          },
        ],
        'item_count': 1,
        'checkout_order': _order(),
      });
      expect(cart.checkoutOrder!.id, 10261);
      expect(cart.hasUnpaidOrder, isTrue);
      expect(cart.badgeCount, 2);
      expect(cart.withLineQuantity(7, 2).checkoutOrder!.id, 10261);
    });

    test(
      'an expired checkout is offered for restore but does not block or count',
      () {
        final cart = Cart.fromJson({
          'items': [],
          'item_count': 0,
          'checkout_order': _order(status: 'cancelled'),
        });
        expect(cart.checkoutOrder, isNotNull);
        expect(cart.hasUnpaidOrder, isFalse);
        expect(cart.badgeCount, 0);
        expect(
          Cart.fromJson({'items': [], 'checkout_order': null}).checkoutOrder,
          isNull,
        );
      },
    );
  });
}
