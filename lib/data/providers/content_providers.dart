import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../integrations/providers/provider_record.dart';
import '../../integrations/providers/provider_resolver.dart';
import '../models/anime.dart';
import '../models/explore_filter.dart';
import '../models/library.dart';
import '../models/media_page.dart';
import '../repositories/library_repository.dart';
import 'app_providers.dart';

// ── Home rails ───────────────────────────────────────────────────────────────

final FutureProvider<MediaPage> trendingProvider = FutureProvider<MediaPage>((
  Ref ref,
) {
  return ref.watch(metadataRepositoryProvider).trending(perPage: 12);
});

final FutureProvider<MediaPage> recentlyUpdatedProvider =
    FutureProvider<MediaPage>((Ref ref) {
      return ref.watch(metadataRepositoryProvider).recentlyUpdated(perPage: 12);
    });

final FutureProvider<MediaPage> topRatedProvider = FutureProvider<MediaPage>((
  Ref ref,
) {
  return ref.watch(metadataRepositoryProvider).topRated(perPage: 12);
});

/// The season currently airing, computed from the device clock.
final Provider<({AnimeSeason season, int year})> currentSeasonProvider =
    Provider<({AnimeSeason season, int year})>((Ref ref) {
      final DateTime now = DateTime.now();
      return (season: AnimeSeason.of(now), year: AnimeSeason.yearOf(now));
    });

final FutureProvider<MediaPage> seasonalProvider = FutureProvider<MediaPage>((
  Ref ref,
) {
  final ({AnimeSeason season, int year}) current = ref.watch(
    currentSeasonProvider,
  );
  return ref
      .watch(metadataRepositoryProvider)
      .seasonal(season: current.season, year: current.year, perPage: 12);
});

/// One entry per title, newest first — the Continue Watching rail.
final StreamProvider<List<WatchProgress>> continueWatchingProvider =
    StreamProvider<List<WatchProgress>>((Ref ref) {
      return ref
          .watch(historyRepositoryProvider)
          .watchContinueWatching(limit: 8);
    });

/// Ids of saved titles, used to show a filled bookmark on posters.
final StreamProvider<Set<int>> savedAnimeIdsProvider = StreamProvider<Set<int>>(
  (Ref ref) {
    return ref.watch(libraryRepositoryProvider).watchSavedIds();
  },
);

// ── Explore ──────────────────────────────────────────────────────────────────

/// Explore filter state. The screen owns no filter logic of its own.
class ExploreController extends Notifier<ExploreFilter> {
  @override
  ExploreFilter build() => const ExploreFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleGenre(String genre) => state = state.toggleGenre(genre);

  void setYear(int? year) => state = year == null
      ? state.copyWith(clearYear: true)
      : state.copyWith(year: year);

  void setSeason(AnimeSeason? season) => state = season == null
      ? state.copyWith(clearSeason: true)
      : state.copyWith(season: season);

  void setSort(ExploreSort sort) => state = state.copyWith(sort: sort);

  void clearFilters() => state = state.cleared();

  void reset() => state = const ExploreFilter();
}

final NotifierProvider<ExploreController, ExploreFilter> exploreFilterProvider =
    NotifierProvider<ExploreController, ExploreFilter>(ExploreController.new);

/// Results for the current Explore filter, accumulated across pages.
///
/// Explore is the only paged surface: the filter is the reset boundary, so a
/// new query or facet replaces this accumulation instead of extending it.
class ExploreResults {
  const ExploreResults({
    required this.items,
    required this.filter,
    required this.page,
    required this.hasNextPage,
    this.loadingMore = false,
    this.moreFailure,
  });

  /// Every title loaded for [filter], de-duplicated by [Anime.id] in page order.
  final List<Anime> items;

  /// The filter these items belong to. A screen can compare it with the live
  /// filter to tell whether it is looking at stale results.
  final ExploreFilter filter;

  /// Last successfully loaded page (1-based).
  final int page;

  /// Whether another page exists within both the source's and AniList's limits.
  final bool hasNextPage;

  /// True while the next page is being fetched — the items already shown stay
  /// on screen.
  final bool loadingMore;

  /// Failure of the *last append only*. Earlier pages are kept, and the footer
  /// retries the append instead of emptying the grid.
  final Object? moreFailure;

  bool get isEmpty => items.isEmpty;

  bool get hasMoreFailure => moreFailure != null;

  ExploreResults copyWith({
    List<Anime>? items,
    int? page,
    bool? hasNextPage,
    bool? loadingMore,
    Object? moreFailure,
    bool clearMoreFailure = false,
  }) {
    return ExploreResults(
      items: items ?? this.items,
      filter: filter,
      page: page ?? this.page,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      loadingMore: loadingMore ?? this.loadingMore,
      moreFailure: clearMoreFailure ? null : (moreFailure ?? this.moreFailure),
    );
  }
}

