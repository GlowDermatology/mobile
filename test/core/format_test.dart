import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/format/dates.dart';
import 'package:glow_derma/core/format/money.dart';
import 'package:glow_derma/core/format/phone.dart';
import 'package:glow_derma/core/i18n/tr.dart';

void main() {
  test('money uses non-breaking spaces and the Uzbek ‘', () {
    expect(formatMoney(784400), '784 400 so‘m');
    expect(formatMoney(185000, language: AppLanguage.ru), '185 000 сум');
    expect(formatMoney(1128000, language: AppLanguage.en), '1,128,000 UZS');
    expect(formatSigned(-48600), '−48 600');
    expect(formatSigned(5680), '+5 680');
    expect(cashbackFor(185000, '1.00'), 1850);
    expect(cashbackFor(185000, null), 0);
  });

  test('phones', () {
    expect(maskNational('901234567'), '90 123 45 67');
    expect(maskNational('+998 90 123'), '90 123');
    expect(toE164('90 123 45 67'), '+998901234567');
    expect(toE164('90 123'), isNull);
    expect(formatPhone('+998901234567'), '+998 90 123 45 67');
  });

  test('dates are shown in Tashkent time', () {
    final t = DateTime.parse('2026-10-23T14:02:00+05:00');
    expect(formatTime(t), '14:02');
    expect(formatDayMonth(t, AppLanguage.uz), '23-oktabr');
    expect(formatDayMonth(t, AppLanguage.ru), '23 октября');
    expect(formatDateTime(t, AppLanguage.uz), '23-oktabr, 14:02');
    // 2026-10-26 is a Monday.
    expect(
      formatSlot(DateTime.parse('2026-10-26T09:00:00+05:00'), AppLanguage.uz),
      'Du, 26-oktabr · 09:00',
    );
    expect(isoDate(DateTime.parse('2026-10-26T23:30:00+05:00')), '2026-10-26');
    expect(isoDate(DateTime.parse('2026-10-26T19:30:00Z')), '2026-10-27');
    expect(formatCountdown(const Duration(minutes: 14, seconds: 37)), '14:37');
    expect(formatCountdown(const Duration(seconds: -5)), '00:00');
  });
}
