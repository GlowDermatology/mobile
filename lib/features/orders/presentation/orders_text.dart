import '../../../core/i18n/tr.dart';

/// Copy of the payment, success, orders and order screens. Uzbek strings
/// visible in the design PDF (pages 6–8) are transcribed from it; the rest
/// follows the website copy (`frontend/src/features/shop/copy/orders.ts`).
abstract final class OrdersText {
  // Payment (PDF p.6)
  static const payTitle = Tr('To‘lov', 'Оплата', 'Payment');
  static const reservedTitle = Tr(
    'Mahsulotlar siz uchun band',
    'Товары зарезервированы для вас',
    'Your items are on hold',
  );
  static const reservedBody = Tr(
    'Vaqt tugasa, buyurtma bekor qilinadi.',
    'Когда время истечёт, заказ будет отменён.',
    'When the time runs out, the order is cancelled.',
  );
  static const checkingBody = Tr(
    'Bu bir necha soniya oladi. Sahifani yopmang.',
    'Это займёт несколько секунд. Не закрывайте страницу.',
    'This takes a few seconds. Please keep this page open.',
  );
  static const checkingFallback = Tr(
    'To‘lov tekshirilmoqda',
    'Проверяем оплату',
    'Checking your payment',
  );
  static const orderNumber = Tr('Buyurtma №{id}', 'Заказ №{id}', 'Order #{id}');
  static const shortNumber = Tr('№{id}', '№{id}', '#{id}');
  static const itemCount = Tr(
    '{n} ta mahsulot',
    '{n} товар(ов)',
    '{n} item(s)',
  );
  static const toPay = Tr('To‘lanadi', 'К оплате', 'To pay');
  static const paid = Tr('To‘landi', 'Оплачено', 'Paid');
  static const methodTitle = Tr(
    'To‘lov usuli',
    'Способ оплаты',
    'Payment method',
  );
  static const clickHint = Tr(
    'Click ilovasi yoki to‘lov sahifasi',
    'Приложение Click или страница оплаты',
    'Click app or payment page',
  );
  static const paymeHint = Tr(
    'Payme ilovasi yoki to‘lov sahifasi',
    'Приложение Payme или страница оплаты',
    'Payme app or payment page',
  );
  static const providerHint = Tr(
    '{p} ilovasi yoki to‘lov sahifasi',
    'Приложение {p} или страница оплаты',
    '{p} app or payment page',
  );
  static const cash = Tr('Naqd pul', 'Наличные', 'Cash');
  static const safetyNote = Tr(
    'To‘lov ilovasi ochiladi; u o‘rnatilmagan bo‘lsa, to‘lov sahifasi ochiladi. Karta ma’lumotlari Glow Derma ilovasida kiritilmaydi.',
    'Откроется платёжное приложение; если его нет, откроется страница оплаты. Данные карты в приложении Glow Derma не вводятся.',
    'The payment app opens; if it is not installed, the payment page opens. Card details are never entered in the Glow Derma app.',
  );
  static const payWith = Tr(
    '{p} orqali to‘lash',
    'Оплатить через {p}',
    'Pay with {p}',
  );
  static const pay = Tr('To‘lash', 'Оплатить', 'Pay');
  static const cannotOpen = Tr(
    'To‘lov sahifasini ochib bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось открыть страницу оплаты. Повторите попытку.',
    'Could not open the payment page. Please try again.',
  );
  static const noProviders = Tr(
    'Onlayn to‘lov hozircha mavjud emas.',
    'Онлайн-оплата пока недоступна.',
    'Online payment is not available yet.',
  );
  static const expiredTitle = Tr(
    'To‘lov muddati tugadi',
    'Время оплаты истекло',
    'The time to pay has run out',
  );
  static const expiredBody = Tr(
    'Mahsulotlarni savatga qaytarib, qaytadan rasmiylashtiring.',
    'Верните товары в корзину и оформите заказ заново.',
    'Put the items back in your bag and check out again.',
  );
  static const reorderShort = Tr(
    'Qayta buyurtma',
    'Повторить заказ',
    'Order again',
  );
  static const ordersLink = Tr('Buyurtmalar', 'Заказы', 'Orders');
  static const simulate = Tr(
    'Simulate payment (dev)',
    'Simulate payment (dev)',
    'Simulate payment (dev)',
  );
  static const cancelledTitle = Tr(
    'Buyurtma bekor qilindi',
    'Заказ отменён',
    'Order cancelled',
  );
  static const openOrder = Tr(
    'Buyurtmani ochish',
    'Открыть заказ',
    'Open the order',
  );

  // Success (PDF p.7)
  static const successTitle = Tr(
    'Buyurtmangiz qabul qilindi',
    'Ваш заказ принят',
    'Your order is confirmed',
  );
  static const successBody = Tr(
    'To‘lov tasdiqlandi. Holat o‘zgarganda bildirishnoma yuboramiz.',
    'Оплата подтверждена. Мы пришлём уведомление, когда статус изменится.',
    'Payment confirmed. We will notify you when the status changes.',
  );
  static const paidVia = Tr('To‘landi · {p}', 'Оплачено · {p}', 'Paid · {p}');
  static const cashbackUsed = Tr(
    'Cashback ishlatildi',
    'Использован кешбэк',
    'Cashback used',
  );
  static const fulfilment = Tr(
    'Olish usuli',
    'Способ получения',
    'How you get it',
  );
  static const cashbackEarnedBox = Tr(
    'cashback hisobingizga tushdi',
    'кешбэка зачислено на ваш счёт',
    'cashback added to your balance',
  );
  static const track = Tr(
    'Buyurtmani kuzatish',
    'Отследить заказ',
    'Track the order',
  );
  static const toCatalog = Tr(
    'Katalogga qaytish',
    'Вернуться в каталог',
    'Back to the catalog',
  );

