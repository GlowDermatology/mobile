import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/widgets/gd_widgets.dart';
import '../../settings/data/public_settings.dart';
import '../application/profile_logic.dart';
import 'profile_text.dart';

/// Privacy policy, terms of use or booking rules from `settings/public/`.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.doc});

  /// `privacy`, `terms` or `booking`.
  final String doc;

  static Tr titleOf(LegalDoc doc) => switch (doc) {
    LegalDoc.privacy => ProfileText.privacy,
    LegalDoc.terms => ProfileText.terms,
    LegalDoc.booking => ProfileText.booking,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legal = LegalDoc.fromSlug(doc);
    final settings = ref.watch(publicSettingsProvider);
    return Scaffold(
      appBar: GdHeader(title: titleOf(legal).of(context)),
      body: settings.when(
        loading: () => const GdLoading(),
        error: (e, _) => GdErrorView(
          error: e,
          onRetry: () => ref.invalidate(publicSettingsProvider),
        ),
        data: (s) {
          final text = legal.textOf(s).trim();
          if (text.isEmpty) {
            return GdEmptyView(
              icon: Icons.description_outlined,
              title: ProfileText.legalEmpty.of(context),
              body: ProfileText.legalEmptyBody.of(context),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              GdSpace.page,
              8,
              GdSpace.page,
              32,
            ),
            child: SafeArea(
              top: false,
              child: Semantics(
                identifier: 'legal.text',
                child: SelectableText(
                  text,
                  style: context.gdText.bodyMd.copyWith(height: 1.55),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
