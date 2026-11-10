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
}
