import 'package:material_ui/material_ui.dart';

/// Spacing scale. Layout code uses these steps instead of magic numbers.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Horizontal page gutter on phones.
  static const double gutterCompact = 20;

  /// Horizontal page gutter on tablets and desktop.
  static const double gutterExpanded = 40;

  /// Maximum width of scrollable content on wide windows.
  static const double maxContentWidth = 1320;

  /// Height of the player control bar hit area.
  static const double playerControlHeight = 48;
}

/// Corner radii. The approved direction uses generous, consistent rounding.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 18;
  static const double xxl = 24;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius posterRadius = BorderRadius.all(
    Radius.circular(md),
  );
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(AppRadius.xxl),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(AppRadius.pill),
  );
}

/// Motion tokens. Durations are short and purposeful; nothing decorative.
abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeOutQuint;
}

/// Responsive breakpoints used by the adaptive shell and grids.
abstract final class AppBreakpoints {
  /// Phones and small windows: bottom navigation.
  static const double compact = 0;

  /// Large phones / small tablets.
  static const double medium = 600;

  /// Tablets and desktop windows: persistent sidebar.
  static const double expanded = 900;

  /// Large desktop: wider grids and artwork.
  static const double large = 1280;

  /// True when the layout should use the desktop sidebar.
  static bool usesSidebar(double width) => width >= expanded;
}

/// Shared shadows and gradients.
abstract final class AppDecorations {
  static const LinearGradient backdropScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x00000000), Color(0xCC101014), Color(0xFF101014)],
    stops: <double>[0.0, 0.72, 1.0],
  );

  static const LinearGradient sideScrim = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[Color(0xE6101014), Color(0x00101014)],
  );

  static const LinearGradient posterScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x00000000), Color(0xB3000000)],
    stops: <double>[0.45, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF9275F5), Color(0xFF6D4FD6)],
  );
}
