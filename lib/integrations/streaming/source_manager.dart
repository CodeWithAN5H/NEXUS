import '../../data/models/anime.dart';
import 'streaming_provider.dart';

/// Holds every registered provider.
///
/// Registering a new source is a one-line change here; no screen references a
/// concrete provider type.
class ProviderRegistry {
  const ProviderRegistry(this.providers);

  final List<StreamingProvider> providers;

  List<StreamingProvider> get all => providers;

  StreamingProvider? byId(String id) {
    for (final StreamingProvider provider in providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  /// Providers the user has enabled, filtered to those that are usable.
  List<StreamingProvider> enabled(Set<String> enabledIds) {
    return providers
        .where((StreamingProvider provider) => enabledIds.contains(provider.id))
        .toList(growable: false);
  }
}

/// A provider that can serve a specific title.
class SourceResolution {
  const SourceResolution({required this.provider, required this.series});

  final StreamingProvider provider;
  final ProviderSeries series;
}

/// The outcome of asking every enabled source about one title.
class SourceLookup {
  const SourceLookup({
    this.resolution,
    this.failures = const <String, String>{},
    this.attempted = 0,
  });

  final SourceResolution? resolution;

  /// provider id → failure message, for the "source errors" UI.
  final Map<String, String> failures;

  /// Number of providers that were asked.
  final int attempted;

  bool get hasSource => resolution != null;

  bool get hasFailures => failures.isNotEmpty;
}

/// Application service that hides the provider list from the UI.
class SourceManager {
  const SourceManager(this._registry, this._enabledIds);

  final ProviderRegistry _registry;
  final Set<String> _enabledIds;

  List<StreamingProvider> get enabledProviders =>
      _registry.enabled(_enabledIds);

  List<StreamingProvider> get activeProviders => enabledProviders
      .where((StreamingProvider provider) => provider.status.isUsable)
      .toList(growable: false);

  /// Finds the first enabled provider that recognises [anime].
  Future<SourceLookup> lookup(Anime anime) async {
    final List<StreamingProvider> candidates = activeProviders
        .where(
          (StreamingProvider provider) =>
              provider.capabilities.contains(ProviderCapability.seriesMatching),
        )
        .toList(growable: false);

    final Map<String, String> failures = <String, String>{};
    for (final StreamingProvider provider in candidates) {
      try {
        final ProviderSeries? series = await provider.match(anime);
        if (series != null) {
          return SourceLookup(
            resolution: SourceResolution(provider: provider, series: series),
            failures: failures,
            attempted: candidates.length,
          );
        }
      } on ProviderException catch (error) {
        failures[provider.id] = error.message;
      } catch (error) {
        failures[provider.id] = error.toString();
      }
    }

    return SourceLookup(failures: failures, attempted: candidates.length);
  }

  /// Episodes for a resolved title, de-duplicated and ordered.
  Future<List<ProviderEpisode>> episodesFor(
    SourceResolution resolution, {
    String? seasonId,
  }) async {
    final List<ProviderEpisode> episodes = await resolution.provider.episodes(
      resolution.series,
      seasonId: seasonId,
    );
    final List<ProviderEpisode> sorted = <ProviderEpisode>[...episodes]
      ..sort(
        (ProviderEpisode a, ProviderEpisode b) => a.number.compareTo(b.number),
      );
    return sorted;
  }
}
