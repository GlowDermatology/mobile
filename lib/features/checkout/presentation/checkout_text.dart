import '../../../core/i18n/tr.dart';

/// Strings of checkout and the address form (website copy where the PDF has
/// no screen).
abstract final class CheckoutText {
  static const title = Tr('Rasmiylashtirish', 'Оформление заказа', 'Checkout');
  static const items = Tr('{n} ta mahsulot', '{n} товар(ов)', '{n} item(s)');

  static const fulfilmentTitle = Tr(
    'Olish usuli',
    'Способ получения',
    'How you get it',
  );
  static const delivery = Tr(
    'BTS orqali yetkazib berish',
    'Доставка через BTS',
    'Delivery by BTS',
  );
  static const deliveryHint = Tr(
    'BTS kuryeri manzilingizga olib boradi',
    'Курьер BTS привезёт по адресу',
    'A BTS courier brings it to your address',
  );
  static const pickup = Tr(
    'Do‘kondan olib ketish',
    'Самовывоз из магазина',
    'Pick up in store',
  );
  static const free = Tr('Bepul', 'Бесплатно', 'Free');

  static const addressTitle = Tr(
    'Yetkazib berish manzili',
    'Адрес доставки',
    'Delivery address',
  );
  static const addAddress = Tr(
    'Yangi manzil qo‘shish',
    'Добавить адрес',
    'Add an address',
  );
  static const noAddress = Tr(
    'Saqlangan manzil yo‘q. Yetkazib berish uchun manzil qo‘shing.',
    'Нет сохранённых адресов. Добавьте адрес для доставки.',
    'No saved addresses yet. Add one for delivery.',
  );
  static const addressNoRegion = Tr(
    'Viloyat va tuman ko‘rsatilmagan — manzilni tahrirlang',
    'Не указаны область и район — отредактируйте адрес',
    'Region and district are missing — edit the address',
  );
  static const editAddresses = Tr(
    'Manzillarni tahrirlash',
    'Изменить адреса',
    'Edit addresses',
  );
  static const defaultAddress = Tr('Asosiy', 'Основной', 'Default');
  static const addressFallback = Tr('Manzil', 'Адрес', 'Address');
  static const chooseAddress = Tr(
    'Yetkazib berish manzilini tanlang.',
    'Выберите адрес доставки.',
    'Choose a delivery address.',
  );

  static const cashbackTitle = Tr(
    'Cashback ishlatish',
    'Использовать кешбэк',
    'Use cashback',
  );
  static const cashbackAvailable = Tr(
    'Mavjud: {amount}',
    'Доступно: {amount}',
    'Available: {amount}',
  );
  static const cashbackMax = Tr(
    'Bu buyurtmada ko‘pi bilan {amount}',
    'В этом заказе не больше {amount}',
    'Up to {amount} on this order',
  );
  static const cashbackNone = Tr(
    'Hozircha ishlatish mumkin bo‘lgan cashback yo‘q.',
    'Пока нет кешбэка, который можно использовать.',
    'No cashback to use yet.',
  );

  static const noteLabel = Tr(
    'Izoh (ixtiyoriy)',
    'Комментарий (необязательно)',
    'Note (optional)',
  );
  static const notePlaceholder = Tr(
    'Masalan, soat 18:00 dan keyin qo‘ng‘iroq qiling',
    'Например, позвоните после 18:00',
    'For example, call after 6 pm',
  );

  static const summaryTitle = Tr('Buyurtma', 'Заказ', 'Order');
  static const subtotal = Tr('Mahsulotlar', 'Товары', 'Items');
  static const deliveryFee = Tr('Yetkazib berish', 'Доставка', 'Delivery');
  static const cashbackDiscount = Tr(
    'Cashback chegirmasi',
    'Скидка кешбэком',
    'Cashback discount',
  );
  static const total = Tr('Jami', 'Итого', 'Total');
  static const calculating = Tr('Hisoblanmoqda…', 'Считаем…', 'Calculating…');
  static const reservation = Tr(
    'Buyurtma {minutes} daqiqa band qilinadi — shu vaqt ichida to‘lang.',
    'Товары резервируются на {minutes} мин — оплатите заказ за это время.',
    'Your items are held for {minutes} minutes — please pay within that time.',
  );
  static const placeOrder = Tr(
    'Buyurtma berish',
    'Оформить заказ',
    'Place order',
  );

  static const outOfStockTitle = Tr(
    'Ba’zi mahsulotlar yetarli emas',
    'Некоторых товаров не хватает',
    'Some items are short',
  );
  static const outOfStockLine = Tr(
    'So‘ralgan: {requested} ta · mavjud: {available} ta',
    'Запрошено: {requested} · в наличии: {available}',
    'Requested: {requested} · available: {available}',
  );
  static const backToCart = Tr(
    'Savatga qaytish',
    'Вернуться в корзину',
    'Back to your cart',
  );
  static const openOrder = Tr(
    'To‘lanmagan buyurtmani ochish',
    'Открыть неоплаченный заказ',
    'Open the unpaid order',
  );
  static const emptyCart = Tr(
    'Savat bo‘sh.',
    'Корзина пуста.',
    'Your cart is empty.',
  );

  // Address form
  static const addressFormTitle = Tr(
    'Yangi manzil',
    'Новый адрес',
    'New address',
  );
  static const labelField = Tr(
    'Nomi (ixtiyoriy)',
    'Название (необязательно)',
    'Name (optional)',
  );
  static const labelHome = Tr('Uy', 'Дом', 'Home');
  static const labelWork = Tr('Ish', 'Работа', 'Work');
  static const region = Tr('Viloyat', 'Область', 'Region');
  static const city = Tr('Tuman / shahar', 'Район / город', 'District / city');
  static const chooseRegionFirst = Tr(
    'Avval viloyatni tanlang',
    'Сначала выберите область',
    'Choose the region first',
  );
  static const addressText = Tr(
    'To‘liq manzil',
    'Полный адрес',
    'Full address',
  );
  static const addressTextHint = Tr(
    'Ko‘cha, uy, xonadon',
    'Улица, дом, квартира',
    'Street, building, apartment',
  );
  static const comment = Tr(
    'Kuryer uchun izoh (ixtiyoriy)',
    'Комментарий для курьера (необязательно)',
    'Note for the courier (optional)',
  );
  static const commentHint = Tr(
    'Mo‘ljal, podyezd, qavat',
    'Ориентир, подъезд, этаж',
    'Landmark, entrance, floor',
  );
  static const required = Tr(
    'Majburiy maydon',
    'Обязательное поле',
    'Required',
  );
  static const textLength = Tr(
    '5 tadan 300 tagacha belgi kiriting',
    'Введите от 5 до 300 символов',
    'Enter 5 to 300 characters',
  );
  static const noRegions = Tr(
    'Yetkazib berish hozircha mavjud emas. Olib ketishni tanlang.',
    'Доставка пока недоступна. Выберите самовывоз.',
    'Delivery is not available yet. Choose pick-up.',
  );
}
