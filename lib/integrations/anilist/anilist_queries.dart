/// GraphQL documents for the AniList metadata API (https://docs.anilist.co/).
///
/// Only fields NEXUS actually renders are requested, which keeps responses
/// small and rate-limit friendly.
library;

/// Shared selection set for a media item.
const String _mediaFields = r'''
  id
  title { romaji english native }
  coverImage { extraLarge large medium color }
  bannerImage
  averageScore
  popularity
  favourites
  format
  status
  season
  seasonYear
  episodes
  duration
  genres
  description(asHtml: false)
  siteUrl
  isAdult
  studios(isMain: true) { nodes { name } }
  nextAiringEpisode { episode airingAt timeUntilAiring }
''';

/// Page wrapper used by every list query.
String _pageQuery(String mediaArgs) =>
    '''
query (\$page: Int, \$perPage: Int) {
  Page(page: \$page, perPage: \$perPage) {
    pageInfo { currentPage lastPage hasNextPage total }
    media($mediaArgs) {
      $_mediaFields
    }
  }
}
''';

/// Trending titles right now.
final String trendingQuery = _pageQuery(
  'type: ANIME, sort: TRENDING_DESC, isAdult: false',
);

/// Most popular titles of all time.
final String popularQuery = _pageQuery(
  'type: ANIME, sort: POPULARITY_DESC, isAdult: false',
);

/// Highest rated titles.
final String topRatedQuery = _pageQuery(
  'type: ANIME, sort: SCORE_DESC, isAdult: false',
);

/// Recently updated (newly aired episodes).
final String recentlyUpdatedQuery = _pageQuery(
  'type: ANIME, sort: UPDATED_AT_DESC, isAdult: false',
);

/// Season-specific rail. `$season` is a `MediaSeason`, `$seasonYear` an Int.
const String seasonalQuery =
    '''
query (\$season: MediaSeason, \$seasonYear: Int, \$page: Int, \$perPage: Int) {
  Page(page: \$page, perPage: \$perPage) {
    pageInfo { currentPage lastPage hasNextPage total }
    media(
      type: ANIME
      season: \$season
      seasonYear: \$seasonYear
      sort: POPULARITY_DESC
      isAdult: false
    ) {
      $_mediaFields
    }
  }
}
''';

/// Free-text search plus optional filters. Every argument is nullable so the
/// same document serves the explore screen and the search field.
const String browseQuery =
    '''
query (
  \$search: String
  \$genres: [String]
  \$seasonYear: Int
  \$season: MediaSeason
  \$sort: [MediaSort]
  \$format: [MediaFormat]
  \$page: Int
  \$perPage: Int
) {
  Page(page: \$page, perPage: \$perPage) {
    pageInfo { currentPage lastPage hasNextPage total }
    media(
      type: ANIME
      search: \$search
      genre_in: \$genres
      seasonYear: \$seasonYear
      season: \$season
      sort: \$sort
      format_in: \$format
      isAdult: false
    ) {
      $_mediaFields
    }
  }
}
''';

/// Single title with relations for the details screen.
const String animeDetailsQuery =
    '''
query (\$id: Int) {
  Media(id: \$id, type: ANIME) {
    $_mediaFields
    endDate { year month day }
    startDate { year month day }
    trailer { id site }
    relations {
      edges {
        relationType(version: 2)
        node {
          id
          type
          format
          title { romaji english }
          coverImage { large medium color }
        }
      }
    }
  }
}
''';

/// Genre list used to build the explore filter panel.
const String genreCollectionQuery = '''
query {
  GenreCollection
}
''';
