import '../../../core/i18n/tr.dart';

/// QR + cashback strings (PDF page 9, then the website loyalty copy).
abstract final class LoyaltyText {
  static const title = Tr('Mening QR kodim', 'Мой QR-код', 'My QR code');
  static const brightness = Tr(
    'Yorqinlik oshirildi',
    'Яркость повышена',
    'Brightness raised',
  );
  static const showAtCheckout = Tr(
    'KASSADA KO‘RSATING',
    'ПОКАЖИТЕ НА КАССЕ',
    'SHOW AT THE CHECKOUT',
  );
  static const refreshesIn = Tr(
    'Kod {n} soniyadan so‘ng yangilanadi',
    'Код обновится через {n} с',
    'The code refreshes in {n} s',
  );
  static const refresh = Tr('Yangilash', 'Обновить', 'Refresh');
  static const loading = Tr(
    'Kod yuklanmoqda…',
    'Загружаем код…',
    'Loading the code…',
  );
  static const hidden = Tr(
    'Kod vaqtincha yashirildi',
    'Код временно скрыт',
    'The code is hidden for now',
  );
  static const throttled = Tr(
    'Kod juda tez-tez so‘raldi. Yangi kod birozdan so‘ng chiqadi.',
    'Код запрашивали слишком часто. Новый код появится чуть позже.',
    'The code was requested too often. A new one will appear shortly.',
  );
  static const failed = Tr(
    'Kodni yuklab bo‘lmadi.',
    'Не удалось загрузить код.',
    'Could not load the code.',
  );
  static const qrAlt = Tr(
    'Shaxsiy QR kod',
    'Персональный QR-код',
    'Personal QR code',
  );
  static const hint = Tr(
    'Kod faqat bir marta ishlaydi. Skanerlashdan keyin xato chiqsa, «Yangilash»ni bosing.',
    'Код действует один раз. Если код не сканируется, нажмите «Обновить».',
    'The code works once. If the scan fails, tap “Refresh”.',
  );
  static const phoneTitle = Tr(
    'QR uchun telefon raqami kerak',
    'Для QR нужен номер телефона',
    'The QR code needs a phone number',
  );
  static const phoneBody = Tr(
    'Kassir xaridni telefon raqamingiz bo‘yicha biriktiradi. Raqamni bir marta tasdiqlang.',
    'Кассир привязывает покупку по вашему номеру. Подтвердите номер один раз.',
    'The cashier links the purchase by your phone number. Confirm it once.',
  );
  static const phoneAction = Tr(
    'Raqamni tasdiqlash',
    'Подтвердить номер',
    'Confirm my number',
  );

  static const balanceTitle = Tr(
    'CASHBACK BALANSI',
    'БАЛАНС КЕШБЭКА',
    'CASHBACK BALANCE',
  );
  static const held = Tr(
    'Band qilingan: {amount}',
    'В резерве: {amount}',
    'On hold: {amount}',
  );
  static const nextTier = Tr(
    '{remaining} xariddan so‘ng — {percent}%',
    'Купите ещё на {remaining} — и кешбэк станет {percent}%',
    'Spend {remaining} more to reach {percent}%',
  );
  static const topTier = Tr(
    'Siz eng yuqori darajadasiz',
    'У вас максимальный уровень',
    'You are at the top level',
  );
  static const negative = Tr(
    'Balans manfiy: qaytarilgan xarid uchun cashback ushlab qolindi.',
    'Баланс отрицательный: кешбэк удержан за возвращённую покупку.',
    'Your balance is negative: cashback was taken back for a returned purchase.',
  );

  static const historyTitle = Tr(
    'Cashback tarixi',
    'История кешбэка',
    'Cashback history',
  );
  static const historyEmpty = Tr(
    'Hozircha cashback harakati yo‘q.',
    'Движений кешбэка пока нет.',
    'No cashback activity yet.',
  );
  static const loadMoreFailed = Tr(
    'Yuklab bo‘lmadi. Qayta urinish',
    'Не удалось загрузить. Повторить',
    'Could not load. Try again',
  );
}
