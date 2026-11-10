import '../../../core/i18n/tr.dart';

/// Strings of the catalog screens: the design (PDF p.3–4) first, then the
/// website copy (`frontend/src/features/shop/content`, `copy/orders.ts`).
abstract final class CatalogText {
  // Home (PDF p.3)
  static const searchHint = Tr(
    'Mahsulot qidirish',
    'Поиск товаров',
    'Search products',
  );
  static const all = Tr('Hammasi', 'Все', 'All');
  static const popular = Tr(
    'Mashhur mahsulotlar',
    'Популярные товары',
    'Popular products',
  );
  static const seeAll = Tr('Barchasi', 'Все', 'See all');
  static const notifications = Tr(
    'Bildirishnomalar',
    'Уведомления',
    'Notifications',
  );
  static const search = Tr('Qidirish', 'Поиск', 'Search');
  static const promoBadge = Tr('AKSIYA', 'АКЦИЯ', 'OFFER');
  static const soldOutPill = Tr('Tugagan', 'Нет в наличии', 'Out of stock');
  static const banners = Tr('Aksiyalar', 'Акции', 'Offers');

  // Product (PDF p.4)
  static const inStock = Tr('Omborda bor', 'В наличии', 'In stock');
  static const outOfStock = Tr('Tugagan', 'Нет в наличии', 'Out of stock');
  static const tabDescription = Tr('Tavsif', 'Описание', 'Description');
  static const tabIngredients = Tr('Tarkibi', 'Состав', 'Ingredients');
  static const tabUsage = Tr('Qo‘llash', 'Применение', 'How to use');
  static const addToCart = Tr('Savatga qo‘shish', 'В корзину', 'Add to cart');
  static const goToCart = Tr(
    'Savatga o‘tish',
    'Перейти в корзину',
    'Go to cart',
  );
  static const cashback = Tr(
    '+{amount} cashback',
    '+{amount} кешбэк',
    '+{amount} cashback',
  );
  static const promoNoCashback = Tr(
    'Aksiya — cashback hisoblanmaydi',
    'Акция — кешбэк не начисляется',
    'Offer — no cashback',
  );
  static const soldOut = Tr(
    'Hozircha mavjud emas',
    'Временно нет в наличии',
    'Currently unavailable',
  );
  static const salesOff = Tr(
    'Onlayn buyurtma vaqtincha mavjud emas. Mahsulotni do‘konimizdan xarid qilishingiz mumkin.',
    'Онлайн-заказ временно недоступен. Товар можно купить в нашем магазине.',
    'Online ordering is temporarily unavailable. You can buy this product in our store.',
  );
  static const imageCounter = Tr('{i} / {n}', '{i} / {n}', '{i} / {n}');
  static const imageLabel = Tr(
    '{n} ta rasmdan {i}-si',
    'Фото {i} из {n}',
    'Image {i} of {n}',
  );
  static const notFound = Tr(
    'Mahsulot topilmadi',
    'Товар не найден',
    'Product not found',
  );

  // Add to cart
  static const maxReached = Tr(
    'Mavjud miqdorning hammasi savatda. Ko‘proq kerak bo‘lsa, sotuvchi bilan bog‘laning.',
    'В корзине уже всё доступное количество. Если нужно больше, свяжитесь с продавцом.',
    'You already have all our stock of this in your bag. Need more? Contact the store.',
  );
  static const signInToAdd = Tr(
    'Savatga qo‘shish uchun hisobga kiring',
    'Войдите, чтобы добавить в корзину',
    'Sign in to add to your bag',
  );

  // Catalog list
  static const catalog = Tr('Katalog', 'Каталог', 'Catalog');
  static const promoTitle = Tr('Aksiya', 'Акция', 'Offers');
  static const searchPlaceholder = Tr(
    'Masalan, ko‘pik yoki SPF',
    'Например, пенка или SPF',
    'For example, foam or SPF',
  );
  static const clearSearch = Tr(
    'Qidiruvni tozalash',
    'Очистить поиск',
    'Clear search',
  );
  static const sortLabel = Tr('Tartib', 'Порядок', 'Sort by');
  static const sortNewest = Tr('Yangilari', 'Новинки', 'Newest');
  static const sortPriceAsc = Tr(
    'Arzonroq',
    'Сначала дешевле',
    'Price: low to high',
  );
  static const sortPriceDesc = Tr(
    'Qimmatroq',
    'Сначала дороже',
    'Price: high to low',
  );
  static const sortName = Tr('Nomi bo‘yicha', 'По названию', 'Name');
  static const onlyInStock = Tr(
    'Faqat mavjudlari',
    'Только в наличии',
    'In stock only',
  );
  static const results = Tr('{n} ta mahsulot', 'Товаров: {n}', 'Products: {n}');
  static const shortQuery = Tr(
    'Kamida 2 ta harf kiriting.',
    'Введите не меньше 2 букв.',
    'Type at least 2 letters.',
  );
  static const emptyTitle = Tr(
    'Hech narsa topilmadi',
    'Ничего не найдено',
    'Nothing found',
  );
  static const emptyBody = Tr(
    'So‘rovni o‘zgartirib ko‘ring yoki filtrlarni olib tashlang.',
    'Измените запрос или сбросьте фильтры.',
    'Try another search or clear the filters.',
  );
  static const emptyCategory = Tr(
    'Bu toifada hozircha mahsulot yo‘q.',
    'В этой категории пока нет товаров.',
    'There are no products in this category yet.',
  );
  static const resetFilters = Tr(
    'Filtrlarni tozalash',
    'Сбросить фильтры',
    'Clear filters',
  );
}
