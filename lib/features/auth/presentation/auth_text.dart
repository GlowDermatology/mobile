import '../../../core/i18n/tr.dart';

/// Sign in, sign up, the code step, password reset and social sign-in. The
/// wording follows the website (`frontend/src/features/shop/copy/auth.ts`
/// and `common.ts`).
abstract final class AuthText {
  // --- the entry screen ------------------------------------------------------
  static const modeSignIn = Tr('Kirish', 'Вход', 'Sign in');
  static const modeSignUp = Tr('Ro‘yxatdan o‘tish', 'Регистрация', 'Sign up');
  static const signInTitle = Tr(
    'Xush kelibsiz',
    'С возвращением',
    'Welcome back',
  );
  static const signInLead = Tr(
    'Buyurtmalar, cashback va qabullaringiz bir joyda.',
    'Заказы, кешбэк и записи — в одном месте.',
    'Your orders, cashback and appointments in one place.',
  );
  static const signUpTitle = Tr(
    'Hisob yaratish',
    'Создать аккаунт',
    'Create an account',
  );
  static const signUpLead = Tr(
    'Telefon raqami yoki email bilan — bir daqiqada. Telefon raqami faqat birinchi buyurtmada kerak bo‘ladi.',
    'С номером телефона или email — за минуту. Телефон понадобится только при первом заказе.',
    'With a phone number or an e-mail address, in a minute. A phone is only needed for your first order.',
  );
  static const resetTitle = Tr(
    'Parolni tiklash',
    'Восстановление пароля',
    'Reset your password',
  );
  static const resetLead = Tr(
    'Hisobingizga bog‘langan telefon raqami yoki emailni kiriting — tasdiqlash kodini yuboramiz.',
    'Введите номер телефона или email вашего аккаунта — мы отправим код подтверждения.',
    'Enter the phone number or e-mail of your account and we will send you a code.',
  );
  static const resetBack = Tr(
    'Kirishga qaytish',
    'Вернуться ко входу',
    'Back to sign in',
  );

  static const channelPhone = Tr('Telefon', 'Телефон', 'Phone');
  static const channelEmail = Tr('E-mail', 'E-mail', 'E-mail');
  static const phone = Tr('Telefon raqami', 'Номер телефона', 'Phone number');
  static const email = Tr('E-mail manzili', 'Адрес e-mail', 'E-mail address');
  static const emailHint = Tr('siz@pochta.uz', 'you@mail.uz', 'you@mail.com');
  static const phoneInvalid = Tr(
    'Telefon raqamini to‘liq kiriting.',
    'Введите номер полностью.',
    'Enter the full phone number.',
  );
  static const emailInvalid = Tr(
    'E-mail manzilini to‘g‘ri kiriting.',
    'Введите корректный адрес e-mail.',
    'Enter a valid e-mail address.',
  );

  static const password = Tr('Parol', 'Пароль', 'Password');
  static const signIn = Tr('Kirish', 'Войти', 'Sign in');
  static const passwordRequired = Tr(
    'Parolni kiriting.',
    'Введите пароль.',
    'Enter your password.',
  );
  static const forgot = Tr(
    'Parolni unutdingizmi?',
    'Забыли пароль?',
    'Forgot your password?',
  );
  static const getCode = Tr('Kod olish', 'Получить код', 'Get a code');
  static const codeValid = Tr(
    'Kod 2 daqiqa amal qiladi',
    'Код действует 2 минуты',
    'The code is valid for 2 minutes',
  );
  static const signUpAction = Tr(
    'Ro‘yxatdan o‘tish',
    'Зарегистрироваться',
    'Sign up',
  );

  // --- social sign-in --------------------------------------------------------
  static const or = Tr('yoki', 'или', 'or');
  static const google = Tr(
    'Google bilan davom etish',
    'Продолжить с Google',
    'Continue with Google',
  );
  static const facebook = Tr(
    'Facebook bilan davom etish',
    'Продолжить с Facebook',
    'Continue with Facebook',
  );
  static const socialFailed = Tr(
    'Kirish amalga oshmadi. Qayta urinib ko‘ring.',
    'Не удалось войти. Попробуйте ещё раз.',
    'Sign-in did not work. Please try again.',
  );
  static const completeTitle = Tr(
    'Hisobingizni yakunlang',
    'Завершите регистрацию',
    'Finish your account',
  );
  static const completeLead = Tr(
    'Telefon raqamingizni hozir bog‘lashingiz mumkin — yoki keyinroq, birinchi buyurtma yoki qabul paytida.',
    'Привяжите номер телефона сейчас — или позже, при первом заказе или записи.',
    'Link your phone number now — or later, at your first order or appointment.',
  );
  static const socialSkip = Tr(
    'Hozircha davom etish',
    'Продолжить пока так',
    'Continue for now',
  );
  static const socialLink = Tr(
    'Telefon yoki e-mailni bog‘lash',
    'Привязать телефон или e-mail',
    'Link a phone or e-mail',
  );
  static const linkLead = Tr(
    'Kodni yuboramiz — shu raqam yoki email bilan hisob bo‘lsa, unga bog‘lanadi.',
    'Мы отправим код. Если с этим номером или email уже есть аккаунт, профиль привяжется к нему.',
    'We will send a code. If an account has this phone or e-mail, the profile is linked to it.',
  );
  static const existingPassword = Tr(
    'Bu hisobning paroli',
    'Пароль этого аккаунта',
    'Password of that account',
  );
  static const existingPasswordHint = Tr(
    'Bu raqam bilan hisob bor. Bog‘lash uchun uning parolini kiriting.',
    'С этим номером уже есть аккаунт. Чтобы привязать, введите его пароль.',
    'An account with this number exists. Enter its password to link it.',
  );

