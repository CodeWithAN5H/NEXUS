import 'package:drift/drift.dart';

import '../../core/errors/app_failure.dart';
import '../database/nexus_database.dart';
import '../models/app_settings.dart';

/// Reads and writes [AppSettings] to the local database.
///
/// Preferences live in SQLite rather than SharedPreferences so that a single
/// versioned database covers library, history *and* settings — one migration
/// story instead of two.
class PreferencesRepository {
  PreferencesRepository(this._db);

  final NexusDatabase _db;

  Future<AppSettings> load() async {
    try {
      final List<PreferenceRow> rows = await _db
          .select(_db.preferenceEntries)
          .get();
      if (rows.isEmpty) return AppSettings.defaults;
      return AppSettings.fromMap(<String, String>{
        for (final PreferenceRow row in rows) row.key: row.value,
      });
    } catch (error) {
      throw StorageFailure('Could not read your settings.', cause: error);
    }
  }

  Future<void> save(AppSettings settings) async {
    try {
      final Map<String, String> values = settings.toMap();
      final DateTime now = DateTime.now();
      await _db.batch(
        (Batch batch) => batch.insertAllOnConflictUpdate(
          _db.preferenceEntries,
          values.entries
              .map(
                (MapEntry<String, String> entry) =>
                    PreferenceEntriesCompanion.insert(
                      key: entry.key,
                      value: entry.value,
                      updatedAt: Value<DateTime>(now),
                    ),
              )
              .toList(growable: false),
        ),
      );
    } catch (error) {
      throw StorageFailure('Could not save your settings.', cause: error);
    }
  }
}
