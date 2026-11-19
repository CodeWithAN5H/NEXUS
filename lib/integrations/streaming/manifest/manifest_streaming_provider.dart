import 'dart:convert';
import 'dart:math' as math;

import '../../../data/models/anime.dart';
import '../../providers/provider_descriptor.dart';
import '../../providers/provider_failure.dart';
import '../../providers/title_matching.dart';
import '../streaming_provider.dart';
import 'json_path_reader.dart';
import 'manifest_error.dart';
import 'manifest_http.dart';
import 'manifest_validator.dart';
import 'provider_manifest.dart';
import 'template_binder.dart';

/// Tier B: a streaming provider interpreted from a declarative manifest.
///
/// It implements exactly the same [StreamingProvider] contract as a built-in
/// adapter, so the resolver, the details screen and the player cannot tell the
/// difference. What it may do is fixed by `docs/PROVIDER_MANIFEST.md`: named
/// HTTPS requests, a JSON path subset, and a typed field mapping. There is no
/// script, expression or template logic to evaluate.
///
/// Every failure crossing this class is a [ProviderFailure]; the adapter never
/// throws a raw exception, and no message contains a configured value or a
/// stream URL.
class ManifestStreamingProvider extends StreamingProvider {
  ManifestStreamingProvider({
    required this.manifest,
    Map<String, String> config = const <String, String>{},
    ManifestTransport? transport,
    ManifestRequestGate? gate,
    Future<void> Function(Duration)? delay,
    DateTime Function()? clock,
  }) : _config = Map<String, String>.unmodifiable(config) {
    _http = ManifestHttp(
      providerId: manifest.id,
      net: manifest.net,
      errors: manifest.errors,
      transport: transport ?? DioManifestTransport(providerId: manifest.id),
      allowedOrigins: _allowedOrigins(),
      gate: gate,
      delay: delay,
      clock: clock,
    );
  }

  final ProviderManifest manifest;
  final Map<String, String> _config;
  late final ManifestHttp _http;

  /// The most recent ambiguous title match, for the details screen's "choose
  /// the right series" affordance. Never used to pick automatically.
  List<ProviderSeries> _lastAmbiguousMatch = const <ProviderSeries>[];

  /// Origin of the most recent request, used to resolve relative media URLs.
  Uri? _lastOrigin;
  bool _disposed = false;

  /// True once [dispose] has run. Used by tests to prove the registry releases
  /// instances it drops.
  bool get isDisposed => _disposed;

  List<ProviderSeries> get lastAmbiguousMatch =>
      List<ProviderSeries>.unmodifiable(_lastAmbiguousMatch);

  /// The effective allowlist, exposed for diagnostics and tests.
  Set<String> get allowedOrigins => _http.allowedOrigins;

  // ── Descriptor ────────────────────────────────────────────────────────────

  @override
  String get id => manifest.id;

  @override
  String get name => manifest.name;

  @override
  String get description => manifest.description ?? 'Installed source.';

  @override
  String get version => manifest.version;

  @override
  String get attribution => manifest.attribution;

  @override
  ProviderOrigin get origin => ProviderOrigin.userAdded;

  @override
  ProviderContractRange get contract => manifest.contractRange;

  @override
  Set<ProviderPlatform> get platforms => const <ProviderPlatform>{
    ProviderPlatform.android,
    ProviderPlatform.windows,
    ProviderPlatform.linux,
  };

  @override
  Set<ProviderCapability> get capabilities => manifest.providerCapabilities;

  @override
  List<ProviderConfigField> get configuration => <ProviderConfigField>[
    for (final ManifestConfigField field in manifest.config)
      field.toProviderConfigField(),
  ];

