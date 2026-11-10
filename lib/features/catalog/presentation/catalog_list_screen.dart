import 'package:flutter/material.dart';

import '../../../core/widgets/gd_widgets.dart';

// Placeholder: replaced by the feature implementation.
class CatalogListScreen extends StatelessWidget {
  const CatalogListScreen({super.key, this.category, this.search, this.promo = false});
  final String? category;
  final String? search;
  final bool promo;
  @override
  Widget build(BuildContext context) => const Scaffold(appBar: GdHeader(title: 'CatalogListScreen'), body: SizedBox.shrink());
}
