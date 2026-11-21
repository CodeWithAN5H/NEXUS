/// AniZone — NEXUS's first experimental third-party streaming source.
///
/// Everything AniZone-specific lives behind the ordinary [StreamingProvider]
/// contract: the resolver, the details screen, the player and the database are
/// untouched. The provider is registered disabled-by-default, is never
/// presented as licensed, and every failure it raises is a `ProviderFailure`
/// that only disables this one source.
///
/// Deliberate boundaries:
/// * No custom decryption and no DRM handling. The HLS master is handed to
///   media_kit/libmpv, which performs normal HLS AES-128 segment decryption
///   using the key URIs the playlist itself publishes.
/// * No WebView, no script execution, no backend.
/// * The master playlist stays the selected stream so the audio groups it
///   declares remain selectable in the existing player.
library;

import '../../../data/models/anime.dart';
import '../../providers/provider_failure.dart';
import '../../providers/title_matching.dart';
import '../episode_list_notice.dart';
import '../streaming_provider.dart';
import 'anizone_client.dart';
import 'anizone_parser.dart';

/// Streaming provider backed by `anizone.to`.
class AniZoneProvider extends StreamingProvider implements EpisodeListNotice {
  AniZoneProvider({AniZoneClient? client, this.maxEpisodePages = 60})
    : _client = client ?? AniZoneClient();

  /// Stable provider id — permanent once released.
  static const String providerId = 'anizone';

  /// A title match must reach this similarity before it is offered.
  static const double _minMatchScore = 0.82;

  /// Two plausible candidates closer than this are "ambiguous", never a guess.
  static const double _minMatchMargin = 0.08;

  final AniZoneClient _client;

  /// Upper bound on continuation pages (24 episodes each). 60 pages is 1 440
  /// episodes — past the longest series AniZone carries — and stops a runaway
  /// loop if the site ever reports `hasMore` forever.
  final int maxEpisodePages;

  final Map<String, String> _notices = <String, String>{};

  @override
  String get id => providerId;

  @override
  String get name => 'AniZone';

  @override
  String get version => '0.1.0';

  @override
  String get description =>
      'Experimental third-party catalogue (anizone.to) with HLS video, '
      'external subtitles and multiple audio tracks. Unofficial and '
      'unlicensed: availability can change without notice.';

  @override
  String get attribution => 'AniZone — unofficial third-party source';

  @override
  Set<ProviderCapability> get capabilities => const <ProviderCapability>{
    ProviderCapability.search,
    ProviderCapability.seriesMatching,
    ProviderCapability.episodes,
    ProviderCapability.streams,
    ProviderCapability.subtitles,
    ProviderCapability.audioTracks,
  };

  /// A short, honest note about the most recent episode list for [seriesId].
  ///
  /// `null` means the list was complete. See [EpisodeListNotice].
  @override
  String? episodeNotice(String seriesId) => _notices[seriesId];

