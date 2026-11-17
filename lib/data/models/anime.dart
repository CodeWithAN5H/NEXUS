/// Domain model for an anime title.
///
/// This is deliberately independent of AniList's JSON shape: [fromAniList]
/// performs the mapping so the rest of the app (and any future metadata
/// provider) speaks one language.
library;

/// An anime title with the metadata NEXUS displays.
class Anime {
  const Anime({
    required this.id,
    required this.title,
    this.romajiTitle,
    this.englishTitle,
    this.nativeTitle,
    this.coverImage,
    this.bannerImage,
    this.coverColor,
    this.averageScore,
    this.popularity,
    this.favourites,
    this.format,
    this.status,
    this.season,
    this.seasonYear,
    this.episodes,
    this.duration,
    this.genres = const <String>[],
    this.description,
    this.studios = const <String>[],
    this.relations = const <AnimeRelation>[],
    this.nextEpisode,
    this.siteUrl,
    this.isAdult = false,
  });

  /// AniList media id — the stable key used for library entries.
  final int id;

  /// Primary display title.
  final String title;
  final String? romajiTitle;
  final String? englishTitle;
  final String? nativeTitle;

  /// Large cover image URL.
  final String? coverImage;

  /// Wide banner image URL, used for cinematic headers.
  final String? bannerImage;

  /// Dominant colour provided by AniList (`#rrggbb`) for image placeholders.
  final String? coverColor;

  /// 0-100 average score.
  final int? averageScore;
  final int? popularity;
  final int? favourites;

  /// TV, MOVIE, OVA, …
  final String? format;

  /// FINISHED, RELEASING, NOT_YET_RELEASED, CANCELLED, HIATUS.
  final String? status;

  /// WINTER, SPRING, SUMMER, FALL.
  final String? season;
  final int? seasonYear;

  /// Total episode count when known.
  final int? episodes;

  /// Typical episode length in minutes.
  final int? duration;

  final List<String> genres;

  /// Synopsis, already stripped of markup.
  final String? description;

  final List<String> studios;
  final List<AnimeRelation> relations;
  final NextAiringEpisode? nextEpisode;

  /// Canonical AniList page, opened externally when the user wants more detail.
  final String? siteUrl;

  final bool isAdult;

  /// Title used in rails and cards.
  String get displayTitle =>
      _firstNonEmpty(<String?>[englishTitle, romajiTitle, title]) ?? 'Untitled';

  /// Alternative titles shown on the details screen (deduplicated, non-empty).
  List<String> get alternativeTitles {
    final List<String> values = <String>[];
    for (final String? candidate in <String?>[
      romajiTitle,
      englishTitle,
      nativeTitle,
    ]) {
      if (candidate == null) continue;
      final String trimmed = candidate.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.toLowerCase() == displayTitle.toLowerCase()) continue;
      if (values.contains(trimmed)) continue;
      values.add(trimmed);
    }
    return values;
  }

  /// `RELEASING` → `Releasing`.
  String? get statusLabel => status == null
      ? null
      : status![0] + status!.substring(1).toLowerCase().replaceAll('_', ' ');

  /// `NOT_YET_RELEASED` → `Upcoming`.
  String? get releaseLabel {
    if (status == 'RELEASING') {
      final NextAiringEpisode? next = nextEpisode;
      return next == null
          ? 'Airing'
          : 'Ep ${next.episode} in ${next.daysUntil}d';
    }
    if (status == 'NOT_YET_RELEASED') return 'Upcoming';
    if (status == 'FINISHED') return 'Finished';
    if (status == 'HIATUS') return 'On hiatus';
    if (status == 'CANCELLED') return 'Cancelled';
    return statusLabel;
  }

  /// Maps AniList's `Media` object. Unknown or missing fields degrade to null
  /// rather than throwing, so a partial response never breaks a screen.
  factory Anime.fromAniList(Map<String, dynamic> json) {
    final Map<String, dynamic> title = _asMap(json['title']);
    final Map<String, dynamic> cover = _asMap(json['coverImage']);
    final Map<String, dynamic> trailer = _asMap(json['trailer']);

    return Anime(
      id: _asInt(json['id']) ?? 0,
      title:
          _firstNonEmpty(<String?>[
            _asString(title['english']),
            _asString(title['romaji']),
            _asString(title['native']),
          ]) ??
          'Untitled',
      romajiTitle: _asString(title['romaji']),
      englishTitle: _asString(title['english']),
      nativeTitle: _asString(title['native']),
      coverImage: _firstNonEmpty(<String?>[
        _asString(cover['extraLarge']),
        _asString(cover['large']),
        _asString(cover['medium']),
      ]),
      bannerImage: _asString(json['bannerImage']),
      coverColor: _asString(cover['color']),
      averageScore: _asInt(json['averageScore']),
      popularity: _asInt(json['popularity']),
      favourites: _asInt(json['favourites']),
      format: _asString(json['format']),
      status: _asString(json['status']),
      season: _asString(json['season']),
      seasonYear: _asInt(json['seasonYear']),
      episodes: _asInt(json['episodes']),
      duration: _asInt(json['duration']),
      genres: _asStringList(json['genres']),
      description: _asString(json['description']),
      studios: _parseStudios(json['studios']),
      relations: _parseRelations(json['relations']),
      nextEpisode: NextAiringEpisode.fromAniList(json['nextAiringEpisode']),
      siteUrl: _firstNonEmpty(<String?>[
        _asString(json['siteUrl']),
        _asString(trailer['siteUrl']),
      ]),
      isAdult: json['isAdult'] == true,
    );
  }

  static List<String> _parseStudios(Object? value) {
    final Map<String, dynamic> studios = _asMap(value);
    final List<dynamic> nodes = studios['nodes'] is List
        ? studios['nodes'] as List<dynamic>
        : const <dynamic>[];
    return nodes
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> node) => _asString(node['name']))
        .whereType<String>()
        .toList(growable: false);
  }

  static List<AnimeRelation> _parseRelations(Object? value) {
    final Map<String, dynamic> relations = _asMap(value);
    final List<dynamic> edges = relations['edges'] is List
        ? relations['edges'] as List<dynamic>
        : const <dynamic>[];
    return edges
        .whereType<Map<String, dynamic>>()
        .map(AnimeRelation.fromEdge)
        .where((AnimeRelation relation) {
          return relation.id != 0;
        })
        .toList(growable: false);
  }
}

