import '../../../core/i18n/tr.dart';

/// Strings of the cart tab (PDF page 5; the rest from the website copy).
abstract final class CartText {
  static const title = Tr('Savat', 'Корзина', 'Cart');
  static const selectAll = Tr('Hammasini tanlash', 'Выбрать все', 'Select all');
  static const removeSelected = Tr(
    'O‘chirish ({n})',
    'Удалить ({n})',
    'Remove ({n})',
  );
  static const removeSelectedConfirm = Tr(
    'Tanlangan {n} ta mahsulot savatdan olib tashlansinmi?',
    'Удалить выбранные товары ({n}) из корзины?',
    'Remove the {n} selected item(s) from your cart?',
  );
  static const removeOneConfirm = Tr(
    '{name} savatdan olib tashlansinmi?',
    'Удалить «{name}» из корзины?',
    'Remove {name} from your cart?',
  );
  static const remove = Tr('Olib tashlash', 'Удалить', 'Remove');
  static const removed = Tr(
    '{name} savatdan olib tashlandi',
    '«{name}» удалён из корзины',
    '{name} was removed from your cart',
  );
  static const pay = Tr('To‘lash', 'Оплатить', 'Pay');

  // Line states
  static const outOfStock = Tr(
    'Tugagan — buyurtmaga kirmaydi',
    'Закончился — не войдёт в заказ',
    'Sold out — not included in the order',
  );
  static const unavailable = Tr(
    'Hozir sotuvda yo‘q',
    'Сейчас не продаётся',
    'Not on sale right now',
  );
  static const insufficient = Tr(
    'Faqat {available} ta qolgan — miqdorni kamaytiring',
    'Осталось только {available} шт. — уменьшите количество',
    'Only {available} left — lower the quantity',
  );
  static const fixQuantity = Tr(
    '{n} taga kamaytirish',
    'Уменьшить до {n}',
    'Set to {n}',
  );
  static const priceChanged = Tr(
    'Narx o‘zgardi (avval {previous})',
    'Цена изменилась (было {previous})',
    'Price changed (was {previous})',
  );
  static const promo = Tr('AKSIYA', 'АКЦИЯ', 'OFFER');
  static const noCashback = Tr(
    'Cashback hisoblanmaydi',
    'Кешбэк не начисляется',
    'No cashback',
  );
  static const maxReached = Tr(
    'Ko‘proq kerak bo‘lsa, sotuvchi bilan bog‘laning',
    'Если нужно больше, свяжитесь с продавцом',
    'Need more? Contact the store',
  );

  // Pay bar
  static const fixProblems = Tr(
    'Buyurtma berish uchun belgilangan mahsulotlarni tuzating.',
    'Чтобы оформить заказ, исправьте отмеченные товары.',
    'Fix the marked items to place the order.',
  );
  static const salesOff = Tr(
    'Onlayn buyurtma vaqtincha mavjud emas. Mahsulotlarni do‘konimizdan xarid qilishingiz mumkin.',
    'Онлайн-заказ временно недоступен. Товары можно купить в нашем магазине.',
    'Online ordering is temporarily unavailable. You can buy these products in our store.',
  );
  static const noPayments = Tr(
    'Onlayn to‘lov hozircha mavjud emas.',
    'Онлайн-оплата пока недоступна.',
    'Online payment is not available yet.',
  );

  // Empty / guest
  static const emptyTitle = Tr(
    'Savat hozircha bo‘sh',
    'Корзина пока пуста',
    'Your cart is empty',
  );
  static const emptyBody = Tr(
    'Dermatologlar tanlagan parvarish vositalarini katalogdan toping.',
    'Найдите в каталоге средства, которые выбирают дерматологи.',
    'Find the care dermatologists choose in our catalog.',
  );
  static const toCatalog = Tr(
    'Katalogga o‘tish',
    'Перейти в каталог',
    'Browse the catalog',
  );
  static const signedOutTitle = Tr(
    'Savatni ko‘rish uchun hisobga kiring',
    'Войдите, чтобы увидеть корзину',
    'Sign in to see your cart',
  );
  static const signedOutBody = Tr(
    'Savat hisobingizda saqlanadi — telefon va saytda bir xil ko‘rinadi.',
    'Корзина хранится в аккаунте — одна и та же на телефоне и на сайте.',
    'Your cart is kept in your account — the same on the app and the website.',
  );
  static const signIn = Tr('Kirish', 'Войти', 'Sign in');

