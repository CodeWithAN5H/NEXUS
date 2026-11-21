import 'dart:async';

import 'package:dio/dio.dart';
import 'package:nexus/core/errors/app_failure.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/data/models/explore_filter.dart';
import 'package:nexus/data/models/media_page.dart';
import 'package:nexus/integrations/anilist/anilist_client.dart';
import 'package:nexus/integrations/anilist/anilist_metadata_provider.dart';
import 'package:nexus/integrations/providers/metadata_provider.dart';
import 'package:nexus/integrations/providers/provider_failure.dart';
import 'package:nexus/integrations/streaming/streaming_provider.dart';

const Set<ProviderCapability> _defaultCapabilities = <ProviderCapability>{
  ProviderCapability.search,
  ProviderCapability.seriesMatching,
  ProviderCapability.seasons,
  ProviderCapability.episodes,
  ProviderCapability.streams,
};

/// A configurable streaming adapter for contract and resolver tests.
///
/// It refuses every capability it does not declare, so capability honesty is
/// testable in both directions.
class FakeStreamingProvider extends StreamingProvider {
  FakeStreamingProvider({
    required this.id,
    String? name,
    this.series,
    Set<ProviderCapability>? capabilities,
    this.configuration = const <ProviderConfigField>[],
    this.contract = ProviderContractRange.current,
    this.platforms = const <ProviderPlatform>{
      ProviderPlatform.android,
      ProviderPlatform.windows,
      ProviderPlatform.linux,
    },
    this.availability = ProviderAvailability.ready,
    this.probeDelay = Duration.zero,
    this.matchDelay = Duration.zero,
    this.probeError,
    this.matchError,
    this.probeObserver,
    this.probeEndObserver,
  }) : name = name ?? 'Fake $id',
       capabilities = capabilities ?? _defaultCapabilities;

  @override
  final String id;

  @override
  final String name;

  @override
  final Set<ProviderCapability> capabilities;

  @override
  final List<ProviderConfigField> configuration;

  @override
  final ProviderContractRange contract;

  @override
  final Set<ProviderPlatform> platforms;

  final ProviderSeries? series;
  final ProviderAvailability availability;
  final Duration probeDelay;
  final Duration matchDelay;
  final Object? probeError;
  final Object? matchError;

  /// Called when a probe *starts*, used to measure concurrency.
  final void Function(FakeStreamingProvider provider)? probeObserver;

  /// Called when a probe finishes (successfully or not).
  final void Function()? probeEndObserver;

  int probeCalls = 0;
  int matchCalls = 0;
  bool disposed = false;

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Fake streaming provider for tests.';

  @override
  String get attribution => 'Test fixture';

  @override
  Future<ProviderStatusSnapshot> probe() async {
    probeCalls++;
    probeObserver?.call(this);
    try {
      if (probeDelay > Duration.zero) {
        await Future<void>.delayed(probeDelay);
      }
      if (probeError != null) throw probeError!;
      return ProviderStatusSnapshot(
        availability: availability,
        message: 'Fake source',
        observedAt: DateTime.now(),
      );
    } finally {
      probeEndObserver?.call();
    }
  }

  @override
  Future<List<ProviderSeries>> search(String query, {int page = 1}) async {
    if (!capabilities.contains(ProviderCapability.search)) {
      throw ProviderUnsupported(providerId: id, feature: 'search');
    }
    if (series == null) return const <ProviderSeries>[];
    if (query.trim().isEmpty) return <ProviderSeries>[series!];
    return series!.title.toLowerCase().contains(query.trim().toLowerCase())
        ? <ProviderSeries>[series!]
        : const <ProviderSeries>[];
  }

  @override
  Future<ProviderSeries?> match(Anime anime) async {
    if (!capabilities.contains(ProviderCapability.seriesMatching)) {
      throw ProviderUnsupported(providerId: id, feature: 'title matching');
    }
    matchCalls++;
    if (matchDelay > Duration.zero) {
      await Future<void>.delayed(matchDelay);
    }
    if (matchError != null) throw matchError!;
    return series;
  }

  @override
  Future<List<ProviderSeason>> seasons(ProviderSeries series) async {
    if (!capabilities.contains(ProviderCapability.seasons)) {
      throw ProviderUnsupported(providerId: id, feature: 'seasons');
    }
    return series.seasons;
  }

