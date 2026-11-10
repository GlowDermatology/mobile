import 'package:flutter/material.dart';

import '../../../../app/theme/gd_colors.dart';
import '../../../../app/theme/gd_theme.dart';
import '../../../../core/widgets/gd_widgets.dart';
import '../../data/catalog_models.dart';
import '../catalog_text.dart';

/// Home category circles (PDF p.3): "Hammasi" first, then the API categories
/// with their image or the illustrated bottle keyed by slug.
class CategoryStrip extends StatelessWidget {
  const CategoryStrip({
    super.key,
    required this.categories,
    required this.onSelect,
    this.selected,
  });
  final List<CatalogCategory> categories;

  /// null = "Hammasi".
  final void Function(CatalogCategory? category) onSelect;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    return SizedBox(
      height: 66 + 10 + 20 * scale + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: GdSpace.page),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _CategoryBubble(
              id: 'home.category.all',
              label: CatalogText.all.of(context),
              selected: selected == null,
              onTap: () => onSelect(null),
              child: Icon(
                Icons.grid_view_rounded,
                color: context.gd.goldInk,
                size: 26,
              ),
            );
          }
          final cat = categories[i - 1];
          return _CategoryBubble(
            id: 'home.category.${cat.slug}',
            label: cat.name,
            selected: selected == cat.slug,
            onTap: () => onSelect(cat),
            child: GdImage(
              url: cat.imageUrl,
              seed: cat.slug,
              radius: 33,
              artSize: 34,
            ),
          );
        },
      ),
    );
  }
}

class _CategoryBubble extends StatelessWidget {
  const _CategoryBubble({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });
  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    return Semantics(
      identifier: id,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GdRadius.md),
        child: SizedBox(
          width: 74,
          child: Column(
            children: [
              Container(
                width: 66,
                height: 66,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: c.goldSoft,
                  shape: BoxShape.circle,
                  border: selected ? Border.all(color: c.gold, width: 2) : null,
                ),
                alignment: Alignment.center,
                child: child,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: selected
                    ? t.label.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )
                    : t.caption.copyWith(fontSize: 13, color: c.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The outlined "Mahsulot qidirish" field.
class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.hint,
    this.semanticsId = 'catalog.search',
  });
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String? hint;
  final String semanticsId;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final hasClear = onClear != null && controller != null;
    return Semantics(
      identifier: semanticsId,
      textField: true,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        maxLength: ProductQuery.maxSearchLength,
        style: context.gdText.bodyMd,
        decoration: InputDecoration(
          hintText: hint ?? CatalogText.searchHint.of(context),
          counterText: '',
          prefixIcon: Icon(Icons.search_rounded, color: c.inkMuted),
          suffixIcon: hasClear
              ? ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller!,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: CatalogText.clearSearch.of(context),
                          icon: Icon(Icons.close_rounded, color: c.inkMuted),
                          onPressed: onClear,
                        ),
                )
              : null,
        ),
      ),
    );
  }
}
