import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../integrations/anilist/anilist_client.dart';
import '../../integrations/streaming/source_manager.dart';
import '../models/anime.dart';
import '../models/explore_filter.dart';
import '../models/library.dart';
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

/// Results for the current filter. Text search is debounced by the screen.
final FutureProvider<MediaPage> exploreResultsProvider =
    FutureProvider<MediaPage>((Ref ref) {
      final ExploreFilter filter = ref.watch(exploreFilterProvider);
      return ref.watch(metadataRepositoryProvider).browse(filter, perPage: 24);
    });

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

/// Whether any enabled source can serve this title, and which one.
final sourceLookupProvider = FutureProvider.family<SourceLookup, int>((
  Ref ref,
  int animeId,
) async {
  final Anime anime = await ref.watch(animeDetailsProvider(animeId).future);
  return ref.watch(sourceManagerProvider).lookup(anime);
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