  /// Never includes configuration values.
  @override
  String toString() => 'ManifestStreamingProvider($id, ${manifest.version})';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<ProviderStatusSnapshot> probe() async {
    if (_http.isClosed) {
      return ProviderStatusSnapshot(
        availability: ProviderAvailability.unavailable,
        message: 'This source was removed.',
        observedAt: DateTime.now(),
      );
    }
    final List<String> missing = _missingRequiredKeys();
    if (missing.isNotEmpty) {
      return ProviderStatusSnapshot(
        availability: ProviderAvailability.unavailable,
        message: 'Setup required — add ${missing.join(', ')}.',
        observedAt: DateTime.now(),
        actionHint: 'Open this source in Settings → Sources.',
      );
    }
    try {
      final ManifestProbeRequest? probe = manifest.requests.probe;
      if (probe == null) {
        // No probe section: a connectivity check against the first declared
        // origin, with no credentials attached.
        final Uri origin = manifest.declaredOrigins.first;
        await _http.requestJson(
          uri: origin.resolve('/'),
          method: 'GET',
          headers: const <String, String>{'Accept': 'application/json'},
          timeout: Duration(milliseconds: manifest.net.timeoutMs),
          maxBytes: 16384,
          notFoundStatus: const <int>[],
        );
      } else {
        final int status = await _probeStatus(probe);
        // The probe reports through the same status policy as every request, so
        // a rejected sign-in is actionable instead of "HTTP 401".
        if (manifest.errors.unauthorisedStatus.contains(status)) {
          return ProviderStatusSnapshot(
            availability: ProviderAvailability.unavailable,
            message: ProviderAuthRejected(providerId: id).message,
            observedAt: DateTime.now(),
            actionHint: 'Replace the credentials for this source.',
          );
        }
        if (manifest.errors.rateLimitedStatus.contains(status)) {
          return ProviderStatusSnapshot(
            availability: ProviderAvailability.unavailable,
            message: 'The source is limiting requests. Try again shortly.',
            observedAt: DateTime.now(),
          );
        }
        final List<int> expected = probe.expectStatus.isEmpty
            ? const <int>[200]
            : probe.expectStatus;
        if (!expected.contains(status)) {
          return ProviderStatusSnapshot(
            availability: ProviderAvailability.unavailable,
            message: 'The source answered with HTTP $status.',
            observedAt: DateTime.now(),
          );
        }
      }
      return ProviderStatusSnapshot(
        availability: ProviderAvailability.ready,
        message: 'Ready.',
        observedAt: DateTime.now(),
      );
    } on ProviderFailure catch (failure) {
      // Probing observes; it never throws.
      return ProviderStatusSnapshot(
        availability: ProviderAvailability.unavailable,
        message: failure.message,
        observedAt: DateTime.now(),
        actionHint: failure is ProviderAuthRejected
            ? 'Replace the credentials for this source.'
            : null,
      );
    } catch (error) {
      // Even an unexpected bug in one adapter must not reach the UI: it is a
      // provider that is unavailable, not an app crash.
      return ProviderStatusSnapshot(
        availability: ProviderAvailability.unavailable,
        message: ProviderFailure.from(error, providerId: id).message,
        observedAt: DateTime.now(),
      );
    }
  }

