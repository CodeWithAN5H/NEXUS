/// Pure parsers for AniZone's server-rendered pages.
///
/// AniZone is a Laravel + Livewire site: catalogue and episode data ship inside
/// a JavaScript `JSON.parse('…')` argument in an Alpine `x-data` attribute, the
/// player is initialised from `vidstackPlayer(JSON.parse('…'))`, and long
/// episode lists continue through a Livewire POST. Nothing here performs I/O,
/// so every structural assumption is pinned by a captured fixture.
///
/// A page that no longer contains its payload throws [AniZonePayloadException]
/// instead of returning an empty list: "the site changed" and "nothing matched"
/// must never look the same to the user. The one exception is the site's own
/// zero-result representation — a results component initialised with
/// `items: []` — which is a genuine empty result, not a missing payload.
library;

import 'dart:convert';

/// A page did not contain the payload this parser needs.
class AniZonePayloadException implements Exception {
  const AniZonePayloadException(this.message);

  final String message;

  @override
  String toString() => 'AniZonePayloadException: $message';
}

/// One catalogue entry (a search hit or a series identity).
class AniZoneEntry {
  const AniZoneEntry({
    required this.slug,
    required this.title,
    this.titles = const <String>[],
    this.year,
    this.format,
    this.episodeCount = 0,
    this.coverImage,
  });

  /// AniZone's series id — the path segment in `/anime/<slug>`.
  final String slug;

  final String title;

  /// Every title AniZone knows for this entry (romaji, English, native…).
  final List<String> titles;

  final int? year;

  /// AniZone's own type label, e.g. `TV Series`, `Movie`, `OVA`.
  final String? format;

  final int episodeCount;

  final String? coverImage;
}

/// One episode of a series.
class AniZoneEpisode {
  const AniZoneEpisode({
    required this.number,
    required this.title,
    this.duration,
    this.description,
    this.thumbnail,
    this.hasVideos = true,
  });

  /// Absolute episode number, parsed from the item's numeric slug.
  final int number;

  final String title;
  final Duration? duration;
  final String? description;
  final String? thumbnail;

  /// Whether AniZone reports at least one video for the episode.
  final bool hasVideos;
}

/// The first page of a series page, plus what is needed to continue it.
class AniZoneSeriesPage {
  const AniZoneSeriesPage({
    required this.episodes,
    required this.hasMore,
    this.cursor,
    this.csrfToken,
    this.snapshot,
  });

  final List<AniZoneEpisode> episodes;
  final bool hasMore;

  /// Opaque Livewire cursor for the next page.
  final String? cursor;

  /// CSRF token that must accompany the continuation POST.
  final String? csrfToken;

  /// Livewire component snapshot for the series page.
  final String? snapshot;
}

/// A Livewire continuation page.
class AniZoneLivewirePage {
  const AniZoneLivewirePage({
    required this.episodes,
    required this.hasMore,
    this.cursor,
    this.snapshot,
  });

  final List<AniZoneEpisode> episodes;
  final bool hasMore;
  final String? cursor;
  final String? snapshot;

  /// True when the response carried no `items-loaded` dispatch at all.
  bool get isEmpty => episodes.isEmpty && !hasMore;
}

/// One external subtitle track.
class AniZoneSubtitle {
  const AniZoneSubtitle({
    required this.label,
    required this.uri,
    this.language,
    this.format = '',
    this.isDefault = false,
  });

  final String label;
  final Uri uri;
  final String? language;

  /// `srt`, `ass`, `vtt`… lower-cased; empty when AniZone omitted it.
  final String format;

  final bool isDefault;
}

/// One audio rendition advertised by the HLS master playlist.
class AniZoneAudioGroup {
  const AniZoneAudioGroup({
    required this.label,
    this.language,
    this.isDefault = false,
  });

  final String label;
  final String? language;
  final bool isDefault;
}

/// One video rendition advertised by the HLS master playlist.
class AniZoneRendition {
  const AniZoneRendition({required this.uri, this.height, this.bandwidth});

  final Uri uri;
  final int? height;
  final int? bandwidth;
}

