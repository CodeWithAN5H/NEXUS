import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../integrations/providers/metadata_provider.dart';
import '../../integrations/providers/provider_failure.dart';
import '../../integrations/providers/provider_descriptor.dart';
import '../../integrations/providers/provider_record.dart';
import '../../integrations/providers/provider_registries.dart';
import '../../integrations/providers/provider_registry_bootstrap.dart';
import '../../integrations/providers/provider_resolver.dart';
import '../../integrations/providers/provider_state.dart';
import '../../integrations/streaming/manifest/manifest_streaming_provider.dart';
import '../../integrations/streaming/streaming_provider.dart';
import '../services/provider_lifecycle_service.dart';
import '../repositories/provider_secret_store.dart';
import '../database/nexus_database.dart';
import '../models/app_settings.dart';
import '../repositories/history_repository.dart';
import '../repositories/library_repository.dart';
import '../repositories/metadata_repository.dart';
import '../repositories/preferences_repository.dart';
import '../repositories/provider_store.dart';

// ── Infrastructure ───────────────────────────────────────────────────────────

/// Single database instance for the app lifetime.
final Provider<NexusDatabase> databaseProvider = Provider<NexusDatabase>((
  Ref ref,
) {
  final NexusDatabase database = NexusDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Configured HTTP client. Only metadata endpoints are ever called.
final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: AppConstants.networkTimeout,
      receiveTimeout: AppConstants.networkTimeout,
      sendTimeout: AppConstants.networkTimeout,
      headers: const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'NEXUS/${AppConstants.appVersion} (Flutter)',
      },
      responseType: ResponseType.json,
      validateStatus: (int? status) => status != null && status < 500,
    ),
  );
  return dio;
});

/// Every streaming provider NEXUS can offer right now: the built-ins compiled
/// into the app, then the installed manifests that are enabled, compatible and
/// configured. There is one registry type, never a parallel one.
final Provider<StreamingProviderRegistry> streamingProviderRegistryProvider =
    Provider<StreamingProviderRegistry>((Ref ref) {
      return StreamingProviderRegistry(<StreamingProvider>[
        ...buildStreamingProviderRegistry().all,
        ...ref.watch(userStreamingProvidersProvider),
      ]);
    });

/// Every *metadata* provider compiled into the app.
final Provider<MetadataProviderRegistry> metadataRegistryProvider =
    Provider<MetadataProviderRegistry>(
      (Ref ref) => buildMetadataProviderRegistry(ref.watch(dioProvider)),
    );

// ── Repositories ─────────────────────────────────────────────────────────────

final Provider<MetadataRepository> metadataRepositoryProvider =
    Provider<MetadataRepository>((Ref ref) {
      final MetadataProvider? catalogue = ref
          .watch(metadataRegistryProvider)
          .primary;
      if (catalogue == null) {
        throw StateError(
          'No compatible metadata provider is registered. AniList is the '
          'built-in catalogue; check provider_registry_bootstrap.dart.',
        );
      }
      return MetadataRepository(catalogue);
    });

final Provider<ProviderStore> providerStoreProvider = Provider<ProviderStore>(
  (Ref ref) => ProviderStore(ref.watch(databaseProvider)),
);

/// Platform keystore wrapper. Only `type: secret` fields are ever written here.
final Provider<ProviderSecretStore> providerSecretStoreProvider =
    Provider<ProviderSecretStore>(
      (Ref ref) => FlutterSecureStorageSecretStore(),
    );

/// Installation, configuration and removal of declarative providers.
final Provider<ProviderLifecycleService> providerLifecycleServiceProvider =
    Provider<ProviderLifecycleService>((Ref ref) {
      return ProviderLifecycleService(
        ref.watch(providerStoreProvider),
        ref.watch(providerSecretStoreProvider),
        builtInIds: <String>{
          for (final StreamingProvider provider
              in buildStreamingProviderRegistry().all)
            provider.id,
        },
      );
    });

