import 'package:dio/dio.dart';

import '../../data/models/anime.dart';
import '../../data/models/explore_filter.dart';
import '../../data/models/media_page.dart';
import '../providers/metadata_provider.dart';
import '../providers/provider_descriptor.dart';
import '../providers/provider_state.dart';
import 'anilist_client.dart';

/// AniList as a [MetadataProvider].
///
/// The client stays AniList-specific; this wrapper is the only thing the rest of
/// the app sees, so a second catalogue (or a replacement) is another
/// implementation of the same interface. AniList supplies metadata only — it is
/// never an episode or stream source.
class AniListMetadataProvider extends MetadataProvider {
  AniListMetadataProvider(this._client);

  /// Builds the wrapper around a client that shares the app's HTTP connection
  /// pool. Keeps `AniListClient` construction inside this package.
  factory AniListMetadataProvider.withDio(Dio dio) =>
      AniListMetadataProvider(AniListClient(dio));

  final AniListClient _client;
  bool _disposed = false;

  @override
  String get id => 'anilist';

  @override
  String get name => 'AniList';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Community anime catalogue: titles, scores, relations and air dates. '
      'Metadata only — never video.';

  @override
  String get attribution => 'Metadata © AniList contributors';

  @override
  Set<MetadataCapability> get capabilities => const <MetadataCapability>{
    MetadataCapability.trending,
    MetadataCapability.seasonal,
    MetadataCapability.topRated,
    MetadataCapability.recentlyUpdated,
    MetadataCapability.search,
    MetadataCapability.filters,
    MetadataCapability.details,
    MetadataCapability.relations,
    MetadataCapability.genres,
    MetadataCapability.externalIds,
  };

  /// A local descriptor check performs no request; availability reflects whether
  /// the provider has been disposed. Never throws.
  @override
  Future<ProviderStatusSnapshot> probe() async {
    if (_disposed) {
      return ProviderStatusSnapshot(
        availability: ProviderAvailability.unavailable,
        message: 'This catalogue has been released.',
        observedAt: DateTime.now(),
      );
    }
    return ProviderStatusSnapshot(
      availability: ProviderAvailability.ready,
      message: 'AniList catalogue available.',
      observedAt: DateTime.now(),
    );
  }

  @override
  Future<MediaPage> trending({int page = 1, int perPage = 20}) =>
      _client.trending(page: page, perPage: perPage);

  @override
  Future<MediaPage> popular({int page = 1, int perPage = 20}) =>
      _client.popular(page: page, perPage: perPage);

  @override
  Future<MediaPage> topRated({int page = 1, int perPage = 20}) =>
      _client.topRated(page: page, perPage: perPage);

  @override
  Future<MediaPage> recentlyUpdated({int page = 1, int perPage = 20}) =>
      _client.recentlyUpdated(page: page, perPage: perPage);

  @override
  Future<MediaPage> seasonal({
    required AnimeSeason season,
    required int year,
    int page = 1,
    int perPage = 20,
  }) {
    return _client.seasonal(
      season: season,
      year: year,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<MediaPage> browse(
    ExploreFilter filter, {
    int page = 1,
    int perPage = 24,
  }) {
    return _client.browse(filter, page: page, perPage: perPage);
  }

  @override
  Future<MediaPage> search(String query, {int page = 1, int perPage = 20}) =>
      _client.search(query, page: page, perPage: perPage);

  @override
  Future<Anime> details(int id) => _client.details(id);

  @override
  Future<List<String>> genres() => _client.genreCollection();

  /// The HTTP client is owned by the app, not by this catalogue, so disposal is
  /// a flag change. Idempotent by design.
  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}
