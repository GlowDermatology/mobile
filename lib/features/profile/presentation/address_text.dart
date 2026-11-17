import '../../../core/i18n/tr.dart';

/// Strings of the address map pin and the address form (create · edit).
/// Copied from the website (`account.ts`, `addresses.map`).
abstract final class AddressMapText {
  static const title = Tr(
    'Xaritadagi nuqta',
    'Точка на карте',
    'Point on the map',
  );
  static const hint = Tr(
    'Xaritani bosing yoki belgini suring: kuryer aynan shu nuqtaga keladi.',
    'Нажмите на карту или перетащите метку: курьер приедет именно в эту точку.',
    'Tap the map or drag the marker: the courier comes to exactly this point.',
  );
  static const hintNoRegions = Tr(
    'Kuryer yetkazib berishi uchun xaritada nuqta belgilang.',
    'Чтобы курьер мог доставить заказ, отметьте точку на карте.',
    'Set the point on the map so a courier can deliver here.',
  );
  static const region = Tr('Manzil xaritasi', 'Карта адреса', 'Address map');
  static const loading = Tr(
    'Xarita yuklanmoqda…',
    'Карта загружается…',
    'Loading the map…',
  );
  static const unavailable = Tr(
    'Xaritani yuklab bo‘lmadi. Internetni tekshirib, oynani qayta oching.',
    'Не удалось загрузить карту. Проверьте интернет и откройте окно снова.',
    'The map could not be loaded. Check your connection and open this window again.',
  );
  static const locate = Tr(
    'Joylashuvimni aniqlash',
    'Определить моё местоположение',
    'Find my location',
  );
  static const locating = Tr(
    'Joylashuv aniqlanmoqda…',
    'Определяем местоположение…',
    'Finding your location…',
  );
  static const locateDenied = Tr(
    'Joylashuvga ruxsat berilmadi. Nuqtani xaritada o‘zingiz belgilang yoki brauzer sozlamalarida ruxsat bering.',
    'Доступ к местоположению не разрешён. Отметьте точку на карте сами или разрешите доступ в настройках браузера.',
    'Location access was not allowed. Set the point on the map yourself or allow access in your browser settings.',
  );
  static const locateFailed = Tr(
    'Joylashuvni aniqlab bo‘lmadi. Nuqtani xaritada o‘zingiz belgilang.',
    'Не удалось определить местоположение. Отметьте точку на карте сами.',
    'Your location could not be found. Set the point on the map yourself.',
  );
  static const center = Tr(
    'Xarita markaziga qo‘yish',
    'Поставить в центр карты',
    'Place at the map centre',
  );
  static const clear = Tr(
    'Pinni olib tashlash',
    'Убрать метку',
    'Remove the pin',
  );
  static const chosen = Tr(
    'Tanlangan nuqta',
    'Выбранная точка',
    'Chosen point',
  );
  static const none = Tr(
    'Pin qo‘yilmagan',
    'Метка не поставлена',
    'No pin set',
  );
  static const marker = Tr(
    'Yetkazib berish nuqtasi',
    'Точка доставки',
    'Delivery point',
  );
  static const zoomIn = Tr('Yaqinlashtirish', 'Приблизить', 'Zoom in');
  static const zoomOut = Tr('Uzoqlashtirish', 'Отдалить', 'Zoom out');

  /// `latitude` / `longitude` field errors (`latlng_pair`).
  static const pinInvalid = Tr(
    'Xaritadagi nuqtani qayta belgilang.',
    'Отметьте точку на карте ещё раз.',
    'Set the point on the map again.',
  );
}

abstract final class AddressFormText {
  static const editTitle = Tr(
    'Manzilni tahrirlash',
    'Изменить адрес',
    'Edit address',
  );
  static const edit = Tr('Tahrirlash', 'Изменить', 'Edit');
  static const notFound = Tr(
    'Manzil topilmadi',
    'Адрес не найден',
    'Address not found',
  );
}
