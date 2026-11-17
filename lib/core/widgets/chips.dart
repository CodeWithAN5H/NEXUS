import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Selectable genre pill used in Explore and the filter sheet.
class GenreChip extends StatefulWidget {
  const GenreChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.dense = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool dense;

  @override
  State<GenreChip> createState() => _GenreChipState();
}

class _GenreChipState extends State<GenreChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color background = widget.selected
        ? AppColors.accent
        : (_hovered ? AppColors.surfaceElevated : AppColors.surfaceSecondary);
    final Color foreground = widget.selected
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: EdgeInsets.symmetric(
            horizontal: widget.dense ? AppSpacing.sm + 2 : AppSpacing.md,
            vertical: widget.dense ? 6 : AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadius.pillRadius,
            border: Border.all(
              color: widget.selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Text(
            widget.label,
            style: AppTypography.label.copyWith(
              color: foreground,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small read-only pill for metadata (`★ 8.6`, `2024 · TV`).
class MetaChip extends StatelessWidget {
  const MetaChip({
    required this.label,
    this.icon,
    this.color,
    this.background,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final Color foreground = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background ?? AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.xs - 2),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rating pill with the accent star used on cards and details.
class ScoreChip extends StatelessWidget {
  const ScoreChip({required this.label, this.dense = false, super.key});

  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : AppSpacing.xs,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xs - 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.star_rounded,
            size: dense ? 11 : 13,
            color: AppColors.accent,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: dense ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Count badge used on library tabs.
class CountBadge extends StatelessWidget {
  const CountBadge({required this.count, this.highlighted = false, super.key});

  final int count;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.accent.withValues(alpha: 0.22)
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: AppTypography.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: highlighted ? AppColors.accent : AppColors.textMuted,
        ),
      ),
    );
  }
}