/// Paged Explore results. Text search is still debounced by the screen.
///
/// Invariants:
/// * page 1 is loaded by [build], so a filter change replaces the accumulation
///   and any append still in flight for the previous filter is dropped;
/// * [loadMore] is a no-op while a page is loading, at the end of the list, or
///   when the live filter no longer matches the loaded one — every scroll
///   notification can call it without producing duplicate requests;
/// * appended items are de-duplicated by [Anime.id]: AniList re-ranks between
///   requests, so one title can legitimately appear on two pages.
class ExploreResultsController extends AsyncNotifier<ExploreResults> {
  /// Posters per request — fills a phone grid and stays under AniList's cap of
  /// 50 results per page.
  static const int pageSize = 24;

  /// AniList refuses requests beyond 5 000 entries of depth, answering HTTP 400
  /// (`Page depth exceeds maximum allowed…`). Paging stops before that request
  /// is made, so the list ends quietly instead of failing.
  static const int maxEntries = 5000;

  /// Bumped by every rebuild, so a page that resolves after the filter changed
  /// can never be merged into the new results.
  int _generation = 0;
  bool _appending = false;

  @override
  Future<ExploreResults> build() async {
    final ExploreFilter filter = ref.watch(exploreFilterProvider);
    _generation++;
    _appending = false;

    final MediaPage first = await ref
        .watch(metadataRepositoryProvider)
        .browse(filter, page: 1, perPage: pageSize);

    return ExploreResults(
      items: _append(const <Anime>[], first.items),
      filter: filter,
      page: 1,
      hasNextPage: first.hasNextPage && _pageAllowed(2),
    );
  }

  /// Appends the next page. Safe to call from every scroll notification.
  Future<void> loadMore() async {
    final ExploreResults? current = state.value;
    if (current == null) return; // Initial load, or page 1 failed.
    if (current.loadingMore || _appending) return;
    if (!current.hasNextPage) return;

    final ExploreFilter filter = ref.read(exploreFilterProvider);
    if (filter != current.filter) return;

    final int nextPage = current.page + 1;
    if (!_pageAllowed(nextPage)) return;

    final int generation = _generation;
    _appending = true;
    state = AsyncData<ExploreResults>(
      current.copyWith(loadingMore: true, clearMoreFailure: true),
    );

    try {
      final MediaPage page = await ref
          .read(metadataRepositoryProvider)
          .browse(filter, page: nextPage, perPage: pageSize);
      if (!_isCurrent(generation, filter)) return;
      state = AsyncData<ExploreResults>(
        current.copyWith(
          items: _append(current.items, page.items),
          page: nextPage,
          hasNextPage: page.hasNextPage && _pageAllowed(nextPage + 1),
          loadingMore: false,
        ),
      );
    } catch (error) {
      // A failed append keeps every page already shown; the footer retries it.
      if (!_isCurrent(generation, filter)) return;
      state = AsyncData<ExploreResults>(
        current.copyWith(loadingMore: false, moreFailure: error),
      );
    } finally {
      _appending = false;
    }
  }

  /// Retries only the failed append, leaving the loaded pages untouched.
  Future<void> retryLoadMore() async {
    final ExploreResults? current = state.value;
    if (current == null || !current.hasMoreFailure) return;
    state = AsyncData<ExploreResults>(current.copyWith(clearMoreFailure: true));
    await loadMore();
  }

  bool _isCurrent(int generation, ExploreFilter filter) {
    if (!ref.mounted) return false;
    if (generation != _generation) return false;
    return ref.read(exploreFilterProvider) == filter;
  }

  /// AniList's depth cap, applied to the page that would be requested next.
  static bool _pageAllowed(int page) => page * pageSize <= maxEntries;

  /// Appends [page] to [items], skipping ids already present and keeping order.
  static List<Anime> _append(List<Anime> items, List<Anime> page) {
    if (page.isEmpty) return items;
    final Set<int> seen = <int>{for (final Anime anime in items) anime.id};
    final List<Anime> merged = <Anime>[...items];
    for (final Anime anime in page) {
      if (!seen.add(anime.id)) continue;
      merged.add(anime);
    }
    return List<Anime>.unmodifiable(merged);
  }
}

final AsyncNotifierProvider<ExploreResultsController, ExploreResults>
exploreResultsProvider =
    AsyncNotifierProvider<ExploreResultsController, ExploreResults>(
      ExploreResultsController.new,
    );

final FutureProvider<List<String>> genresProvider =
    FutureProvider<List<String>>((Ref ref) {
      return ref.watch(metadataRepositoryProvider).genres();
    });