/// A related title (sequel, prequel, side story…) shown on details.
class AnimeRelation {
  const AnimeRelation({
    required this.id,
    required this.title,
    required this.relationType,
    this.coverImage,
    this.format,
  });

  final int id;
  final String title;
  final String relationType;
  final String? coverImage;
  final String? format;

  String get relationLabel {
    final String spaced = relationType.replaceAll('_', ' ').toLowerCase();
    if (spaced.isEmpty) return 'Related';
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  factory AnimeRelation.fromEdge(Map<String, dynamic> edge) {
    final Map<String, dynamic> node = _asMap(edge['node']);
    final Map<String, dynamic> title = _asMap(node['title']);
    final Map<String, dynamic> cover = _asMap(node['coverImage']);
    return AnimeRelation(
      id: _asInt(node['id']) ?? 0,
      title:
          _firstNonEmpty(<String?>[
            _asString(title['english']),
            _asString(title['romaji']),
          ]) ??
          'Untitled',
      relationType: _asString(edge['relationType']) ?? 'RELATED',
      coverImage: _firstNonEmpty(<String?>[
        _asString(cover['large']),
        _asString(cover['medium']),
      ]),
      format: _asString(node['format']),
    );
  }
}

/// The next scheduled episode for a releasing title.
class NextAiringEpisode {
  const NextAiringEpisode({
    required this.episode,
    required this.airingAt,
    required this.secondsUntil,
  });

  final int episode;
  final DateTime airingAt;
  final int secondsUntil;

  int get daysUntil => (secondsUntil / Duration.secondsPerDay).ceil();

  static NextAiringEpisode? fromAniList(Object? value) {
    final Map<String, dynamic> json = _asMap(value);
    final int? episode = _asInt(json['episode']);
    final int? airingAt = _asInt(json['airingAt']);
    if (episode == null || airingAt == null) return null;
    return NextAiringEpisode(
      episode: episode,
      airingAt: DateTime.fromMillisecondsSinceEpoch(airingAt * 1000),
      secondsUntil: _asInt(json['timeUntilAiring']) ?? 0,
    );
  }
}

// ── Safe JSON helpers ────────────────────────────────────────────────────────
// AniList responses are external input: every read is defensive.

Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String? _asString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<String> _asStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.whereType<String>().toList(growable: false);
}

String? _firstNonEmpty(List<String?> values) {
  for (final String? value in values) {
    if (value != null && value.trim().isNotEmpty) return value;
  }
  return null;
}
