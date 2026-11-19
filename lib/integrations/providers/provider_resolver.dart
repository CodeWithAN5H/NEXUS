import 'dart:async';
import 'dart:math' as math;

import '../../data/models/anime.dart';
import '../streaming/streaming_provider.dart';
import 'provider_failure.dart';
import 'provider_record.dart';
import 'provider_registries.dart';
import 'provider_state.dart';

/// A provider that can serve a specific title.
class SourceResolution {
  const SourceResolution({
    required this.provider,
    required this.series,
    required this.availability,
    this.priority = 0,
  });

  final StreamingProvider provider;
  final ProviderSeries series;

  /// Availability observed when the title was resolved — used to label sample
  /// media without a second probe.
  final ProviderAvailability availability;

  final int priority;

  bool get isSample => availability == ProviderAvailability.limited;
}

/// The outcome of asking every eligible source about one title.
///
/// Every match is kept, not just the first: "the first provider that recognises
/// a title" is not "the provider the user wants to watch it from".
class SourceLookup {
  const SourceLookup({
    this.matches = const <SourceResolution>[],
    this.failures = const <String, ProviderFailure>{},
    this.attempted = 0,
    this.preferredProviderId,
  });

  /// All matches, in the user's order (per-title preference first).
  final List<SourceResolution> matches;

  /// provider id → typed failure, for the "source errors" line.
  final Map<String, ProviderFailure> failures;

  /// Number of providers that were eligible and probed.
  final int attempted;

  /// The preference that was actually applied, if any.
  final String? preferredProviderId;

  SourceResolution? get resolution => matches.isEmpty ? null : matches.first;

  bool get hasSource => matches.isNotEmpty;

  bool get hasFailures => failures.isNotEmpty;

  /// Some sources worked, some did not — the screen stays usable.
  bool get isPartial => hasSource && hasFailures;

  SourceResolution? forProvider(String providerId) {
    for (final SourceResolution match in matches) {
      if (match.provider.id == providerId) return match;
    }
    return null;
  }
}

/// Application service that hides the provider list from the UI.
///
/// Candidate rule (PROVIDERS.md §5): installed ∩ enabled ∩ compatible ∩
/// configured ∩ `seriesMatching`. Probes are capped so ten sources neither melt
/// the device nor trip rate limits; one provider failing never fails the screen.
class ProviderResolver {
  ProviderResolver({
    required this.registry,
    required List<ProviderRecord> records,
    this.titlePreferences = const <int, String>{},
    this.maxConcurrentProbes = 4,
    this.probeTimeout = const Duration(seconds: 10),
    this.matchTimeout = const Duration(seconds: 10),
    this.matchCacheTtl = const Duration(minutes: 2),
    DateTime Function()? clock,
  }) : _records = List<ProviderRecord>.unmodifiable(records),
       _clock = clock ?? DateTime.now;

  final StreamingProviderRegistry registry;
  final List<ProviderRecord> _records;

  /// anime id → preferred provider id.
  final Map<int, String> titlePreferences;

  final int maxConcurrentProbes;
  final Duration probeTimeout;
  final Duration matchTimeout;
  final Duration matchCacheTtl;
  final DateTime Function() _clock;

  final Map<String, _MatchCacheEntry> _matchCache =
      <String, _MatchCacheEntry>{};

