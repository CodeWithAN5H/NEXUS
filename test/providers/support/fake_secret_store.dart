import 'package:nexus/data/repositories/provider_secret_store.dart';

/// In-memory keystore. Tests never touch the platform one.
class FakeSecretStore implements ProviderSecretStore {
  final Map<String, Map<String, String>> data = <String, Map<String, String>>{};

  /// When true, every write fails as if the platform keystore were unavailable.
  bool failWrites = false;

  /// Every write attempted, including rolled-back ones.
  final List<String> writeLog = <String>[];

  Map<String, String> _namespace(String providerId) =>
      data.putIfAbsent(providerId, () => <String, String>{});

  @override
  Future<String?> read(String providerId, String key) async =>
      data[providerId]?[key];

  @override
  Future<void> write(String providerId, String key, String value) async {
    writeLog.add('$providerId.$key');
    if (failWrites) throw const SecretStorageUnavailable();
    _namespace(providerId)[key] = value;
  }

  @override
  Future<void> delete(String providerId, String key) async {
    data[providerId]?.remove(key);
    if (data[providerId]?.isEmpty ?? false) data.remove(providerId);
  }

  @override
  Future<void> deleteProvider(String providerId, Iterable<String> keys) async {
    for (final String key in keys) {
      await delete(providerId, key);
    }
    // Mirrors the real store's namespace sweep for a corrupt manifest.
    data.remove(providerId);
  }

  @override
  Future<Set<String>> presentKeys(
    String providerId,
    Iterable<String> keys,
  ) async {
    return <String>{
      for (final String key in keys)
        if ((data[providerId]?[key] ?? '').isNotEmpty) key,
    };
  }

  /// Every value currently stored, for "must never appear in SQLite" assertions.
  Iterable<String> get allValues sync* {
    for (final Map<String, String> namespace in data.values) {
      yield* namespace.values;
    }
  }
}
