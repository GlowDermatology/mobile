import '../../../core/i18n/tr.dart';

/// Inbox strings (PDF page 10, then the website inbox copy).
abstract final class NotificationsText {
  static const title = Tr('Bildirishnomalar', 'Уведомления', 'Notifications');
  static const readAll = Tr('Hammasini o‘qish', 'Прочитать все', 'Read all');
  static const empty = Tr(
    'Hozircha xabar yo‘q',
    'Сообщений пока нет',
    'No messages yet',
  );
  static const emptyBody = Tr(
    'Buyurtma va qabullar holati, aksiyalar va hisob xavfsizligi haqida.',
    'О статусе заказов и записей, акциях и безопасности аккаунта.',
    'Order and appointment updates, offers and account security.',
  );
  static const unread = Tr('O‘qilmagan', 'Непрочитанное', 'Unread');
  static const loadMoreFailed = Tr(
    'Yuklab bo‘lmadi. Qayta urinish',
    'Не удалось загрузить. Повторить',
    'Could not load. Try again',
  );
}
