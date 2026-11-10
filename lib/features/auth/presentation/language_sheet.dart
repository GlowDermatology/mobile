import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/gd_colors.dart';
import '../../../core/i18n/tr.dart';
import '../application/session_controller.dart';

const languageTitle = Tr('Til', 'Язык', 'Language');

/// Language picker; also updates the account language when signed in.
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final current = ref.read(languageProvider);
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text(languageTitle.of(context), style: context.gdText.heading)),
            ),
            for (final l in AppLanguage.values)
              ListTile(
                title: Text(l.label, style: context.gdText.bodyMd),
                trailing: l == current ? Icon(Icons.check_circle, color: context.gd.goldInk) : null,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(sessionProvider.notifier).setLanguage(l);
                },
              ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
