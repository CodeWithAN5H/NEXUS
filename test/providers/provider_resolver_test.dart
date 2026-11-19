import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/integrations/providers/provider_failure.dart';
import 'package:nexus/integrations/providers/provider_record.dart';
import 'package:nexus/integrations/providers/provider_registries.dart';
import 'package:nexus/integrations/providers/provider_resolver.dart';
import 'package:nexus/integrations/streaming/streaming_provider.dart';

import 'support/fake_providers.dart';

const Anime _title = Anime(id: 154587, title: "Frieren: Beyond Journey's End");

ProviderSeries _seriesFor(String providerId) => ProviderSeries(
  providerId: providerId,
  seriesId: '$providerId-series',
  title: _title.title,
);

ProviderRecord _record(
  String id, {
  bool enabled = true,
  int priority = 0,
  Map<String, String> config = const <String, String>{},
}) {
  return ProviderRecord.builtIn(
    id,
    enabled: enabled,
    priority: priority,
    installedAt: DateTime(2026, 1, 1),
    contractVersion: ProviderContract.current,
  ).copyWith(config: config);
}

StreamingProviderRegistry _registry(List<FakeStreamingProvider> providers) =>
    StreamingProviderRegistry(providers);

void main() {
  group('T-R01 all matches are returned in priority order', () {
    test('two providers matching one title are both listed', () async {
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[
          FakeStreamingProvider(id: 'a', series: _seriesFor('a')),
          FakeStreamingProvider(id: 'b', series: _seriesFor('b')),
        ]),
        records: <ProviderRecord>[_record('a'), _record('b', priority: 1)],
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(lookup.matches, hasLength(2));
      expect(
        lookup.matches.map((SourceResolution m) => m.provider.id),
        <String>['a', 'b'],
      );
      expect(lookup.attempted, 2);
      expect(lookup.hasFailures, isFalse);
    });

    test('stored priority decides the order (T-R02)', () async {
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[
          FakeStreamingProvider(id: 'a', series: _seriesFor('a')),
          FakeStreamingProvider(id: 'b', series: _seriesFor('b')),
        ]),
        records: <ProviderRecord>[_record('a', priority: 4), _record('b')],
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(
        lookup.matches.map((SourceResolution m) => m.provider.id),
        <String>['b', 'a'],
      );
      expect(lookup.resolution?.provider.id, 'b');
    });

    test('a disabled provider is not a candidate', () async {
      final FakeStreamingProvider disabled = FakeStreamingProvider(
        id: 'b',
        series: _seriesFor('b'),
      );
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[
          FakeStreamingProvider(id: 'a', series: _seriesFor('a')),
          disabled,
        ]),
        records: <ProviderRecord>[_record('a'), _record('b', enabled: false)],
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(lookup.matches, hasLength(1));
      expect(disabled.probeCalls, 0);
    });
  });

  group('T-R03 / T-R04 per-title preference', () {
    test('the chosen source is first, the others stay listed', () async {
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[
          FakeStreamingProvider(id: 'a', series: _seriesFor('a')),
          FakeStreamingProvider(id: 'b', series: _seriesFor('b')),
        ]),
        records: <ProviderRecord>[_record('a'), _record('b', priority: 1)],
        titlePreferences: <int, String>{_title.id: 'b'},
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(
        lookup.matches.map((SourceResolution m) => m.provider.id),
        <String>['b', 'a'],
      );
      expect(lookup.preferredProviderId, 'b');
    });

    test('a preference for a removed provider is ignored', () async {
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[
          FakeStreamingProvider(id: 'a', series: _seriesFor('a')),
        ]),
        records: <ProviderRecord>[_record('a')],
        titlePreferences: <int, String>{_title.id: 'removed'},
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(lookup.resolution?.provider.id, 'a');
      expect(lookup.preferredProviderId, isNull);
    });

    test(
      'a stale installed row for an unregistered provider is skipped',
      () async {
        final ProviderResolver resolver = ProviderResolver(
          registry: _registry(<FakeStreamingProvider>[
            FakeStreamingProvider(id: 'a', series: _seriesFor('a')),
          ]),
          records: <ProviderRecord>[_record('a'), _record('ghost')],
        );

        final SourceLookup lookup = await resolver.lookup(_title);
        expect(lookup.attempted, 1);
        expect(lookup.hasSource, isTrue);
      },
    );
  });

  group('T-R07 / T-R08 partial and total failure', () {
    test('one failing source does not empty the screen', () async {
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[
          FakeStreamingProvider(
            id: 'a',
            series: _seriesFor('a'),
            matchError: const ProviderTimeout(providerId: 'a'),
          ),
          FakeStreamingProvider(id: 'b', series: _seriesFor('b')),
        ]),
        records: <ProviderRecord>[_record('a'), _record('b', priority: 1)],
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(lookup.hasSource, isTrue);
      expect(lookup.isPartial, isTrue);
      expect(lookup.failures['a'], isA<ProviderTimeout>());
      expect(lookup.matches.single.provider.id, 'b');
    });

    test('every source failing is reported per provider', () async {
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[
          FakeStreamingProvider(
            id: 'a',
            matchError: const ProviderUpstreamError(
              providerId: 'a',
              status: 502,
            ),
          ),
          FakeStreamingProvider(
            id: 'b',
            matchError: const ProviderRateLimited(
              providerId: 'b',
              retryAfter: Duration(seconds: 10),
            ),
          ),
        ]),
        records: <ProviderRecord>[_record('a'), _record('b', priority: 1)],
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(lookup.hasSource, isFalse);
      expect(lookup.failures, hasLength(2));
      expect(lookup.failures['b'], isA<ProviderRateLimited>());
    });

    test('an unavailable probe is a typed failure, not an exception', () async {
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[
          FakeStreamingProvider(
            id: 'a',
            availability: ProviderAvailability.unavailable,
          ),
        ]),
        records: <ProviderRecord>[_record('a')],
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(lookup.failures['a'], isA<ProviderUpstreamError>());
      expect(lookup.hasSource, isFalse);
    });
  });

  group('T-R09 no match', () {
    test(
      'no provider recognising the title is an empty, failure-free lookup',
      () async {
        final ProviderResolver resolver = ProviderResolver(
          registry: _registry(<FakeStreamingProvider>[
            FakeStreamingProvider(id: 'a'),
          ]),
          records: <ProviderRecord>[_record('a')],
        );
        final SourceLookup lookup = await resolver.lookup(_title);
        expect(lookup.hasSource, isFalse);
        expect(lookup.hasFailures, isFalse);
        expect(lookup.attempted, 1);
      },
    );
  });

  group('T-R10 / T-R11 / T-R12 candidate gating', () {
    test('an incompatible provider is never probed', () async {
      final FakeStreamingProvider future = FakeStreamingProvider(
        id: 'future',
        contract: const ProviderContractRange(min: 9, max: 9),
        series: _seriesFor('future'),
      );
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[future]),
        records: <ProviderRecord>[_record('future')],
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(future.probeCalls, 0);
      expect(lookup.attempted, 0);
    });

    test('an unconfigured provider is never probed', () async {
      final FakeStreamingProvider needsSetup = FakeStreamingProvider(
        id: 'needs-setup',
        configuration: const <ProviderConfigField>[
          ProviderConfigField(key: 'apiKey', label: 'API key', required: true),
        ],
        series: _seriesFor('needs-setup'),
      );
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[needsSetup]),
        records: <ProviderRecord>[_record('needs-setup')],
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(needsSetup.probeCalls, 0);
      expect(lookup.attempted, 0);
    });

    test('a provider without seriesMatching is not a candidate', () async {
      final FakeStreamingProvider noMatching = FakeStreamingProvider(
        id: 'no-matching',
        capabilities: const <ProviderCapability>{ProviderCapability.search},
        series: _seriesFor('no-matching'),
      );
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[noMatching]),
        records: <ProviderRecord>[_record('no-matching')],
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(noMatching.probeCalls, 0);
      expect(lookup.attempted, 0);
    });
  });

  group('T-R13 probe cap and match cache', () {
    test('at most four probes are in flight', () async {
      int inFlight = 0;
      int maxInFlight = 0;
      final List<FakeStreamingProvider> providers = <FakeStreamingProvider>[
        for (int i = 0; i < 6; i++)
          FakeStreamingProvider(
            id: 'p$i',
            series: _seriesFor('p$i'),
            probeDelay: const Duration(milliseconds: 5),
            probeObserver: (FakeStreamingProvider _) {
              inFlight++;
              if (inFlight > maxInFlight) maxInFlight = inFlight;
            },
            probeEndObserver: () => inFlight--,
          ),
      ];

      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(providers),
        records: <ProviderRecord>[
          for (int i = 0; i < providers.length; i++)
            _record('p$i', priority: i),
        ],
      );

      await resolver.lookup(_title);
      expect(maxInFlight, lessThanOrEqualTo(4));
      expect(maxInFlight, greaterThan(1));
    });

    test('a repeated lookup inside the TTL reuses the cached match', () async {
      final FakeStreamingProvider provider = FakeStreamingProvider(
        id: 'a',
        series: _seriesFor('a'),
      );
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[provider]),
        records: <ProviderRecord>[_record('a')],
        clock: () => DateTime(2026, 11, 19, 12),
      );

      await resolver.lookup(_title);
      await resolver.lookup(_title);
      expect(provider.matchCalls, 1);
    });

    test('clearing the cache forces a fresh match', () async {
      final FakeStreamingProvider provider = FakeStreamingProvider(
        id: 'a',
        series: _seriesFor('a'),
      );
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[provider]),
        records: <ProviderRecord>[_record('a')],
        clock: () => DateTime(2026, 11, 19, 12),
      );

      await resolver.lookup(_title);
      resolver.clearCache();
      await resolver.lookup(_title);
      expect(provider.matchCalls, 2);
    });
  });

  group('sample labelling and episodes', () {
    test('limited availability marks a resolution as sample media', () async {
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[
          FakeStreamingProvider(
            id: 'a',
            series: _seriesFor('a'),
            availability: ProviderAvailability.limited,
          ),
        ]),
        records: <ProviderRecord>[_record('a')],
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      expect(lookup.resolution?.isSample, isTrue);
    });

    test('episodes are ordered and listed for a resolution', () async {
      final ProviderResolver resolver = ProviderResolver(
        registry: _registry(<FakeStreamingProvider>[
          FakeStreamingProvider(id: 'a', series: _seriesFor('a')),
        ]),
        records: <ProviderRecord>[_record('a')],
      );

      final SourceLookup lookup = await resolver.lookup(_title);
      final List<ProviderEpisode> episodes = await resolver.episodesFor(
        lookup.resolution!,
      );
      expect(episodes, isNotEmpty);
      expect(episodes.first.number, 1);
      expect(episodes.first.providerId, 'a');
    });
  });
}