  @override
  Future<List<ProviderEpisode>> episodes(
    ProviderSeries series, {
    String? seasonId,
  }) async {
    if (!capabilities.contains(ProviderCapability.episodes)) {
      throw ProviderUnsupported(providerId: id, feature: 'episodes');
    }
    return <ProviderEpisode>[
      ProviderEpisode(
        providerId: id,
        seriesId: series.seriesId,
        episodeId: '${series.seriesId}-1',
        number: 1,
        title: 'Episode 1',
      ),
    ];
  }

  @override
  Future<EpisodeStream> resolve(
    ProviderSeries series,
    ProviderEpisode episode,
  ) async {
    if (!capabilities.contains(ProviderCapability.streams)) {
      throw ProviderUnsupported(providerId: id, feature: 'video streams');
    }
    return const EpisodeStream(
      variants: <StreamVariant>[],
      protocol: StreamProtocol.hls,
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// A metadata catalogue with no network dependency.
class FakeMetadataProvider extends MetadataProvider {
  FakeMetadataProvider({
    this.id = 'fake.metadata',
    this.items = const <Anime>[],
    this.failure,
    this.pageResults = const <int, MediaPage>{},
    Map<int, Object>? pageFailures,
    Map<int, Completer<void>>? pageGates,
  }) : pageFailures = pageFailures ?? <int, Object>{},
       pageGates = pageGates ?? <int, Completer<void>>{};

  @override
  final String id;

  final List<Anime> items;
  final Object? failure;

  /// Scripted `browse` results by page. Empty keeps the pre-paging behaviour:
  /// every browse answers [items] with no next page.
  final Map<int, MediaPage> pageResults;

  /// A browse for one of these pages throws. A test removes the entry to
  /// simulate a retry that succeeds.
  final Map<int, Object> pageFailures;

  /// A browse for one of these pages waits for the completer — used to observe
  /// in-flight appends and stale responses.
  final Map<int, Completer<void>> pageGates;

  int browseCalls = 0;
  final List<int> pagesRequested = <int>[];
  final List<ExploreFilter> filtersRequested = <ExploreFilter>[];

  bool disposed = false;
  int detailCalls = 0;

  @override
  String get name => 'Fake Catalogue';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Fake metadata provider for tests.';

  @override
  String get attribution => 'Test fixture';

  @override
  Set<MetadataCapability> get capabilities => MetadataCapability.values.toSet();

  @override
  Future<ProviderStatusSnapshot> probe() async => ProviderStatusSnapshot(
    availability: ProviderAvailability.ready,
    message: 'Fake catalogue',
    observedAt: DateTime.now(),
  );

  MediaPage _page() {
    if (failure != null) throw failure!;
    return MediaPage(items: items, hasNextPage: false, total: items.length);
  }

  @override
  Future<MediaPage> trending({int page = 1, int perPage = 20}) async => _page();

  @override
  Future<MediaPage> popular({int page = 1, int perPage = 20}) async => _page();

  @override
  Future<MediaPage> topRated({int page = 1, int perPage = 20}) async => _page();

  @override
  Future<MediaPage> recentlyUpdated({int page = 1, int perPage = 20}) async =>
      _page();

  @override
  Future<MediaPage> seasonal({
    required AnimeSeason season,
    required int year,
    int page = 1,
    int perPage = 20,
  }) async => _page();

  @override
  Future<MediaPage> browse(
    ExploreFilter filter, {
    int page = 1,
    int perPage = 24,
  }) async {
    browseCalls++;
    pagesRequested.add(page);
    filtersRequested.add(filter);
    if (pageResults.isEmpty) return _page();

    await pageGates[page]?.future;
    final Object? pageFailure = pageFailures[page];
    if (pageFailure != null) throw pageFailure;
    return pageResults[page] ??
        const MediaPage(items: <Anime>[], hasNextPage: false);
  }

  @override
  Future<MediaPage> search(
    String query, {
    int page = 1,
    int perPage = 20,
  }) async => _page();

  @override
  Future<Anime> details(int id) async {
    detailCalls++;
    if (failure != null) throw failure!;
    for (final Anime anime in items) {
      if (anime.id == id) return anime;
    }
    throw const NotFoundFailure('No such title in the fake catalogue.');
  }

  @override
  Future<List<String>> genres() async =>
      failure != null ? throw failure! : const <String>['Action', 'Drama'];

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// An AniList wrapper over a Dio that never sends a request.
AniListMetadataProvider fakeAniListProvider() =>
    AniListMetadataProvider(AniListClient(Dio()));
