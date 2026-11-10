import '../../../core/i18n/tr.dart';

/// UI strings of specialists, booking and appointments (PDF pages 12–14;
/// the rest after the website's `booking.ts`).
abstract final class AppointmentsText {
  // Specialists (p.12)
  static const specialistsTitle = Tr(
    'Mutaxassislar',
    'Специалисты',
    'Specialists',
  );
  static const filterAll = Tr('Hammasi', 'Все', 'All');
  static const filterDermatologists = Tr(
    'Dermatologlar',
    'Дерматологи',
    'Dermatologists',
  );
  static const filterCosmetologists = Tr(
    'Kosmetologlar',
    'Косметологи',
    'Cosmetologists',
  );
  static const weekBusy = Tr(
    'Bu hafta band',
    'На неделе всё занято',
    'Fully booked this week',
  );
  static const servicesFrom = Tr(
    '{n} xizmat · {price}dan',
    '{n} усл. · от {price}',
    '{n} services · from {price}',
  );
  static const specialistsNote = Tr(
    'Mutaxassis ko‘rigi mahsulot tanlashdan oldin tavsiya etiladi. Tashxis va muolajalar faqat qabulda belgilanadi.',
    'Перед выбором средств рекомендуется осмотр специалиста. Диагноз и процедуры назначаются только на приёме.',
    'A specialist consultation is recommended before choosing products. Diagnosis and treatments are set only at the appointment.',
  );
  static const noSpecialists = Tr(
    'Hozircha onlayn yozilish mumkin bo‘lgan mutaxassis yo‘q.',
    'Пока нет специалистов для онлайн-записи.',
    'No specialists take online bookings yet.',
  );
  static const noSpecialistsInFilter = Tr(
    'Bu bo‘limda mutaxassis yo‘q.',
    'В этом разделе нет специалистов.',
    'No specialists in this group.',
  );

  // Booking (p.13)
  static const bookingTitle = Tr(
    'Qabulga yozilish',
    'Запись на приём',
    'Book an appointment',
  );
  static const service = Tr('Xizmat', 'Услуга', 'Service');
  static const date = Tr('Sana', 'Дата', 'Date');
  static const freeTime = Tr('Bo‘sh vaqt', 'Свободное время', 'Free times');
  static const minutes = Tr('{n} daqiqa', '{n} мин', '{n} min');
  static const noSlots = Tr(
    'Bu kunda bo‘sh vaqt yo‘q',
    'На этот день свободного времени нет',
    'No free time on this day',
  );
  static const notWorking = Tr(
    'Mutaxassis bu kuni ishlamaydi.',
    'Специалист в этот день не работает.',
    'The specialist does not work on this day.',
  );
  static const bookingNote = Tr(
    'So‘rovingizni mutaxassis tasdiqlaydi. Narx bron paytidagidek saqlanadi.',
    'Специалист подтвердит ваш запрос. Цена сохраняется на момент записи.',
    'The specialist confirms your request. The price stays as at booking.',
  );
  static const book = Tr('Bron qilish', 'Забронировать', 'Book');
  static const chooseTime = Tr(
    'Vaqtni tanlang',
    'Выберите время',
    'Choose a time',
  );
  static const noServices = Tr(
    'Bu mutaxassisda onlayn yozilish uchun xizmat yo‘q.',
    'У специалиста нет услуг для онлайн-записи.',
    'This specialist has no services to book online.',
  );
  static const rescheduleHint = Tr(
    'Yangi vaqtni tanlang — eski qabul bekor qilinadi.',
    'Выберите новое время — прежняя запись будет отменена.',
    'Choose a new time — the previous appointment will be cancelled.',
  );
  static const rescheduleCancelFailed = Tr(
    'Yangi qabul yaratildi, lekin eskisini bekor qilib bo‘lmadi: {message}',
    'Новая запись создана, но прежнюю отменить не удалось: {message}',
    'The new appointment is booked, but the previous one could not be cancelled: {message}',
  );

  // Appointment (p.14)
  static const sentTitle = Tr(
    'So‘rovingiz yuborildi',
    'Запрос отправлен',
    'Request sent',
  );
  static const sentBody = Tr(
    'Mutaxassis vaqtni tasdiqlagach bildirishnoma yuboramiz.',
    'Мы пришлём уведомление, когда специалист подтвердит время.',
    'We will notify you once the specialist confirms the time.',
  );
  static const appointmentTitle = Tr('Qabul', 'Приём', 'Appointment');
  static const rowSpecialist = Tr('Mutaxassis', 'Специалист', 'Specialist');
  static const rowService = Tr('Xizmat', 'Услуга', 'Service');
  static const rowTime = Tr('Vaqt', 'Время', 'Time');
  static const rowAddress = Tr('Manzil', 'Адрес', 'Address');
  static const rowPrice = Tr('Narx', 'Цена', 'Price');
  static const policy = Tr(
    'Bekor qilish va ko‘chirish shartlari: {policy}',
    'Условия отмены и переноса: {policy}',
    'Cancellation and rescheduling terms: {policy}',
  );
  static const reschedule = Tr(
    'Vaqtni o‘zgartirish',
    'Перенести',
    'Reschedule',
  );
  static const cancel = Tr('Bekor qilish', 'Отменить', 'Cancel');
  static const backToCatalog = Tr(
    'Katalogga qaytish',
    'Вернуться в каталог',
    'Back to catalog',
  );
  static const cancelTitle = Tr(
    'Qabulni bekor qilasizmi?',
    'Отменить запись?',
    'Cancel this appointment?',
  );
  static const cancelBody = Tr(
    'Qabul ({when}) bekor qilinadi, vaqt boshqalar uchun bo‘shaydi.',
    'Запись на {when} будет отменена, время освободится.',
    'Your appointment on {when} will be cancelled and the time released.',
  );
  static const cancelConfirm = Tr(
    'Ha, bekor qilish',
    'Да, отменить',
    'Yes, cancel',
  );
  static const cancelKeep = Tr('Yo‘q', 'Нет', 'No');
  static const cancelled = Tr(
    'Qabul bekor qilindi',
    'Запись отменена',
    'Appointment cancelled',
  );
  static const cancelledByClinic = Tr(
    'Klinika tomonidan bekor qilingan',
    'Отменено клиникой',
    'Cancelled by the clinic',
  );

  // Appointments list
  static const myAppointments = Tr(
    'Mening qabullarim',
    'Мои записи',
    'My appointments',
  );
  static const upcoming = Tr('Kelgusi', 'Предстоящие', 'Upcoming');
  static const past = Tr('O‘tgan', 'Прошедшие', 'Past');
  static const emptyUpcoming = Tr(
    'Kelgusi qabul yo‘q.',
    'Предстоящих записей нет.',
    'No upcoming appointments.',
  );
  static const emptyPast = Tr(
    'O‘tgan qabullar yo‘q.',
    'Прошедших записей нет.',
    'No past appointments.',
  );
  static const emptyBody = Tr(
    'Mutaxassis, xizmat va qulay vaqtni tanlang — qabul klinika tomonidan tasdiqlanadi.',
    'Выберите специалиста, услугу и удобное время — клиника подтвердит запись.',
    'Choose a specialist, a service and a time — the clinic confirms your request.',
  );
  static const loadMoreFailed = Tr(
    'Yuklab bo‘lmadi',
    'Не удалось загрузить',
    'Could not load',
  );
}
