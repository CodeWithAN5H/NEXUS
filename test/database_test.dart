import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/constants/app_constants.dart';
import 'package:nexus/data/database/nexus_database.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/data/models/app_settings.dart';
import 'package:nexus/data/models/library.dart';
import 'package:nexus/data/repositories/history_repository.dart';
import 'package:nexus/data/repositories/library_repository.dart';
import 'package:nexus/data/repositories/preferences_repository.dart';

Anime anime(int id, {String? title, int? episodes = 12}) => Anime(
  id: id,
  title: title ?? 'Anime $id',
  coverImage: 'https://img.example/$id.jpg',
  averageScore: 80,
  episodes: episodes,
  format: 'TV',
  seasonYear: 2024,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The restart test intentionally opens the same file twice.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late NexusDatabase db;
  late LibraryRepository library;
  late HistoryRepository history;
  late SearchHistoryRepository searches;
  late PreferencesRepository preferences;

  setUp(() {
    db = NexusDatabase(NativeDatabase.memory());
    library = LibraryRepository(db);
    history = HistoryRepository(db);
    searches = SearchHistoryRepository(db);
    preferences = PreferencesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('schema', () {
    test('uses the versioned schema constant', () {
      expect(db.schemaVersion, AppConstants.databaseSchemaVersion);
      expect(db.schemaVersion, 2);
    });

    test('creates all tables on open', () async {
      // Touching each table proves onCreate ran for every one of them.
      expect(await db.select(db.libraryEntries).get(), isEmpty);
      expect(await db.select(db.progressEntries).get(), isEmpty);
      expect(await db.select(db.recentSearches).get(), isEmpty);
      expect(await db.select(db.preferenceEntries).get(), isEmpty);
      expect(await db.select(db.providerEntries).get(), isEmpty);
      expect(await db.select(db.providerTitlePrefs).get(), isEmpty);
      expect(await db.select(db.providerManifests).get(), isEmpty);
    });
  });

  group('LibraryRepository', () {
    test('saves, reads and upserts without duplicating rows', () async {
      await library.save(anime(1), status: LibraryStatus.watching);
      final LibraryEntry? first = await library.entryFor(1);
      expect(first?.title, 'Anime 1');
      expect(first?.status, LibraryStatus.watching);

      await library.save(anime(1, title: 'Renamed'));
      final List<LibraryEntry> all = await library.watchAll().first;
      expect(all, hasLength(1));
      expect(all.single.title, 'Renamed');
    });

    test('preserves watch progress when the title is saved again', () async {
      await library.save(anime(2), status: LibraryStatus.watching);
      await library.markEpisodeWatched(2, 4, totalEpisodes: 12);
      await library.save(anime(2));

      final LibraryEntry? entry = await library.entryFor(2);
      expect(entry?.watchedEpisodes, 4);
    });

    test('never decreases recorded progress', () async {
      await library.save(anime(3));
      await library.markEpisodeWatched(3, 5, totalEpisodes: 12);
      await library.markEpisodeWatched(3, 2, totalEpisodes: 12);
      expect((await library.entryFor(3))?.watchedEpisodes, 5);
    });

    test(
      'marks the entry completed when the last episode is watched',
      () async {
        await library.save(anime(4), status: LibraryStatus.watching);
        await library.markEpisodeWatched(4, 12, totalEpisodes: 12);
        final LibraryEntry? entry = await library.entryFor(4);
        expect(entry?.status, LibraryStatus.completed);
        expect(entry?.isComplete, isTrue);
      },
    );

    test('filters by status and searches by title', () async {
      await library.save(
        anime(10, title: 'Frieren'),
        status: LibraryStatus.watching,
      );
      await library.save(
        anime(11, title: 'Solo Leveling'),
        status: LibraryStatus.completed,
      );

      final List<LibraryEntry> watching = await library
          .watchEntries(status: LibraryStatus.watching)
          .first;
      expect(watching.map((LibraryEntry e) => e.title), <String>['Frieren']);

      final List<LibraryEntry> search = await library
          .watchEntries(query: 'solo')
          .first;
      expect(search.single.title, 'Solo Leveling');
    });

    test('sorts by title when asked', () async {
      await library.save(anime(20, title: 'Zeta'));
      await library.save(anime(21, title: 'Alpha'));
      final List<LibraryEntry> sorted = await library
          .watchEntries(sort: LibrarySort.title)
          .first;
      expect(sorted.map((LibraryEntry e) => e.title), <String>[
        'Alpha',
        'Zeta',
      ]);
    });

    test('removes entries and reports saved ids', () async {
      await library.save(anime(30));
      await library.save(anime(31));
      expect(await library.watchSavedIds().first, <int>{30, 31});

      await library.remove(30);
      expect(await library.watchSavedIds().first, <int>{31});
      expect(await library.entryFor(30), isNull);
    });

    test('updates status and user score', () async {
      await library.save(anime(40));
      await library.updateStatus(40, LibraryStatus.onHold);
      await library.setUserScore(40, 85);
      final LibraryEntry? entry = await library.entryFor(40);
      expect(entry?.status, LibraryStatus.onHold);
      expect(entry?.userScore, 85);
    });
  });

  group('HistoryRepository', () {
    Future<void> record(
      int animeId,
      int episode, {
      Duration position = const Duration(minutes: 5),
      Duration duration = const Duration(minutes: 24),
    }) {
      return history.record(
        animeId: animeId,
        episodeNumber: episode,
        title: 'Anime $animeId',
        position: position,
        duration: duration,
        providerId: 'sample',
        seriesId: 'series-$animeId',
      );
    }

    test('stores and reads back a position', () async {
      await record(1, 3);
      final WatchProgress? progress = await history.progressFor(1, 3);
      expect(progress?.episodeNumber, 3);
      expect(progress?.position, const Duration(minutes: 5));
      expect(progress?.providerId, 'sample');
      expect(progress?.seriesId, 'series-1');
    });

    test('upserts a position for the same episode', () async {
      await record(1, 1, position: const Duration(minutes: 2));
      await record(1, 1, position: const Duration(minutes: 9));
      final WatchProgress? progress = await history.progressFor(1, 1);
      expect(progress?.position, const Duration(minutes: 9));
      expect(await history.watchHistory().first, hasLength(1));
    });

    test('continue watching keeps one entry per title, newest first', () async {
      await record(1, 1, position: const Duration(minutes: 1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await record(1, 2, position: const Duration(minutes: 8));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await record(2, 1, position: const Duration(minutes: 3));

      final List<WatchProgress> rail = await history
          .watchContinueWatching()
          .first;
      expect(rail, hasLength(2));
      expect(rail.first.animeId, 1);
      expect(rail.first.episodeNumber, 2);
    });

    test('hides unstarted and finished episodes from the rail', () async {
      await record(1, 1, position: const Duration(seconds: 1));
      await record(
        2,
        1,
        position: const Duration(minutes: 24),
        duration: const Duration(minutes: 24),
      );
      final List<WatchProgress> rail = await history
          .watchContinueWatching()
          .first;
      expect(rail, isEmpty);
    });

    test('exposes per-episode progress for a title', () async {
      await record(5, 1);
      await record(5, 2);
      await record(6, 1);
      final Map<int, WatchProgress> map = await history
          .watchEpisodesFor(5)
          .first;
      expect(map.keys, <int>[1, 2]);
    });

    test('deletes single entries and clears everything', () async {
      await record(7, 1);
      await record(7, 2);
      await history.deleteEntry(7, 1);
      expect(await history.progressFor(7, 1), isNull);
      expect(await history.progressFor(7, 2), isNotNull);

      await history.clearAll();
      expect(await history.watchHistory().first, isEmpty);
    });
  });

  group('SearchHistoryRepository', () {
    test('records, lower-cases and de-duplicates searches', () async {
      await searches.record('Frieren');
      await searches.record('frieren');
      await searches.record('Solo');
      final List<String> recent = await searches.watchRecent().first;
      expect(recent, containsAll(<String>['frieren', 'solo']));
      expect(recent.where((String q) => q == 'frieren'), hasLength(1));
    });

    test('ignores queries shorter than two characters', () async {
      await searches.record('a');
      expect(await searches.watchRecent().first, isEmpty);
    });

    test('caps stored history and can clear itself', () async {
      for (int i = 0; i < 30; i++) {
        await searches.record('query $i');
      }
      expect(
        (await db.select(db.recentSearches).get()).length,
        lessThanOrEqualTo(20),
      );
      await searches.clear();
      expect(await searches.watchRecent().first, isEmpty);
    });
  });

  group('PreferencesRepository', () {
    test('returns defaults before anything is written', () async {
      final AppSettings settings = await preferences.load();
      expect(settings.autoplayNext, AppSettings.defaults.autoplayNext);
      expect(
        settings.enabledProviderIds,
        AppSettings.defaults.enabledProviderIds,
      );
    });

    test('persists and reloads every setting', () async {
      const AppSettings settings = AppSettings(
        autoplayNext: false,
        rememberPosition: false,
        preferredQualityHeight: 480,
        subtitleSize: SubtitleSize.small,
        preferredAudioLanguage: 'en',
        enabledProviderIds: <String>{'sample'},
        gridDensity: GridDensity.compact,
        reduceMotion: true,
      );
      await preferences.save(settings);

      final AppSettings loaded = await preferences.load();
      expect(loaded.autoplayNext, isFalse);
      expect(loaded.preferredQualityHeight, 480);
      expect(loaded.subtitleSize, SubtitleSize.small);
      expect(loaded.preferredAudioLanguage, 'en');
      expect(loaded.reduceMotion, isTrue);
    });
  });

  group('data preservation across restarts', () {
    test(
      'library, progress and settings survive a close/reopen cycle',
      () async {
        final Directory dir = await Directory.systemTemp.createTemp('nexus-db');
        final File file = File('${dir.path}/nexus.sqlite');

        // First "install".
        final NexusDatabase first = NexusDatabase(NativeDatabase(file));
        await LibraryRepository(first)
            .save(anime(99), status: LibraryStatus.watching);
        await LibraryRepository(first)
            .markEpisodeWatched(99, 3, totalEpisodes: 12);
        await HistoryRepository(first).record(
          animeId: 99,
          episodeNumber: 3,
          title: 'Anime 99',
          position: const Duration(minutes: 7),
          duration: const Duration(minutes: 24),
        );
        await PreferencesRepository(first)
            .save(const AppSettings(preferredQualityHeight: 720));
        await first.close();

        // Simulated app update: same file, new connection.
        final NexusDatabase second = NexusDatabase(NativeDatabase(file));
        final LibraryEntry? entry = await LibraryRepository(second)
            .entryFor(99);
        final WatchProgress? progress = await HistoryRepository(second)
            .progressFor(99, 3);
        final AppSettings settings = await PreferencesRepository(second).load();

        expect(
          entry?.watchedEpisodes,
          3,
          reason: 'library progress must persist',
        );
        expect(progress?.position, const Duration(minutes: 7));
        expect(settings.preferredQualityHeight, 720);

        await second.close();
        await dir.delete(recursive: true);
      },
    );
  });
}
