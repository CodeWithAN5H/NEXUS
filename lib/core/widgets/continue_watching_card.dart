import 'package:material_ui/material_ui.dart';

import '../../data/models/library.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'nexus_image.dart';

/// Landscape resume card used by the Continue Watching rail.
class ContinueWatchingCard extends StatefulWidget {
  const ContinueWatchingCard({
    required this.progress,
    required this.width,
    this.onTap,
    this.onRemove,
    super.key,
  });

  final WatchProgress progress;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  State<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<ContinueWatchingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final WatchProgress progress = widget.progress;
    final String? image = progress.bannerImage ?? progress.coverImage;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: AppRadius.cardRadius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        NexusImage(
                          url: image,
                          borderRadius: AppRadius.cardRadius,
                          fallbackIcon: Icons.play_circle_outline_rounded,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppDecorations.posterScrim,
                          ),
                        ),
                        Center(
                          child: AnimatedOpacity(
                            duration: AppDurations.fast,
                            opacity: _hovered ? 1 : 0.85,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.background.withValues(
                                  alpha: 0.55,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.textPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        if (widget.onRemove != null)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: AnimatedOpacity(
                              duration: AppDurations.fast,
                              opacity: _hovered ? 1 : 0,
                              child: GestureDetector(
                                onTap: widget.onRemove,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AppColors.background.withValues(
                                      alpha: 0.7,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: progress.fraction,
                            minHeight: 3,
                            backgroundColor: AppColors.surfaceSecondary,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.accent,
                            ),
                          ),
                        ),
                        Positioned(
                          left: AppSpacing.xs,
                          bottom: AppSpacing.xs + 2,
                          child: _EpisodePill(
                            label: 'EP ${progress.episodeNumber}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                progress.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle,
              ),
              const SizedBox(height: 2),
              Text(
                'S${progress.episodeNumber} · ${Formatters.percent(progress.fraction)} · '
                '${Formatters.clock(progress.remaining)} left',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodePill extends StatelessWidget {
  const _EpisodePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Row of resume cards with consistent sizing.
class ContinueWatchingRail extends StatelessWidget {
  const ContinueWatchingRail({
    required this.items,
    required this.cardWidth,
    this.onTap,
    this.onRemove,
    super.key,
  });

  final List<WatchProgress> items;
  final double cardWidth;
  final void Function(WatchProgress progress)? onTap;
  final void Function(WatchProgress progress)? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardWidth * 9 / 16 + 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (BuildContext context, int _) =>
            const SizedBox(width: AppSpacing.sm + 2),
        itemBuilder: (BuildContext context, int index) {
          final WatchProgress progress = items[index];
          return ContinueWatchingCard(
            progress: progress,
            width: cardWidth,
            onTap: onTap == null ? null : () => onTap!(progress),
            onRemove: onRemove == null ? null : () => onRemove!(progress),
          );
        },
      ),
    );
  }
}
