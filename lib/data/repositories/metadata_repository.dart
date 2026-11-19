import '../../integrations/providers/metadata_provider.dart';
import '../models/anime.dart';
import '../models/explore_filter.dart';
import '../models/media_page.dart';

/// Metadata access with a short-lived in-memory cache.
///
/// Depends on [MetadataProvider], never on a concrete catalogue: swapping or
/// supplementing AniList happens behind this interface. The cache stays here,
/// above the interface, so every catalogue gets the same TTL behaviour.
/// Nothing here is authoritative user data — the cache is safe to discard at any
/// time.
class MetadataRepository {
  MetadataRepository(this._client, {this.ttl = const Duration(minutes: 5)});

  final MetadataProvider _client;
  final Duration ttl;

  final Map<String, _CacheEntry<Object>> _cache =
      <String, _CacheEntry<Object>>{};

  static const MediaPage _emptyPage = MediaPage.empty();

  Future<MediaPage> trending({int perPage = 20}) => _memo<MediaPage>(
    'trending:$perPage',
    () => _client.trending(perPage: perPage),
  );

  Future<MediaPage> popular({int perPage = 20}) => _memo<MediaPage>(
    'popular:$perPage',
    () => _client.popular(perPage: perPage),
  );

  Future<MediaPage> topRated({int perPage = 20}) => _memo<MediaPage>(
    'top:$perPage',
    () => _client.topRated(perPage: perPage),
  );

  Future<MediaPage> recentlyUpdated({int perPage = 20}) => _memo<MediaPage>(
    'updated:$perPage',
    () => _client.recentlyUpdated(perPage: perPage),
  );

  Future<MediaPage> seasonal({
    required AnimeSeason season,
    required int year,
    int perPage = 20,
  }) {
    return _memo<MediaPage>(
      'season:${season.name}:$year:$perPage',
      () => _client.seasonal(season: season, year: year, perPage: perPage),
    );
  }

  Future<MediaPage> browse(
    ExploreFilter filter, {
    int page = 1,
    int perPage = 24,
  }) {
    final String key =
        'browse:${filter.query}|${filter.genres.join(",")}|${filter.year}|'
        '${filter.season?.name}|${filter.sort.name}|$page|$perPage';
    return _memo<MediaPage>(
      key,
      () => _client.browse(filter, page: page, perPage: perPage),
    );
  }

  Future<MediaPage> search(String query, {int page = 1, int perPage = 20}) {
    return _memo<MediaPage>(
      'search:${query.trim().toLowerCase()}:$page:$perPage',
      () => _client.search(query, page: page, perPage: perPage),
    );
  }

  Future<Anime> details(int id) =>
      _memo<Anime>('anime:$id', () => _client.details(id));

  Future<List<String>> genres() =>
      _memo<List<String>>('genres', _client.genres);

  /// Clears the cache — used by pull-to-refresh and after failures.
  void invalidate([String? prefix]) {
    if (prefix == null) {
      _cache.clear();
      return;
    }
    _cache.removeWhere(
      (String key, _CacheEntry<Object> _) => key.startsWith(prefix),
    );
  }

  Future<T> _memo<T extends Object>(String key, Future<T> Function() load) {
    final _CacheEntry<Object>? cached = _cache[key];
    if (cached != null && cached.isFresh) {
      return Future<T>.value(cached.value as T);
    }
    final Future<T> pending = load();
    return pending.then((T value) {
      _cache[key] = _CacheEntry<Object>(value, DateTime.now().add(ttl));
      return value;
    });
  }

  static const MediaPage emptyPage = _emptyPage;
}

class _CacheEntry<T extends Object> {
  _CacheEntry(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;

  bool get isFresh => expiresAt.isAfter(DateTime.now());
}