/// A parsed HLS master playlist.
class AniZoneMasterPlaylist {
  const AniZoneMasterPlaylist({
    this.renditions = const <AniZoneRendition>[],
    this.audioGroups = const <AniZoneAudioGroup>[],
  });

  final List<AniZoneRendition> renditions;
  final List<AniZoneAudioGroup> audioGroups;

  /// Tallest advertised rendition, when one is declared.
  int? get maxHeight {
    int? tallest;
    for (final AniZoneRendition rendition in renditions) {
      final int? height = rendition.height;
      if (height == null) continue;
      if (tallest == null || height > tallest) tallest = height;
    }
    return tallest;
  }
}

/// The playable data embedded in one episode page.
class AniZoneEpisodeSource {
  const AniZoneEpisodeSource({
    required this.master,
    this.subtitles = const <AniZoneSubtitle>[],
    this.storyboard,
    this.chapters,
  });

  /// HLS master playlist. Kept as the master so its audio groups stay usable.
  final Uri master;

  final List<AniZoneSubtitle> subtitles;
  final Uri? storyboard;
  final Uri? chapters;
}

// ── Page parsers ─────────────────────────────────────────────────────────────

/// Parses `GET /anime?search=<q>`.
///
/// Throws [AniZonePayloadException] when the payload is missing entirely;
/// returns an empty list when AniZone reports no matches — a no-match page
/// carries no `JSON.parse` argument at all, only `items: []`.
List<AniZoneEntry> parseSearchItems(String html) {
  final List<Object?> items = _itemsArgumentOrEmpty(html);
  final List<AniZoneEntry> entries = <AniZoneEntry>[];
  for (final Object? item in items) {
    final AniZoneEntry? entry = _entryFrom(item);
    if (entry != null) entries.add(entry);
  }
  return entries;
}

/// Parses `GET /anime/<slug>` (first episode page plus continuation state).
///
/// A series AniZone has no episodes for is the same `items: []` page as an
/// empty search, so it parses to an empty page instead of a failure.
AniZoneSeriesPage parseSeriesPage(String html) {
  final List<Object?> items = _itemsArgumentOrEmpty(html);
  if (items.isEmpty) {
    return const AniZoneSeriesPage(
      episodes: <AniZoneEpisode>[],
      hasMore: false,
    );
  }
  final List<AniZoneEpisode> episodes = <AniZoneEpisode>[];
  for (final Object? item in items) {
    final AniZoneEpisode? episode = _episodeFrom(item);
    if (episode != null) episodes.add(episode);
  }
  return AniZoneSeriesPage(
    episodes: _orderedUnique(episodes),
    hasMore: _boolProperty(html, 'hasMore') ?? false,
    cursor: _stringProperty(html, 'nextCursor'),
    csrfToken: _csrfToken(html),
    snapshot: _snapshot(html),
  );
}

/// Parses a `POST /livewire/update` response.
///
/// The episodes arrive through the component's `items-loaded` dispatch, not in
/// the component state, so an absent dispatch is a parse failure rather than an
/// empty page.
AniZoneLivewirePage parseLivewirePage(String body) {
  final Object? decoded = _decodeJson(body, 'Livewire response');
  final Map<String, Object?> root = _asMap(decoded);
  final List<Object?> components = _asList(root['components']);
  if (components.isEmpty) {
    throw const AniZonePayloadException('Livewire response had no components.');
  }
  final Map<String, Object?> component = _asMap(components.first);
  final Map<String, Object?> effects = _asMap(component['effects']);
  final List<Object?> dispatches = _asList(effects['dispatches']);

  Map<String, Object?>? loaded;
  for (final Object? dispatch in dispatches) {
    final Map<String, Object?> candidate = _asMap(dispatch);
    if (candidate['name'] == 'items-loaded') {
      loaded = _asMap(candidate['params']);
      break;
    }
  }
  if (loaded == null) {
    throw const AniZonePayloadException(
      'Livewire continuation carried no items-loaded dispatch.',
    );
  }

  final List<AniZoneEpisode> episodes = <AniZoneEpisode>[];
  for (final Object? item in _asList(loaded['items'])) {
    final AniZoneEpisode? episode = _episodeFrom(item);
    if (episode != null) episodes.add(episode);
  }
  final String? snapshot = _asString(component['snapshot']);
  return AniZoneLivewirePage(
    episodes: _orderedUnique(episodes),
    hasMore: loaded['hasMore'] == true,
    cursor: _asString(loaded['nextCursor']),
    snapshot: snapshot,
  );
}