  /// All eligible matches for [anime], in the user's order.
  Future<SourceLookup> lookup(Anime anime) async {
    final List<_Candidate> candidates = _candidates();
    final Map<String, ProviderFailure> failures = <String, ProviderFailure>{};
    final Map<String, ProviderStatusSnapshot> observed =
        <String, ProviderStatusSnapshot>{};

    for (final List<_Candidate> chunk in _chunks(
      candidates,
      math.max(1, maxConcurrentProbes),
    )) {
      await Future.wait(
        chunk.map((_Candidate candidate) async {
          try {
            final ProviderStatusSnapshot snapshot = await candidate.provider
                .probe()
                .timeout(probeTimeout);
            observed[candidate.id] = snapshot;
            if (!snapshot.canServe) {
              failures[candidate.id] = ProviderUpstreamError(
                providerId: candidate.id,
                message: snapshot.message,
              );
            }
          } catch (error) {
            observed[candidate.id] = ProviderStatusSnapshot.unprobed();
            failures[candidate.id] = ProviderFailure.from(
              error,
              providerId: candidate.id,
            );
          }
        }),
      );
    }

    final Map<String, ProviderSeries> matched = <String, ProviderSeries>{};
    for (final _Candidate candidate in candidates) {
      if (observed[candidate.id]?.canServe != true) continue;
      try {
        final ProviderSeries? series = await _match(candidate, anime);
        if (series != null) matched[candidate.id] = series;
      } catch (error) {
        failures[candidate.id] = ProviderFailure.from(
          error,
          providerId: candidate.id,
        );
      }
    }

    final List<SourceResolution> ordered = <SourceResolution>[
      for (final _Candidate candidate in candidates)
        if (matched[candidate.id] != null)
          SourceResolution(
            provider: candidate.provider,
            series: matched[candidate.id]!,
            availability: observed[candidate.id]!.availability,
            priority: candidate.record.priority,
          ),
    ];

    final String? preference = titlePreferences[anime.id];
    if (preference != null) {
      final int index = ordered.indexWhere(
        (SourceResolution match) => match.provider.id == preference,
      );
      if (index > 0) ordered.insert(0, ordered.removeAt(index));
    }
    final bool preferenceApplied =
        preference != null &&
        ordered.any(
          (SourceResolution match) => match.provider.id == preference,
        );

    return SourceLookup(
      matches: List<SourceResolution>.unmodifiable(ordered),
      failures: Map<String, ProviderFailure>.unmodifiable(failures),
      attempted: candidates.length,
      preferredProviderId: preferenceApplied ? preference : null,
    );
  }

  /// Episodes for one resolved title, de-duplicated and ordered.
  Future<List<ProviderEpisode>> episodesFor(
    SourceResolution resolution, {
    String? seasonId,
  }) async {
    final List<ProviderEpisode> episodes = await resolution.provider.episodes(
      resolution.series,
      seasonId: seasonId,
    );
    return <ProviderEpisode>[...episodes]..sort(
      (ProviderEpisode a, ProviderEpisode b) => a.number.compareTo(b.number),
    );
  }

  /// Drops cached matches — after a configuration change or a manual refresh.
  void clearCache() => _matchCache.clear();

  List<_Candidate> _candidates() {
    final List<ProviderRecord> ordered = <ProviderRecord>[..._records]
      ..sort((ProviderRecord a, ProviderRecord b) {
        final int byPriority = a.priority.compareTo(b.priority);
        if (byPriority != 0) return byPriority;
        final int byInstall = a.installedAt.compareTo(b.installedAt);
        if (byInstall != 0) return byInstall;
        return a.providerId.compareTo(b.providerId);
      });

    final List<_Candidate> candidates = <_Candidate>[];
    for (final ProviderRecord record in ordered) {
      // A stale row for a provider that no longer exists is ignored, never an
      // error: removing a provider must not break a screen.
      final ProviderRegistration<StreamingProvider>? registration = registry
          .registrationFor(record.providerId);
      if (registration == null) continue;
      if (!record.enabled) continue;
      if (!registration.isCompatible) continue;
      final ProviderConfigurationState configuration =
          ProviderConfigurationState.evaluate(
            registration.provider.configuration,
            record.config,
          );
      if (!configuration.isSatisfied) continue;
      if (!registration.provider.capabilities.contains(
        ProviderCapability.seriesMatching,
      )) {
        continue;
      }
      candidates.add(
        _Candidate(provider: registration.provider, record: record),
      );
    }
    return candidates;
  }

  Future<ProviderSeries?> _match(_Candidate candidate, Anime anime) {
    final String key = '${anime.id}|${candidate.id}|${anime.title}';
    final DateTime now = _clock();
    final _MatchCacheEntry? cached = _matchCache[key];
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return Future<ProviderSeries?>.value(cached.series);
    }
    return candidate.provider.match(anime).timeout(matchTimeout).then((
      ProviderSeries? series,
    ) {
      _matchCache[key] = _MatchCacheEntry(series, now.add(matchCacheTtl));
      return series;
    });
  }
}

class _Candidate {
  const _Candidate({required this.provider, required this.record});

  final StreamingProvider provider;
  final ProviderRecord record;

  String get id => provider.id;
}

class _MatchCacheEntry {
  const _MatchCacheEntry(this.series, this.expiresAt);

  final ProviderSeries? series;
  final DateTime expiresAt;
}

Iterable<List<T>> _chunks<T>(List<T> items, int size) sync* {
  for (int start = 0; start < items.length; start += size) {
    yield items.sublist(start, math.min(start + size, items.length));
  }
}
