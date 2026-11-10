import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/network/api_exception.dart';
import 'package:glow_derma/features/profile/application/profile_logic.dart';
import 'package:glow_derma/features/profile/application/profile_providers.dart';
import 'package:glow_derma/features/settings/data/public_settings.dart';

void main() {
  group('LegalDoc', () {
    test('maps slugs and falls back to terms', () {
      expect(LegalDoc.fromSlug('privacy'), LegalDoc.privacy);
      expect(LegalDoc.fromSlug('booking'), LegalDoc.booking);
      expect(LegalDoc.fromSlug('nope'), LegalDoc.terms);
      expect(LegalDoc.privacy.route, '/settings/legal/privacy');
    });

    test('reads the matching text', () {
      const s = PublicSettings({
        'privacy_policy': 'P',
        'terms': 'T',
        'booking_policy': 'B',
      });
      expect(LegalDoc.privacy.textOf(s), 'P');
      expect(LegalDoc.terms.textOf(s), 'T');
      expect(LegalDoc.booking.textOf(s), 'B');
    });
  });

  group('contactLinks', () {
    test('keeps the design order and builds tel: for the phone', () {
      const s = PublicSettings({
        'telegram_url': 'https://t.me/glowderma',
        'instagram_url': 'https://instagram.com/glowderma',
        'website_url': 'glowderma.uz',
        'store_phone': '+998 71 200 00 01',
      });
      final links = contactLinks(s);
      expect(links.map((l) => l.kind), [
        ContactKind.telegram,
        ContactKind.instagram,
        ContactKind.website,
        ContactKind.phone,
      ]);
      expect(links[2].uri.toString(), 'https://glowderma.uz');
      expect(links[3].uri.toString(), 'tel:+998712000001');
    });

    test('hides tiles whose value is missing or blank', () {
      const s = PublicSettings({
        'telegram_url': null,
        'instagram_url': '',
        'website_url': 'https://glowderma.uz',
        'store_phone': null,
      });
      expect(contactLinks(s).map((l) => l.kind), [ContactKind.website]);
    });
  });

  test('checkNewPassword', () {
    expect(checkNewPassword('short'), PasswordProblem.tooShort);
    expect(checkNewPassword('12345678'), PasswordProblem.numeric);
    expect(checkNewPassword('Glowderma-2026'), isNull);
  });

  test('isValidName', () {
    expect(isValidName(' A '), isFalse);
    expect(isValidName('Al'), isTrue);
    expect(isValidName('x' * 151), isFalse);
  });

  group('splitFieldErrors', () {
    test('field errors go inline, nothing left for a snack', () {
      const e = ApiException(
        status: 400,
        code: 'validation_error',
        message: 'Maydonlarni tekshiring.',
        fieldErrors: {'password': 'Parol noto‘g‘ri.'},
      );
      final (fields, general) = splitFieldErrors(e, {'password'});
      expect(fields, {'password': 'Parol noto‘g‘ri.'});
      expect(general, isNull);
    });

    test('a conflict without fields is shown as is', () {
      const e = ApiException(
        status: 409,
        code: 'payment_in_progress',
        message: 'To‘lov davom etmoqda.',
      );
      final (fields, general) = splitFieldErrors(e, {'password'});
      expect(fields, isEmpty);
      expect(general, same(e));
    });

    test('unknown fields keep the general error', () {
      const e = ApiException(
        status: 400,
        code: 'validation_error',
        message: 'x',
        fieldErrors: {'password': 'a', 'other': 'b'},
      );
      final (fields, general) = splitFieldErrors(e, {'password'});
      expect(fields.keys, ['password']);
      expect(general, same(e));
    });
  });

  group('sessions', () {
    CustomerSession s(String id, {bool current = false}) =>
        CustomerSession.fromJson({
          'id': id,
          'device': 'Chrome (Windows)',
          'platform': 'web',
          'location': '—',
          'created_at': '2026-10-27T10:12:00+05:00',
          'updated_at': '2026-10-27T18:40:00+05:00',
          'current': current,
        });

    test('parses the contract shape', () {
      final x = s('a', current: true);
      expect(x.device, 'Chrome (Windows)');
      expect(x.platform, 'web');
      expect(x.hasLocation, isFalse);
      expect(x.current, isTrue);
      expect(x.updatedAt, DateTime.utc(2026, 10, 27, 13, 40));
    });

    test('current first, duplicates dropped, server order kept', () {
      final ordered = orderSessions([
        s('a'),
        s('b', current: true),
        s('c'),
        s('a'),
      ]);
      expect(ordered.map((e) => e.id), ['b', 'a', 'c']);
    });
  });
}
