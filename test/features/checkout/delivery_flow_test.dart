import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/format/money.dart';
import 'package:glow_derma/core/i18n/tr.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/core/network/json.dart';
import 'package:glow_derma/features/checkout/application/delivery_flow.dart';
import 'package:glow_derma/features/checkout/data/checkout_api.dart';
import 'package:glow_derma/features/checkout/presentation/delivery_options.dart';

/// The real answer of the local backend (with_options, address with a pin).
Json pinnedAnswer() => {
  'fulfilment': 'delivery',
  'delivery_fee': 40000,
  'region_code': '10',
  'city_code': '1002',
  'weight_g': 300,
  'pickup_address': null,
  'quoted_at': '2026-11-17T19:48:31+05:00',
  'items_subtotal': 185000,
  'cashback_max': 0,
  'cashback_to_use': 0,
  'expected_total': 225000,
  'provider': 'yandex',
  'method': 'standard',
  'quote_id': '7191dc8f-788d-4a1f-aa55-55ee83fdfb1a',
  'quote_expires_at': '2026-11-17T20:03:31+05:00',
  'options': [
    {
      'provider': 'yandex',
      'method': 'standard',
      'label': 'Yandex Standart',
      'available': true,
      'unavailable_reason': null,
      'fee': 40000,
      'eta_from': '2026-11-17T21:18:31+05:00',
      'eta_to': '2026-11-17T23:18:31+05:00',
      'scheduled': false,
      'quote_id': '7191dc8f-788d-4a1f-aa55-55ee83fdfb1a',
      'expires_at': '2026-11-17T20:03:31+05:00',
      'expected_total': 225000,
    },
    {
      'provider': 'yandex',
      'method': 'express',
      'label': 'Yandex Ekspress',
      'available': true,
      'unavailable_reason': null,
      'fee': 51000,
      'eta_from': '2026-11-17T20:48:31+05:00',
      'eta_to': '2026-11-17T21:48:31+05:00',
      'scheduled': false,
      'quote_id': '4847f532-59b0-47ab-a0f9-fab683dcef75',
      'expires_at': '2026-11-17T20:03:31+05:00',
      'expected_total': 236000,
    },
    {
      'provider': 'bts',
      'method': null,
      'label': 'BTS pochta',
      'available': true,
      'unavailable_reason': null,
      'fee': 25000,
      'eta_from': null,
      'eta_to': null,
      'scheduled': false,
      'quote_id': null,
      'expires_at': null,
      'expected_total': 210000,
    },
  ],
};

Json _refusedYandex(String method, String label) => {
  'provider': 'yandex',
  'method': method,
  'label': label,
  'available': false,
  'unavailable_reason': 'coordinates_required',
  'fee': null,
  'eta_from': null,
  'eta_to': null,
  'scheduled': false,
  'quote_id': null,
  'expires_at': null,
  'expected_total': null,
};

/// The same address without a pin: BTS is selected, Yandex is refused.
Json unpinnedAnswer() => {
  ...pinnedAnswer(),
  'delivery_fee': 25000,
  'expected_total': 210000,
  'provider': 'bts',
  'method': null,
  'quote_id': null,
  'quote_expires_at': null,
  'options': [
    _refusedYandex('standard', 'Yandex Standart'),
    _refusedYandex('express', 'Yandex Ekspress'),
    (pinnedAnswer()['options']! as List)[2],
  ],
};

Json pickupAnswer() => {
  'fulfilment': 'pickup',
  'delivery_fee': 0,
  'region_code': null,
  'city_code': null,
  'weight_g': 300,
  'pickup_address': 'Toshkent, Bunyodkor 12',
  'quoted_at': '2026-11-17T19:48:31+05:00',
  'items_subtotal': 185000,
  'cashback_max': 0,
  'cashback_to_use': 0,
  'expected_total': 185000,
  'provider': null,
  'method': null,
  'quote_id': null,
  'quote_expires_at': null,
  'options': <Object?>[],
};

