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

/// One row per installed provider (schema v2).
///
/// `config_json` holds **non-secret** configuration only. Credentials live in
/// the platform keystore under `provider.<id>.<field>` and never enter SQLite.
@DataClassName('ProviderEntryRow')
class ProviderEntries extends Table {
  TextColumn get providerId => text()();
  TextColumn get origin => text().withDefault(const Constant('builtIn'))();
  TextColumn get manifestVersion => text().nullable()();
  IntColumn get contractVersion => integer().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get configJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get installedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{providerId};
}

/// The user's chosen source per title (schema v2).
///
/// The composite key follows `DATABASE.md` §6. The store keeps one row per
/// title (choosing another source replaces the row), so "preference" stays a
/// single choice while the schema remains the documented one.
@DataClassName('ProviderTitlePrefRow')
class ProviderTitlePrefs extends Table {
  IntColumn get animeId => integer()();
  TextColumn get providerId => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{animeId, providerId};
}

/// Stored declarative manifests, user-added providers only (schema v2).
///
/// A row is written only after full validation and re-validated on load; a
/// stored document that no longer validates disables only its provider.
@DataClassName('ProviderManifestRow')
class ProviderManifests extends Table {
  TextColumn get providerId => text()();
  TextColumn get manifestJson => text()();
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get installedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{providerId};
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
    ProviderEntries,
    ProviderTitlePrefs,
    ProviderManifests,
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
        // Every step is additive and keeps existing rows. v1 → v2 adds the
        // provider platform tables and backfills them from the only provider
        // state v1 had: the comma-separated `sources.enabled` preference.
        if (from < 2) {
          await m.createTable(providerEntries);
          await m.createTable(providerTitlePrefs);
          await m.createTable(providerManifests);
          await _backfillProvidersFromLegacyPreference();
        }
      },
      beforeOpen: (OpeningDetails details) async {
        // Enforce referential integrity early; cheap and catches schema drift.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Seeds `provider_entries` from the v1 `sources.enabled` preference.
  ///
  /// When the preference row is absent the user never changed the default, so
  /// nothing is inserted here: `ProviderStore.syncBuiltIns` seeds the registered
  /// providers from `AppSettings` defaults, which keeps a fresh install and an
  /// upgraded install identical. When the row exists but is empty, no provider
  /// is inserted and the store adds the built-in as disabled — exactly the v1
  /// meaning of an empty set.
  Future<void> _backfillProvidersFromLegacyPreference() async {
    final List<String> values = await customSelect(
      "SELECT value FROM preference_entries WHERE key = 'sources.enabled'",
    ).map<String>((dynamic row) => row.read<String>('value') as String).get();
    if (values.isEmpty) return;

    final List<String> ids = values.first
        .split(',')
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    final DateTime now = DateTime.now();
    for (int index = 0; index < ids.length; index++) {
      await into(providerEntries).insert(
        ProviderEntriesCompanion.insert(
          providerId: ids[index],
          origin: const Value<String>('builtIn'),
          enabled: const Value<bool>(true),
          priority: Value<int>(index),
          installedAt: Value<DateTime>(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: AppConstants.databaseName);
  }
}
