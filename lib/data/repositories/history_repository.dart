import 'package:drift/drift.dart';

import '../../core/errors/app_failure.dart';
import '../database/nexus_database.dart';
import '../models/library.dart';

/// Persists playback positions so viewing can resume across launches.
class HistoryRepository {
  HistoryRepository(this._db);

  final NexusDatabase _db;

  /// One entry per title (the most recently watched episode), newest first.
  Stream<List<WatchProgress>> watchContinueWatching({int limit = 12}) {
    return watchHistory(limit: limit * 4).map((List<WatchProgress> all) {
      final Set<int> seen = <int>{};
      final List<WatchProgress> result = <WatchProgress>[];
      for (final WatchProgress progress in all) {
        if (!seen.add(progress.animeId)) continue;
        if (progress.position.inSeconds < 5) continue;
        if (progress.fraction >= 0.995) continue;
        result.add(progress);
        if (result.length >= limit) break;
      }
      return result;
    });
  }

  /// Full history, newest first.
  Stream<List<WatchProgress>> watchHistory({int limit = 100}) {
    final SimpleSelectStatement<$ProgressEntriesTable, ProgressRow> statement =
        _db.select(_db.progressEntries)
          ..orderBy(<OrderingTerm Function($ProgressEntriesTable)>[
            ($ProgressEntriesTable table) => OrderingTerm.desc(table.updatedAt),
            // Timestamps are stored with second precision, so break ties by
            // episode number to keep the rail stable.
            ($ProgressEntriesTable table) =>
                OrderingTerm.desc(table.episodeNumber),
          ])
          ..limit(limit);
    return statement.watch().map(
      (List<ProgressRow> rows) => rows.map(_toModel).toList(growable: false),
    );
  }

  /// Progress recorded for each episode of one title, keyed by episode number.
  Stream<Map<int, WatchProgress>> watchEpisodesFor(int animeId) {
    final SimpleSelectStatement<$ProgressEntriesTable, ProgressRow> statement =
        _db.select(_db.progressEntries)
          ..where((ProgressEntries table) => table.animeId.equals(animeId));
    return statement.watch().map((List<ProgressRow> rows) {
      return <int, WatchProgress>{
        for (final ProgressRow row in rows) row.episodeNumber: _toModel(row),
      };
    });
  }

  /// Latest position for a specific episode, used to resume playback.
  Future<WatchProgress?> progressFor(int animeId, int episodeNumber) async {
    final ProgressRow? row =
        await (_db.select(_db.progressEntries)..where(
              (ProgressEntries table) =>
                  table.animeId.equals(animeId) &
                  table.episodeNumber.equals(episodeNumber),
            ))
            .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  /// Upserts a position. Called by the player on pause, seek and exit.
  Future<void> record({
    required int animeId,
    required int episodeNumber,
    required String title,
    required Duration position,
    required Duration duration,
    String? episodeTitle,
    String? coverImage,
    String? bannerImage,
    int? totalEpisodes,
    String? providerId,
    String? seriesId,
  }) async {
    try {
      await _db
          .into(_db.progressEntries)
          .insertOnConflictUpdate(
            ProgressEntriesCompanion.insert(
              animeId: animeId,
              episodeNumber: episodeNumber,
              title: title,
              positionMs: Value<int>(position.inMilliseconds),
              durationMs: Value<int>(duration.inMilliseconds),
              episodeTitle: Value<String?>(episodeTitle),
              coverImage: Value<String?>(coverImage),
              bannerImage: Value<String?>(bannerImage),
              totalEpisodes: Value<int?>(totalEpisodes),
              providerId: Value<String?>(providerId),
              seriesId: Value<String?>(seriesId),
              updatedAt: Value<DateTime>(DateTime.now()),
            ),
          );
    } catch (error) {
      throw StorageFailure(
        'Could not save your playback position.',
        cause: error,
      );
    }
  }

  Future<void> deleteEntry(int animeId, int episodeNumber) async {
    await (_db.delete(_db.progressEntries)..where(
          (ProgressEntries table) =>
              table.animeId.equals(animeId) &
              table.episodeNumber.equals(episodeNumber),
        ))
        .go();
  }

  Future<void> clearForAnime(int animeId) async {
    await (_db.delete(
      _db.progressEntries,
    )..where((ProgressEntries table) => table.animeId.equals(animeId))).go();
  }

  Future<void> clearAll() async {
    await _db.delete(_db.progressEntries).go();
  }

  WatchProgress _toModel(ProgressRow row) {
    return WatchProgress(
      animeId: row.animeId,
      episodeNumber: row.episodeNumber,
      title: row.title,
      episodeTitle: row.episodeTitle,
      coverImage: row.coverImage,
      bannerImage: row.bannerImage,
      totalEpisodes: row.totalEpisodes,
      providerId: row.providerId,
      seriesId: row.seriesId,
      position: Duration(milliseconds: row.positionMs),
      duration: Duration(milliseconds: row.durationMs),
      updatedAt: row.updatedAt,
    );
  }
}

/// Recent search terms for the Explore screen.
class SearchHistoryRepository {
  SearchHistoryRepository(this._db);

  final NexusDatabase _db;

  Stream<List<String>> watchRecent({int limit = 8}) {
    final SimpleSelectStatement<$RecentSearchesTable, SearchRow> statement =
        _db.select(_db.recentSearches)
          ..orderBy(<OrderingTerm Function($RecentSearchesTable)>[
            ($RecentSearchesTable table) => OrderingTerm.desc(table.searchedAt),
          ])
          ..limit(limit);
    return statement.watch().map(
      (List<SearchRow> rows) =>
          rows.map((SearchRow row) => row.query).toList(growable: false),
    );
  }

  Future<void> record(String query) async {
    final String trimmed = query.trim();
    if (trimmed.length < 2) return;
    await _db
        .into(_db.recentSearches)
        .insertOnConflictUpdate(
          RecentSearchesCompanion.insert(
            query: trimmed.toLowerCase(),
            searchedAt: Value<DateTime>(DateTime.now()),
          ),
        );
    // Keep the table bounded: the UI only ever shows the newest entries.
    final List<SearchRow> rows =
        await (_db.select(_db.recentSearches)
              ..orderBy(<OrderingTerm Function($RecentSearchesTable)>[
                ($RecentSearchesTable table) =>
                    OrderingTerm.desc(table.searchedAt),
              ]))
            .get();
    if (rows.length > 20) {
      final List<String> stale = rows
          .skip(20)
          .map((SearchRow row) => row.query)
          .toList(growable: false);
      await (_db.delete(
        _db.recentSearches,
      )..where((RecentSearches table) => table.query.isIn(stale))).go();
    }
  }

  Future<void> remove(String query) async {
    await (_db.delete(
      _db.recentSearches,
    )..where((RecentSearches table) => table.query.equals(query))).go();
  }

  Future<void> clear() async {
    await _db.delete(_db.recentSearches).go();
  }
}
