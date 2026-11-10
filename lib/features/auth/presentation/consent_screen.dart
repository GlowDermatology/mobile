import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../settings/data/public_settings.dart';
import '../application/session_controller.dart';

const _title = Tr('Shartlar yangilandi', 'Условия обновлены', 'Terms updated');
const _body = Tr(
  'Davom etish uchun Foydalanish shartlari va Maxfiylik siyosatining yangi tahririni qabul qiling.',
  'Чтобы продолжить, примите новую редакцию Условий использования и Политики конфиденциальности.',
  'To continue, please accept the updated Terms of use and Privacy policy.',
);
const _acceptLabel = Tr('Qabul qilaman', 'Принимаю', 'I accept');

/// Asked when `Me.consent.update_required` or a 409 `terms_update_required`
/// (checkout, booking). Pops `true` once accepted.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _busy = false;

  Future<void> _accept(String version) async {
    setState(() => _busy = true);
    try {
      final me = await ref.read(authApiProvider).acceptTerms(version);
      ref.read(sessionProvider.notifier).updateMe(me);
      if (mounted) context.pop(true);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(publicSettingsProvider);
    return Scaffold(
      appBar: GdHeader(title: _title.of(context)),
      body: settings.when(
        loading: () => const GdLoading(),
        error: (e, _) => GdErrorView(error: e, onRetry: () => ref.invalidate(publicSettingsProvider)),
        data: (s) => ListView(padding: const EdgeInsets.all(20), children: [
          Text(_body.of(context), style: context.gdText.bodyMd),
          const SizedBox(height: 20),
          GdCard(child: Text(s.terms, style: context.gdText.bodySm.copyWith(color: context.gd.ink))),
          const SizedBox(height: 12),
          GdCard(child: Text(s.privacyPolicy, style: context.gdText.bodySm.copyWith(color: context.gd.ink))),
        ]),
      ),
      bottomNavigationBar: settings.hasValue && settings.value!.termsVersion != null
          ? GdBottomBar(child: GdButton(label: _acceptLabel.of(context), loading: _busy, onPressed: () => _accept(settings.value!.termsVersion!), semanticsId: 'consent.accept'))
          : null,
    );
  }
}

/// Opens the consent screen; true when the customer accepted.
Future<bool> askConsent(BuildContext context) async => await context.push<bool>('/consent') ?? false;