  // Orders list
  static const ordersTitle = Tr('Buyurtmalar', 'Заказы', 'Orders');
  static const scopeAll = Tr('Hammasi', 'Все', 'All');
  static const scopeActive = Tr('Faol', 'Активные', 'Active');
  static const scopeCompleted = Tr('Yetkazilgan', 'Доставленные', 'Delivered');
  static const scopeCancelled = Tr('Bekor qilingan', 'Отменённые', 'Cancelled');
  static const emptyTitle = Tr(
    'Hozircha buyurtma yo‘q',
    'Заказов пока нет',
    'No orders yet',
  );
  static const emptyBody = Tr(
    'Birinchi buyurtmangiz shu yerda paydo bo‘ladi.',
    'Здесь появится ваш первый заказ.',
    'Your first order will appear here.',
  );
  static const emptyScope = Tr(
    'Bu bo‘limda buyurtma yo‘q.',
    'В этом разделе заказов нет.',
    'No orders here.',
  );
  static const payBy = Tr(
    '{time} gacha to‘lang',
    'Оплатите до {time}',
    'Pay by {time}',
  );
  static const loadMoreFailed = Tr(
    'Yuklab bo‘lmadi',
    'Не удалось загрузить',
    'Could not load',
  );

  // Order detail (PDF p.8)
  static const itemsTitle = Tr('Mahsulotlar', 'Товары', 'Items');
  static const quantityPrice = Tr(
    '{q} × {price}',
    '{q} × {price}',
    '{q} × {price}',
  );
  static const promo = Tr('Aksiya', 'Акция', 'Offer');
  static const subtotal = Tr('Mahsulotlar', 'Товары', 'Items');
  static const deliveryFee = Tr('Yetkazib berish', 'Доставка', 'Delivery');
  static const free = Tr('Bepul', 'Бесплатно', 'Free');
  static const cashbackDiscount = Tr(
    'Cashback chegirmasi',
    'Скидка кешбэком',
    'Cashback discount',
  );
  static const cashbackEarned = Tr(
    'Cashback hisoblandi',
    'Начислен кешбэк',
    'Cashback earned',
  );
  static const cashbackReversed = Tr(
    'Cashback bekor qilindi',
    'Кешбэк отменён',
    'Cashback reversed',
  );
  static const awaitBts = Tr(
    'BTS tasdiqlagach yangilanadi',
    'Обновится после подтверждения BTS',
    'Updates once BTS confirms',
  );
  static const address = Tr('Manzil', 'Адрес', 'Address');
  static const pickupAddress = Tr(
    'Olib ketish manzili',
    'Адрес самовывоза',
    'Pick-up address',
  );
  static const note = Tr('Izoh', 'Комментарий', 'Note');
  static const refund = Tr('Pul qaytarish', 'Возврат средств', 'Refund');
  static const history = Tr('Tarix', 'История', 'History');
  static const payByLine = Tr(
    'To‘lov muddati: {time}',
    'Оплатить до {time}',
    'Pay by {time}',
  );
  static const reorder = Tr(
    'Qayta buyurtma berish',
    'Повторить заказ',
    'Order again',
  );
  static const reordered = Tr(
    'Mahsulotlar savatga qaytarildi',
    'Товары возвращены в корзину',
    'The items are back in your bag',
  );
  static const notFoundTitle = Tr(
    'Buyurtma topilmadi',
    'Заказ не найден',
    'Order not found',
  );
  static const notFoundBody = Tr(
    'Bu buyurtma sizning hisobingizda yo‘q yoki havola noto‘g‘ri.',
    'Этого заказа нет в вашем аккаунте или ссылка неверна.',
    'This order is not in your account, or the link is wrong.',
  );

  // Cancel
  static const cancel = Tr(
    'Buyurtmani bekor qilish',
    'Отменить заказ',
    'Cancel order',
  );
  static const cancelTitle = Tr(
    'Buyurtmani bekor qilasizmi?',
    'Отменить заказ?',
    'Cancel this order?',
  );
  static const cancelBody = Tr(
    'Band qilingan mahsulotlar bo‘shatiladi. Ularni keyinroq qayta buyurtma qilishingiz mumkin.',
    'Резерв товаров будет снят. Вы сможете заказать их снова позже.',
    'The reserved items will be released. You can order them again later.',
  );
  static const cancelConfirm = Tr(
    'Ha, bekor qilish',
    'Да, отменить',
    'Yes, cancel',
  );
  static const cancelKeep = Tr(
    'Yo‘q, qoldirish',
    'Нет, оставить',
    'No, keep it',
  );
  static const cancelled = Tr(
    'Buyurtma bekor qilindi',
    'Заказ отменён',
    'Order cancelled',
  );
}