/// Parses the `vidstackPlayer(JSON.parse('…'))` payload of an episode page.
AniZoneEpisodeSource parseEpisodeSource(String html) {
  final RegExp pattern = RegExp(
    r"vidstackPlayer\s*\(\s*JSON\.parse\('((?:[^'\\]|\\.)*)'\)\s*\)",
  );
  final RegExpMatch? match = pattern.firstMatch(html);
  if (match == null) {
    throw const AniZonePayloadException(
      'Episode page carried no player payload.',
    );
  }
  final Map<String, Object?> payload = _asMap(
    _decodeJson(decodeJsonArgument(match.group(1) ?? ''), 'player payload'),
  );

  final Uri? master = _httpsUri(_asString(payload['src']));
  if (master == null) {
    throw const AniZonePayloadException(
      'Player payload carried no usable stream URL.',
    );
  }

  final List<AniZoneSubtitle> subtitles = <AniZoneSubtitle>[];
  for (final Object? raw in _asList(payload['subtitles'])) {
    final Map<String, Object?> entry = _asMap(raw);
    final Uri? uri = _httpsUri(_asString(entry['file']));
    if (uri == null) continue;
    subtitles.add(
      AniZoneSubtitle(
        label: _asString(entry['title']) ?? 'Subtitles',
        uri: uri,
        language: _asString(entry['language']),
        format: (_asString(entry['format']) ?? '').toLowerCase(),
        isDefault: entry['default'] == true,
      ),
    );
  }

  return AniZoneEpisodeSource(
    master: master,
    subtitles: subtitles,
    storyboard: _httpsUri(_asString(payload['storyboard'])),
    chapters: _httpsUri(_asString(payload['chapter'])),
  );
}

/// Parses an HLS master playlist.
///
/// Returns empty lists for a document that is not `#EXTM3U` — the caller
/// decides whether a master without renditions is still playable (it is: mpv
/// follows the master itself).
AniZoneMasterPlaylist parseMasterPlaylist(
  String text, {
  required Uri masterUri,
}) {
  if (!text.trimLeft().startsWith('#EXTM3U')) {
    return const AniZoneMasterPlaylist();
  }

  final List<AniZoneAudioGroup> audioGroups = <AniZoneAudioGroup>[];
  final List<AniZoneRendition> renditions = <AniZoneRendition>[];
  String? pendingResolution;
  for (final String raw in const LineSplitter().convert(text)) {
    final String line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXT-X-MEDIA:')) {
      final Map<String, String> attributes = _attributes(
        line.substring('#EXT-X-MEDIA:'.length),
      );
      if (attributes['TYPE']?.toUpperCase() != 'AUDIO') continue;
      audioGroups.add(
        AniZoneAudioGroup(
          label: attributes['NAME'] ?? attributes['LANGUAGE'] ?? 'Audio',
          language: attributes['LANGUAGE'],
          isDefault: attributes['DEFAULT']?.toUpperCase() == 'YES',
        ),
      );
      continue;
    }
    if (line.startsWith('#EXT-X-STREAM-INF:')) {
      final Map<String, String> attributes = _attributes(
        line.substring('#EXT-X-STREAM-INF:'.length),
      );
      pendingResolution = attributes['RESOLUTION'] ?? '';
      continue;
    }
    if (line.startsWith('#')) continue;
    final Uri? uri = _httpsUri(masterUri.resolve(line).toString());
    if (uri != null && pendingResolution != null) {
      renditions.add(
        AniZoneRendition(uri: uri, height: _height(pendingResolution)),
      );
    }
    pendingResolution = null;
  }

  return AniZoneMasterPlaylist(
    renditions: List<AniZoneRendition>.unmodifiable(renditions),
    audioGroups: List<AniZoneAudioGroup>.unmodifiable(audioGroups),
  );
}

// ── Shared helpers ───────────────────────────────────────────────────────────

