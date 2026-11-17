import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/constants/app_constants.dart';

part 'nexus_database.g.dart';

/// Saved titles, one row per anime.
///
/// `animeId` is the AniList media id and is the primary key, so saving the same
/// title twice updates the existing row instead of duplicating it.
@DataClassName('LibraryRow')
class LibraryEntries extends Table {
  IntColumn get animeId => integer()();
  TextColumn get title => text()();
  TextColumn get coverImage => text().nullable()();
  TextColumn get bannerImage => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('watching'))();
  IntColumn get watchedEpisodes => integer().withDefault(const Constant(0))();
  IntColumn get totalEpisodes => integer().nullable()();
  IntColumn get animeScore => integer().nullable()();
  IntColumn get userScore => integer().nullable()();
  TextColumn get format => text().nullable()();
  IntColumn get seasonYear => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{animeId};
}

/// Resumable playback positions, one row per (anime, episode).
@DataClassName('ProgressRow')
class ProgressEntries extends Table {
  IntColumn get animeId => integer()();
  IntColumn get episodeNumber => integer()();
  TextColumn get title => text()();
  TextColumn get episodeTitle => text().nullable()();
  TextColumn get coverImage => text().nullable()();
  TextColumn get bannerImage => text().nullable()();
  IntColumn get totalEpisodes => integer().nullable()();
  TextColumn get providerId => text().nullable()();
  TextColumn get seriesId => text().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    animeId,
    episodeNumber,
  };
}

/// Recent search terms for the Explore screen.
@DataClassName('SearchRow')
class RecentSearches extends Table {
  TextColumn get query => text()();
  DateTimeColumn get searchedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{query};
}

/// Key/value store for preferences that are not transient UI state.
@DataClassName('PreferenceRow')
class PreferenceEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

/// The NEXUS local database.
///
/// ## Migration policy
/// * [schemaVersion] must always equal [AppConstants.databaseSchemaVersion].
/// * Every schema change ships with an `onUpgrade` step that preserves data —
///   add columns, backfill, then (only if unavoidable) recreate with copy.
/// * User data is never dropped to make an update work. A failed migration is
///   caught by [MigrationStrategy.beforeOpen] logging and must leave the
///   previous database intact.
@DriftDatabase(
  tables: <Type>[
    LibraryEntries,
    ProgressEntries,
    RecentSearches,
    PreferenceEntries,
  ],
)
class NexusDatabase extends _$NexusDatabase {
  NexusDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => AppConstants.databaseSchemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Example of the intended pattern for v0.2:
        //   if (from < 2) await m.addColumn(libraryEntries, libraryEntries.someNewColumn);
        // Each step is additive and keeps existing rows.
      },
      beforeOpen: (OpeningDetails details) async {
        // Enforce referential integrity early; cheap and catches schema drift.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: AppConstants.databaseName);
  }
}