/// Installed user providers, revalidated from their stored manifests.
final FutureProvider<List<InstalledProvider>> installedProvidersProvider =
    FutureProvider<List<InstalledProvider>>((Ref ref) {
      return ref.watch(providerLifecycleServiceProvider).loadInstalled();
    });

final Provider<LibraryRepository> libraryRepositoryProvider =
    Provider<LibraryRepository>(
      (Ref ref) => LibraryRepository(ref.watch(databaseProvider)),
    );

final Provider<HistoryRepository> historyRepositoryProvider =
    Provider<HistoryRepository>(
      (Ref ref) => HistoryRepository(ref.watch(databaseProvider)),
    );

final Provider<SearchHistoryRepository> searchHistoryRepositoryProvider =
    Provider<SearchHistoryRepository>(
      (Ref ref) => SearchHistoryRepository(ref.watch(databaseProvider)),
    );

final Provider<PreferencesRepository> preferencesRepositoryProvider =
    Provider<PreferencesRepository>(
      (Ref ref) => PreferencesRepository(ref.watch(databaseProvider)),
    );

// ── Settings ─────────────────────────────────────────────────────────────────

/// Loads settings once, then keeps them in memory while writing through to the
/// database on every change.
///
/// Provider enablement is written to both `provider_entries` (authoritative for
/// resolution) and the legacy `sources.enabled` preference, which stays readable
/// for this release (decision D8).
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(preferencesRepositoryProvider).load();
  }

  Future<void> _set(AppSettings next) async {
    state = AsyncData<AppSettings>(next);
    await ref.read(preferencesRepositoryProvider).save(next);
  }

  AppSettings get _current => switch (state) {
    AsyncData<AppSettings>(:final AppSettings value) => value,
    _ => AppSettings.defaults,
  };

  Future<void> setAutoplayNext(bool value) =>
      _set(_current.copyWith(autoplayNext: value));

  Future<void> setRememberPosition(bool value) =>
      _set(_current.copyWith(rememberPosition: value));

  Future<void> setPreferredQuality(int height) =>
      _set(_current.copyWith(preferredQualityHeight: height));

  Future<void> setSubtitleSize(SubtitleSize size) =>
      _set(_current.copyWith(subtitleSize: size));

  Future<void> setPreferredAudioLanguage(String? language) => _set(
    _current.copyWith(
      preferredAudioLanguage: language,
      clearAudioLanguage: language == null,
    ),
  );

  Future<void> setGridDensity(GridDensity density) =>
      _set(_current.copyWith(gridDensity: density));

  Future<void> setReduceMotion(bool value) =>
      _set(_current.copyWith(reduceMotion: value));

  Future<void> toggleProvider(String id) async {
    final Set<String> next = Set<String>.of(_current.enabledProviderIds);
    if (!next.remove(id)) next.add(id);
    await _set(_current.copyWith(enabledProviderIds: next));
    await ref.read(providerStoreProvider).setEnabled(id, next.contains(id));
    ref.invalidate(providerRecordsProvider);
  }

  /// Persists a user-defined source order (2.1c; the reorder control ships in
  /// 2.2d).
  Future<void> setProviderPriority(List<String> orderedProviderIds) async {
    await ref.read(providerStoreProvider).setPriority(orderedProviderIds);
    ref.invalidate(providerRecordsProvider);
  }

  Future<void> resetToDefaults() => _set(AppSettings.defaults);
}

final AsyncNotifierProvider<SettingsController, AppSettings> settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );

/// Settings with defaults applied — screens read this, never the AsyncValue.
final Provider<AppSettings> appSettingsProvider = Provider<AppSettings>((
  Ref ref,
) {
  return switch (ref.watch(settingsProvider)) {
    AsyncData<AppSettings>(:final AppSettings value) => value,
    _ => AppSettings.defaults,
  };
});

// ── Sources ──────────────────────────────────────────────────────────────────

