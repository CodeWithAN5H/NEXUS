/// Filter and sort state for the Explore screen.
library;

/// Sort orders exposed in the UI, mapped to AniList `MediaSort` values.
enum ExploreSort {
  trending('Trending', 'TRENDING_DESC'),
  popular('Most Popular', 'POPULARITY_DESC'),
  topRated('Top Rated', 'SCORE_DESC'),
  newest('Newest', 'START_DATE_DESC'),
  title('A–Z', 'TITLE_ROMAJI');

  const ExploreSort(this.label, this.anilistValue);

  final String label;
  final String anilistValue;
}

/// Anime seasons, mapped to AniList `MediaSeason`.
enum AnimeSeason {
  winter('Winter', 'WINTER'),
  spring('Spring', 'SPRING'),
  summer('Summer', 'SUMMER'),
  fall('Fall', 'FALL');

  const AnimeSeason(this.label, this.anilistValue);

  final String label;
  final String anilistValue;

  /// The season containing [date] — used for the "This Season" rail.
  static AnimeSeason of(DateTime date) {
    switch (date.month) {
      case 1:
      case 2:
      case 3:
        return AnimeSeason.winter;
      case 4:
      case 5:
      case 6:
        return AnimeSeason.spring;
      case 7:
      case 8:
      case 9:
        return AnimeSeason.summer;
      default:
        return AnimeSeason.fall;
    }
  }

  /// Season year for [date]; the winter season starts in December of the
  /// previous year for release purposes, but the calendar year is clearer here.
  static int yearOf(DateTime date) => date.year;
}

/// Immutable filter state for the Explore screen.
class ExploreFilter {
  const ExploreFilter({
    this.query = '',
    this.genres = const <String>{},
    this.year,
    this.season,
    this.sort = ExploreSort.trending,
  });

  final String query;
  final Set<String> genres;
  final int? year;
  final AnimeSeason? season;
  final ExploreSort sort;

  bool get hasSearchQuery => query.trim().isNotEmpty;

  bool get hasActiveFilters =>
      genres.isNotEmpty || year != null || season != null;

  bool get isDefault =>
      !hasSearchQuery && !hasActiveFilters && sort == ExploreSort.trending;

  /// Number of active filter facets, shown on the filter button badge.
  int get activeFacetCount =>
      genres.length + (year == null ? 0 : 1) + (season == null ? 0 : 1);

  ExploreFilter copyWith({
    String? query,
    Set<String>? genres,
    int? year,
    AnimeSeason? season,
    ExploreSort? sort,
    bool clearYear = false,
    bool clearSeason = false,
  }) {
    return ExploreFilter(
      query: query ?? this.query,
      genres: genres ?? this.genres,
      year: clearYear ? null : (year ?? this.year),
      season: clearSeason ? null : (season ?? this.season),
      sort: sort ?? this.sort,
    );
  }

  ExploreFilter toggleGenre(String genre) {
    final Set<String> next = Set<String>.of(genres);
    if (!next.remove(genre)) next.add(genre);
    return copyWith(genres: next);
  }

  ExploreFilter cleared() => ExploreFilter(sort: sort);

  @override
  bool operator ==(Object other) =>
      other is ExploreFilter &&
      other.query == query &&
      other.year == year &&
      other.season == season &&
      other.sort == sort &&
      other.genres.length == genres.length &&
      other.genres.containsAll(genres);

  @override
  int get hashCode =>
      Object.hash(query, year, season, sort, Object.hashAllUnordered(genres));
}

/// Years offered in the year filter, newest first.
List<int> exploreYears(DateTime now, {int count = 26}) {
  final int currentYear = now.year;
  return List<int>.generate(count, (int index) => currentYear + 1 - index);
}