  Future<int> _probeStatus(ManifestProbeRequest probe) {
    final Map<String, String> values = _values();
    return _http.requestStatus(
      uri: _uri(probe.spec, values),
      method: probe.spec.method,
      headers: _headers(probe.spec, values),
      timeout: Duration(milliseconds: manifest.net.timeoutMs),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _http.close();
  }

  // ── Search and matching ───────────────────────────────────────────────────

  @override
  Future<List<ProviderSeries>> search(String query, {int page = 1}) async {
    _requireCapability(
      ProviderCapability.search,
      manifest.requests.search != null,
      'search',
    );
    final ManifestSearchRequest request = manifest.requests.search!;
    _assertConfigured();
    final Map<String, String> values = _values(
      query: query,
      page: page.toString(),
    );
    final Object? json = await _request(request.spec, values);
    final List<Map<String, dynamic>> items = _items(
      json,
      request.mapping,
      maxResults: request.maxResults,
    );
    final List<ProviderSeries> series = <ProviderSeries>[];
    for (final Map<String, dynamic> item in items) {
      final ProviderSeries? mapped = _mapSeries(item, request.mapping);
      if (mapped != null) series.add(mapped);
    }
    _requireSome(items, series, 'search');
    return series;
  }

  @override
  Future<ProviderSeries?> match(Anime anime) async {
    _lastAmbiguousMatch = const <ProviderSeries>[];
    _requireCapability(
      ProviderCapability.seriesMatching,
      manifest.requests.match != null,
      'title matching',
    );
    final ManifestMatchRequest request = manifest.requests.match!;
    _assertConfigured();
    final Map<String, String> values = _values(
      query: anime.displayTitle,
      title: anime.displayTitle,
      titleRomaji: anime.romajiTitle ?? '',
      titleEnglish: anime.englishTitle ?? '',
      year: anime.seasonYear?.toString() ?? '',
    );
    final Object? json = await _request(request.spec, values);
    final List<Map<String, dynamic>> items = _items(
      json,
      request.mapping,
      maxResults: request.maxResults,
    );

    final List<ProviderSeries> passing = <ProviderSeries>[];
    final double floor = request.minConfidence;
    for (final Map<String, dynamic> item in items) {
      final ProviderSeries? series = _mapSeries(item, request.mapping);
      if (series == null) continue;
      final double confidence = _confidence(series, anime, request.strategy);
      if (confidence >= floor && confidence > 0) passing.add(series);
    }

    if (passing.length == 1) return passing.single;
    if (passing.length > 1) {
      // Never pick for the user: an ambiguous match is offered explicitly.
      _lastAmbiguousMatch = List<ProviderSeries>.unmodifiable(passing);
      return null;
    }
    return null;
  }

  double _confidence(
    ProviderSeries series,
    Anime anime,
    ManifestMatchStrategy strategy,
  ) {
    final List<String> known = <String>{
      anime.displayTitle,
      if (anime.romajiTitle != null) anime.romajiTitle!,
      if (anime.englishTitle != null) anime.englishTitle!,
      if (anime.title.isNotEmpty) anime.title,
    }.toList(growable: false);

    bool yearClash = false;
    if (strategy == ManifestMatchStrategy.normalisedTitleAndYear &&
        series.year != null &&
        anime.seasonYear != null) {
      yearClash = (series.year! - anime.seasonYear!).abs() > 1;
    }

    if (strategy == ManifestMatchStrategy.exactTitle) {
      if (yearClash) return 0;
      return known.contains(series.title) ? 1.0 : 0.0;
    }

    final String candidateNormalised = normaliseTitle(series.title);
    if (candidateNormalised.isEmpty) return 0;
    for (final String title in known) {
      if (normaliseTitle(title) == candidateNormalised) {
        if (yearClash) return 0;
        return 1.0;
      }
    }
    for (final String title in known) {
      if (_withinOneEdit(candidateNormalised, normaliseTitle(title))) {
        if (yearClash) return 0;
        return 0.8;
      }
    }
    return 0;
  }

  /// True when the edit distance is exactly one insertion, deletion or
  /// substitution — the documented 0.8-confidence case, not a fuzzy guess.
  static bool _withinOneEdit(String a, String b) {
    if (a == b) return false;
    if ((a.length - b.length).abs() > 1) return false;
    if (a.length == b.length) {
      int differences = 0;
      for (int i = 0; i < a.length; i++) {
        if (a.codeUnitAt(i) != b.codeUnitAt(i)) differences++;
        if (differences > 1) return false;
      }
      return differences == 1;
    }
    final String shorter = a.length < b.length ? a : b;
    final String longer = a.length < b.length ? b : a;
    int i = 0;
    while (i < shorter.length &&
        shorter.codeUnitAt(i) == longer.codeUnitAt(i)) {
      i++;
    }
    return shorter.substring(i) == longer.substring(i + 1);
  }

  // ── Seasons and episodes ──────────────────────────────────────────────────

  @override
  Future<List<ProviderSeason>> seasons(ProviderSeries series) async {
    _requireCapability(
      ProviderCapability.seasons,
      manifest.requests.seasons != null,
      'season data',
    );
    final List<_SeasonRecord> records = await _seasonRecords(series);
    return <ProviderSeason>[
      for (final _SeasonRecord record in records)
        ProviderSeason(
          seriesId: series.seriesId,
          seasonId: record.id,
          label: record.label,
          index: record.index,
        ),
    ];
  }

  @override
  Future<List<ProviderEpisode>> episodes(
    ProviderSeries series, {
    String? seasonId,
  }) async {
    _requireCapability(
      ProviderCapability.episodes,
      manifest.requests.episodes != null,
      'episodes',
    );
    final ManifestEpisodesRequest request = manifest.requests.episodes!;
    _assertConfigured();

    int seasonIndex = 0;
    int offset = 0;
    if (request.numbering == ManifestNumbering.seasonRelative) {
      if (manifest.requests.seasons == null) {
        throw ProviderParseFailure(
          providerId: id,
          message:
              'This source numbers episodes per season but declares no seasons '
              'request, so absolute numbers cannot be computed.',
        );
      }
      final List<_SeasonRecord> records = await _seasonRecords(series);
      int target = 0;
      if (seasonId != null) {
        final int found = records.indexWhere(
          (_SeasonRecord record) => record.id == seasonId,
        );
        if (found >= 0) target = records[found].index;
      }
      for (final _SeasonRecord record in records) {
        if (record.index >= target) continue;
        final int? count = record.episodeCount;
        if (count == null) {
          throw ProviderParseFailure(
            providerId: id,
            message:
                'An earlier season does not declare its episode count, so '
                'absolute numbering cannot be computed.',
          );
        }
        offset += count;
      }
      seasonIndex = target;
    }

    final Map<String, String> values = _values(
      seriesId: series.seriesId,
      seasonId: seasonId ?? '',
      seasonIndex: seasonIndex.toString(),
    );
    final Object? json = await _request(request.spec, values);
    final List<Map<String, dynamic>> items = _items(
      json,
      request.mapping,
      maxResults: 2000,
    );

    final List<ProviderEpisode> episodes = <ProviderEpisode>[];
    for (final Map<String, dynamic> item in items) {
      final String? episodeId = _textAt(
        item,
        request.mapping.path('episodeId'),
        maxLength: 2048,
      );
      final int? number = _intAt(item, request.mapping.path('number'));
      final String? title = _textAt(
        item,
        request.mapping.path('title'),
        maxLength: 300,
      );
      if (episodeId == null || number == null || title == null) continue;
      episodes.add(
        ProviderEpisode(
          providerId: id,
          seriesId: series.seriesId,
          episodeId: episodeId,
          number: number + offset,
          title: title,
          seasonId:
              _textAt(item, request.mapping.path('seasonId'), maxLength: 128) ??
              seasonId,
          duration: _durationAt(item, request.mapping.path('durationSeconds')),
          thumbnail: _httpsAt(item, request.mapping.path('thumbnail')),
          description: _textAt(
            item,
            request.mapping.path('description'),
            maxLength: 2000,
          ),
        ),
      );
    }
    _requireSome(items, episodes, 'episode list');
    episodes.sort(
      (ProviderEpisode a, ProviderEpisode b) => a.number.compareTo(b.number),
    );
    return episodes;
  }

  Future<List<_SeasonRecord>> _seasonRecords(ProviderSeries series) async {
    final ManifestSeasonsRequest? request = manifest.requests.seasons;
    if (request == null) {
      throw ProviderUnsupported(providerId: id, feature: 'season data');
    }
    _assertConfigured();
    final Map<String, String> values = _values(seriesId: series.seriesId);
    final Object? json = await _request(request.spec, values);
    final List<Map<String, dynamic>> items = _items(
      json,
      request.mapping,
      maxResults: 200,
    );
    final List<_SeasonRecord> records = <_SeasonRecord>[];
    for (int i = 0; i < items.length; i++) {
      final Map<String, dynamic> item = items[i];
      final String? seasonId = _textAt(
        item,
        request.mapping.path('seasonId'),
        maxLength: 2048,
      );
      final String? label = _textAt(
        item,
        request.mapping.path('label'),
        maxLength: 40,
      );
      final int? index = _intAt(item, request.mapping.path('index'));
      if (seasonId == null || label == null) continue;
      records.add(
        _SeasonRecord(
          id: seasonId,
          label: label,
          index: index ?? i,
          episodeCount: _intAt(item, request.mapping.path('episodeCount')),
        ),
      );
    }
    _requireSome(items, records, 'season list');
    return records;
  }

  // ── Resolve ───────────────────────────────────────────────────────────────

  @override
  Future<EpisodeStream> resolve(
    ProviderSeries series,
    ProviderEpisode episode,
  ) async {
    _requireCapability(
      ProviderCapability.streams,
      manifest.requests.resolve != null,
      'video streams',
    );
    final ManifestResolveRequest request = manifest.requests.resolve!;
    _assertConfigured();

    final Map<String, String> values = _values(
      seriesId: series.seriesId,
      episodeId: episode.episodeId,
    );
    final Object? json = await _request(request.spec, values);

    final List<Map<String, dynamic>> rawVariants = _items(
      json,
      request.variants,
      maxResults: 32,
    );
    final List<StreamVariant> variants = <StreamVariant>[];
    for (final Map<String, dynamic> item in rawVariants) {
      final String? label = _textAt(
        item,
        request.variants.path('label'),
        maxLength: 40,
      );
      final Uri? uri = _mediaUriAt(item, request.variants.path('uri'));
      if (label == null || uri == null) continue;
      variants.add(
        StreamVariant(
          label: label,
          uri: uri,
          height: _intAt(item, request.variants.path('height')),
          isDefault: _boolAt(item, request.variants.path('isDefault')),
          protocol: _protocolAt(
            item,
            request.variants.path('protocol'),
            uri,
            request.defaultProtocol,
          ),
        ),
      );
    }
    if (rawVariants.isNotEmpty && variants.isEmpty) {
      // A list was returned but nothing survived validation: refuse rather than
      // hand the player zero playable streams.
      throw ProviderInvalidStream(
        providerId: id,
        message: 'This source returned no playable stream for that episode.',
      );
    }

    return EpisodeStream(
      protocol: variants.isEmpty
          ? _protocol(request.defaultProtocol)
          : variants.first.protocol,
      notice: manifest.notice,
      variants: variants,
      subtitles: _subtitles(request, json),
      audioTracks: _audio(request, json),
      headers: _streamHeaders(request, values),
    );
  }

  List<SubtitleTrackInfo> _subtitles(
    ManifestResolveRequest request,
    Object? json,
  ) {
    final ManifestListMapping? mapping = request.subtitles;
    if (mapping == null) return const <SubtitleTrackInfo>[];
    final List<Map<String, dynamic>> items = _tryItems(
      json,
      mapping,
      maxResults: 64,
    );
    final List<SubtitleTrackInfo> tracks = <SubtitleTrackInfo>[];
    for (final Map<String, dynamic> item in items) {
      final String? label = _textAt(item, mapping.path('label'), maxLength: 40);
      final Uri? uri = _mediaUriAt(item, mapping.path('uri'));
      if (label == null || uri == null) continue;
      tracks.add(
        SubtitleTrackInfo(
          label: label,
          uri: uri,
          language: _languageAt(item, mapping.path('language')),
          isDefault: _boolAt(item, mapping.path('isDefault')),
        ),
      );
    }
    return tracks;
  }

  List<AudioTrackInfo> _audio(ManifestResolveRequest request, Object? json) {
    final ManifestListMapping? mapping = request.audio;
    if (mapping == null) return const <AudioTrackInfo>[];
    final List<Map<String, dynamic>> items = _tryItems(
      json,
      mapping,
      maxResults: 32,
    );
    final List<AudioTrackInfo> tracks = <AudioTrackInfo>[];
    for (final Map<String, dynamic> item in items) {
      final String? label = _textAt(item, mapping.path('label'), maxLength: 40);
      if (label == null) continue;
      tracks.add(
        AudioTrackInfo(
          label: label,
          language: _languageAt(item, mapping.path('language')),
          isDefault: _boolAt(item, mapping.path('isDefault')),
        ),
      );
    }
    return tracks;
  }

  Map<String, String> _streamHeaders(
    ManifestResolveRequest request,
    Map<String, String> values,
  ) {
    if (request.streamHeaders.isEmpty) return const <String, String>{};
    final TemplateBinder binder = TemplateBinder(values: values);
    return <String, String>{
      for (final MapEntry<String, String> entry
          in request.streamHeaders.entries)
        entry.key: binder.bindHeader(
          entry.value,
          providerId: id,
          headerName: entry.key,
        ),
    };
  }

  static StreamProtocol _protocol(ManifestProtocol protocol) =>
      switch (protocol) {
        ManifestProtocol.hls => StreamProtocol.hls,
        ManifestProtocol.dash => StreamProtocol.dash,
        ManifestProtocol.progressive => StreamProtocol.progressive,
      };

  StreamProtocol _protocolAt(
    Map<String, dynamic> item,
    String? path,
    Uri uri,
    ManifestProtocol fallback,
  ) {
    final String? declared = _textAt(item, path, maxLength: 20)?.toLowerCase();
    switch (declared) {
      case 'hls':
        return StreamProtocol.hls;
      case 'dash':
        return StreamProtocol.dash;
      case 'progressive':
        return StreamProtocol.progressive;
    }
    final String path_ = uri.path.toLowerCase();
    if (path_.endsWith('.m3u8')) return StreamProtocol.hls;
    if (path_.endsWith('.mpd')) return StreamProtocol.dash;
    return _protocol(fallback);
  }

  // ── Request building ──────────────────────────────────────────────────────

  Future<Object?> _request(
    ManifestRequestSpec spec,
    Map<String, String> values,
  ) {
    final Uri uri = _uri(spec, values);
    final Map<String, String> headers = _headers(spec, values);
    final String? body = _body(spec, values);
    final int timeoutMs = math.min(
      spec.timeoutMs ?? manifest.net.timeoutMs,
      manifest.net.timeoutMs,
    );
    final int maxBytes = math.min(
      spec.maxBytes ?? manifest.net.maxResponseBytes,
      manifest.net.maxResponseBytes,
    );
    return _http.requestJson(
      uri: uri,
      method: spec.method,
      headers: headers,
      body: body,
      timeout: Duration(milliseconds: timeoutMs),
      maxBytes: maxBytes,
      notFoundStatus: spec.notFoundStatus,
    );
  }

  Uri _uri(ManifestRequestSpec spec, Map<String, String> values) {
    final TemplateBinder binder = TemplateBinder(values: values);
    final String bound = binder.bindUriComponent(
      spec.url,
      providerId: id,
      path: 'url',
    );
    final Uri? parsed = Uri.tryParse(bound);
    if (parsed == null ||
        parsed.scheme != 'https' ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty) {
      throw ProviderManifestInvalid(
        providerId: id,
        message:
            'The manifest built a request URL that is not a valid HTTPS URL.',
      );
    }
    Uri uri = parsed;
    if (spec.query.isNotEmpty) {
      uri = uri.replace(
        queryParameters: <String, String>{
          ...uri.queryParameters,
          for (final MapEntry<String, String> entry in spec.query.entries)
            entry.key: binder.bindQueryValue(
              entry.value,
              providerId: id,
              name: entry.key,
            ),
        },
      );
    }
    _lastOrigin = Uri(
      scheme: 'https',
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    );
    return uri;
  }

  Map<String, String> _headers(
    ManifestRequestSpec spec,
    Map<String, String> values,
  ) {
    if (spec.headers.isEmpty) return const <String, String>{};
    final TemplateBinder binder = TemplateBinder(values: values);
    return <String, String>{
      for (final MapEntry<String, String> entry in spec.headers.entries)
        entry.key: binder.bindHeader(
          entry.value,
          providerId: id,
          headerName: entry.key,
        ),
    };
  }

  String? _body(ManifestRequestSpec spec, Map<String, String> values) {
    if (spec.body.isEmpty) return null;
    final TemplateBinder binder = TemplateBinder(values: values);
    final Map<String, Object?> encoded = <String, Object?>{};
    for (final MapEntry<String, Object?> entry in spec.body.entries) {
      final Object? value = entry.value;
      encoded[entry.key] = value is String
          ? binder.bindScalar(value, providerId: id, field: entry.key)
          : value;
    }
    return jsonEncode(encoded);
  }

  /// Placeholder values for one call. Only the fields the request may use are
  /// populated; a template referencing anything else fails at binding time and
  /// is refused by validation first.
  Map<String, String> _values({
    String? query,
    String? page,
    String? title,
    String? titleRomaji,
    String? titleEnglish,
    String? year,
    String? seriesId,
    String? seasonId,
    String? seasonIndex,
    String? episodeId,
  }) {
    final Map<String, String> values = <String, String>{};
    String? baseUrl;
    for (final ManifestConfigField field in manifest.config) {
      final String? value = _config[field.key] ?? field.defaultValue;
      if (value == null) continue;
      values['config.${field.key}'] = value;
      if (field.key == 'baseUrl') baseUrl = value;
    }
    if (baseUrl != null) values['baseUrl'] = baseUrl;
    if (query != null) values['query'] = query;
    if (page != null) values['page'] = page;
    if (title != null) values['title'] = title;
    if (titleRomaji != null) values['titleRomaji'] = titleRomaji;
    if (titleEnglish != null) values['titleEnglish'] = titleEnglish;
    if (year != null) values['year'] = year;
    if (seriesId != null) values['seriesId'] = seriesId;
    if (seasonId != null) values['seasonId'] = seasonId;
    if (seasonIndex != null) values['seasonIndex'] = seasonIndex;
    if (episodeId != null) values['episodeId'] = episodeId;
    return values;
  }

  Set<Uri> _allowedOrigins() {
    final Set<Uri> origins = <Uri>{...manifest.declaredOrigins};
    for (final ManifestConfigField field in manifest.config) {
      if (field.type != ProviderConfigType.url) continue;
      final String? value = _config[field.key] ?? field.defaultValue;
      if (value == null) continue;
      final Uri? uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) continue;
      origins.add(
        Uri(
          scheme: 'https',
          host: uri.host,
          port: uri.hasPort ? uri.port : null,
        ),
      );
    }
    return origins;
  }