/// Installed provider rows, seeded with the built-in registrations.
///
/// Resolution and the Sources screen read this, so enablement and priority have
/// exactly one authority (schema v2) while the legacy preference stays in sync.
final FutureProvider<List<ProviderRecord>> providerRecordsProvider =
    FutureProvider<List<ProviderRecord>>((Ref ref) async {
      final ProviderStore store = ref.watch(providerStoreProvider);
      final AppSettings settings = ref.watch(appSettingsProvider);
      // Built-ins only: user providers already have their own rows, and must
      // never be re-seeded as if they were compiled into the app.
      await store.syncBuiltIns(
        buildStreamingProviderRegistry().all,
        enabledIds: settings.enabledProviderIds,
      );
      return store.loadAll();
    });

/// Resolver over the currently loaded records.
///
/// `lookup()` awaits [providerRecordsProvider] itself; this instance is for
/// episode listing and for screens that need the service, not the data.
final Provider<ProviderResolver> sourceResolverProvider =
    Provider<ProviderResolver>((Ref ref) {
      final List<ProviderRecord> records = switch (ref.watch(
        providerRecordsProvider,
      )) {
        AsyncData<List<ProviderRecord>>(:final List<ProviderRecord> value) =>
          value,
        _ => const <ProviderRecord>[],
      };
      return ProviderResolver(
        registry: ref.watch(streamingProviderRegistryProvider),
        records: records,
      );
    });

/// The user's chosen source for one title, if any.
final providerTitlePreferenceProvider = FutureProvider.family<String?, int>((
  Ref ref,
  int animeId,
) {
  return ref.watch(providerStoreProvider).preferenceFor(animeId);
});

/// The three axes plus the derived presentation state for one provider.
///
/// Availability comes from `probe()`, which is an observation, never stored
/// truth. Configurations are read from the row; a secret's presence is signalled
/// by the configuration layer in 2.2c.
final providerStateProvider = FutureProvider.family<ProviderState, String>((
  Ref ref,
  String providerId,
) async {
  final StreamingProviderRegistry registry = ref.watch(
    streamingProviderRegistryProvider,
  );
  final ProviderRegistration<StreamingProvider>? registration = registry
      .registrationFor(providerId);

  final List<InstalledProvider> installedProviders = await ref.watch(
    installedProvidersProvider.future,
  );
  InstalledProvider? installed;
  for (final InstalledProvider candidate in installedProviders) {
    if (candidate.id == providerId) {
      installed = candidate;
      break;
    }
  }

  final List<ProviderRecord> records = await ref.watch(
    providerRecordsProvider.future,
  );
  ProviderRecord? record;
  for (final ProviderRecord candidate in records) {
    if (candidate.providerId == providerId) {
      record = candidate;
      break;
    }
  }

  if (registration == null) {
    // A disabled, unconfigured or invalid user provider is deliberately not in
    // the registry, but Sources still shows its state. Only an id that is
    // neither registered nor installed is genuinely gone.
    final ProviderDescriptor? descriptor = installed?.descriptor;
    if (descriptor == null) {
      throw ProviderNotFound(
        providerId: providerId,
        message: 'This source is no longer registered.',
      );
    }
    return ProviderState.from(
      descriptor: descriptor,
      compatibility: installed!.compatibility,
      configurationValues: installed.presenceConfig,
      availability: ProviderStatusSnapshot(
        availability: ProviderAvailability.unavailable,
        message:
            installed.failure?.message ??
            (installed.record.enabled
                ? 'Not checked yet.'
                : 'This source is turned off.'),
        observedAt: DateTime.now(),
      ),
      enabled: installed.record.enabled,
    );
  }

  ProviderStatusSnapshot snapshot;
  try {
    snapshot = await registration.provider.probe().timeout(
      const Duration(seconds: 10),
    );
  } on Object {
    snapshot = ProviderStatusSnapshot(
      availability: ProviderAvailability.unavailable,
      message: 'This source did not answer in time.',
      observedAt: DateTime.now(),
    );
  }

  return ProviderState.from(
    descriptor: registration.provider,
    compatibility: registration.compatibility,
    // Presence markers from the keystore keep a configured secret from looking
    // like a missing required value.
    configurationValues: <String, String>{
      ...?record?.config,
      ...?installed?.presenceConfig,
    },
    availability: snapshot,
    enabled: record?.enabled ?? false,
  );
});

