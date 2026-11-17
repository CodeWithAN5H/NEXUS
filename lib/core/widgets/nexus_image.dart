import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Artwork loader used for every poster, banner and thumbnail.
///
/// Always renders something: a tinted placeholder while loading and a neutral
/// fallback glyph when the URL is missing or the request fails.
class NexusImage extends StatelessWidget {
  const NexusImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderColor,
    this.fallbackIcon = Icons.broken_image_outlined,
    this.alignment = Alignment.center,
    super.key,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Dominant colour from the metadata API, used to tint the placeholder.
  final Color? placeholderColor;
  final IconData fallbackIcon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final Widget content = url == null || url!.isEmpty
        ? _Fallback(icon: fallbackIcon, tint: placeholderColor)
        : CachedNetworkImage(
            imageUrl: url!,
            fit: fit,
            alignment: alignment,
            fadeInDuration: AppDurations.fast,
            placeholder: (BuildContext context, String _) =>
                _Placeholder(tint: placeholderColor),
            errorWidget: (BuildContext context, String _, Object _) =>
                _Fallback(icon: fallbackIcon, tint: placeholderColor),
          );

    final BorderRadius radius = borderRadius ?? BorderRadius.zero;
    if (radius == BorderRadius.zero) return content;
    return ClipRRect(borderRadius: radius, child: content);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.tint});

  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final Color base = tint ?? AppColors.surfaceSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            base.withValues(alpha: 0.55),
            AppColors.surfaceSecondary,
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.icon, this.tint});

  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final Color base = tint ?? AppColors.surfaceSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            base.withValues(alpha: 0.35),
            AppColors.surfaceSecondary,
          ],
        ),
      ),
      child: Center(child: Icon(icon, size: 22, color: AppColors.textMuted)),
    );
  }
}

/// Parses AniList's `#rrggbb` colour strings.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final String value = hex.replaceFirst('#', '');
  if (value.length != 6) return null;
  final int? parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}
