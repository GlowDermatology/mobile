import '../../../core/i18n/tr.dart';

/// Strings of the settings tab and its inner screens. Uzbek from the design
/// (page 11) and the website copy (`account.ts`).
abstract final class ProfileText {
  // Settings tab (design p.11)
  static const title = Tr('Sozlamalar', 'Настройки', 'Settings');
  static const editName = Tr('Ismni o‘zgartirish', 'Изменить имя', 'Edit name');
  static const nameLabel = Tr('Ism', 'Имя', 'Name');
  static const nameInvalid = Tr(
    'Ismingizni kiriting (kamida 2 belgi).',
    'Введите имя (не меньше 2 символов).',
    'Enter your name (at least 2 characters).',
  );
  static const nameSaved = Tr(
    'O‘zgarishlar saqlandi',
    'Изменения сохранены',
    'Changes saved',
  );
  static const guestTitle = Tr(
    'Hisobingizga kiring',
    'Войдите в аккаунт',
    'Sign in to your account',
  );
  static const guestBody = Tr(
    'Buyurtmalar, qabullar va cashback bir joyda.',
    'Заказы, записи и кешбэк в одном месте.',
    'Orders, appointments and cashback in one place.',
  );
  static const guestAction = Tr(
    'Kirish yoki ro‘yxatdan o‘tish',
    'Войти или зарегистрироваться',
    'Sign in or sign up',
  );
  static const orders = Tr(
    'Buyurtmalar tarixi',
    'История заказов',
    'Order history',
  );
  static const appointments = Tr(
    'Mening qabullarim',
    'Мои записи',
    'My appointments',
  );
  static const specialists = Tr('Mutaxassislar', 'Специалисты', 'Specialists');
  static const addresses = Tr('Manzillarim', 'Мои адреса', 'My addresses');
  static const language = Tr('Til', 'Язык', 'Language');
  static const theme = Tr('Mavzu', 'Тема', 'Theme');
  static const themeLight = Tr('Yorug‘', 'Светлая', 'Light');
  static const themeDark = Tr('Qorong‘i', 'Тёмная', 'Dark');
  static const privacy = Tr(
    'Maxfiylik siyosati',
    'Политика конфиденциальности',
    'Privacy policy',
  );
  static const terms = Tr(
    'Foydalanish shartlari',
    'Условия использования',
    'Terms of use',
  );
  static const booking = Tr(
    'Qabul qoidalari',
    'Правила записи',
    'Booking rules',
  );
  static const sessions = Tr(
    'Faol seanslar',
    'Активные сеансы',
    'Active sessions',
  );
  static const changePassword = Tr(
    'Parolni o‘zgartirish',
    'Сменить пароль',
    'Change password',
  );
  static const deleteAccount = Tr(
    'Hisobni o‘chirish',
    'Удалить аккаунт',
    'Delete account',
  );
  static const signOut = Tr('Chiqish', 'Выйти', 'Log out');
  static const signOutTitle = Tr(
    'Hisobdan chiqasizmi?',
    'Выйти из аккаунта?',
    'Log out?',
  );
  static const signOutBody = Tr(
    'Qayta kirish uchun telefon raqami va parol kerak bo‘ladi.',
    'Чтобы войти снова, понадобятся номер телефона и пароль.',
    'You will need your phone number and password to sign in again.',
  );
  static const signOutConfirm = Tr('Ha, chiqish', 'Да, выйти', 'Yes, log out');
  static const telegram = Tr('Telegram', 'Telegram', 'Telegram');
  static const instagram = Tr('Instagram', 'Instagram', 'Instagram');
  static const website = Tr('Veb-sayt', 'Веб-сайт', 'Website');
  static const phone = Tr('Telefon', 'Телефон', 'Phone');
  static const linkFailed = Tr(
    'Havolani ochib bo‘lmadi',
    'Не удалось открыть ссылку',
    'Could not open the link',
  );

  // Legal
  static const legalEmpty = Tr(
    'Matn hali qo‘shilmagan',
    'Текст пока не добавлен',
    'No text yet',
  );
  static const legalEmptyBody = Tr(
    'Keyinroq qayta kiring.',
    'Загляните позже.',
    'Please check back later.',
  );

