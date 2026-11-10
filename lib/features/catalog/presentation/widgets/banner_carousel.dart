import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/gd_colors.dart';
import '../../../../app/theme/gd_theme.dart';
import '../../../../core/widgets/rings.dart';
import '../../data/catalog_models.dart';
import '../catalog_text.dart';

/// Opens what a banner links to: a product, a category or an external page
/// (system browser, never a web view with the session).
Future<void> openBannerLink(BuildContext context, BannerLink link) async {
  final location = link.location;
  if (location != null) {
    await context.push(location);
    return;
  }
  final uri = link.externalUri;
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Home banner carousel (PDF p.3): ~2:1 cards with the title over a dark
/// gradient, and page dots.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, required this.banners});
  final List<CatalogBanner> banners;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    return Semantics(
      label: CatalogText.banners.of(context),
      container: true,
      child: AspectRatio(
        aspectRatio: 2.15,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(GdRadius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _BannerSlide(banner: banners[i]),
              ),
              if (banners.length > 1)
                Positioned(
                  left: 20,
                  bottom: 12,
                  child: IgnorePointer(
                    child: PageDots(
                      count: banners.length,
                      index: _index,
                      inactive: context.gd.bannerInkSoft.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({required this.banner});
  final CatalogBanner banner;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final title = Text(
      banner.title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: context.gdText.title.copyWith(
        color: c.bannerInk,
        fontSize: 26,
        height: 1.1,
      ),
    );
    final hasLink = banner.link.kind != BannerLinkKind.none;
    return Semantics(
      identifier: 'home.banner.${banner.id}',
      button: hasLink,
      label: banner.title,
      excludeSemantics: true,
      onTap: hasLink ? () => openBannerLink(context, banner.link) : null,
      child: Material(
        color: c.banner,
        child: InkWell(
          onTap: hasLink ? () => openBannerLink(context, banner.link) : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (banner.hasImage) ...[
                CachedNetworkImage(
                  imageUrl: banner.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(color: c.banner),
                  errorWidget: (_, _, _) => const _RingsArt(),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.3, 1],
                      colors: [Color(0x002B2620), Color(0xD92B2620)],
                    ),
                  ),
                ),
                Positioned(left: 20, right: 20, bottom: 30, child: title),
              ] else ...[
                const _RingsArt(),
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 18,
                  right: 0,
                  child: FractionallySizedBox(
                    widthFactor: 0.6,
                    alignment: Alignment.centerLeft,
                    child: Align(alignment: Alignment.centerLeft, child: title),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The rings motif on the right of an image-less banner.
class _RingsArt extends StatelessWidget {
  const _RingsArt();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.maxHeight * 1.5;
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -size * 0.28,
            top: (constraints.maxHeight - size) / 2,
            width: size,
            height: size,
            child: GdRings(
              count: 4,
              color: context.gd.bannerInk.withValues(alpha: 0.75),
            ),
          ),
        ],
      );
    },
  );
}

/// Pill-and-dots page indicator.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.index,
    this.inactive,
  });
  final int count;
  final int index;
  final Color? inactive;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index
                  ? c.gold
                  : (inactive ?? c.lineStrong.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
