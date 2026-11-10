import 'package:flutter/material.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/rings.dart';

const _title = Tr('AI yordamchi', 'AI-помощник', 'AI assistant');
const _body = Tr(
  'Teri holatini tahlil qilish va sizga mos parvarish tavsiyalari tez orada shu yerda bo‘ladi.',
  'Скоро здесь появятся анализ кожи и персональные рекомендации по уходу.',
  'Skin analysis and personal care recommendations are coming here soon.',
);

/// The AI tab of the design. The backend has no AI endpoints yet (customer
/// contract: "Phase 2"), so it is a placeholder.
class AiScreen extends StatelessWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 190,
                  child: GdRings(
                    color: c.gold.withValues(alpha: 0.7),
                    child: Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: c.goldSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 38,
                          color: c.goldInk,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _title.of(context),
                  style: context.gdText.displayLg,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _body.of(context),
                  style: context.gdText.bodyMd.copyWith(color: c.inkMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: c.goldSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    Strings.comingSoon.of(context).toUpperCase(),
                    style: context.gdText.overline.copyWith(color: c.goldInk),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