  // ── Configuration ─────────────────────────────────────────────────────────

  List<String> _missingRequiredKeys() => <String>[
    for (final ManifestConfigField field in manifest.config)
      if (field.required &&
          (_config[field.key] ?? field.defaultValue ?? '').trim().isEmpty)
        field.key,
  ];

  void _assertConfigured() {
    final List<String> missing = _missingRequiredKeys();
    if (missing.isEmpty) return;
    throw ProviderNotConfigured(
      providerId: id,
      message: 'Set up this source: add ${missing.join(', ')}.',
    );
  }

  void _requireCapability(
    ProviderCapability capability,
    bool backed,
    String feature,
  ) {
    if (!capabilities.contains(capability) || !backed) {
      throw ProviderUnsupported(providerId: id, feature: feature);
    }
  }

  // ── Mapping helpers ───────────────────────────────────────────────────────

  List<Map<String, dynamic>> _items(
    Object? json,
    ManifestListMapping mapping, {
    required int maxResults,
  }) {
    final JsonPath? path = JsonPath.tryParse(mapping.list);
    if (path == null) {
      throw ProviderManifestInvalid(
        providerId: id,
        message: 'The manifest contains an unsupported JSON path.',
      );
    }
    final Object? raw = path.readRaw(json);
    if (raw == null) {
      throw ProviderParseFailure(
        providerId: id,
        message: 'The source did not return the list this manifest expects.',
      );
    }
    if (raw is! List) {
      throw ProviderParseFailure(
        providerId: id,
        message:
            'The source returned an object where this manifest expects a list.',
      );
    }
    final int count = math.min(raw.length, maxResults);
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    for (int i = 0; i < count; i++) {
      final Object? item = raw[i];
      if (item is Map<String, dynamic>) {
        items.add(item);
      } else if (item is Map) {
        items.add(Map<String, dynamic>.from(item));
      }
    }
    return items;
  }