DeliveryQuote quote(Json j) => DeliveryQuote.fromJson(j, addressId: 12);

/// [base] with its selected option's fee and total replaced.
Json withStandard(Json base, {required int fee, required int total}) {
  final options = [...(base['options']! as List)];
  options[0] = {
    ...(options[0] as Map<String, Object?>),
    'fee': fee,
    'expected_total': total,
  };
  return {
    ...base,
    'delivery_fee': fee,
    'expected_total': total,
    'options': options,
  };
}

void main() {
  group('parsing', () {
    test('a Yandex quote with every option', () {
      final q = quote(pinnedAnswer());
      expect(q.provider, 'yandex');
      expect(q.method, 'standard');
      expect(q.quoteId, '7191dc8f-788d-4a1f-aa55-55ee83fdfb1a');
      expect(q.quoteExpiresAt, DateTime.parse('2026-11-17T20:03:31+05:00'));
      expect(q.quotedAt, DateTime.parse('2026-11-17T19:48:31+05:00'));
      expect(q.choice, (provider: 'yandex', method: 'standard'));
      expect(q.options.map((o) => o.label), [
        'Yandex Standart',
        'Yandex Ekspress',
        'BTS pochta',
      ]);
      final express = q.options[1];
      expect(express.available, isTrue);
      expect(express.fee, 51000);
      expect(express.expectedTotal, 236000);
      expect(express.quoteId, '4847f532-59b0-47ab-a0f9-fab683dcef75');
      expect(express.etaFrom, DateTime.parse('2026-11-17T20:48:31+05:00'));
      expect(express.etaTo, DateTime.parse('2026-11-17T21:48:31+05:00'));
      final bts = q.options[2];
      expect(bts.method, isNull);
      expect(bts.quoteId, isNull);
      expect(bts.etaFrom, isNull);
      expect(bts.fee, 25000);
      expect(q.selectedOption?.label, 'Yandex Standart');
      expect(q.selectedTotal, 225000);
      expect(placeable(q), isTrue);
    });

    test('an address without a pin selects BTS; Yandex is refused', () {
      final q = quote(unpinnedAnswer());
      expect(q.provider, 'bts');
      expect(q.method, isNull);
      expect(q.quoteId, isNull);
      expect(q.quoteExpiresAt, isNull);
      expect(q.options, hasLength(3));
      for (final o in q.options.take(2)) {
        expect(o.available, isFalse);
        expect(o.unavailableReason, 'coordinates_required');
        expect(o.fee, isNull);
        expect(o.expectedTotal, isNull);
      }
      expect(q.selectedOption?.provider, 'bts');
      expect(q.selectedTotal, 210000);
      expect(placeable(q), isTrue);
    });

    test('pickup has no carrier and no options', () {
      final q = DeliveryQuote.fromJson(pickupAnswer());
      expect(q.provider, isNull);
      expect(q.method, isNull);
      expect(q.quoteId, isNull);
      expect(q.options, isEmpty);
      expect(q.selectedTotal, 185000);
    });

    test('an available option without its price or quote id is refused', () {
      final o = DeliveryOption.fromJson({
        'provider': 'yandex',
        'method': 'express',
        'label': 'Yandex Ekspress',
        'available': true,
        'fee': 51000,
        'expected_total': 236000,
        'quote_id': null,
      });
      expect(o!.available, isFalse);
      expect(o.unavailableReason, 'provider_unavailable');
      expect(
        DeliveryOption.fromJson({'provider': 'dhl', 'label': 'DHL'}),
        isNull,
      );
    });
  });

  group('buildCheckoutBody', () {
    test('a Yandex selection sends its quote id and the option total', () {
      expect(
        buildCheckoutBody(
          quote: quote(pinnedAnswer()),
          paymentProviders: const ['click'],
          note: '',
        ),
        {
          'fulfilment': 'delivery',
          'address_id': 12,
          'payment_provider': 'click',
          'cashback_to_use': 0,
          'expected_total': 225000,
          'customer_note': '',
          'delivery_quote_id': '7191dc8f-788d-4a1f-aa55-55ee83fdfb1a',
        },
      );
    });

    test('a BTS selection sends the released body', () {
      final body = buildCheckoutBody(
        quote: quote(unpinnedAnswer()),
        paymentProviders: const ['payme'],
        note: ' ',
      );
      expect(body.containsKey('delivery_quote_id'), isFalse);
      expect(body['expected_total'], 210000);
    });
  });

  group('placeable', () {
    test('needs a quote; pickup, BTS and quoted Yandex can be placed', () {
      expect(placeable(null), isFalse);
      expect(placeable(DeliveryQuote.fromJson(pickupAnswer())), isTrue);
      expect(placeable(quote(unpinnedAnswer())), isTrue);
      expect(placeable(quote(pinnedAnswer())), isTrue);
      // An older answer without options (BTS only).
      expect(
        placeable(
          quote({...pinnedAnswer(), 'provider': null, 'options': null}),
        ),
        isTrue,
      );
    });

    test('a delivery answer where every option is refused cannot', () {
      final q = quote({
        ...unpinnedAnswer(),
        'provider': null,
        'options': [
          _refusedYandex('standard', 'Yandex Standart'),
          _refusedYandex('express', 'Yandex Ekspress'),
        ],
      });
      expect(placeable(q), isFalse);
    });
  });

  group('displayedChoice', () {
    final q = quote(pinnedAnswer());
    const express = (provider: 'yandex', method: 'express');
    test('follows the tap while its re-quote is on the way', () {
      expect(displayedChoice(q, express, pending: true), express);
    });
    test('else shows the server selection', () {
      expect(displayedChoice(q, express, pending: false), q.choice);
      expect(displayedChoice(q, null, pending: true), q.choice);
      expect(
        displayedChoice(quote(unpinnedAnswer()), (
          provider: 'yandex',
          method: 'standard',
        ), pending: true),
        (provider: 'bts', method: null),
      );
      expect(displayedChoice(null, express, pending: true), isNull);
    });
  });

  group('optionProblem', () {
    final refused = quote(unpinnedAnswer()).options.first;
    DeliveryOption option(String provider, String reason) =>
        DeliveryOption.fromJson({
          'provider': provider,
          'method': provider == 'bts' ? null : 'standard',
          'label': provider,
          'available': false,
          'unavailable_reason': reason,
        })!;

    test('an available option has none', () {
      expect(
        optionProblem(
          quote(pinnedAnswer()).options.first,
          hasAddress: true,
          addressHasRegion: true,
        ),
        isNull,
      );
    });
    test('a missing pin offers the map when there is an address', () {
      expect(optionProblem(refused, hasAddress: true, addressHasRegion: true), (
        reason: 'coordinates_required',
        action: OptionAction.pin,
      ));
      expect(
        optionProblem(refused, hasAddress: false, addressHasRegion: false),
        (reason: 'coordinates_required', action: null),
      );
    });
    test('BTS out of zone without a region asks to edit the address', () {
      expect(
        optionProblem(
          option('bts', 'out_of_zone'),
          hasAddress: true,
          addressHasRegion: false,
        ),
        (reason: 'region_required', action: OptionAction.edit),
      );
      expect(
        optionProblem(
          option('bts', 'out_of_zone'),
          hasAddress: true,
          addressHasRegion: true,
        ),
        (reason: 'out_of_zone', action: null),
      );
    });
    test('a silent provider can be asked again; others have no action', () {
      expect(
        optionProblem(
          option('yandex', 'provider_unavailable'),
          hasAddress: true,
          addressHasRegion: true,
        ),
        (reason: 'provider_unavailable', action: OptionAction.retry),
      );
      expect(
        optionProblem(
          option('yandex', 'too_heavy'),
          hasAddress: true,
          addressHasRegion: true,
        ),
        (reason: 'too_heavy', action: null),
      );
    });
  });

  group('compareQuotes', () {
    final seen = seenTerms(quote(pinnedAnswer()));
    test('same option, fee and total', () {
      expect(compareQuotes(seen, quote(pinnedAnswer())), isA<RequoteSame>());
    });
    test('another fee', () {
      final outcome = compareQuotes(
        seen,
        quote(withStandard(pinnedAnswer(), fee: 45000, total: 230000)),
      );
      expect(outcome, isA<RequoteFeeChanged>());
      outcome as RequoteFeeChanged;
      expect((outcome.from, outcome.to), (40000, 45000));
    });
    test('same fee, another total', () {
      expect(
        compareQuotes(
          seen,
          quote(withStandard(pinnedAnswer(), fee: 40000, total: 220000)),
        ),
        isA<RequoteTotalChanged>(),
      );
    });
    test('the option went away', () {
      final outcome = compareQuotes(seen, quote(unpinnedAnswer()));
      expect(outcome, isA<RequoteReplaced>());
      expect((outcome as RequoteReplaced).label, 'BTS pochta');
    });
    test('nothing can take the order', () {
      expect(
        compareQuotes(
          seen,
          quote({
            ...unpinnedAnswer(),
            'provider': null,
            'options': [_refusedYandex('standard', 'Yandex Standart')],
          }),
        ),
        isA<RequoteNone>(),
      );
    });
  });

  group('requoteAt / quoteExpired', () {
    test('measures the lifetime on the server clock from the receipt', () {
      // The phone clock is a day and 7 minutes behind the server.
      final received = DateTime.parse('2026-11-16T19:41:00+05:00');
      expect(
        requoteAt(quote(pinnedAnswer()), received),
        received.add(const Duration(minutes: 15, seconds: 1)),
      );
    });
    test('without quoted_at falls back to the expiry itself', () {
      final q = quote({...pinnedAnswer(), 'quoted_at': null});
      expect(
        requoteAt(q, DateTime.now()),
        DateTime.parse('2026-11-17T20:03:32+05:00'),
      );
    });
    test('BTS and pickup never expire', () {
      expect(requoteAt(quote(unpinnedAnswer()), DateTime.now()), isNull);
      expect(
        requoteAt(DeliveryQuote.fromJson(pickupAnswer()), DateTime.now()),
        isNull,
      );
    });
    test('quoteExpired', () {
      final deadline = DateTime.utc(2026, 11, 17, 15, 3, 32);
      expect(quoteExpired(null, deadline), isFalse);
      expect(
        quoteExpired(deadline, deadline.subtract(const Duration(seconds: 2))),
        isFalse,
      );
      expect(quoteExpired(deadline, deadline.subtract(requoteGrace)), isTrue);
      expect(quoteExpired(deadline, deadline), isTrue);
    });
  });

  group('readDeliveryConflict', () {
    ApiException conflict(String code, Json details) =>
        ApiException(status: 409, code: code, message: 'msg', details: details);
    final options = pinnedAnswer()['options'];

    test('a Yandex price change brings the new fee and the options', () {
      final c = readDeliveryConflict(
        conflict('price_changed', {'delivery_fee': 45000, 'options': options}),
      );
      expect(c, isA<DeliveryPriceChanged>());
      c as DeliveryPriceChanged;
      expect(c.fee, 45000);
      expect(c.options, hasLength(3));
    });
    test('an expired quote', () {
      final c = readDeliveryConflict(conflict('quote_expired', const {}));
      expect(c, isA<QuoteExpired>());
      expect(c!.options, isNull);
    });
    test('no delivery to the address', () {
      final c = readDeliveryConflict(
        conflict('delivery_unavailable', {
          'options': [_refusedYandex('standard', 'Yandex Standart')],
        }),
      );
      expect(c, isA<DeliveryUnavailable>());
      expect(c!.options!.single.unavailableReason, 'coordinates_required');
    });
    test('the released price_changed (items) is not about delivery', () {
      expect(
        readDeliveryConflict(
          conflict('price_changed', {
            'expected_total': 1,
            'cart': <String, Object?>{},
          }),
        ),
        isNull,
      );
      expect(readDeliveryConflict(conflict('OUT_OF_STOCK', const {})), isNull);
    });
  });

  group('formatEtaWindow', () {
    final now = DateTime.parse('2026-10-26T08:10:00+05:00');
    DateTime at(String s) => DateTime.parse(s);

    test('today and tomorrow are relative to the quote', () {
      expect(
        formatEtaWindow(
          at('2026-10-26T14:30:00+05:00'),
          at('2026-10-26T16:00:00+05:00'),
          AppLanguage.uz,
          now: now,
        ),
        'Bugun, 14:30–16:00',
      );
      expect(
        formatEtaWindow(
          at('2026-10-27T04:00:00Z'),
          at('2026-10-27T06:00:00Z'),
          AppLanguage.uz,
          now: now,
        ),
        'Ertaga, 09:00–11:00',
      );
      expect(
        formatEtaWindow(
          at('2026-10-26T14:30:00+05:00'),
          at('2026-10-26T16:00:00+05:00'),
          AppLanguage.ru,
          now: now,
        ),
        'Сегодня, 14:30–16:00',
      );
    });
    test('other days read as dates, in Tashkent time', () {
      expect(
        formatEtaWindow(
          at('2026-10-26T14:30:00+05:00'),
          at('2026-10-26T16:00:00+05:00'),
          AppLanguage.uz,
        ),
        '26-oktabr, 14:30–16:00',
      );
      expect(
        formatEtaWindow(
          at('2026-10-26T18:00:00+05:00'),
          at('2026-10-27T10:00:00+05:00'),
          AppLanguage.uz,
        ),
        '26-oktabr, 18:00 – 27-oktabr, 10:00',
      );
      expect(
        formatEtaWindow(
          at('2026-10-26T18:00:00+05:00'),
          at('2026-10-27T10:00:00+05:00'),
          AppLanguage.uz,
          now: now,
        ),
        'Bugun, 18:00 – Ertaga, 10:00',
      );
      // 20:00 UTC is already the next day in Tashkent.
      expect(
        formatEtaWindow(
          at('2026-10-25T20:00:00Z'),
          at('2026-10-25T21:00:00Z'),
          AppLanguage.en,
        ),
        '26 October, 01:00–02:00',
      );
    });
    test('one end or none', () {
      expect(
        formatEtaWindow(
          at('2026-10-26T14:30:00+05:00'),
          null,
          AppLanguage.uz,
          now: now,
        ),
        'Bugun, 14:30',
      );
      expect(formatEtaWindow(null, null, AppLanguage.uz), isNull);
    });
  });

  test('requoteNotice words every outcome', () {
    expect(requoteNotice(const RequoteSame(), AppLanguage.uz), isNull);
    expect(
      requoteNotice(const RequoteFeeChanged(40000, 45000), AppLanguage.uz),
      'Yetkazib berish narxi o‘zgardi: endi ${formatMoney(45000)} '
      '(avval ${formatMoney(40000)}). Yangi narxni tekshirib, qaytadan tasdiqlang.',
    );
    expect(
      requoteNotice(const RequoteReplaced('BTS pochta'), AppLanguage.uz),
      contains('«BTS pochta»'),
    );
    expect(
      requoteNotice(const RequoteReplaced(''), AppLanguage.en),
      startsWith('The delivery price had expired'),
    );
    expect(
      requoteNotice(const RequoteTotalChanged(), AppLanguage.ru),
      startsWith('Цены обновились'),
    );
    expect(
      requoteNotice(const RequoteNone(), AppLanguage.uz),
      startsWith('Bu manzilga hozir yetkazib bera olmaymiz'),
    );
  });
}
