import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_failure.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';

/// Renders an [AsyncValue] with consistent loading, error and data states.
///
/// Every data-dependent surface goes through this widget, so no screen has to
/// re-implement error handling.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
    this.compact = false,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;
  final Widget? loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData<T>(:final T value) => builder(context, value),
      AsyncError<T>(:final Object error) => ErrorState(
        failure: AppFailure.from(error),
        onRetry: onRetry,
        compact: compact,
      ),
      _ => loading ?? LoadingSkeleton(compact: compact),
    };
  }
}

/// Shimmering block used while content loads.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    this.width,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.sm)),
    this.compact = false,
    super.key,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final bool compact;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2, 0),
              end: Alignment(1 + t * 2, 0),
              colors: const <Color>[
                AppColors.surface,
                AppColors.surfaceSecondary,
                AppColors.surface,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Placeholder for an empty result set.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.movie_filter_outlined,
    this.action,
    this.compact = false,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: compact ? AppSpacing.lg : AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: AppColors.textMuted, size: 24),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                style: AppTypography.body,
                textAlign: TextAlign.center,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Failure surface with a retry action when the failure allows it.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.failure,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  final AppFailure failure;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: compact ? AppSpacing.lg : AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              failure.title,
              style: AppTypography.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                failure.message,
                style: AppTypography.body,
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null && failure.isRetryable) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Slim inline error for spaces that cannot show a full state.
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = InlineTone.neutral,
    this.action,
    super.key,
  });

  final String message;
  final IconData icon;
  final InlineTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (tone) {
      InlineTone.neutral => AppColors.textMuted,
      InlineTone.info => AppColors.accent,
      InlineTone.warning => AppColors.warning,
      InlineTone.error => AppColors.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            action!,
          ],
        ],
      ),
    );
  }
}

enum InlineTone { neutral, info, warning, error }

/// Retry helper that makes the intended callback explicit.
class RetryButton extends StatelessWidget {
  const RetryButton({required this.onRetry, this.label = 'Retry', super.key});

  final VoidCallback onRetry;
  final String label;

  @override
  Widget build(BuildContext context) {
    return NexusIconButton(
      icon: Icons.refresh_rounded,
      tooltip: label,
      size: 32,
      iconSize: 16,
      onPressed: onRetry,
    );
  }
}
