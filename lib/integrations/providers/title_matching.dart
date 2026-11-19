import '../streaming/streaming_provider.dart';

/// How a set of provider candidates related to a metadata title.
enum TitleMatchKind { none, single, ambiguous }

/// Result of matching one metadata title against provider candidates.
class TitleMatchResult {
  const TitleMatchResult._({
    required this.kind,
    this.series,
    this.candidates = const <ProviderSeries>[],
  });

  const TitleMatchResult.none() : this._(kind: TitleMatchKind.none);

  const TitleMatchResult.single(ProviderSeries series)
    : this._(kind: TitleMatchKind.single, series: series);

  const TitleMatchResult.ambiguous(List<ProviderSeries> candidates)
    : this._(kind: TitleMatchKind.ambiguous, candidates: candidates);

  final TitleMatchKind kind;

  /// The unique match, when [kind] is [TitleMatchKind.single].
  final ProviderSeries? series;

  /// The equally good matches, when [kind] is [TitleMatchKind.ambiguous].
  /// Ambiguity is offered to the user; it is never resolved by guessing.
  final List<ProviderSeries> candidates;

  bool get isAmbiguous => kind == TitleMatchKind.ambiguous;
}

/// Lower-cases, folds `&` to `and`, and drops everything that is not a letter
/// or digit, so punctuation and spacing differences do not defeat a match.
///
/// `"Frieren: Beyond Journey's End"` and `"frieren beyond journeys end"` both
/// normalise to `frieren beyond journeys end`.
String normaliseTitle(String value) {
  final String folded = value.toLowerCase().replaceAll('&', ' and ');
  final StringBuffer buffer = StringBuffer();
  bool lastWasSpace = true;
  for (final int rune in folded.runes) {
    // Apostrophes are elided, not separated: "journey's" and "journeys" are
    // the same title, while "journey s" is not.
    if (rune == 0x27 || rune == 0x2019) continue;
    final bool isLetter = (rune >= 0x61 && rune <= 0x7a);
    final bool isDigit = rune >= 0x30 && rune <= 0x39;
    if (isLetter || isDigit) {
      buffer.writeCharCode(rune);
      lastWasSpace = false;
    } else if (rune > 0x7f) {
      // Non-ASCII letters are kept as-is; dropping them would erase whole
      // titles in scripts the app supports.
      buffer.writeCharCode(rune);
      lastWasSpace = false;
    } else if (!lastWasSpace) {
      buffer.write(' ');
      lastWasSpace = true;
    }
  }
  return buffer.toString().trim();
}

/// Selects the single candidate whose normalised title equals [title].
///
/// Returns `none` when nothing matches, `ambiguous` when two or more do, and
/// `single` only for exactly one candidate. A year, when both sides declare it,
/// must agree — this is the guard that stops a remake being served as the
/// original.
TitleMatchResult selectUniqueSeries(
  Iterable<ProviderSeries> candidates,
  String title, {
  int? year,
}) {
  final String target = normaliseTitle(title);
  if (target.isEmpty) return const TitleMatchResult.none();

  final List<ProviderSeries> matches = <ProviderSeries>[];
  for (final ProviderSeries candidate in candidates) {
    if (normaliseTitle(candidate.title) != target) continue;
    if (year != null && candidate.year != null && candidate.year != year) {
      continue;
    }
    matches.add(candidate);
  }

  if (matches.isEmpty) return const TitleMatchResult.none();
  if (matches.length == 1) return TitleMatchResult.single(matches.single);
  return TitleMatchResult.ambiguous(List<ProviderSeries>.unmodifiable(matches));
}