final StreamProvider<List<String>> recentSearchesProvider =
    StreamProvider<List<String>>((Ref ref) {
      return ref.watch(searchHistoryRepositoryProvider).watchRecent();
    });

// ── Library ──────────────────────────────────────────────────────────────────

/// Grid or list layout for the library screen.
enum LibraryLayout { grid, list }

/// View state for the Library screen.
class LibraryView {
  const LibraryView({
    this.status = LibraryStatus.watching,
    this.sort = LibrarySort.recentlyUpdated,
    this.query = '',
    this.layout = LibraryLayout.grid,
  });

  final LibraryStatus status;
  final LibrarySort sort;
  final String query;
  final LibraryLayout layout;

  LibraryView copyWith({
    LibraryStatus? status,
    LibrarySort? sort,
    String? query,
    LibraryLayout? layout,
  }) {
    return LibraryView(
      status: status ?? this.status,
      sort: sort ?? this.sort,
      query: query ?? this.query,
      layout: layout ?? this.layout,
    );
  }
}

class LibraryViewController extends Notifier<LibraryView> {
  @override
  LibraryView build() => const LibraryView();

  void setStatus(LibraryStatus status) =>
      state = state.copyWith(status: status);

  void setSort(LibrarySort sort) => state = state.copyWith(sort: sort);

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleLayout() => state = state.copyWith(
    layout: state.layout == LibraryLayout.grid
        ? LibraryLayout.list
        : LibraryLayout.grid,
  );
}

final NotifierProvider<LibraryViewController, LibraryView>
libraryViewControllerProvider =
    NotifierProvider<LibraryViewController, LibraryView>(
      LibraryViewController.new,
    );

final StreamProvider<List<LibraryEntry>> libraryEntriesProvider =
    StreamProvider<List<LibraryEntry>>((Ref ref) {
      final LibraryView view = ref.watch(libraryViewControllerProvider);
      return ref
          .watch(libraryRepositoryProvider)
          .watchEntries(
            status: view.status,
            sort: view.sort,
            query: view.query,
          );
    });

/// Every saved title regardless of status — used for profile statistics.
final StreamProvider<List<LibraryEntry>> allLibraryEntriesProvider =
    StreamProvider<List<LibraryEntry>>((Ref ref) {
      return ref.watch(libraryRepositoryProvider).watchAll();
    });

/// Number of saved titles per status — drives the tab badges.
final StreamProvider<Map<LibraryStatus, int>> libraryCountsProvider =
    StreamProvider<Map<LibraryStatus, int>>((Ref ref) {
      return ref.watch(libraryRepositoryProvider).watchAll().map((
        List<LibraryEntry> entries,
      ) {
        final Map<LibraryStatus, int> counts = <LibraryStatus, int>{
          for (final LibraryStatus status in LibraryStatus.values) status: 0,
        };
        for (final LibraryEntry entry in entries) {
          counts[entry.status] = (counts[entry.status] ?? 0) + 1;
        }
        return counts;
      });
    });

// ── Details ──────────────────────────────────────────────────────────────────

final animeDetailsProvider = FutureProvider.family<Anime, int>((
  Ref ref,
  int animeId,
) {
  return ref.watch(metadataRepositoryProvider).details(animeId);
});

/// Every enabled source that can serve this title, in the user's order.
///
/// The resolver is built per lookup from the stored rows, so enablement,
/// priority and per-title preference all have one source of truth.
final sourceLookupProvider = FutureProvider.family<SourceLookup, int>((
  Ref ref,
  int animeId,
) async {
  final Anime anime = await ref.watch(animeDetailsProvider(animeId).future);
  final List<ProviderRecord> records = await ref.watch(
    providerRecordsProvider.future,
  );
  final String? preference = await ref.watch(
    providerTitlePreferenceProvider(animeId).future,
  );
  final ProviderResolver resolver = ProviderResolver(
    registry: ref.watch(streamingProviderRegistryProvider),
    records: records,
    titlePreferences: <int, String>{animeId: ?preference},
  );
  return resolver.lookup(anime);
});

/// Recorded positions for each episode of one title.
final episodeProgressProvider =
    StreamProvider.family<Map<int, WatchProgress>, int>((Ref ref, int animeId) {
      return ref.watch(historyRepositoryProvider).watchEpisodesFor(animeId);
    });

/// Saved entry for one title (`null` when not in the library).
final libraryEntryProvider = StreamProvider.family<LibraryEntry?, int>((
  Ref ref,
  int animeId,
) {
  return ref.watch(libraryRepositoryProvider).watchEntry(animeId);
});

/// Full watch history for the History screen.
final StreamProvider<List<WatchProgress>> historyProvider =
    StreamProvider<List<WatchProgress>>((Ref ref) {
      return ref.watch(historyRepositoryProvider).watchHistory(limit: 100);
    });