  // Unpaid order (website `ordersCopy.recovery`)
  static const recoveryTitle = Tr(
    'To‘lov kutilmoqda',
    'Ожидает оплаты',
    'Awaiting payment',
  );
  static const recoveryBody = Tr(
    'Mahsulotlaringiz saqlangan. To‘lov hali tasdiqlanmadi. To‘lovni davom ettiring yoki mahsulotlarni tahrirlang.',
    'Ваши товары сохранены. Оплата ещё не подтверждена. Продолжите оплату или измените товары.',
    'Your items are saved. Payment has not been confirmed. Continue payment or edit your items.',
  );
  static const recoveryConfirmingTitle = Tr(
    'To‘lov tasdiqlanishi kutilmoqda',
    'Ожидаем подтверждение оплаты',
    'Waiting for payment confirmation',
  );
  static const recoveryConfirmingBody = Tr(
    'To‘lov tizimi javobini kutyapmiz. Natija aniqlanmaguncha qayta to‘lamang. Holat avtomatik yangilanadi.',
    'Ждём ответ платёжной системы. Не платите повторно до получения результата. Статус обновляется автоматически.',
    'We’re waiting for the payment provider. Please don’t pay again until the result is known. The status updates automatically.',
  );
  static const recoveryExpiredTitle = Tr(
    'Band qilish muddati tugadi',
    'Срок бронирования истёк',
    'Your reservation expired',
  );
  static const recoveryExpiredBody = Tr(
    'Mahsulotlaringiz saqlangan. Savatga qaytarganingizda narx va mavjudlik yangilanadi.',
    'Ваши товары сохранены. При возврате в корзину цены и наличие обновятся.',
    'Your items are saved. Prices and availability will be checked when you return them to the cart.',
  );
  static const recoveryCancelledTitle = Tr(
    'To‘lanmagan buyurtma bekor qilingan',
    'Неоплаченный заказ отменён',
    'Your unpaid order was cancelled',
  );
  static const recoveryCancelledBody = Tr(
    'Mahsulotlarni savatga qaytarib, qaytadan rasmiylashtirishingiz mumkin.',
    'Вы можете вернуть товары в корзину и оформить заказ заново.',
    'You can return the items to your cart and check out again.',
  );
  static const recoveryContinuePayment = Tr(
    'To‘lovni davom ettirish',
    'Продолжить оплату',
    'Continue payment',
  );
  static const recoveryEdit = Tr(
    'Mahsulotlarni tahrirlash',
    'Изменить товары',
    'Edit items',
  );
  static const recoveryEditHint = Tr(
    'Tahrirlash to‘lanmagan buyurtmani bekor qiladi va mahsulotlarni savatga qaytaradi. Keyin qo‘shilgan mahsulotlar ham saqlanadi.',
    'Изменение отменит неоплаченный заказ и вернёт товары в корзину. Добавленные позже товары сохранятся.',
    'Editing cancels the unpaid order and returns its items to your cart. Items added afterwards are kept too.',
  );
  static const recoveryRestore = Tr(
    'Mahsulotlarni savatga qaytarish',
    'Вернуть товары в корзину',
    'Return items to cart',
  );
  static const recoveryRestored = Tr(
    'Mahsulotlar savatga qaytarildi. Narx va miqdorlarni tekshiring.',
    'Товары возвращены в корзину. Проверьте цены и количество.',
    'Items returned to your cart. Check the prices and quantities.',
  );
  static const recoveryNewItems = Tr(
    'Keyin qo‘shilgan mahsulotlar',
    'Товары, добавленные позже',
    'Items added afterwards',
  );
  static const recoveryResolveFirst = Tr(
    'Yangi buyurtma berish uchun avval yuqoridagi to‘lovni davom ettiring yoki mahsulotlarni tahrirlang.',
    'Перед новым заказом продолжите оплату выше или измените товары.',
    'Before placing a new order, continue payment above or edit your items.',
  );
  static const recoveryRefresh = Tr(
    'Holatni yangilash',
    'Обновить статус',
    'Refresh status',
  );
  static const recoveryDetails = Tr(
    'Buyurtma tafsilotlari',
    'Подробнее о заказе',
    'Order details',
  );
  static const recoveryDeliveryFee = Tr(
    'Yetkazib berish',
    'Доставка',
    'Delivery',
  );
  static const recoveryCashback = Tr('Cashback', 'Кешбэк', 'Cashback');
  static const recoveryTotal = Tr('Jami', 'Итого', 'Total');
}
