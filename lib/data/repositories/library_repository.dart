import 'package:drift/drift.dart';

import '../../core/errors/app_failure.dart';
import '../database/nexus_database.dart';
import '../models/anime.dart';
import '../models/library.dart';

/// How the library grid is ordered.
enum LibrarySort {
  recentlyUpdated('Recently updated'),
  title('Title A–Z'),
  score('Score'),
  progress('Progress');

  const LibrarySort(this.label);

  final String label;
}

/// Local, offline-first library storage.
///
/// The library is the source of truth for "saved" state; nothing here is
/// synchronised yet, so it must survive updates and never be cleared silently.
class LibraryRepository {
  LibraryRepository(this._db);

  final NexusDatabase _db;

  /// Reactive list for the Library screen, optionally filtered by [status].
  Stream<List<LibraryEntry>> watchEntries({
    LibraryStatus? status,
    LibrarySort sort = LibrarySort.recentlyUpdated,
    String query = '',
  }) {
    final SimpleSelectStatement<$LibraryEntriesTable, LibraryRow> statement =
        _db.select(_db.libraryEntries);

    if (status != null) {
      statement.where(
        (LibraryEntries table) => table.status.equals(status.storageValue),
      );
    }
    final String trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      statement.where(
        (LibraryEntries table) =>
            table.title.lower().contains(trimmed.toLowerCase()),
      );
    }

    switch (sort) {
      case LibrarySort.recentlyUpdated:
        statement.orderBy(<OrderingTerm Function($LibraryEntriesTable)>[
          ($LibraryEntriesTable table) => OrderingTerm.desc(table.updatedAt),
        ]);
      case LibrarySort.title:
        statement.orderBy(<OrderingTerm Function($LibraryEntriesTable)>[
          ($LibraryEntriesTable table) => OrderingTerm.asc(table.title),
        ]);
      case LibrarySort.score:
        statement.orderBy(<OrderingTerm Function($LibraryEntriesTable)>[
          ($LibraryEntriesTable table) => OrderingTerm.desc(table.animeScore),
        ]);
      case LibrarySort.progress:
        statement.orderBy(<OrderingTerm Function($LibraryEntriesTable)>[
          ($LibraryEntriesTable table) =>
              OrderingTerm.desc(table.watchedEpisodes),
        ]);
    }

