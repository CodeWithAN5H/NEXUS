import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../integrations/providers/metadata_provider.dart';
import '../../integrations/providers/provider_failure.dart';
import '../../integrations/providers/provider_record.dart';
import '../../integrations/providers/provider_registries.dart';
import '../../integrations/providers/provider_registry_bootstrap.dart';
import '../../integrations/providers/provider_resolver.dart';
import '../../integrations/providers/provider_state.dart';
import '../../integrations/streaming/streaming_provider.dart';
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

/// Every *streaming* provider compiled into the app, with compatibility
/// evaluated once at registration.
final Provider<StreamingProviderRegistry> streamingProviderRegistryProvider =
    Provider<StreamingProviderRegistry>(
      (Ref ref) => buildStreamingProviderRegistry(),
    );

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
      await store.syncBuiltIns(
        ref.watch(streamingProviderRegistryProvider).all,
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
  if (registration == null) {
    throw ProviderNotFound(
      providerId: providerId,
      message: 'This source is no longer registered.',
    );
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
    configurationValues: record?.config ?? const <String, String>{},
    availability: snapshot,
    enabled: record?.enabled ?? false,
  );
});

/// Providers the user could manage in Settings → Sources.
final Provider<List<StreamingProvider>> configuredProvidersProvider =
    Provider<List<StreamingProvider>>(
      (Ref ref) => ref.watch(streamingProviderRegistryProvider).all,
    );
