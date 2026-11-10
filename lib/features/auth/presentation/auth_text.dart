import '../../../core/i18n/tr.dart';

abstract final class AuthText {
  static const welcome = Tr('Xush kelibsiz', 'Добро пожаловать', 'Welcome');
  static const welcomeBody = Tr(
    'Telefon raqamingizni kiriting — tasdiqlash kodini SMS orqali yuboramiz.',
    'Введите номер телефона — мы отправим код подтверждения по SMS.',
    'Enter your phone number — we will text you a confirmation code.',
  );
  static const phone = Tr('Telefon raqami', 'Номер телефона', 'Phone number');
  static const agreePrefix = Tr('', 'Я согласен(на) с ', 'I agree to the ');
  static const privacy = Tr(
    'Maxfiylik siyosati',
    'Политикой конфиденциальности',
    'Privacy policy',
  );
  static const and = Tr(' va ', ' и ', ' and ');
  static const terms = Tr(
    'Foydalanish shartlari',
    'Условиями использования',
    'Terms of use',
  );
  static const agreeSuffix = Tr('ga roziman', '', '');
  static const getCode = Tr('Kod olish', 'Получить код', 'Get code');
  static const codeValid = Tr(
    'Kod 2 daqiqa amal qiladi',
    'Код действует 2 минуты',
    'The code is valid for 2 minutes',
  );
  static const phoneInvalid = Tr(
    'Telefon raqamini to‘liq kiriting.',
    'Введите номер полностью.',
    'Enter the full phone number.',
  );
  static const consentRequired = Tr(
    'Davom etish uchun shartlarga rozilik bering.',
    'Чтобы продолжить, примите условия.',
    'Accept the terms to continue.',
  );

  static const step = Tr('{n}-QADAM · 3 DAN', 'ШАГ {n} ИЗ 3', 'STEP {n} OF 3');
  static const enterCode = Tr(
    'Kodni kiriting',
    'Введите код',
    'Enter the code',
  );
  static const codeSent = Tr(
    'raqamiga {n} xonali kod yubordik.',
    '— отправили {n}-значный код.',
    '— we sent a {n}-digit code.',
  );
  static const changeNumber = Tr(
    'Raqamni o‘zgartirish',
    'Изменить номер',
    'Change number',
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
  static const nextStepHint = Tr(
    'Keyingi qadam: parol o‘rnatish yoki parolni kiritish',
    'Следующий шаг: задать или ввести пароль',
    'Next: set or enter your password',
  );
  static const codeResent = Tr(
    'Yangi kod yuborildi.',
    'Новый код отправлен.',
    'A new code was sent.',
  );

  static const enterPassword = Tr(
    'Parolni kiriting',
    'Введите пароль',
    'Enter your password',
  );
  static const enterPasswordBody = Tr(
    'Bu raqam bilan hisob mavjud. Parolingizni kiriting.',
    'Аккаунт с этим номером уже есть. Введите пароль.',
    'An account with this number exists. Enter your password.',
  );
  static const password = Tr('Parol', 'Пароль', 'Password');
  static const signIn = Tr('Kirish', 'Войти', 'Sign in');
  static const forgot = Tr(
    'Parolni unutdingizmi?',
    'Забыли пароль?',
    'Forgot password?',
  );

  static const createAccount = Tr(
    'Hisob yaratish',
    'Создание аккаунта',
    'Create account',
  );
  static const createAccountBody = Tr(
    'Ismingizni kiriting va parol o‘rnating.',
    'Введите имя и задайте пароль.',
    'Enter your name and choose a password.',
  );
  static const name = Tr('Ismingiz', 'Ваше имя', 'Your name');
  static const passwordRule = Tr(
    'Kamida 8 ta belgi; faqat raqamlardan iborat bo‘lmasin.',
    'Минимум 8 символов; не только цифры.',
    'At least 8 characters; not only digits.',
  );
  static const finish = Tr(
    'Ro‘yxatdan o‘tish',
    'Зарегистрироваться',
    'Sign up',
  );
  static const newPassword = Tr('Yangi parol', 'Новый пароль', 'New password');
  static const newPasswordBody = Tr(
    'Hisobingiz uchun yangi parol o‘rnating.',
    'Задайте новый пароль для аккаунта.',
    'Choose a new password for your account.',
  );
  static const savePassword = Tr(
    'Parolni saqlash',
    'Сохранить пароль',
    'Save password',
  );
  static const restart = Tr(
    'Kirishni qaytadan boshlang.',
    'Начните вход заново.',
    'Please start signing in again.',
  );
}
