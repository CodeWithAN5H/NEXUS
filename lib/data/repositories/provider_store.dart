import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/errors/app_failure.dart';
import '../../integrations/providers/provider_descriptor.dart';
import '../../integrations/providers/provider_record.dart';
import '../database/nexus_database.dart';

/// Reads and writes provider platform state (schema v2).
///
/// Nothing in this store touches library entries, playback progress or
/// preferences: installing, disabling or removing a provider must never damage
/// user data. Secrets are never written here.
class ProviderStore {
  ProviderStore(this._db);

  final NexusDatabase _db;

  /// A stored manifest is capped at 512 KiB, checked before it is parsed.
  static const int maxManifestBytes = 512 * 1024;

  Future<List<ProviderRecord>> loadAll() async {
    try {
      final List<ProviderEntryRow> rows =
          await (_db.select(_db.providerEntries)..orderBy([
                (t) => OrderingTerm(expression: t.priority),
                (t) => OrderingTerm(expression: t.installedAt),
              ]))
              .get();
      return rows.map(_toRecord).toList(growable: false);
    } catch (error) {
      throw StorageFailure('Could not read your sources.', cause: error);
    }
  }

  /// Inserts a row for every registered built-in provider that has none yet.
  ///
  /// Newly seen built-ins inherit the legacy `sources.enabled` meaning: enabled
  /// only when the user's v1 set contained them. Existing rows are never
  /// modified, so this is safe to call on every app start.
  Future<void> syncBuiltIns(
    Iterable<ProviderDescriptor> builtIns, {
    required Set<String> enabledIds,
  }) async {
    try {
      final List<ProviderRecord> existing = await loadAll();
      final Set<String> known = <String>{
        for (final ProviderRecord record in existing) record.providerId,
      };
      int nextPriority = existing.isEmpty
          ? 0
          : existing
                    .map((ProviderRecord record) => record.priority)
                    .reduce((int a, int b) => a > b ? a : b) +
                1;
      final DateTime now = DateTime.now();
      for (final ProviderDescriptor provider in builtIns) {
        if (!known.add(provider.id)) continue;
        await _db
            .into(_db.providerEntries)
            .insert(
              ProviderEntriesCompanion.insert(
                providerId: provider.id,
                origin: Value<String>(provider.origin.name),
                contractVersion: Value<int>(provider.contract.max),
                enabled: Value<bool>(enabledIds.contains(provider.id)),
                priority: Value<int>(nextPriority++),
                installedAt: Value<DateTime>(now),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    } catch (error) {
      throw StorageFailure('Could not prepare your sources.', cause: error);
    }
  }

  Future<void> setEnabled(String providerId, bool enabled) {
    return _write(
      () =>
          (_db.update(_db.providerEntries)
                ..where((table) => table.providerId.equals(providerId)))
              .write(ProviderEntriesCompanion(enabled: Value<bool>(enabled))),
      failure: 'Could not update that source.',
    );
  }

  /// Stores the user's order. Ids that are not installed are ignored.
  Future<void> setPriority(List<String> orderedProviderIds) async {
    try {
      await _db.transaction(() async {
        for (int index = 0; index < orderedProviderIds.length; index++) {
          await (_db.update(_db.providerEntries)..where(
                (table) => table.providerId.equals(orderedProviderIds[index]),
              ))
              .write(ProviderEntriesCompanion(priority: Value<int>(index)));
        }
      });
    } catch (error) {
      throw StorageFailure('Could not save the source order.', cause: error);
    }
  }

  /// One choice per title: replacing it deletes the previous row.
  Future<void> setPreference(int animeId, String providerId) async {
    try {
      await _db.transaction(() async {
        await (_db.delete(
          _db.providerTitlePrefs,
        )..where((table) => table.animeId.equals(animeId))).go();
        await _db
            .into(_db.providerTitlePrefs)
            .insert(
              ProviderTitlePrefsCompanion.insert(
                animeId: animeId,
                providerId: providerId,
                updatedAt: Value<DateTime>(DateTime.now()),
              ),
            );
      });
    } catch (error) {
      throw StorageFailure('Could not save that source choice.', cause: error);
    }
  }

  Future<String?> preferenceFor(int animeId) async {
    try {
      final ProviderTitlePrefRow? row =
          await (_db.select(_db.providerTitlePrefs)
                ..where((table) => table.animeId.equals(animeId))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(1))
              .getSingleOrNull();
      return row?.providerId;
    } catch (error) {
      throw StorageFailure('Could not read that source choice.', cause: error);
    }
  }

  Future<void> clearPreference(int animeId) {
    return _write(
      () => (_db.delete(
        _db.providerTitlePrefs,
      )..where((table) => table.animeId.equals(animeId))).go(),
      failure: 'Could not clear that source choice.',
    );
  }

  /// Inserts or replaces one provider row.
  Future<void> upsert(ProviderRecord record) {
    return _write(
      () => _db
          .into(_db.providerEntries)
          .insertOnConflictUpdate(
            ProviderEntriesCompanion.insert(
              providerId: record.providerId,
              origin: Value<String>(record.origin.name),
              manifestVersion: Value<String?>(record.manifestVersion),
              contractVersion: Value<int?>(record.contractVersion),
              enabled: Value<bool>(record.enabled),
              priority: Value<int>(record.priority),
              configJson: Value<String>(jsonEncode(record.config)),
              installedAt: Value<DateTime>(record.installedAt),
            ),
          ),
      failure: 'Could not save that source.',
    );
  }

  /// Persists a newly installed user provider: its row and its manifest in one
  /// transaction, so a failure cannot leave a provider without a manifest (or a
  /// manifest without a provider).
  ///
  /// The caller writes secrets first; `ProviderLifecycleService` removes them if
  /// this throws.
  Future<void> installUserProvider({
    required ProviderRecord record,
    required String manifestJson,
    String? sourceUrl,
  }) async {
    if (utf8.encode(manifestJson).length > maxManifestBytes) {
      throw const StorageFailure(
        'That manifest is larger than the 512 KiB limit.',
        cause: null,
      );
    }
    try {
      await _db.transaction(() async {
        await _db
            .into(_db.providerManifests)
            .insertOnConflictUpdate(
              ProviderManifestsCompanion.insert(
                providerId: record.providerId,
                manifestJson: manifestJson,
                sourceUrl: Value<String?>(sourceUrl),
                installedAt: Value<DateTime>(record.installedAt),
              ),
            );
        await _db
            .into(_db.providerEntries)
            .insertOnConflictUpdate(
              ProviderEntriesCompanion.insert(
                providerId: record.providerId,
                origin: Value<String>(record.origin.name),
                manifestVersion: Value<String?>(record.manifestVersion),
                contractVersion: Value<int?>(record.contractVersion),
                enabled: Value<bool>(record.enabled),
                priority: Value<int>(record.priority),
                configJson: Value<String>(jsonEncode(record.config)),
                installedAt: Value<DateTime>(record.installedAt),
              ),
            );
      });
    } catch (error) {
      if (error is StorageFailure) rethrow;
      throw StorageFailure('Could not install that source.', cause: error);
    }
  }

  /// Replaces the non-secret configuration of one provider.
  Future<void> setConfig(String providerId, Map<String, String> config) {
    return _write(
      () =>
          (_db.update(
            _db.providerEntries,
          )..where((table) => table.providerId.equals(providerId))).write(
            ProviderEntriesCompanion(
              configJson: Value<String>(jsonEncode(config)),
            ),
          ),
      failure: 'Could not save that configuration.',
    );
  }

  /// Next free priority, so a new provider runs after existing ones.
  Future<int> nextPriority() async {
    try {
      final List<ProviderEntryRow> rows = await _db
          .select(_db.providerEntries)
          .get();
      if (rows.isEmpty) return 0;
      return rows
              .map((ProviderEntryRow row) => row.priority)
              .reduce((int a, int b) => a > b ? a : b) +
          1;
    } catch (error) {
      throw StorageFailure('Could not read the source order.', cause: error);
    }
  }

  /// Deletes a provider's own rows — entry, per-title choices and manifest.
  ///
  /// Library entries, history and playback positions are deliberately untouched:
  /// they are keyed by metadata identity, not by provider identity.
  Future<void> remove(String providerId) async {
    try {
      await _db.transaction(() async {
        await (_db.delete(
          _db.providerEntries,
        )..where((table) => table.providerId.equals(providerId))).go();
        await (_db.delete(
          _db.providerTitlePrefs,
        )..where((table) => table.providerId.equals(providerId))).go();
        await (_db.delete(
          _db.providerManifests,
        )..where((table) => table.providerId.equals(providerId))).go();
      });
    } catch (error) {
      throw StorageFailure('Could not remove that source.', cause: error);
    }
  }

  Future<void> saveManifest({
    required String providerId,
    required String manifestJson,
    String? sourceUrl,
    DateTime? installedAt,
  }) async {
    if (utf8.encode(manifestJson).length > maxManifestBytes) {
      throw const StorageFailure(
        'That manifest is larger than the 512 KiB limit.',
        cause: null,
      );
    }
    await _write(
      () => _db
          .into(_db.providerManifests)
          .insertOnConflictUpdate(
            ProviderManifestsCompanion.insert(
              providerId: providerId,
              manifestJson: manifestJson,
              sourceUrl: Value<String?>(sourceUrl),
              installedAt: Value<DateTime>(installedAt ?? DateTime.now()),
            ),
          ),
      failure: 'Could not store that manifest.',
    );
  }

  Future<String?> manifestJsonFor(String providerId) async {
    try {
      final ProviderManifestRow? row =
          await (_db.select(_db.providerManifests)
                ..where((table) => table.providerId.equals(providerId)))
              .getSingleOrNull();
      return row?.manifestJson;
    } catch (error) {
      throw StorageFailure('Could not read that manifest.', cause: error);
    }
  }

  ProviderRecord _toRecord(ProviderEntryRow row) {
    return ProviderRecord(
      providerId: row.providerId,
      origin: ProviderOrigin.values.firstWhere(
        (ProviderOrigin origin) => origin.name == row.origin,
        orElse: () => ProviderOrigin.builtIn,
      ),
      enabled: row.enabled,
      priority: row.priority,
      installedAt: row.installedAt,
      manifestVersion: row.manifestVersion,
      contractVersion: row.contractVersion,
      config: _decodeConfig(row.configJson),
    );
  }

  static Map<String, String> _decodeConfig(String? json) {
    if (json == null || json.trim().isEmpty) return const <String, String>{};
    try {
      final Object? decoded = jsonDecode(json);
      if (decoded is! Map) return const <String, String>{};
      final Map<String, String> config = <String, String>{};
      for (final Object? key in decoded.keys) {
        final Object? value = decoded[key];
        if (key is String && value is String) config[key] = value;
      }
      return config;
    } on FormatException {
      // A corrupt config row must not break app start; the declaration decides
      // whether the provider is usable without it.
      return const <String, String>{};
    }
  }

  Future<void> _write(
    Future<void> Function() operation, {
    required String failure,
  }) async {
    try {
      await operation();
    } catch (error) {
      throw StorageFailure(failure, cause: error);
    }
  }
}