/// Providers the user could manage in Settings → Sources.
final Provider<List<StreamingProvider>> configuredProvidersProvider =
    Provider<List<StreamingProvider>>(
      (Ref ref) => ref.watch(streamingProviderRegistryProvider).all,
    );

/// Owns the provider instances created from installed manifests.
///
/// Rebuilds the list on demand (install, configuration change, enable, remove),
/// reuses an instance when nothing about it changed, and **disposes** every
/// instance it drops — so a replaced or disabled provider cannot leak an HTTP
/// client or a timer.
class UserStreamingProvidersController
    extends Notifier<List<StreamingProvider>> {
  final Map<String, _OwnedProvider> _owned = <String, _OwnedProvider>{};
  bool _refreshing = false;
  bool _queued = false;
  bool _disposed = false;

  @override
  List<StreamingProvider> build() {
    ref.onDispose(() {
      _disposed = true;
      for (final _OwnedProvider owned in _owned.values) {
        owned.provider.dispose();
      }
      _owned.clear();
    });
    // Deferred: build() stays synchronous, and loading happens once the first
    // frame is scheduled rather than during provider construction.
    Future<void>.microtask(() {
      if (!_disposed) refresh();
    });
    return const <StreamingProvider>[];
  }

  /// Re-reads installed providers and reconciles the live instances.
  Future<void> refresh() async {
    if (_disposed) return;
    if (_refreshing) {
      _queued = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _queued = false;
        final ProviderLifecycleService service = ref.read(
          providerLifecycleServiceProvider,
        );
        // Read through the service, not the cached UI future: this must observe
        // a just-saved enable/disable/removal even when no screen invalidated
        // the UI provider.
        final List<InstalledProvider> entries = await service.loadInstalled();
        final Map<String, (InstalledProvider, String)> desired =
            <String, (InstalledProvider, String)>{};
        for (final InstalledProvider entry in entries) {
          if (!entry.record.enabled) continue;
          if (!entry.isValid || !entry.isCompatible || !entry.isConfigured) {
            continue;
          }
          desired[entry.id] = (entry, _signatureOf(entry, service.revision));
        }

        for (final String id in _owned.keys.toList(growable: false)) {
          final (InstalledProvider, String)? wanted = desired[id];
          if (wanted == null || wanted.$2 != _owned[id]!.signature) {
            await _owned.remove(id)?.provider.dispose();
          }
        }

        for (final MapEntry<String, (InstalledProvider, String)> entry
            in desired.entries) {
          if (_owned.containsKey(entry.key)) continue;
          final ManifestStreamingProvider? provider = await service
              .buildProvider(entry.value.$1);
          if (provider == null) continue;
          _owned[entry.key] = _OwnedProvider(provider, entry.value.$2);
        }

        if (!_disposed) {
          state = List<StreamingProvider>.unmodifiable(
            _owned.values.map((_OwnedProvider owned) => owned.provider),
          );
        }
      } while (_queued && !_disposed);
    } catch (_) {
      // A broken store or keystore must not take app start down; whatever was
      // already loaded stays available and Sources shows the failure.
    } finally {
      _refreshing = false;
    }
  }

  /// Changes identity when the stored manifest or the effective configuration
  /// changes, which is what forces a new instance.
  static String _signatureOf(InstalledProvider entry, int revision) {
    final List<String> keys = entry.config.keys.toList()..sort();
    final List<String> secrets = entry.presentSecrets.toList()..sort();
    return <String>[
      '$revision',
      entry.manifestJson ?? '',
      for (final String key in keys) '$key=${entry.config[key]}',
      secrets.join(','),
    ].join('|');
  }
}

final NotifierProvider<
  UserStreamingProvidersController,
  List<StreamingProvider>
>
userStreamingProvidersProvider =
    NotifierProvider<UserStreamingProvidersController, List<StreamingProvider>>(
      UserStreamingProvidersController.new,
    );

class _OwnedProvider {
  const _OwnedProvider(this.provider, this.signature);

  final ManifestStreamingProvider provider;
  final String signature;
}
