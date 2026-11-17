import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'nexus_image.dart';

/// A single episode row.
///
/// Shows watch state, resume position and an optional thumbnail; all of them are
/// optional so the tile works for providers without artwork.
class EpisodeTile extends StatefulWidget {
  const EpisodeTile({
    required this.number,
    required this.title,
    this.thumbnail,
    this.duration,
    this.progress,
    this.watched = false,
    this.onTap,
    this.trailingLabel,
    this.subtitle,
    super.key,
  });

  final int number;
  final String title;
  final String? thumbnail;
  final Duration? duration;

  /// 0-1 resume position, or `null` when the episode was never started.
  final double? progress;
  final bool watched;
  final VoidCallback? onTap;
  final String? trailingLabel;
  final String? subtitle;

  @override
  State<EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<EpisodeTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool playable = widget.onTap != null;

    return MouseRegion(
      cursor: playable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: _hovered && playable
                ? AppColors.surfaceSecondary
                : AppColors.transparent,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 92,
                height: 52,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      NexusImage(
                        url: widget.thumbnail,
                        fallbackIcon: Icons.movie_outlined,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppDecorations.posterScrim,
                        ),
                      ),
                      if (widget.progress != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: widget.progress,
                            minHeight: 2.5,
                            backgroundColor: AppColors.surfaceElevated,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.accent,
                            ),
                          ),
                        ),
                      if (widget.watched)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${widget.number}. ${widget.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        color: widget.watched
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle ??
                          (widget.duration == null
                              ? 'Length unavailable'
                              : Formatters.clock(widget.duration!)),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (widget.trailingLabel != null)
                Text(
                  widget.trailingLabel!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                )
              else
                Icon(
                  playable
                      ? Icons.play_circle_fill_rounded
                      : Icons.lock_outline_rounded,
                  size: 22,
                  color: playable
                      ? (_hovered
                            ? AppColors.accentHover
                            : AppColors.textSecondary)
                      : AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