  // --- the code step ---------------------------------------------------------
  static const enterCode = Tr(
    'Kodni kiriting',
    'Введите код',
    'Enter the code',
  );
  static const newDeviceTitle = Tr(
    'Yangi qurilmadan kirish',
    'Вход с нового устройства',
    'Signing in from a new device',
  );
  static const newDeviceLead = Tr(
    'Bu qurilmadan birinchi marta kiryapsiz. Xavfsizlik uchun tasdiqlash kodini yubordik.',
    'Вы впервые входите с этого устройства. Для безопасности мы отправили код подтверждения.',
    'This is your first sign-in on this device. For your security we sent you a code.',
  );
  static const codeSentSms = Tr(
    'SMS orqali {mask} raqamiga {n} xonali kod yubordik.',
    'Мы отправили {n}-значный код по SMS на номер {mask}.',
    'We texted a {n}-digit code to {mask}.',
  );
  static const codeSentEmail = Tr(
    '{mask} e-mail manziliga {n} xonali kod yubordik. «Spam» papkasini ham tekshiring.',
    'Мы отправили {n}-значный код на {mask}. Проверьте и папку «Спам».',
    'We sent a {n}-digit code to {mask}. Check your spam folder too.',
  );
  static const changeNumber = Tr(
    'Raqamni o‘zgartirish',
    'Изменить номер',
    'Change number',
  );
  static const changeEmail = Tr(
    'E-mailni o‘zgartirish',
    'Изменить e-mail',
    'Change e-mail',
  );
  static const sendToEmail = Tr(
    'Kodni e-mailga yuborish',
    'Отправить код на e-mail',
    'Send the code by e-mail',
  );
  static const sendBySms = Tr(
    'SMS orqali yuborish',
    'Отправить по SMS',
    'Send it by SMS',
  );
  static const attemptsLeft = Tr(
    'Qolgan urinishlar: {n}',
    'Осталось попыток: {n}',
    'Attempts left: {n}',
  );
  static const resendIn = Tr(
    'Kodni qayta yuborish:',
    'Отправить код повторно через',
    'Resend code in',
  );
  static const resend = Tr(
    'Kodni qayta yuborish',
    'Отправить код повторно',
    'Resend code',
  );
  static const confirm = Tr('Tasdiqlash', 'Подтвердить', 'Confirm');
  static const codeResent = Tr(
    'Yangi kod yuborildi.',
    'Новый код отправлен.',
    'A new code was sent.',
  );
  static const restart = Tr(
    'Kirishni qaytadan boshlang.',
    'Начните вход заново.',
    'Please start signing in again.',
  );

  // --- account details (sign-up) ---------------------------------------------
  static const detailsTitle = Tr(
    'Hisob ma’lumotlari',
    'Данные аккаунта',
    'Account details',
  );
  static const createAccountBody = Tr(
    'Ismingizni kiriting va parol o‘rnating.',
    'Введите имя и задайте пароль.',
    'Enter your name and choose a password.',
  );
  static const name = Tr('Ismingiz', 'Ваше имя', 'Your name');
  static const namePlaceholder = Tr(
    'Masalan, Malika',
    'Например, Малика',
    'For example, Malika',
  );
  static const passwordRule = Tr(
    'Kamida 8 ta belgi; faqat raqamlardan iborat bo‘lmasin.',
    'Минимум 8 символов; не только цифры.',
    'At least 8 characters; not only digits.',
  );
  static const create = Tr(
    'Hisobni yaratish',
    'Создать аккаунт',
    'Create account',
  );

  // --- the terms consent (sign-up and the social completion only) -----------
  static const consentBefore = Tr('Men ', 'Я принимаю ', 'I accept the ');
  static const terms = Tr(
    'Foydalanish shartlari',
    'Условия использования',
    'Terms of use',
  );
  static const consentMiddle = Tr(' va ', ' и ', ' and the ');
  static const privacy = Tr(
    'Maxfiylik siyosati',
    'Политику конфиденциальности',
    'Privacy policy',
  );
  static const consentAfter = Tr('ni qabul qilaman', '', '');
  static const consentRequired = Tr(
    'Davom etish uchun shartlarni qabul qiling.',
    'Чтобы продолжить, примите условия.',
    'Please accept the terms to continue.',
  );
  static const termsUnavailable = Tr(
    'Ro‘yxatdan o‘tish vaqtincha mavjud emas. Keyinroq urinib ko‘ring.',
    'Регистрация временно недоступна. Попробуйте позже.',
    'Sign-up is temporarily unavailable. Please try again later.',
  );
  static const termsUpdated = Tr(
    'Shartlar yangilandi. Ularni qabul qilib, qayta bosing.',
    'Условия обновились. Примите их и нажмите ещё раз.',
    'The terms were updated. Accept them and tap again.',
  );

  // --- the new password (reset) ----------------------------------------------
  static const newPassword = Tr('Yangi parol', 'Новый пароль', 'New password');
  static const newPasswordBody = Tr(
    'Hisobingiz uchun yangi parol o‘rnating.',
    'Задайте новый пароль для аккаунта.',
    'Choose a new password for your account.',
  );
  static const repeatPassword = Tr(
    'Parolni takrorlang',
    'Повторите пароль',
    'Repeat the password',
  );
  static const passwordsDiffer = Tr(
    'Parollar mos kelmadi.',
    'Пароли не совпадают.',
    'The passwords do not match.',
  );
  static const savePassword = Tr(
    'Parolni saqlash',
    'Сохранить пароль',
    'Save password',
  );
}
