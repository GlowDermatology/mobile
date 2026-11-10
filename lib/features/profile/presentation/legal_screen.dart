import 'package:flutter/material.dart';

import '../../../core/widgets/gd_widgets.dart';

// Placeholder: replaced by the feature implementation.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  /// `privacy`, `terms` or `booking`.
  final String doc;
  @override
  Widget build(BuildContext context) => const Scaffold(appBar: GdHeader(title: 'LegalScreen'), body: SizedBox.shrink());
}
