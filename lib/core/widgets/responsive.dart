import 'package:material_ui/material_ui.dart';

import '../theme/app_spacing.dart';

/// Layout helpers derived from the current window size.
extension NexusLayout on BuildContext {
  Size get windowSize => MediaQuery.sizeOf(this);

  /// True when the shell should use the persistent sidebar.
  bool get usesDesktopShell => windowSize.width >= AppBreakpoints.expanded;

  /// True on large desktop windows — wider artwork and more columns.
  bool get isWideWindow => windowSize.width >= AppBreakpoints.large;

  double get pageGutter =>
      usesDesktopShell ? AppSpacing.gutterExpanded : AppSpacing.gutterCompact;

  /// Poster width for horizontal rails.
  double get railPosterWidth {
    if (isWideWindow) return 172;
    if (usesDesktopShell) return 156;
    return 128;
  }

  /// Poster width for grids.
  double get gridPosterWidth {
    if (isWideWindow) return 168;
    if (usesDesktopShell) return 150;
    return 118;
  }

  /// Number of poster columns that fit the current width.
  int gridColumns({double minWidth = 104}) {
    final double available = windowSize.width - pageGutter * 2;
    return (available / (minWidth + AppSpacing.sm + 2)).floor().clamp(2, 8);
  }

  /// Height reserved for the featured carousel on Home.
  double get heroHeight {
    if (isWideWindow) return 420;
    if (usesDesktopShell) return 380;
    return 420;
  }
}

/// Centres content and clamps it to a comfortable reading width.
class NexusContent extends StatelessWidget {
  const NexusContent({
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth,
    this.padding,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding:
              padding ?? EdgeInsets.symmetric(horizontal: context.pageGutter),
          child: child,
        ),
      ),
    );
  }
}

/// Adds a consistent page gutter without clamping width.
class NexusPagePadding extends StatelessWidget {
  const NexusPagePadding({required this.child, this.top = 0, super.key});

  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pageGutter,
        top,
        context.pageGutter,
        0,
      ),
      child: child,
    );
  }
}
