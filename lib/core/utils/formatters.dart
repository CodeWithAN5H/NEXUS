import 'package:intl/intl.dart';

/// Pure display helpers. Kept free of Flutter imports so they are unit-testable.
abstract final class Formatters {
  static final NumberFormat _compact = NumberFormat.compact();

  /// AniList reports a 0-100 average; the reference design shows one decimal.
  static String score(int? averageScore) =>
      averageScore == null ? '—' : (averageScore / 10).toStringAsFixed(1);

  /// `782K`, `1.4M`, …
  static String compactCount(int? value) =>
      value == null ? '—' : _compact.format(value);

  /// `24:17` or `1:02:44`.
  static String clock(Duration position) {
    final Duration safe = position < Duration.zero ? Duration.zero : position;
    final int hours = safe.inHours;
    final String minutes = (safe.inMinutes % 60).toString().padLeft(
      hours > 0 ? 2 : 1,
      '0',
    );
    final String seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  /// `24 min` for an episode length in minutes.
  static String episodeLength(int? minutes) =>
      minutes == null || minutes <= 0 ? '—' : '$minutes min';

  /// `2023` or `—`.
  static String year(int? value) => value?.toString() ?? '—';

  /// `Winter 2024` style season label.
  static String season(String? season, int? year) {
    if (season == null && year == null) return '—';
    final String label = season == null
        ? ''
        : season[0] + season.substring(1).toLowerCase();
    if (season == null) return '$year';
    if (year == null) return label;
    return '$label $year';
  }

  /// `S2 · Ep 5` style progress summary.
  static String progress(int watched, int? total) {
    final String current = 'Ep $watched';
    return total == null || total <= 0 ? current : '$current of $total';
  }

  /// `68%` from a 0-1 fraction.
  static String percent(double fraction) =>
      '${(fraction.clamp(0.0, 1.0) * 100).round()}%';

  /// `2 days ago`, `just now`, `12 Mar 2024`.
  static String relativeDate(DateTime value, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final Duration diff = reference.difference(value);
    if (diff.inSeconds.abs() < 45) return 'just now';
    if (diff.inMinutes.abs() < 60) {
      final int n = diff.inMinutes.abs();
      return '$n minute${n == 1 ? '' : 's'} ago';
    }
    if (diff.inHours.abs() < 24) {
      final int n = diff.inHours.abs();
      return '$n hour${n == 1 ? '' : 's'} ago';
    }
    if (diff.inDays.abs() < 7) {
      final int n = diff.inDays.abs();
      return '$n day${n == 1 ? '' : 's'} ago';
    }
    if (diff.inDays.abs() < 365) {
      final int weeks = diff.inDays.abs() ~/ 7;
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    }
    return DateFormat.yMMMd().format(value);
  }

  /// Turns AniList's HTML-ish synopsis into plain text.
  static String plainText(String? html) {
    if (html == null || html.isEmpty) return '';
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>\s*<p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// `TV · 24 episodes · 2024`.
  static String metaLine({
    String? format,
    int? episodes,
    int? year,
    int? duration,
  }) {
    final List<String> parts = <String>[
      if (format != null && format.isNotEmpty) format,
      if (episodes != null && episodes > 0) '$episodes eps',
      if (duration != null && duration > 0) '$duration min',
      if (year != null) '$year',
    ];
    return parts.join(' · ');
  }
}