  // Change password
  static const currentPassword = Tr(
    'Joriy parol',
    'Текущий пароль',
    'Current password',
  );
  static const newPassword = Tr('Yangi parol', 'Новый пароль', 'New password');
  static const passwordRules = Tr(
    'Kamida 8 ta belgi; faqat raqamlardan iborat bo‘lmasin.',
    'Не меньше 8 символов и не только цифры.',
    'At least 8 characters, not digits only.',
  );
  static const passwordTooShort = Tr(
    'Kamida 8 ta belgi kiriting.',
    'Введите не меньше 8 символов.',
    'Enter at least 8 characters.',
  );
  static const passwordNumeric = Tr(
    'Parol faqat raqamlardan iborat bo‘lmasin.',
    'Пароль не должен состоять только из цифр.',
    'The password cannot be digits only.',
  );
  static const required = Tr(
    'Maydonni to‘ldiring.',
    'Заполните поле.',
    'This field is required.',
  );
  static const passwordLead = Tr(
    'Parol o‘zgargach, boshqa qurilmalardagi seanslar yakunlanadi.',
    'После смены пароля сеансы на других устройствах будут завершены.',
    'After the change, sessions on other devices are signed out.',
  );
  static const passwordSave = Tr(
    'Parolni saqlash',
    'Сохранить пароль',
    'Save password',
  );
  static const passwordChanged = Tr(
    'Parol o‘zgartirildi',
    'Пароль изменён',
    'Password changed',
  );
  static const noPassword = Tr(
    'Parol o‘rnatilmagan — hozir ijtimoiy tarmoq orqali kirasiz. Parolni veb-saytdagi profil sahifasida o‘rnating.',
    'Пароль не установлен — сейчас вы входите через соцсеть. Установите пароль в профиле на сайте.',
    'No password yet — you sign in with a social account. Set one on the profile page of the website.',
  );
  static const showPassword = Tr(
    'Parolni ko‘rsatish',
    'Показать пароль',
    'Show password',
  );
  static const hidePassword = Tr(
    'Parolni yashirish',
    'Скрыть пароль',
    'Hide password',
  );

  // Sessions
  static const sessionsLead = Tr(
    'Hisobingizga kirilgan telefonlar va brauzerlar. Tanimagan seansdan darhol chiqing.',
    'Телефоны и браузеры, где выполнен вход в аккаунт. Если сеанс вам незнаком, сразу завершите его.',
    'Phones and browsers signed in to your account. Sign out of any session you do not recognise.',
  );
  static const sessionCurrent = Tr('Joriy', 'Текущий', 'Current');
  static const sessionUpdated = Tr(
    'Yangilangan: {date}',
    'Обновлён: {date}',
    'Updated: {date}',
  );
  static const sessionCreated = Tr(
    'Kirilgan: {date}',
    'Вход: {date}',
    'Signed in: {date}',
  );
  static const signOutOthers = Tr(
    'Boshqa qurilmalardan chiqish',
    'Выйти на других устройствах',
    'Sign out of all other devices',
  );
  static const othersTitle = Tr(
    'Boshqa qurilmalardan chiqasizmi?',
    'Выйти на других устройствах?',
    'Sign out of all other devices?',
  );
  static const othersBody = Tr(
    'Shu telefondan boshqa barcha telefon va brauzerlardagi seanslar yakunlanadi.',
    'Будут завершены сеансы на всех других телефонах и браузерах, кроме этого.',
    'Every other phone and browser will be signed out. This one stays signed in.',
  );
  static const oneTitle = Tr(
    'Bu seansdan chiqasizmi?',
    'Завершить этот сеанс?',
    'Log out of this session?',
  );
  static const oneBody = Tr(
    '{device} hisobingizdan chiqariladi.',
    '{device} выйдет из вашего аккаунта.',
    '{device} will be signed out of your account.',
  );
  static const oneCurrentBody = Tr(
    'Bu — shu telefon. Undan chiqsangiz, katalogga qaytasiz.',
    'Это текущий телефон. После выхода вы вернётесь в каталог.',
    'This is the phone you are using. You will return to the catalog.',
  );
  static const revoked = Tr(
    'Seans yakunlandi',
    'Сеанс завершён',
    'Session signed out',
  );
  static const revokedOthers = Tr(
    '{n} ta seans yakunlandi',
    'Завершено сеансов: {n}',
    'Sessions signed out: {n}',
  );
  static const noOthers = Tr(
    'Boshqa faol seans yo‘q.',
    'Других активных сеансов нет.',
    'No other active sessions.',
  );

