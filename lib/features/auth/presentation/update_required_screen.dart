import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/json.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../../core/widgets/rings.dart';

const _title = Tr('Ilovani yangilang', 'Обновите приложение', 'Update the app');
const _update = Tr('Yangilash', 'Обновить', 'Update');

/// Blocking screen for 426 `app_update_required` (contract §1.2).
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.error});
  final ApiException error;

  @override
  Widget build(BuildContext context) {
    final storeUrl = asStringOrNull(error.details['store_url']);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GdLogo(size: 88),
              const SizedBox(height: 28),
              Text(
                _title.of(context),
                style: context.gdText.displayLg,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                error.message,
                style: context.gdText.bodyMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              if (storeUrl != null)
                GdButton(
                  label: _update.of(context),
                  onPressed: () => launchUrl(
                    Uri.parse(storeUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
