import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../integrations/anilist/anilist_client.dart';
import '../../integrations/streaming/provider_registry_bootstrap.dart';
import '../../integrations/streaming/source_manager.dart';
import '../../integrations/streaming/streaming_provider.dart';
import '../database/nexus_database.dart';
import '../models/app_settings.dart';
import '../repositories/history_repository.dart';
import '../repositories/library_repository.dart';
import '../repositories/metadata_repository.dart';
import '../repositories/preferences_repository.dart';

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

// ── Repositories ─────────────────────────────────────────────────────────────

final Provider<AniListClient> aniListClientProvider = Provider<AniListClient>(
  (Ref ref) => AniListClient(ref.watch(dioProvider)),
);

final Provider<MetadataRepository> metadataRepositoryProvider =
    Provider<MetadataRepository>(
      (Ref ref) => MetadataRepository(ref.watch(aniListClientProvider)),
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

  Future<void> toggleProvider(String id) {
    final Set<String> next = Set<String>.of(_current.enabledProviderIds);
    if (!next.remove(id)) next.add(id);
    return _set(_current.copyWith(enabledProviderIds: next));
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

/// Every provider known to the app.
final Provider<ProviderRegistry> providerRegistryProvider =
    Provider<ProviderRegistry>((Ref ref) => buildProviderRegistry());

final Provider<SourceManager> sourceManagerProvider = Provider<SourceManager>((
  Ref ref,
) {
  final AppSettings settings = ref.watch(appSettingsProvider);
  return SourceManager(
    ref.watch(providerRegistryProvider),
    settings.enabledProviderIds,
  );
});

/// Providers the user could manage in Settings → Sources.
final Provider<List<StreamingProvider>> configuredProvidersProvider =
    Provider<List<StreamingProvider>>(
      (Ref ref) => ref.watch(providerRegistryProvider).all,
    );