  // Addresses
  static const addressesTitle = Tr('Manzillarim', 'Мои адреса', 'My addresses');
  static const addressesEmpty = Tr(
    'Saqlangan manzil yo‘q.',
    'Сохранённых адресов нет.',
    'No saved addresses.',
  );
  static const addressesEmptyBody = Tr(
    'Manzilni saqlab qo‘ysangiz, buyurtma berish tezroq bo‘ladi.',
    'Сохраните адрес — оформлять заказы станет быстрее.',
    'Save an address to check out faster.',
  );
  static const newAddress = Tr('Yangi manzil', 'Новый адрес', 'New address');
  static const addressDefault = Tr('Asosiy', 'Основной', 'Default');
  static const makeDefault = Tr(
    'Asosiy manzil qilish',
    'Сделать основным',
    'Make default',
  );
  static const delete = Tr('O‘chirish', 'Удалить', 'Delete');
  static const deleteAddressTitle = Tr(
    'Manzilni o‘chirasizmi?',
    'Удалить адрес?',
    'Delete the address?',
  );
  static const deleteConfirm = Tr(
    'Ha, o‘chirish',
    'Да, удалить',
    'Yes, delete',
  );
  static const addressDeleted = Tr(
    'Manzil o‘chirildi',
    'Адрес удалён',
    'Address deleted',
  );
  static const addressSaved = Tr(
    'Manzil saqlandi',
    'Адрес сохранён',
    'Address saved',
  );
  static const addressActions = Tr('Amallar', 'Действия', 'Actions');

  // Delete account
  static const deleteLead = Tr(
    'Hisob o‘chirilgach, profil, manzillar va kirish usullari o‘chadi.',
    'После удаления исчезнут профиль, адреса и способы входа.',
    'Deleting removes your profile, addresses and sign-in methods.',
  );
  static const deletePaid = Tr(
    'To‘langan buyurtmalar yetkazib beriladi.',
    'Оплаченные заказы будут доставлены.',
    'Paid orders will still be delivered.',
  );
  static const deleteCancelled = Tr(
    'To‘lanmagan buyurtmalar va kelgusi qabullar bekor qilinadi.',
    'Неоплаченные заказы и будущие записи будут отменены.',
    'Unpaid orders and upcoming appointments will be cancelled.',
  );
  static const deleteCashback = Tr(
    'Cashback balansi va xaridlar tarixi saqlanadi; shu raqam bilan qayta ro‘yxatdan o‘tsangiz, ular tiklanadi.',
    'Баланс кешбэка и история покупок сохраняются и восстановятся при повторной регистрации с этим номером.',
    'Your cashback balance and purchase history are kept and come back if you sign up again with this number.',
  );
  static const deleteIrreversible = Tr(
    'Bu amalni ortga qaytarib bo‘lmaydi.',
    'Это действие нельзя отменить.',
    'This cannot be undone.',
  );
  static const deletePasswordHint = Tr(
    'Tasdiqlash uchun hisob parolini kiriting.',
    'Для подтверждения введите пароль аккаунта.',
    'Enter your account password to confirm.',
  );
  static const deleteConfirmTitle = Tr(
    'Hisobingizni o‘chirasizmi?',
    'Удалить аккаунт?',
    'Delete your account?',
  );
  static const deleteConfirm2 = Tr(
    'Ha, hisobni o‘chirish',
    'Да, удалить аккаунт',
    'Yes, delete my account',
  );
  static const deleted = Tr(
    'Hisob o‘chirildi',
    'Аккаунт удалён',
    'Account deleted',
  );
  static const deleteNeedsPassword = Tr(
    'Hisobingizda parol yo‘q. Hisobni veb-saytdagi profil sahifasida SMS kod orqali o‘chiring.',
    'У аккаунта нет пароля. Удалите аккаунт в профиле на сайте с подтверждением по SMS.',
    'Your account has no password. Delete it on the website profile page with an SMS code.',
  );
}
