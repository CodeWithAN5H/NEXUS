import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where provider credentials live.
///
/// Non-secret configuration belongs in `provider_entries.config_json`; anything
/// declared `type: secret` goes here and nowhere else (PROVIDERS.md §6,
/// PROVIDER_SECURITY.md §3.4). Keys are namespaced `provider.<id>.<key>` so one
/// provider's removal can never touch another's credentials.
abstract class ProviderSecretStore {
  Future<String?> read(String providerId, String key);

  Future<void> write(String providerId, String key, String value);

  Future<void> delete(String providerId, String key);

  /// Deletes every key this provider owns. Never touches another namespace.
  Future<void> deleteProvider(String providerId, Iterable<String> keys);

  /// Which of [keys] currently hold a value, without returning the values.
  ///
  /// Implementations must treat an unreadable keystore as "absent" rather than
  /// throwing: a locked or corrupted store makes a provider need setup, it does
  /// not crash the app or leak an error containing a credential.
  Future<Set<String>> presentKeys(String providerId, Iterable<String> keys);

  static String storageKey(String providerId, String key) =>
      'provider.$providerId.$key';
}

/// `flutter_secure_storage` implementation: Android Keystore, iOS/macOS
/// Keychain, libsecret on Linux.
///
/// Windows support comes from the plugin's DPAPI-backed implementation but is
/// **not verified here** (no Windows host — decision D5), so NEXUS does not claim
/// parity on Windows. If the backend is unavailable the store degrades to
/// "absent", which surfaces as `Setup required` rather than a crash.
class FlutterSecureStorageSecretStore implements ProviderSecretStore {
  FlutterSecureStorageSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String providerId, String key) async {
    try {
      return await _storage.read(
        key: ProviderSecretStore.storageKey(providerId, key),
      );
    } catch (_) {
      // Inaccessible or corrupted entry: report absence, never the error text
      // (which can contain the key name or platform detail).
      return null;
    }
  }

  @override
  Future<void> write(String providerId, String key, String value) async {
    try {
      await _storage.write(
        key: ProviderSecretStore.storageKey(providerId, key),
        value: value,
      );
    } catch (_) {
      throw const SecretStorageUnavailable();
    }
  }

  @override
  Future<void> delete(String providerId, String key) async {
    try {
      await _storage.delete(
        key: ProviderSecretStore.storageKey(providerId, key),
      );
    } catch (_) {
      // Deleting is best effort; a stale key is unusable without its provider
      // row, and failing here must not make removal impossible.
    }
  }

  @override
  Future<void> deleteProvider(String providerId, Iterable<String> keys) async {
    for (final String key in keys) {
      await delete(providerId, key);
    }
    // A corrupt manifest may not reveal its secret field names, so sweep the
    // provider's namespace too. This can only ever remove that provider's keys.
    final String prefix = 'provider.$providerId.';
    try {
      final Map<String, String> all = await _storage.readAll();
      for (final String key in all.keys) {
        if (key.startsWith(prefix)) await _storage.delete(key: key);
      }
    } catch (_) {
      // Best effort, as with the named keys above.
    }
  }

  @override
  Future<Set<String>> presentKeys(
    String providerId,
    Iterable<String> keys,
  ) async {
    final Set<String> present = <String>{};
    for (final String key in keys) {
      final String? value = await read(providerId, key);
      if (value != null && value.isNotEmpty) present.add(key);
    }
    return present;
  }
}

/// The platform keystore could not be written.
///
/// Deliberately carries no platform message: it can name the key or the backend,
/// and this text reaches the UI.
class SecretStorageUnavailable implements Exception {
  const SecretStorageUnavailable();

  String get message =>
      'NEXUS could not reach secure storage on this device, so the credential '
      'was not saved.';

  @override
  String toString() => message;
}