    return statement.watch().map(
      (List<LibraryRow> rows) => rows.map(_toModel).toList(growable: false),
    );
  }

  /// Every saved title, for badges and counts.
  Stream<List<LibraryEntry>> watchAll() {
    final SimpleSelectStatement<$LibraryEntriesTable, LibraryRow> statement =
        _db.select(_db.libraryEntries)
          ..orderBy(<OrderingTerm Function($LibraryEntriesTable)>[
            ($LibraryEntriesTable table) => OrderingTerm.desc(table.updatedAt),
          ]);
    return statement.watch().map(
      (List<LibraryRow> rows) => rows.map(_toModel).toList(growable: false),
    );
  }

  /// The saved entry for one title, or `null` when it is not in the library.
  Stream<LibraryEntry?> watchEntry(int animeId) {
    return (_db.select(_db.libraryEntries)
          ..where((LibraryEntries table) => table.animeId.equals(animeId)))
        .watchSingleOrNull()
        .map((LibraryRow? row) => row == null ? null : _toModel(row));
  }

  /// Ids of every saved title — used to paint the bookmark state in rails.
  Stream<Set<int>> watchSavedIds() {
    final JoinedSelectStatement<HasResultSet, dynamic> query = _db.selectOnly(
      _db.libraryEntries,
    )..addColumns(<Expression<Object>>[_db.libraryEntries.animeId]);
    return query.watch().map(
      (List<TypedResult> rows) => rows
          .map(
            (TypedResult row) => row.read<int>(_db.libraryEntries.animeId) ?? 0,
          )
          .where((int id) => id != 0)
          .toSet(),
    );
  }

  Future<LibraryEntry?> entryFor(int animeId) async {
    final LibraryRow? row =
        await (_db.select(_db.libraryEntries)
              ..where((LibraryEntries table) => table.animeId.equals(animeId)))
            .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  /// Adds [anime] to the library, or updates its status if already saved.
  /// Progress already recorded by the user is preserved.
  Future<void> save(
    Anime anime, {
    LibraryStatus status = LibraryStatus.planToWatch,
  }) async {
    try {
      final LibraryRow? existing = await _findRow(anime.id);
      await _db
          .into(_db.libraryEntries)
          .insertOnConflictUpdate(
            LibraryEntriesCompanion.insert(
              animeId: Value<int>(anime.id),
              title: anime.displayTitle,
              coverImage: Value<String?>(anime.coverImage),
              bannerImage: Value<String?>(anime.bannerImage),
              status: Value<String>(status.storageValue),
              watchedEpisodes: Value<int>(existing?.watchedEpisodes ?? 0),
              totalEpisodes: Value<int?>(
                anime.episodes ?? existing?.totalEpisodes,
              ),
              animeScore: Value<int?>(anime.averageScore),
              userScore: Value<int?>(existing?.userScore),
              format: Value<String?>(anime.format),
              seasonYear: Value<int?>(anime.seasonYear),
              createdAt: Value<DateTime>(existing?.createdAt ?? DateTime.now()),
              updatedAt: Value<DateTime>(DateTime.now()),
            ),
          );
    } catch (error) {
      throw StorageFailure(
        'Could not save this title to your library.',
        cause: error,
      );
    }
  }

  Future<void> updateStatus(int animeId, LibraryStatus status) async {
    await (_db.update(
      _db.libraryEntries,
    )..where((LibraryEntries table) => table.animeId.equals(animeId))).write(
      LibraryEntriesCompanion(
        status: Value<String>(status.storageValue),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  Future<void> setUserScore(int animeId, int? score) async {
    await (_db.update(
      _db.libraryEntries,
    )..where((LibraryEntries table) => table.animeId.equals(animeId))).write(
      LibraryEntriesCompanion(
        userScore: Value<int?>(score),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// Marks [episodeNumber] as watched, never decreasing recorded progress.
  Future<void> markEpisodeWatched(
    int animeId,
    int episodeNumber, {
    int? totalEpisodes,
  }) async {
    final LibraryRow? row = await _findRow(animeId);
    if (row == null) return;

    final int total = totalEpisodes ?? row.totalEpisodes ?? 0;
    final int next = episodeNumber > row.watchedEpisodes
        ? episodeNumber
        : row.watchedEpisodes;
    final bool finished = total > 0 && next >= total;

    await (_db.update(
      _db.libraryEntries,
    )..where((LibraryEntries table) => table.animeId.equals(animeId))).write(
      LibraryEntriesCompanion(
        watchedEpisodes: Value<int>(next),
        status: finished
            ? const Value<String>('completed')
            : const Value.absent(),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  Future<void> remove(int animeId) async {
    await (_db.delete(
      _db.libraryEntries,
    )..where((LibraryEntries table) => table.animeId.equals(animeId))).go();
  }

  Future<LibraryRow?> _findRow(int animeId) {
    return (_db.select(_db.libraryEntries)
          ..where((LibraryEntries table) => table.animeId.equals(animeId)))
        .getSingleOrNull();
  }

  LibraryEntry _toModel(LibraryRow row) {
    return LibraryEntry(
      animeId: row.animeId,
      title: row.title,
      status: LibraryStatus.fromStorage(row.status),
      coverImage: row.coverImage,
      bannerImage: row.bannerImage,
      animeScore: row.animeScore,
      totalEpisodes: row.totalEpisodes,
      watchedEpisodes: row.watchedEpisodes,
      userScore: row.userScore,
      format: row.format,
      seasonYear: row.seasonYear,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
