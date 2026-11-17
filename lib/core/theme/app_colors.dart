import 'package:material_ui/material_ui.dart';

/// The single source of truth for every colour used in NEXUS.
///
/// No widget may declare a raw `Color(0x...)` value; tokens from this class are
/// used instead so the approved visual direction stays consistent. Values are
/// taken verbatim from `UI_SPEC.md`.
abstract final class AppColors {
  // ── Surfaces ───────────────────────────────────────────────────────────────
  /// App background (`#101014`).
  static const Color background = Color(0xFF101014);

  /// Primary surface — cards, sheets (`#191920`).
  static const Color surface = Color(0xFF191920);

  /// Secondary surface — nested cards, input fields (`#22222B`).
  static const Color surfaceSecondary = Color(0xFF22222B);

  /// Elevated surface — menus, dialogs, hovered cards (`#292934`).
  static const Color surfaceElevated = Color(0xFF292934);

  // ── Accent ─────────────────────────────────────────────────────────────────
  /// Primary accent (`#9275F5`).
  static const Color accent = Color(0xFF9275F5);

  /// Accent on hover / pressed (`#A58AFF`).
  static const Color accentHover = Color(0xFFA58AFF);

  /// Muted accent for fills and inactive tracks (`#57449B`).
  static const Color accentMuted = Color(0xFF57449B);

  // ── Text ───────────────────────────────────────────────────────────────────
  /// Primary text (`#F3F2F8`).
  static const Color textPrimary = Color(0xFFF3F2F8);

  /// Secondary text (`#AAA9B8`).
  static const Color textSecondary = Color(0xFFAAA9B8);

  /// Muted text / timestamps (`#777685`).
  static const Color textMuted = Color(0xFF777685);

  // ── Lines & status ─────────────────────────────────────────────────────────
  /// Hairline borders (`#30303B`).
  static const Color border = Color(0xFF30303B);

  /// Success (`#63C994`).
  static const Color success = Color(0xFF63C994);

  /// Error / destructive (`#EF6475`).
  static const Color error = Color(0xFFEF6475);

  /// Warning used for partially available sources.
  static const Color warning = Color(0xFFE0B15C);

  // ── Derived helpers ────────────────────────────────────────────────────────
  /// Subtle translucent white used for overlays on artwork.
  static const Color overlayLight = Color(0x1AFFFFFF);

  /// Strong overlay used for player chrome and scrims.
  static const Color scrim = Color(0xB3000000);

  /// Transparent, for explicit gradient stops.
  static const Color transparent = Color(0x00000000);

  /// Card shadow used sparingly on elevated artwork.
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Ambient accent glow used behind the featured carousel.
  static const BoxShadow accentGlow = BoxShadow(
    color: Color(0x4D9275F5),
    blurRadius: 48,
    spreadRadius: -8,
  );
}
