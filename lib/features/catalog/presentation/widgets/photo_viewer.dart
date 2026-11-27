import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/gd_colors.dart';
import '../../../../core/i18n/strings.dart';
import '../../data/catalog_models.dart';
import '../catalog_text.dart';

/// Opens the product's photos full screen at [initial]: the whole original
/// photo on a dark stage, swiped between, pinched or double-tapped to zoom.
Future<void> showPhotoViewer(
  BuildContext context, {
  required List<GalleryImage> images,
  required int initial,
}) {
  HapticFeedback.selectionClick();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => PhotoViewer(images: images, initial: initial),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The full-screen photo viewer of the product screen.
///
/// * A swipe moves between photos (the counter says where you are); the
///   thumbnails jump straight to one.
/// * Two fingers zoom up to 4×; a double tap zooms to 2.5× where it was
///   tapped, and back. While zoomed, a drag looks around instead of
///   changing the photo.
/// * The close button (and the system back gesture) returns to the product.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.images, required this.initial});
  final List<GalleryImage> images;
  final int initial;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initial,
  );
  late int _index = widget.initial;
  final Map<int, TransformationController> _zoom = {};
  bool _zoomed = false;
  Offset _tapAt = Offset.zero;

  static const double _doubleTapScale = 2.5;

  TransformationController _controllerFor(int i) => _zoom.putIfAbsent(i, () {
    final controller = TransformationController();
    controller.addListener(() {
      if (i != _index) return;
      final zoomed = controller.value.getMaxScaleOnAxis() > 1.01;
      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
    });
    return controller;
  });

  @override
  void dispose() {
    _pages.dispose();
    for (final controller in _zoom.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleZoom() {
    final controller = _controllerFor(_index);
    if (_zoomed) {
      controller.value = Matrix4.identity();
      return;
    }
    final p = _tapAt;
    controller.value = Matrix4.identity()
      ..translateByDouble(
        -p.dx * (_doubleTapScale - 1),
        -p.dy * (_doubleTapScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
  }

  void _goTo(int i) {
    _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final count = images.length;
    const onDark = Colors.white;
    final caption = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: onDark.withValues(alpha: 0.72));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0C0B),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          CatalogText.imageLabel.fmt(context, {
                            'i': _index + 1,
                            'n': count,
                          }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: onDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Semantics(
                      identifier: 'photo-viewer.close',
                      button: true,
                      label: Strings.close.of(context),
                      excludeSemantics: true,
                      child: Material(
                        color: onDark.withValues(alpha: 0.12),
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.close_rounded,
                                  color: onDark,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  Strings.close.of(context),
                                  style: const TextStyle(
                                    color: onDark,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('photo-viewer.pages'),
                  controller: _pages,
                  itemCount: count,
                  // Zoomed in, a drag looks around the photo instead.
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (i) {
                    _controllerFor(_index).value = Matrix4.identity();
                    setState(() {
                      _index = i;
                      _zoomed = false;
                    });
                  },
                  itemBuilder: (context, i) => Semantics(
                    image: true,
                    label: CatalogText.imageLabel.fmt(context, {
                      'i': i + 1,
                      'n': count,
                    }),
                    child: GestureDetector(
                      onDoubleTapDown: (details) =>
                          _tapAt = details.localPosition,
                      onDoubleTap: _toggleZoom,
                      child: InteractiveViewer(
                        key: ValueKey('photo-viewer.zoom.$i'),
                        transformationController: _controllerFor(i),
                        minScale: 1,
                        maxScale: 4,
                        child: SizedBox.expand(
                          child: CachedNetworkImage(
                            imageUrl: images[i].original,
                            fit: BoxFit.contain,
                            // The 1000 px copy the hero already loaded, until
                            // the original arrives (sharper, never a spinner).
                            placeholder: (_, _) => CachedNetworkImage(
                              imageUrl: images[i].url,
                              fit: BoxFit.contain,
                            ),
                            errorWidget: (_, _, _) => CachedNetworkImage(
                              imageUrl: images[i].url,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: Text(
                  _zoomed
                      ? CatalogText.viewerHintZoomed.of(context)
                      : CatalogText.viewerHint.of(context),
                  key: const ValueKey('photo-viewer.hint'),
                  textAlign: TextAlign.center,
                  style: caption,
                ),
              ),
              if (count > 1)
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: count,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final current = i == _index;
                      return Semantics(
                        identifier: 'photo-viewer.thumb.$i',
                        button: true,
                        selected: current,
                        label: CatalogText.imageLabel.fmt(context, {
                          'i': i + 1,
                          'n': count,
                        }),
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () => _goTo(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: current
                                    ? context.gd.gold
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Opacity(
                                opacity: current ? 1 : 0.55,
                                child: CachedNetworkImage(
                                  imageUrl: images[i].url,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