  /// Like [_items], but an absent list is an empty list rather than a failure —
  /// used for optional subtitle and audio sections.
  List<Map<String, dynamic>> _tryItems(
    Object? json,
    ManifestListMapping mapping, {
    required int maxResults,
  }) {
    final JsonPath? path = JsonPath.tryParse(mapping.list);
    if (path == null) return const <Map<String, dynamic>>[];
    final Object? raw = path.readRaw(json);
    if (raw is! List) return const <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[
      for (final Object? item in raw.take(maxResults))
        if (item is Map<String, dynamic>) item,
    ];
  }

  /// An entire response whose items were all unusable is a parse failure, not
  /// an empty result (PROVIDER_MANIFEST.md §6.4).
  void _requireSome(
    List<Map<String, dynamic>> rawItems,
    List<Object> mapped,
    String what,
  ) {
    if (rawItems.isEmpty) return;
    if (mapped.isNotEmpty) return;
    throw ProviderParseFailure(
      providerId: id,
      message:
          'The source returned $what entries, but none had the fields this '
          'manifest requires.',
    );
  }

  ProviderSeries? _mapSeries(
    Map<String, dynamic> item,
    ManifestListMapping mapping,
  ) {
    final String? seriesId = _textAt(
      item,
      mapping.path('seriesId'),
      maxLength: 2048,
    );
    final String? title = _textAt(item, mapping.path('title'), maxLength: 300);
    if (seriesId == null || title == null) return null;
    return ProviderSeries(
      providerId: id,
      seriesId: seriesId,
      title: title,
      coverImage: _httpsAt(item, mapping.path('coverImage')),
      synopsis: _textAt(item, mapping.path('synopsis'), maxLength: 4000),
      year: _intAt(item, mapping.path('year')),
    );
  }

