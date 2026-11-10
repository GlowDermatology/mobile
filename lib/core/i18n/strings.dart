import 'tr.dart';

/// Strings shared by several screens. Feature screens keep their own
/// `*_text.dart` next to them.
abstract final class Strings {
  static const back = Tr('Orqaga', 'Назад', 'Back');
  static const retry = Tr('Qayta urinish', 'Повторить', 'Try again');
  static const errorCode = Tr('Xato kodi', 'Код ошибки', 'Error code');
  static const networkError = Tr(
    'Internetga ulanib bo‘lmadi. Aloqani tekshirib, qayta urinib ko‘ring.',
    'Нет соединения с интернетом. Проверьте связь и повторите.',
    'No internet connection. Check your connection and try again.',
  );
  static const unexpectedError = Tr(
    'Kutilmagan xato. Qayta urinib ko‘ring.',
    'Непредвиденная ошибка. Повторите попытку.',
    'Unexpected error. Please try again.',
  );
  static const cancel = Tr('Bekor qilish', 'Отмена', 'Cancel');
  static const ok = Tr('Tushunarli', 'Понятно', 'OK');
  static const save = Tr('Saqlash', 'Сохранить', 'Save');
  static const close = Tr('Yopish', 'Закрыть', 'Close');
  static const pieces = Tr('{n} ta', '{n} шт.', '{n} pcs');
  static const products = Tr('{n} ta mahsulot', '{n} товар(ов)', '{n} item(s)');
  static const comingSoon = Tr('Tez orada', 'Скоро', 'Coming soon');

  // Bottom navigation
  static const tabCatalog = Tr('Katalog', 'Каталог', 'Catalog');
  static const tabQr = Tr('QR', 'QR', 'QR');
  static const tabCart = Tr('Savat', 'Корзина', 'Cart');
  static const tabAi = Tr('AI', 'AI', 'AI');
  static const tabSettings = Tr('Sozlamalar', 'Настройки', 'Settings');
}
