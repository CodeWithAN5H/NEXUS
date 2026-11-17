import 'package:material_ui/material_ui.dart';

import '../../data/models/anime.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'chips.dart';
import 'nexus_image.dart';
import 'states.dart';

/// Poster card with optional progress and save affordance.
class AnimePoster extends StatefulWidget {
  const AnimePoster({
    required this.anime,
    required this.width,
    this.onTap,
    this.showTitle = true,
    this.progress,
    this.isSaved = false,
    this.onToggleSaved,
    this.badge,
    this.heroTag,
    super.key,
  });

  final Anime anime;
  final double width;
  final VoidCallback? onTap;

  /// Shows title and meta beneath the artwork.
  final bool showTitle;

  /// 0-1 progress drawn along the bottom of the artwork.
  final double? progress;

  final bool isSaved;
  final VoidCallback? onToggleSaved;

  /// Small label over the artwork (`NEW`, `S2 E5`).
  final String? badge;

  /// Enables a shared element transition to the details screen.
  final String? heroTag;

  @override
  State<AnimePoster> createState() => _AnimePosterState();
}

class _AnimePosterState extends State<AnimePoster> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color? tint = parseHexColor(widget.anime.coverColor);
    Widget artwork = AspectRatio(
      aspectRatio: 2 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          NexusImage(
            url: widget.anime.coverImage,
            borderRadius: AppRadius.posterRadius,
            placeholderColor: tint,
          ),
          // Bottom scrim so scores and progress stay legible on bright art.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.posterRadius,
                gradient: AppDecorations.posterScrim,
              ),
            ),
          ),
          if (widget.anime.averageScore != null)
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: ScoreChip(
                label: Formatters.score(widget.anime.averageScore),
                dense: true,
              ),
            ),
          if (widget.badge != null)
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: MetaChip(
                label: widget.badge!,
                color: AppColors.textPrimary,
                background: AppColors.accent.withValues(alpha: 0.9),
              ),
            ),
          if (widget.progress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.md),
                ),
                child: LinearProgressIndicator(
                  value: widget.progress!.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: AppColors.surfaceSecondary,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
                  ),
                ),
              ),
            ),
          if (widget.onToggleSaved != null)
            Positioned(
              bottom: AppSpacing.xs,
              right: AppSpacing.xs,
              child: AnimatedOpacity(
                duration: AppDurations.fast,
                opacity: _hovered || widget.isSaved ? 1 : 0,
                child: _SaveButton(
                  isSaved: widget.isSaved,
                  onPressed: widget.onToggleSaved!,
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.heroTag != null) {
      artwork = Hero(
        tag: widget.heroTag!,
        child: Material(color: Colors.transparent, child: artwork),
      );
    }

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedScale(
                scale: _hovered ? 1.015 : 1,
                duration: AppDurations.fast,
                curve: AppDurations.standardCurve,
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.posterRadius,
                    boxShadow: _hovered
                        ? AppColors.cardShadow
                        : const <BoxShadow>[],
                  ),
                  child: artwork,
                ),
              ),
              if (widget.showTitle) ...<Widget>[
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  widget.anime.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _subtitle {
    final List<String> parts = <String>[
      ?widget.anime.format,
      if (widget.anime.seasonYear != null) '${widget.anime.seasonYear}',
    ];
    if (parts.isEmpty && widget.anime.genres.isNotEmpty) {
      return widget.anime.genres.first;
    }
    return parts.join(' · ');
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isSaved, required this.onPressed});

  final bool isSaved;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.75),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSaved ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Icon(
          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          size: 16,
          color: isSaved ? AppColors.accent : AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Section heading with an optional "See all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.onSeeAll,
    this.actionLabel = 'See all',
    this.trailing,
    super.key,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final String actionLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title, style: AppTypography.sectionTitle)),
          ?trailing,
          if (onSeeAll != null)
            _SeeAllButton(label: actionLabel, onPressed: onSeeAll!),
        ],
      ),
    );
  }
}

class _SeeAllButton extends StatefulWidget {
  const _SeeAllButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_SeeAllButton> createState() => _SeeAllButtonState();
}

class _SeeAllButtonState extends State<_SeeAllButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            children: <Widget>[
              Text(
                widget.label,
                style: AppTypography.caption.copyWith(
                  color: _hovered
                      ? AppColors.accentHover
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: _hovered ? AppColors.accentHover : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal rail of posters.
class AnimeRail extends StatelessWidget {
  const AnimeRail({
    required this.items,
    required this.posterWidth,
    this.onTap,
    this.savedIds = const <int>{},
    this.onToggleSaved,
    this.progressFor,
    this.badgeFor,
    this.heroPrefix,
    super.key,
  });

  final List<Anime> items;
  final double posterWidth;
  final void Function(Anime anime)? onTap;
  final Set<int> savedIds;
  final void Function(Anime anime)? onToggleSaved;
  final double? Function(Anime anime)? progressFor;
  final String? Function(Anime anime)? badgeFor;
  final String? heroPrefix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: posterWidth * 1.5 + 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (BuildContext context, int _) =>
            const SizedBox(width: AppSpacing.sm + 2),
        itemBuilder: (BuildContext context, int index) {
          final Anime anime = items[index];
          return AnimePoster(
            anime: anime,
            width: posterWidth,
            onTap: onTap == null ? null : () => onTap!(anime),
            isSaved: savedIds.contains(anime.id),
            onToggleSaved: onToggleSaved == null
                ? null
                : () => onToggleSaved!(anime),
            progress: progressFor?.call(anime),
            badge: badgeFor?.call(anime),
            heroTag: heroPrefix == null ? null : '$heroPrefix-${anime.id}',
          );
        },
      ),
    );
  }
}

/// Rail-shaped loading placeholder.
class RailSkeleton extends StatelessWidget {
  const RailSkeleton({required this.posterWidth, super.key});

  final double posterWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: posterWidth * 1.5 + 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (BuildContext context, int _) =>
            const SizedBox(width: AppSpacing.sm + 2),
        itemBuilder: (BuildContext context, int _) => SizedBox(
          width: posterWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: LoadingSkeleton(
                  width: posterWidth,
                  height: posterWidth * 1.5,
                  borderRadius: AppRadius.posterRadius,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              LoadingSkeleton(width: posterWidth * 0.8, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
