import '../../data/models/anime.dart';
import '../../data/models/explore_filter.dart';
import '../../data/models/media_page.dart';
import 'provider_descriptor.dart';
import 'provider_state.dart';

/// A replaceable source of **metadata** only.
///
/// AniList is the first implementation, not a special case: `MetadataRepository`
/// depends on this interface, so a second catalogue (MyAnimeList, a self-hosted
/// instance, an offline cache) is an addition rather than a rewrite.
///
/// Metadata providers never resolve video. Streaming providers never become the
/// source of truth for titles.
abstract class MetadataProvider extends ProviderDescriptor {
  const MetadataProvider();

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  Set<ProviderPlatform> get platforms => const <ProviderPlatform>{
    ProviderPlatform.android,
    ProviderPlatform.windows,
    ProviderPlatform.linux,
  };

  @override
  ProviderContractRange get contract => ProviderContractRange.current;

  @override
  ProviderOrigin get origin => ProviderOrigin.builtIn;

  @override
  List<ProviderConfigField> get configuration => const <ProviderConfigField>[];

  /// What this catalogue can do. The repository checks before calling.
  Set<MetadataCapability> get capabilities;

  /// Refreshes the availability snapshot. Must never throw.
  Future<ProviderStatusSnapshot> probe();

  Future<MediaPage> trending({int page = 1, int perPage = 20});

  Future<MediaPage> popular({int page = 1, int perPage = 20});

  Future<MediaPage> topRated({int page = 1, int perPage = 20});

  Future<MediaPage> recentlyUpdated({int page = 1, int perPage = 20});

  Future<MediaPage> seasonal({
    required AnimeSeason season,
    required int year,
    int page = 1,
    int perPage = 20,
  });

  Future<MediaPage> browse(
    ExploreFilter filter, {
    int page = 1,
    int perPage = 24,
  });

  Future<MediaPage> search(String query, {int page = 1, int perPage = 20});

  Future<Anime> details(int id);

  Future<List<String>> genres();

  /// Releases timers and caches. Must be idempotent.
  ///
  /// A provider must never close a client it does not own (the shared HTTP
  /// client belongs to the app, not to one catalogue).
  Future<void> dispose();
}