  Object? _valueAt(Map<String, dynamic> item, String? path) {
    if (path == null) return null;
    return JsonPath.tryParse(path)?.read(item);
  }

  String? _textAt(
    Map<String, dynamic> item,
    String? path, {
    required int maxLength,
  }) {
    final Object? value = _valueAt(item, path);
    final String? text = switch (value) {
      String value => value,
      int value => value.toString(),
      double value when value == value.roundToDouble() =>
        value.toInt().toString(),
      bool value => value.toString(),
      _ => null,
    };
    if (text == null) return null;
    final String clean = _plainText(text);
    if (clean.isEmpty) return null;
    return clean.length > maxLength ? clean.substring(0, maxLength) : clean;
  }

  int? _intAt(Map<String, dynamic> item, String? path) {
    final Object? value = _valueAt(item, path);
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) return value.toInt();
    if (value is String) {
      final num? parsed = num.tryParse(value.trim());
      if (parsed != null && parsed == parsed.roundToDouble()) {
        return parsed.toInt();
      }
    }
    return null;
  }

  bool _boolAt(Map<String, dynamic> item, String? path) {
    final Object? value = _valueAt(item, path);
    if (value == true || value == 1) return true;
    if (value is String) {
      final String lower = value.trim().toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }

  Duration? _durationAt(Map<String, dynamic> item, String? path) {
    final Object? value = _valueAt(item, path);
    int? seconds;
    if (value is num) {
      seconds = value.round();
    } else if (value is String) {
      seconds = _parseDuration(value.trim());
    }
    if (seconds == null) return null;
    return Duration(seconds: seconds.clamp(0, 24 * 60 * 60));
  }

  String? _languageAt(Map<String, dynamic> item, String? path) {
    final String? raw = _textAt(item, path, maxLength: 35);
    if (raw == null) return null;
    return RegExp(r'^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$').hasMatch(raw)
        ? raw
        : null;
  }

  /// A thumbnail or cover image: https only, else `null`.
  String? _httpsAt(Map<String, dynamic> item, String? path) {
    final String? raw = _textAt(item, path, maxLength: 2048);
    if (raw == null) return null;
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return raw;
  }

  /// A media URL, validated before it can reach the player.
  Uri? _mediaUriAt(Map<String, dynamic> item, String? path) {
    final String? raw = _textAt(item, path, maxLength: 2048);
    if (raw == null) return null;
    Uri? uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (!uri.hasScheme) {
      final Uri? base = _lastOrigin;
      if (base == null) return null;
      uri = base.resolveUri(uri);
    }
    return _http.validateMediaUri(uri);
  }

  /// Trims, strips control characters, and collapses whitespace. HTML is never
  /// parsed: the UI renders plain text, so there is no markup injection path.
  static String _plainText(String value) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in value.runes) {
      if (rune < 0x20 || rune == 0x7f) {
        if (rune == 0x09 || rune == 0x0a || rune == 0x0d) buffer.write(' ');
        continue;
      }
      buffer.writeCharCode(rune);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int? _parseDuration(String value) {
    final RegExp clock = RegExp(r'^(?:(\d{1,2}):)?(\d{1,3}):(\d{1,2})$');
    final RegExpMatch? match = clock.firstMatch(value);
    if (match != null) {
      final int hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final int minutes = int.parse(match.group(2)!);
      final int seconds = int.parse(match.group(3)!);
      return hours * 3600 + minutes * 60 + seconds;
    }
    final RegExpMatch? iso = RegExp(
      r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (iso != null) {
      return (int.tryParse(iso.group(1) ?? '0') ?? 0) * 3600 +
          (int.tryParse(iso.group(2) ?? '0') ?? 0) * 60 +
          (int.tryParse(iso.group(3) ?? '0') ?? 0);
    }
    return null;
  }
}

/// Validates a manifest document and builds a provider, isolating a broken
/// manifest to its own result rather than to the caller.
class ManifestProviderFactory {
  const ManifestProviderFactory();

  /// Validates [json] and returns either a provider or a typed failure.
  ///
  /// Never throws for bad input: a malformed manifest is data, not a crash.
  ManifestProviderLoad create(
    String json, {
    Map<String, String> config = const <String, String>{},
    ManifestTransport? transport,
    ManifestRequestGate? gate,
    Set<String> builtInIds = const <String>{},
  }) {
    final ManifestValidationResult result = ManifestValidator(
      builtInIds: builtInIds,
    ).validate(json);

    switch (result.status) {
      case ManifestStatus.valid:
        return ManifestProviderLoad(
          provider: ManifestStreamingProvider(
            manifest: result.manifest!,
            config: config,
            transport: transport,
            gate: gate,
          ),
          status: result.status,
          manifest: result.manifest,
          compatibility: result.compatibility,
        );
      case ManifestStatus.invalid:
        return ManifestProviderLoad(
          status: result.status,
          errors: result.errors,
          failure: ProviderManifestInvalid(
            providerId: 'manifest',
            message: result.errors.isEmpty
                ? 'This manifest is not valid.'
                : 'This manifest has ${result.errors.length} '
                      '${result.errors.length == 1 ? 'problem' : 'problems'}: '
                      '${result.errors.first.message}',
          ),
        );
      case ManifestStatus.requiresNewerApp:
        return ManifestProviderLoad(
          status: result.status,
          failure: const ProviderManifestInvalid(
            providerId: 'manifest',
            message:
                'This manifest uses a newer format than this build of NEXUS.',
          ),
        );
      case ManifestStatus.unsupportedContract:
        return ManifestProviderLoad(
          status: result.status,
          manifest: result.manifest,
          compatibility: result.compatibility,
          failure: ProviderManifestInvalid(
            providerId: result.manifest?.id ?? 'manifest',
            message:
                'This source targets provider contract '
                '${result.manifest?.contractRange}, which this build does not '
                'support.',
          ),
        );
    }
  }
}

/// Outcome of loading one manifest: exactly one of [provider] or [failure].
class ManifestProviderLoad {
  const ManifestProviderLoad({
    required this.status,
    this.provider,
    this.failure,
    this.errors = const <ManifestError>[],
    this.manifest,
    this.compatibility = ProviderCompatibility.compatible,
  });

  final ManifestStatus status;
  final ManifestStreamingProvider? provider;
  final ProviderFailure? failure;
  final List<ManifestError> errors;

  /// The parsed document, when the format is understood — present for
  /// [ManifestStatus.unsupportedContract] so the provider can be listed without
  /// ever being invoked.
  final ProviderManifest? manifest;
  final ProviderCompatibility compatibility;

  bool get isUsable => provider != null;
}

class _SeasonRecord {
  const _SeasonRecord({
    required this.id,
    required this.label,
    required this.index,
    this.episodeCount,
  });

  final String id;
  final String label;
  final int index;
  final int? episodeCount;
}