/// Decodes the argument of a JavaScript `JSON.parse('…')` call.
///
/// AniZone emits `\u0022`-escaped quotes and backslash-escaped slashes because
/// the document is nested twice (JSON inside a JS string inside an HTML
/// attribute). Doubly escaped sequences are preserved so the result is still
/// valid JSON, then decoded once.
String decodeJsonArgument(String raw) {
  const String marker = '\u0001U\u0001';
  String value = raw.replaceAllMapped(
    RegExp(r'\\\\u([0-9a-fA-F]{4})'),
    (Match match) => '$marker${match.group(1)}',
  );
  value = value.replaceAllMapped(
    RegExp(r'\\u([0-9a-fA-F]{4})'),
    (Match match) =>
        String.fromCharCode(int.parse(match.group(1) ?? '0', radix: 16)),
  );
  return value.replaceAll(marker, r'\u');
}

/// Normalises a URL that survived one level of JSON string escaping.
///
/// `https:\/\/host\/path` and `https:\\/\\/host` both become `https://host`.
String normaliseUrl(String value) {
  return value.replaceAll(RegExp(r'\\+/'), '/').trim();
}

/// Turns AniZone's `23:37` / `1:02:03` duration text into a [Duration].
Duration? parseDuration(String? raw) {
  final String text = (raw ?? '').trim();
  if (text.isEmpty) return null;
  final List<String> parts = text.split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final List<int?> numbers = <int?>[
    for (final String part in parts) int.tryParse(part.trim()),
  ];
  if (numbers.contains(null)) return null;
  final List<int> values = numbers.cast<int>();
  if (parts.length == 2) {
    return Duration(minutes: values[0], seconds: values[1]);
  }
  return Duration(hours: values[0], minutes: values[1], seconds: values[2]);
}

List<String> _titlesOf(Map<String, Object?> item) {
  final List<String> titles = <String>[];
  final Object? main = item['main_title'];
  if (main is String && main.trim().isNotEmpty) {
    titles.add(normaliseUrl(main));
  }
  final Map<String, Object?> list = _asMap(item['title_list']);
  for (final Object? value in list.values) {
    if (value is! String || value.trim().isEmpty) continue;
    final String title = normaliseUrl(value);
    if (!titles.contains(title)) titles.add(title);
  }
  return titles;
}

AniZoneEntry? _entryFrom(Object? raw) {
  final Map<String, Object?> item = _asMap(raw);
  final String? slug = _asString(item['slug']);
  if (slug == null || !RegExp(r'^[a-z0-9-]+$').hasMatch(slug)) return null;
  final List<String> titles = _titlesOf(item);
  if (titles.isEmpty) return null;
  return AniZoneEntry(
    slug: slug,
    title: titles.first,
    titles: titles,
    year: _asInt(item['start_year']),
    format: _asString(item['type']),
    episodeCount: _asInt(item['episode_count']) ?? 0,
    coverImage: _httpsUri(_asString(item['cover']))?.toString(),
  );
}

AniZoneEpisode? _episodeFrom(Object? raw) {
  final Map<String, Object?> item = _asMap(raw);
  final int? number =
      _asInt(item['slug']) ??
      int.tryParse(
        RegExp(r'/(\d+)/?$')
                .firstMatch(normaliseUrl(_asString(item['url']) ?? ''))
                ?.group(1) ??
            '',
      );
  if (number == null || number < 1) return null;

  final Map<String, Object?> list = _asMap(item['title_list']);
  final String? titled = _asString(list['1']) ?? _asString(list['8']);
  return AniZoneEpisode(
    number: number,
    title: titled == null ? 'Episode $number' : normaliseUrl(titled),
    duration: parseDuration(_asString(item['duration'])),
    description: _asString(item['summary']),
    thumbnail: _httpsUri(_asString(item['snapshot']))?.toString(),
    hasVideos: (_asInt(item['videos_count']) ?? 1) > 0,
  );
}

List<AniZoneEpisode> _orderedUnique(List<AniZoneEpisode> episodes) {
  final Map<int, AniZoneEpisode> byNumber = <int, AniZoneEpisode>{};
  for (final AniZoneEpisode episode in episodes) {
    byNumber[episode.number] = episode;
  }
  final List<int> numbers = byNumber.keys.toList()..sort();
  return <AniZoneEpisode>[for (final int number in numbers) byNumber[number]!];
}

