# NEXUS — Local Database

## 1. Overview

| Item | Value |
|---|---|
| Engine | SQLite via **Drift 2.35.4** (`drift_flutter` 0.3.1 bundles the native library on Android and Windows) |
| File | `nexus.sqlite` in the platform application-documents directory (`getApplicationDocumentsDirectory`) |
| Schema version | `1` — `AppConstants.databaseSchemaVersion` must always equal `NexusDatabase.schemaVersion` |
| Generated code | `lib/data/database/nexus_database.g.dart` (`dart run build_runner build`) |
| Foreign keys | `PRAGMA foreign_keys = ON` in `beforeOpen` |

User data lives entirely on the device. Nothing here is synchronised yet; the schema is designed so a future sync layer can add server ids without rewriting local rows.

## 2. Schema v1

### 2.1 `library_entries` — saved titles

| Column | Type | Notes |
|---|---|---|
| `anime_id` | INTEGER, **PK** | AniList media id (negative for provider-local content) |
| `title` | TEXT NOT NULL | Display title at save time |
| `cover_image` | TEXT NULL | |
| `banner_image` | TEXT NULL | |
| `status` | TEXT NOT NULL, default `'watching'` | `watching`, `completed`, `on_hold`, `dropped`, `plan_to_watch` |
| `watched_episodes` | INTEGER NOT NULL, default `0` | High-water mark, never decreases |
| `total_episodes` | INTEGER NULL | From metadata when known |
| `anime_score` | INTEGER NULL | AniList 0–100 average |
| `user_score` | INTEGER NULL | The user's own 0–100 rating |
| `format` | TEXT NULL | TV, MOVIE, … |
| `season_year` | INTEGER NULL | |
| `created_at` | DATETIME NOT NULL | Set once on first save |
| `updated_at` | DATETIME NOT NULL | Touched on every change; drives sorting |

One row per title. `anime_id` is the primary key, so `insertOnConflictUpdate` is an upsert — saving the same title twice never duplicates it or resets progress.

### 2.2 `progress_entries` — resumable positions

| Column | Type | Notes |
|---|---|---|
| `anime_id` | INTEGER | Part of composite PK |
| `episode_number` | INTEGER | Part of composite PK |
| `title` | TEXT NOT NULL | |
| `episode_title` | TEXT NULL | |
| `cover_image`, `banner_image` | TEXT NULL | Kept so History renders without a network call |
| `total_episodes` | INTEGER NULL | |
| `provider_id`, `series_id` | TEXT NULL | Lets Continue Watching resume directly instead of re-resolving the title |
| `position_ms` | INTEGER NOT NULL, default `0` | |
| `duration_ms` | INTEGER NOT NULL, default `0` | |
| `updated_at` | DATETIME NOT NULL | Ordered descending |

- Primary key `(anime_id, episode_number)`; the player upserts the same row every 5 seconds while playing.
- Timestamps have **second** precision (Drift's default integer storage), so ordering breaks ties on `episode_number` to keep the rail stable.
- Continue Watching is derived, not stored: newest row per title, skipping positions under 5 seconds and episodes ≥ 99.5 % complete.

### 2.3 `recent_searches`

| Column | Type | Notes |
|---|---|---|
| `query` | TEXT, **PK** | Lower-cased; re-searching moves the row to the top |
| `searched_at` | DATETIME NOT NULL | |

Queries shorter than two characters are ignored. The table is trimmed to the newest 20 rows.

### 2.4 `preference_entries`

| Column | Type | Notes |
|---|---|---|
| `key` | TEXT, **PK** | Namespaced, e.g. `playback.autoplay_next` |
| `value` | TEXT NOT NULL | `true`/`false`, integers, enum names, comma-separated sets |
| `updated_at` | DATETIME NOT NULL | |

Preferences live in SQLite rather than `SharedPreferences` so library, history and settings share a single migration story. `AppSettings.fromMap` tolerates unknown or missing values and falls back to defaults.

Keys: `playback.autoplay_next`, `playback.remember_position`, `playback.quality_height`, `subtitles.size`, `audio.language`, `sources.enabled`, `appearance.grid_density`, `appearance.reduce_motion`.

## 3. Migration policy

1. **Never drop user data.** No `deleteAll`, no "clear app data to update".
2. Bump `AppConstants.databaseSchemaVersion` and add an `onUpgrade` step in the same commit.
3. Steps are additive first: `addColumn` + backfill. Rebuild-and-copy is allowed only when SQLite cannot express the change.
4. Migrations run before the first query (`beforeOpen`), and a failure surfaces as a `StorageFailure` instead of silently destroying rows.

Adding a setting or a column in v0.2 looks like this:

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async => m.createAll(),
  onUpgrade: (Migrator m, int from, int to) async {
    if (from < 2) {
      await m.addColumn(libraryEntries, libraryEntries.notes);
      // Backfill so existing rows satisfy the new expectation.
      await customStatement("UPDATE library_entries SET notes = '' WHERE notes IS NULL");
    }
  },
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

Regenerate after editing the schema:

```bash
dart run build_runner build
```

## 4. Data preservation — what is verified

`test/database_test.dart` opens a real SQLite file, writes a library entry, progress and a setting, closes the database, reopens the same file (simulating an app update) and asserts the library progress, playback position and quality setting are intact.

Also covered:

- Upserts do not duplicate library rows and do not reset `watched_episodes`.
- `markEpisodeWatched` never lowers progress and flips the entry to `completed` on the final episode.
- Continue Watching deduplicates titles and hides unstarted/finished episodes.
- Search history de-duplicates, trims to 20 rows and can be cleared.
- Settings round-trip through the storage map, including explicit clearing of the audio language.

## 5. Queries and indexes

The dataset is small (hundreds of rows), so v1 relies on primary keys plus an `ORDER BY updated_at DESC` scan. If libraries grow into the thousands, add:

```sql
CREATE INDEX idx_library_status ON library_entries(status);
CREATE INDEX idx_progress_updated ON progress_entries(updated_at DESC);
```

## 6. Future (not implemented)

- **Sync metadata**: `server_id`, `synced_at`, `dirty` columns plus a per-table change log for Supabase (or self-hosted) sync.
- **Export/import**: JSON dump of library, history and settings for device migration.
- **Cache table**: TTL-cached metadata to make the app usable offline (currently only in-memory, so rails need a network on cold start).
