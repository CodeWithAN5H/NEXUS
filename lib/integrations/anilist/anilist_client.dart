import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_failure.dart';
import '../../data/models/anime.dart';
import '../../data/models/explore_filter.dart';
import '../../data/models/media_page.dart';
import 'anilist_queries.dart';

/// Thin, typed wrapper over the AniList GraphQL API.
///
/// AniList supplies *metadata only*. It is not an episode or stream source.
class AniListClient {
  AniListClient(this._dio);

  final Dio _dio;

  // ── Rails ──────────────────────────────────────────────────────────────────

  Future<MediaPage> trending({int page = 1, int perPage = 20}) =>
      _pageQuery(trendingQuery, page, perPage);

  Future<MediaPage> popular({int page = 1, int perPage = 20}) =>
      _pageQuery(popularQuery, page, perPage);

  Future<MediaPage> topRated({int page = 1, int perPage = 20}) =>
      _pageQuery(topRatedQuery, page, perPage);

  Future<MediaPage> recentlyUpdated({int page = 1, int perPage = 20}) =>
      _pageQuery(recentlyUpdatedQuery, page, perPage);

  Future<MediaPage> seasonal({
    required AnimeSeason season,
    required int year,
    int page = 1,
    int perPage = 20,
  }) {
    return _queryPage(seasonalQuery, <String, dynamic>{
      'season': season.anilistValue,
      'seasonYear': year,
      'page': page,
      'perPage': perPage,
    });
  }

  // ── Search & browse ────────────────────────────────────────────────────────

  Future<MediaPage> search(
    String query, {
    int page = 1,
    int perPage = 20,
    ExploreSort sort = ExploreSort.popular,
  }) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Future<MediaPage>.value(const MediaPage.empty());
    }
    return _queryPage(browseQuery, <String, dynamic>{
      'search': trimmed,
      'sort': <String>[sort.anilistValue],
      'page': page,
      'perPage': perPage,
    });
  }

  Future<MediaPage> browse(
    ExploreFilter filter, {
    int page = 1,
    int perPage = 24,
  }) {
    final Map<String, dynamic> variables = <String, dynamic>{
      'sort': <String>[filter.sort.anilistValue],
      'page': page,
      'perPage': perPage,
    };
    if (filter.hasSearchQuery) {
      variables['search'] = filter.query.trim();
    }
    if (filter.genres.isNotEmpty) variables['genres'] = filter.genres.toList();
    if (filter.year != null) {
      variables['seasonYear'] = filter.year;
    }
    if (filter.season != null) {
      variables['season'] = filter.season!.anilistValue;
    }

    return _queryPage(browseQuery, variables);
  }

  // ── Details ────────────────────────────────────────────────────────────────

  Future<Anime> details(int id) async {
    final Map<String, dynamic> data = await _post(
      animeDetailsQuery,
      <String, dynamic>{'id': id},
    );
    final Object? media = data['Media'];
    if (media is! Map<String, dynamic>) {
      throw const NotFoundFailure(
        'This title is no longer available on AniList.',
        cause: null,
      );
    }
    return Anime.fromAniList(media);
  }

  /// Genre names for the filter panel.
  Future<List<String>> genreCollection() async {
    final Map<String, dynamic> data = await _post(
      genreCollectionQuery,
      const <String, dynamic>{},
    );
    final Object? genres = data['GenreCollection'];
    if (genres is! List) return const <String>[];
    return genres
        .whereType<String>()
        .where((String genre) => genre != 'Hentai')
        .toList(growable: false);
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  Future<MediaPage> _pageQuery(String document, int page, int perPage) {
    return _queryPage(document, <String, dynamic>{
      'page': page,
      'perPage': perPage.clamp(1, 50),
    });
  }

  Future<MediaPage> _queryPage(
    String document,
    Map<String, dynamic> variables,
  ) async {
    final Map<String, dynamic> data = await _post(document, variables);
    final Object? page = data['Page'];
    if (page is! Map<String, dynamic>) {
      throw const ParseFailure('AniList returned an unexpected payload.');
    }

    final Object? media = page['media'];
    final List<Anime> items = media is List
        ? media
              .whereType<Map<String, dynamic>>()
              .map(Anime.fromAniList)
              .where((Anime anime) => anime.id != 0)
              .toList(growable: false)
        : const <Anime>[];

    final Object? info = page['pageInfo'];
    final bool hasNextPage =
        info is Map<String, dynamic> && info['hasNextPage'] == true;
    final int total = info is Map<String, dynamic> && info['total'] is int
        ? info['total'] as int
        : items.length;

    return MediaPage(items: items, hasNextPage: hasNextPage, total: total);
  }

  Future<Map<String, dynamic>> _post(
    String document,
    Map<String, dynamic> variables,
  ) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .post<Map<String, dynamic>>(
            AppConstants.anilistEndpoint,
            data: <String, dynamic>{'query': document, 'variables': variables},
          );

      final Map<String, dynamic>? body = response.data;
      if (body == null) {
        throw const ParseFailure('AniList returned an empty response.');
      }

      final Object? errors = body['errors'];
      if (errors is List && errors.isNotEmpty) {
        throw _failureFromErrors(errors);
      }

      final Object? data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw const ParseFailure('AniList returned an unexpected payload.');
      }
      return data;
    } on DioException catch (error) {
      throw AppFailure.from(error);
    }
  }

  AppFailure _failureFromErrors(List<dynamic> errors) {
    final Object? first = errors.first;
    if (first is Map<String, dynamic>) {
      final int? status = first['status'] is int
          ? first['status'] as int
          : null;
      if (status == 429) {
        return const RateLimitFailure(
          'AniList is rate limiting requests. Please wait a moment.',
          cause: null,
        );
      }
      if (status != null && status >= 500) {
        return ServerFailure(
          'AniList is unavailable right now.',
          cause: first['message'],
        );
      }
      final String message = first['message'] is String
          ? first['message'] as String
          : 'AniList rejected the request.';
      return ParseFailure(message);
    }
    return const ParseFailure('AniList returned an error.');
  }
}