  @override
  Future<ProviderStatusSnapshot> probe() async {
    try {
      final List<AniZoneEntry> entries = await _guard(
        () async => parseSearchItems(await _client.fetchSearch('a')),
      );
      return ProviderStatusSnapshot(
        availability: ProviderAvailability.ready,
        // One broad sample query, not the whole catalogue: the count shows that
        // the search page still parses, and is never a catalogue size.
        message: entries.isEmpty
            ? 'Reachable, but a sample search returned no entries.'
            : 'Ready — a sample search returned ${entries.length} catalogue entries.',
        observedAt: DateTime.now(),
      );
    } on ProviderFailure catch (failure) {
      return ProviderStatusSnapshot(
        availability: ProviderAvailability.unavailable,
        message: failure.message,
        observedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<List<ProviderSeries>> search(String query, {int page = 1}) async {
    // AniZone has a single search page; there is no page parameter to send.
    if (page > 1) return const <ProviderSeries>[];
    final String needle = query.trim();
    if (needle.isEmpty) return const <ProviderSeries>[];
    final List<AniZoneEntry> entries = await _guard(
      () async => parseSearchItems(await _client.fetchSearch(needle)),
    );
    return <ProviderSeries>[
      for (final AniZoneEntry entry in entries) _seriesFrom(entry),
    ];
  }

  @override
  Future<ProviderSeries?> match(Anime anime) async {
    final List<String> titles = _titlesOf(anime);
    if (titles.isEmpty) return null;

    final Map<String, AniZoneEntry> found = <String, AniZoneEntry>{};
    final List<ProviderFailure> failures = <ProviderFailure>[];
    for (final String query in _queriesFor(titles)) {
      try {
        final List<AniZoneEntry> entries = parseSearchItems(
          await _client.fetchSearch(query),
        );
        for (final AniZoneEntry entry in entries) {
          found.putIfAbsent(entry.slug, () => entry);
        }
      } on ProviderFailure catch (failure) {
        failures.add(failure);
      } on AniZonePayloadException catch (error) {
        failures.add(
          ProviderParseFailure(
            providerId: providerId,
            message: _payloadMessage,
            cause: error,
          ),
        );
      }
    }
    if (found.isEmpty) {
      // No candidates *and* a broken lookup is a failure, not "no match".
      if (failures.isNotEmpty) throw failures.first;
      return null;
    }

    final List<_ScoredEntry> scored = <_ScoredEntry>[];
    for (final AniZoneEntry entry in found.values) {
      final double titleScore = _bestTitleScore(titles, entry);
      if (titleScore < _minMatchScore) continue;
      if (!_formatsAgree(anime.format, entry.format)) continue;
      final int? year = anime.seasonYear;
      if (year != null && entry.year != null && entry.year != year) continue;
      double score = titleScore;
      if (year != null && entry.year == year) score += 0.10;
      if (_normaliseFormat(anime.format) == _normaliseFormat(entry.format)) {
        score += 0.05;
      }
      scored.add(_ScoredEntry(entry, score));
    }
    if (scored.isEmpty) return null;

    scored.sort((_ScoredEntry a, _ScoredEntry b) => b.score.compareTo(a.score));
    final _ScoredEntry best = scored.first;
    if (scored.length > 1 && best.score - scored[1].score < _minMatchMargin) {
      // Equally plausible: a sequel must never be served as the original.
      return null;
    }
    return _seriesFrom(best.entry);
  }

  @override
  Future<List<ProviderSeason>> seasons(ProviderSeries series) async {
    // AniZone models no seasons: one slug per series, sequels are their own
    // slug. `seasons` is not declared as a capability, so it throws rather than
    // inventing a season list.
    throw const ProviderUnsupported(
      providerId: providerId,
      feature: 'season data',
    );
  }

  @override
  Future<List<ProviderEpisode>> episodes(
    ProviderSeries series, {
    String? seasonId,
  }) async {
    _notices.remove(series.seriesId);
    final AniZoneSeriesPage first = await _guard(
      () async =>
          parseSeriesPage(await _client.fetchSeriesPage(series.seriesId)),
    );

    final Map<int, AniZoneEpisode> byNumber = <int, AniZoneEpisode>{
      for (final AniZoneEpisode episode in first.episodes)
        episode.number: episode,
    };

    String? cursor = first.cursor;
    String? snapshot = first.snapshot;
    final String? csrfToken = first.csrfToken;
    bool hasMore = first.hasMore;
    int pages = 1;
    String? notice;

    while (hasMore) {
      if (cursor == null || snapshot == null || csrfToken == null) {
        // The page advertised more episodes but not how to fetch them.
        notice =
            'This list may be incomplete: AniZone did not offer a way to load '
            'more episodes.';
        break;
      }
      if (pages >= maxEpisodePages) {
        notice =
            'Showing the first ${byNumber.length} episodes — the full list is '
            'longer than this source loads at once.';
        break;
      }
      try {
        final AniZoneLivewirePage page = await _guard(
          () async => parseLivewirePage(
            await _client.fetchEpisodePageContinuation(
              slug: series.seriesId,
              snapshot: snapshot!,
              csrfToken: csrfToken,
              cursor: cursor!,
            ),
          ),
        );
        for (final AniZoneEpisode episode in page.episodes) {
          byNumber[episode.number] = episode;
        }
        cursor = page.cursor;
        snapshot = page.snapshot ?? snapshot;
        hasMore = page.hasMore && page.episodes.isNotEmpty;
        pages++;
      } on ProviderCancelled {
        rethrow;
      } on ProviderFailure {
        // Partial results beat an empty tab, but the list is labelled.
        notice =
            'This list may be incomplete: AniZone stopped responding after '
            '${byNumber.length} episodes.';
        break;
      }
    }

    if (notice != null) _notices[series.seriesId] = notice;

    final List<int> numbers = byNumber.keys.toList()..sort();
    return <ProviderEpisode>[
      for (final int number in numbers)
        ProviderEpisode(
          providerId: providerId,
          seriesId: series.seriesId,
          episodeId: '$number',
          number: number,
          title: byNumber[number]!.title,
          duration: byNumber[number]!.duration,
          thumbnail: byNumber[number]!.thumbnail,
          description: byNumber[number]!.description,
        ),
    ];
  }

  /// AniZone addresses an episode by its number, so the player can resolve the
  /// selected episode without paginating the whole series first.
  @override
  Future<ProviderEpisode?> episodeByNumber(
    ProviderSeries series,
    int number,
  ) async {
    if (number < 1) return null;
    return ProviderEpisode(
      providerId: providerId,
      seriesId: series.seriesId,
      episodeId: '$number',
      number: number,
      title: 'Episode $number',
    );
  }

  @override
  Future<EpisodeStream> resolve(
    ProviderSeries series,
    ProviderEpisode episode,
  ) async {
    final AniZoneEpisodeSource source = await _guard(
      () async => parseEpisodeSource(
        await _client.fetchEpisodePage(series.seriesId, episode.number),
      ),
    );

    AniZoneMasterPlaylist master = const AniZoneMasterPlaylist();
    try {
      master = parseMasterPlaylist(
        await _client.fetchPlaylist(source.master),
        masterUri: source.master,
      );
    } on ProviderCancelled {
      rethrow;
    } on ProviderFailure {
      // The player fetches the master itself; losing only the quality/audio
      // metadata must not stop playback.
      master = const AniZoneMasterPlaylist();
    }

    final int? height = master.maxHeight;
    return EpisodeStream(
      protocol: StreamProtocol.hls,
      notice:
          'Unofficial third-party source. NEXUS does not host this video and '
          'availability can change without notice.',
      headers: <String, String>{'User-Agent': _client.userAgent},
      variants: <StreamVariant>[
        StreamVariant(
          label: height == null ? 'Auto' : 'Auto (up to ${height}p)',
          uri: source.master,
          height: height,
          isDefault: true,
          protocol: StreamProtocol.hls,
        ),
      ],
      subtitles: <SubtitleTrackInfo>[
        for (final AniZoneSubtitle subtitle in source.subtitles)
          SubtitleTrackInfo(
            label: subtitle.format.isEmpty
                ? subtitle.label
                : '${subtitle.label} · ${subtitle.format.toUpperCase()}',
            uri: subtitle.uri,
            language: subtitle.language,
            isDefault: subtitle.isDefault,
          ),
      ],
      audioTracks: <AudioTrackInfo>[
        for (final AniZoneAudioGroup group in master.audioGroups)
          AudioTrackInfo(
            label: group.label,
            language: group.language,
            isDefault: group.isDefault,
          ),
      ],
    );
  }

  @override
  Future<void> dispose() async {
    _client.close();
    _notices.clear();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  static const String _payloadMessage =
      'AniZone changed its page layout, so this source needs an update.';

  /// Maps parser and transport errors onto the contract's failure taxonomy,
  /// without ever letting a raw exception cross the boundary.
  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on ProviderFailure {
      rethrow;
    } on AniZonePayloadException catch (error) {
      throw ProviderParseFailure(
        providerId: providerId,
        message: _payloadMessage,
        cause: error,
      );
    } on FormatException catch (error) {
      throw ProviderParseFailure(
        providerId: providerId,
        message: 'AniZone returned a response NEXUS could not read.',
        cause: error,
      );
    }
  }

  ProviderSeries _seriesFrom(AniZoneEntry entry) {
    return ProviderSeries(
      providerId: providerId,
      seriesId: entry.slug,
      title: entry.title,
      coverImage: entry.coverImage,
      year: entry.year,
    );
  }

  List<String> _titlesOf(Anime anime) {
    final List<String> titles = <String>[];
    for (final String? candidate in <String?>[
      anime.displayTitle,
      anime.romajiTitle,
      anime.englishTitle,
      anime.nativeTitle,
    ]) {
      if (candidate == null) continue;
      final String trimmed = candidate.trim();
      if (trimmed.isEmpty) continue;
      if (titles.contains(trimmed)) continue;
      titles.add(trimmed);
    }
    return titles;
  }

  /// Search queries tried, in order. AniZone matches on its own titles, so the
  /// English and romaji names usually find the same entry.
  ///
  /// AniZone stores a sequel under the parent title with a year suffix
  /// (`Kusuriya no Hitorigoto (2026)`) and its search returns nothing for
  /// `… Season 3`, so each title is retried without its sequel marker.
  List<String> _queriesFor(List<String> titles) {
    final List<String> queries = <String>[];
    void add(String? value) {
      final String query = (value ?? '').trim();
      if (query.length < 3 || queries.contains(query)) return;
      queries.add(query);
    }

    for (final String title in titles.take(3)) {
      add(title);
    }
    if (queries.isEmpty) return const <String>[];
    for (final String title in titles.take(3)) {
      add(_withoutSequelMarker(title));
    }
    // A colon or dash often splits a sequel suffix AniZone stores without it.
    final String head = titles.first.split(RegExp(r'[:\-–]')).first.trim();
    if (normaliseTitle(head) != normaliseTitle(titles.first)) add(head);
    return queries;
  }

  /// `The Apothecary Diaries Season 3` → `The Apothecary Diaries`.
  ///
  /// Markers stack (`… Season 2 Part 2`), so they are removed repeatedly.
  static String? _withoutSequelMarker(String title) {
    String stripped = title.trim();
    for (int pass = 0; pass < 3; pass++) {
      final String next = stripped
          .replaceFirst(_sequelMarker, '')
          .replaceAll(RegExp(r'[\s:\-–—]+$'), '')
          .trim();
      if (next == stripped) break;
      stripped = next;
    }
    if (stripped.length < 3) return null;
    if (normaliseTitle(stripped) == normaliseTitle(title)) return null;
    return stripped;
  }

  /// Trailing markers AniZone does not carry in a title: `Season 3`,
  /// `3rd Season`, `Final Season`, `Part 2`, `S3`, `第3期`.
  static final RegExp _sequelMarker = RegExp(
    r'(?:\s*[:\-–—]\s*)?\s*(?:(?:the\s+)?(?:final\s+)?season\s+\d+|(?:the\s+)?final\s+season|part\s+\d+|\d+(?:st|nd|rd|th)\s+season|s\d+|第\s*\d+\s*期)\s*$',
    caseSensitive: false,
  );

  double _bestTitleScore(List<String> titles, AniZoneEntry entry) {
    double best = 0;
    final List<String> candidates = <String>[entry.title, ...entry.titles];
    for (final String title in titles) {
      for (final String candidate in candidates) {
        for (final String variant in <String>{
          candidate,
          _withoutSourceYear(candidate),
        }) {
          final double score = _similarity(_withoutSourceYear(title), variant);
          if (score > best) best = score;
        }
      }
    }
    return best;
  }

  /// AniZone disambiguates a sequel with a trailing year —
  /// `Kusuriya no Hitorigoto (2026)`. The year is compared on its own, so it
  /// must not pull the title comparison below the match threshold.
  static String _withoutSourceYear(String title) {
    return title.replaceFirst(RegExp(r'\s*\((?:19|20)\d{2}\)\s*$'), '').trim();
  }

  /// Normalised-title similarity: `1` for an exact match, otherwise the Dice
  /// coefficient over character bigrams, with an exact-prefix bonus.
  static double _similarity(String left, String right) {
    final String a = normaliseTitle(left);
    final String b = normaliseTitle(right);
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    if (a.length < 2 || b.length < 2) return 0;

    final Map<String, int> bigrams = <String, int>{};
    for (int index = 0; index < a.length - 1; index++) {
      final String gram = a.substring(index, index + 2);
      bigrams[gram] = (bigrams[gram] ?? 0) + 1;
    }
    int overlap = 0;
    for (int index = 0; index < b.length - 1; index++) {
      final String gram = b.substring(index, index + 2);
      final int remaining = bigrams[gram] ?? 0;
      if (remaining <= 0) continue;
      bigrams[gram] = remaining - 1;
      overlap++;
    }
    return (2 * overlap) / ((a.length - 1) + (b.length - 1));
  }

  static bool _formatsAgree(String? animeFormat, String? siteFormat) {
    final String? left = _normaliseFormat(animeFormat);
    final String? right = _normaliseFormat(siteFormat);
    if (left == null || right == null) return true;
    return left == right;
  }

  /// Maps both vocabularies onto `TV`, `TV_SHORT`, `MOVIE`, `OVA`, `ONA`,
  /// `SPECIAL`; unknown labels return `null` (treated as "no opinion").
  static String? _normaliseFormat(String? value) {
    final String text = (value ?? '').trim().toLowerCase();
    if (text.isEmpty) return null;
    if (text.contains('short')) return 'TV_SHORT';
    if (text.contains('special')) return 'SPECIAL';
    if (text.contains('movie') || text.contains('film')) return 'MOVIE';
    if (text.contains('ova')) return 'OVA';
    if (text.contains('ona') || text.contains('web') || text.contains('ona')) {
      return 'ONA';
    }
    if (text.contains('tv') || text.contains('series')) return 'TV';
    return null;
  }
}

class _ScoredEntry {
  const _ScoredEntry(this.entry, this.score);

  final AniZoneEntry entry;
  final double score;
}