/// The embedded items list, or an empty list when the page declares one.
///
/// AniZone renders no results as a component whose Alpine state starts at
/// `items: [], nextCursor: null, hasMore: false`. That is a real answer, so it
/// must not be reported as a changed layout; a page with neither form is.
List<Object?> _itemsArgumentOrEmpty(String html) {
  final RegExp pattern = RegExp(
    r"items\s*:\s*JSON\.parse\('((?:[^'\\]|\\.)*)'\)",
  );
  final RegExpMatch? match = pattern.firstMatch(html);
  if (match == null) {
    if (RegExp(r'items\s*:\s*\[\s*\]').hasMatch(html)) {
      return const <Object?>[];
    }
    throw const AniZonePayloadException(
      'Page carried no items payload — AniZone changed its markup.',
    );
  }
  final Object? decoded = _decodeJson(
    decodeJsonArgument(match.group(1) ?? ''),
    'items payload',
  );
  if (decoded is! List) {
    throw const AniZonePayloadException('Items payload was not a list.');
  }
  return decoded;
}

String? _snapshot(String html) {
  final RegExp pattern = RegExp(r'wire:snapshot="([^"]*)"');
  for (final RegExpMatch match in pattern.allMatches(html)) {
    final String value = _unescapeAttribute(match.group(1) ?? '');
    if (value.contains('anime-detail')) return value;
  }
  return null;
}

String? _csrfToken(String html) {
  final RegExpMatch? match = RegExp(
    r'<meta\s+name="csrf-token"\s+content="([^"]+)"',
  ).firstMatch(html);
  return match == null ? null : _unescapeAttribute(match.group(1) ?? '');
}

String _unescapeAttribute(String value) {
  return value
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

String? _stringProperty(String html, String name) {
  final RegExp pattern = RegExp(name + r"\s*:\s*'((?:[^'\\]|\\.)*)'");
  final RegExpMatch? match = pattern.firstMatch(html);
  if (match == null) return null;
  return match.group(1);
}

bool? _boolProperty(String html, String name) {
  final RegExpMatch? match = RegExp('$name\\s*:\\s*(true|false)')
      .firstMatch(html);
  if (match == null) return null;
  return match.group(1) == 'true';
}

/// Splits `KEY=VALUE,KEY="a,b"` attribute lists without breaking on quoted
/// commas.
Map<String, String> _attributes(String source) {
  final Map<String, String> attributes = <String, String>{};
  final StringBuffer buffer = StringBuffer();
  bool quoted = false;
  final List<String> parts = <String>[];
  for (int index = 0; index < source.length; index++) {
    final String char = source[index];
    if (char == '"') {
      quoted = !quoted;
      buffer.write(char);
      continue;
    }
    if (char == ',' && !quoted) {
      parts.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  if (buffer.isNotEmpty) parts.add(buffer.toString());

  for (final String part in parts) {
    final int equals = part.indexOf('=');
    if (equals <= 0) continue;
    final String key = part.substring(0, equals).trim().toUpperCase();
    String value = part.substring(equals + 1).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    attributes[key] = value;
  }
  return attributes;
}

int? _height(String resolution) {
  final RegExpMatch? match = RegExp(r'(\d+)\s*x\s*(\d+)')
      .firstMatch(resolution);
  if (match == null) return null;
  return int.tryParse(match.group(2) ?? '');
}

Uri? _httpsUri(String? value) {
  if (value == null) return null;
  final String text = normaliseUrl(value);
  if (text.isEmpty) return null;
  final Uri? uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  if (uri.userInfo.isNotEmpty) return null;
  if (text.length > 2048) return null;
  return uri;
}

Object? _decodeJson(String source, String what) {
  try {
    return jsonDecode(source);
  } on FormatException catch (error) {
    throw AniZonePayloadException('$what was not valid JSON: ${error.message}');
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        if (entry.key is String) entry.key! as String: entry.value,
    };
  }
  return const <String, Object?>{};
}

List<Object?> _asList(Object? value) =>
    value is List ? value.cast<Object?>() : const <Object?>[];

String? _asString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
