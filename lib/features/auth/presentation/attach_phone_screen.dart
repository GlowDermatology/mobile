import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../core/format/phone.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../application/session_controller.dart';
import 'auth_text.dart';
import 'auth_widgets.dart';

const _title = Tr('Telefon raqami', 'Номер телефона', 'Phone number');
const _body = Tr(
  'Buyurtma, to‘lov, qabul va QR kod uchun tasdiqlangan telefon raqami kerak.',
  'Для заказа, оплаты, записи и QR-кода нужен подтверждённый номер телефона.',
  'A verified phone number is needed for orders, payments, bookings and the QR code.',
);

/// Answer to 409 `phone_required` (contract §2.2.10). Only reachable by
/// accounts created without a phone (e-mail or social sign-up on the website).
class AttachPhoneScreen extends ConsumerStatefulWidget {
  const AttachPhoneScreen({super.key});

  @override
  ConsumerState<AttachPhoneScreen> createState() => _AttachPhoneScreenState();
}

class _AttachPhoneScreenState extends ConsumerState<AttachPhoneScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _code = '';
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.displayMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider).me;
    final phone = toE164(_phone.text);
    return Scaffold(
      appBar: GdHeader(title: _title.of(context)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(_body.of(context), style: context.gdText.bodyMd),
        const SizedBox(height: 20),
        GdPhoneField(controller: _phone, errorText: _sent ? null : _error),
        if (_sent) ...[
          const SizedBox(height: 20),
          GdOtpField(length: 6, onChanged: (v) => setState(() => _code = v)),
          if (me?.hasPassword ?? false) ...[
            const SizedBox(height: 16),
            GdPasswordField(controller: _password, label: AuthText.password.of(context)),
          ],
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: context.gdText.bodySm.copyWith(color: context.gd.danger))],
        ],
      ]),
      bottomNavigationBar: GdBottomBar(
        child: GdButton(
          label: _sent ? AuthText.confirm.of(context) : AuthText.getCode.of(context),
          loading: _busy,
          onPressed: phone == null
              ? null
              : () => _run(() async {
                    final api = ref.read(authApiProvider);
                    if (!_sent) {
                      await api.sendAttachPhoneCode(phone);
                      setState(() => _sent = true);
                    } else {
                      final updated = await api.attachPhone(phone: phone, code: _code, password: _password.text.isEmpty ? null : _password.text);
                      ref.read(sessionProvider.notifier).updateMe(updated);
                      if (context.mounted) context.pop(true);
                    }
                  }),
        ),
      ),
    );
  }
}
