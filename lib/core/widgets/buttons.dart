import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Accent-filled call to action.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.dense = false,
    this.expand = false,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;
  final bool expand;
  final bool isLoading;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.isLoading;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: enabled
            ? (TapDownDetails _) => setState(() => _pressed = true)
            : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled
            ? (TapUpDetails _) {
                setState(() => _pressed = false);
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: AppDurations.instant,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppDurations.standardCurve,
            width: widget.expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: widget.dense ? AppSpacing.md : AppSpacing.lg,
              vertical: widget.dense ? AppSpacing.xs + 2 : AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              gradient: enabled ? AppDecorations.accentGradient : null,
              color: enabled
                  ? null
                  : AppColors.accentMuted.withValues(alpha: 0.45),
              borderRadius: AppRadius.pillRadius,
              boxShadow: enabled && _hovered
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x4D9275F5),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (widget.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textPrimary,
                      ),
                    ),
                  )
                else if (widget.icon != null)
                  Icon(
                    widget.icon,
                    size: widget.dense ? 16 : 18,
                    color: AppColors.textPrimary,
                  ),
                if (widget.isLoading || widget.icon != null)
                  const SizedBox(width: AppSpacing.xs),
                Text(
                  widget.label,
                  style: AppTypography.button.copyWith(
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined counterpart used for secondary actions.
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.dense = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;
  final bool expand;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: widget.expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: widget.dense ? AppSpacing.md : AppSpacing.lg,
            vertical: widget.dense ? AppSpacing.xs + 2 : AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: _hovered && enabled
                ? AppColors.surfaceElevated
                : AppColors.surfaceSecondary,
            borderRadius: AppRadius.pillRadius,
            border: Border.all(
              color: _hovered && enabled
                  ? AppColors.accentMuted
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(
                  widget.icon,
                  size: widget.dense ? 16 : 18,
                  color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                widget.label,
                style: AppTypography.button.copyWith(
                  color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular icon button used in app bars and overlays.
class NexusIconButton extends StatefulWidget {
  const NexusIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
    this.iconSize = 20,
    this.isActive = false,
    this.background = AppColors.surfaceSecondary,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool isActive;
  final Color background;

  @override
  State<NexusIconButton> createState() => _NexusIconButtonState();
}

class _NexusIconButtonState extends State<NexusIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isActive || _hovered
                ? AppColors.surfaceElevated
                : widget.background,
            border: Border.all(
              color: widget.isActive ? AppColors.accentMuted : AppColors.border,
            ),
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: widget.isActive ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
