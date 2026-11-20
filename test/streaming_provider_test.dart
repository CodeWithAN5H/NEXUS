import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/integrations/providers/provider_descriptor.dart';
import 'package:nexus/integrations/providers/provider_failure.dart';
import 'package:nexus/integrations/providers/provider_registries.dart';
import 'package:nexus/integrations/providers/provider_registry_bootstrap.dart';
import 'package:nexus/integrations/streaming/sample_provider.dart';
import 'package:nexus/integrations/streaming/streaming_provider.dart';

import 'providers/support/fake_providers.dart';

const Anime _realAnime = Anime(
  id: 154587,
  title: "Frieren: Beyond Journey's End",
);

void main() {
  const SamplePlaybackProvider provider = SamplePlaybackProvider();

  group('SamplePlaybackProvider descriptor', () {
    test('declares a stable envelope and honest capabilities', () {
      expect(provider.id, SamplePlaybackProvider.providerId);
      expect(provider.name, isNotEmpty);
      expect(provider.version, isNotEmpty);
      expect(provider.kind, ProviderKind.streaming);
      expect(provider.origin, ProviderOrigin.builtIn);
      expect(provider.contract.supports(ProviderContract.current), isTrue);
      expect(provider.configuration, isEmpty);
      expect(provider.capabilities, contains(ProviderCapability.episodes));
      expect(provider.capabilities, contains(ProviderCapability.streams));
      expect(provider.capabilities, contains(ProviderCapability.qualities));
      expect(
        provider.capabilities,
        contains(ProviderCapability.seriesMatching),
      );
    });

    test('probes to limited availability with a timestamp', () async {
      final ProviderStatusSnapshot snapshot = await provider.probe();
      expect(snapshot.availability, ProviderAvailability.limited);
      expect(snapshot.canServe, isTrue);
      expect(snapshot.message, isNotEmpty);
      expect(
        snapshot.observedAt.isAfter(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });

    test('dispose is idempotent', () async {
      await provider.dispose();
      await provider.dispose();
    });
  });

  group('SamplePlaybackProvider behaviour', () {
    test('never claims a real anime title', () async {
      expect(await provider.match(_realAnime), isNull);
    });

    test('lists its test episodes in order', () async {
      final List<ProviderEpisode> episodes = await provider.episodes(
        provider.testLibrary,
      );
      expect(episodes, hasLength(2));
      expect(episodes.first.number, 1);
      expect(episodes.last.number, 2);
      expect(
        episodes.every(
          (ProviderEpisode episode) =>
              episode.providerId == SamplePlaybackProvider.providerId,
        ),
        isTrue,
      );
    });

    test('returns no episodes for a foreign series', () async {
      final List<ProviderEpisode> episodes = await provider.episodes(
        const ProviderSeries(
          providerId: 'sample',
          seriesId: 'unknown',
          title: 'Unknown',
        ),
      );
      expect(episodes, isEmpty);
    });

    test(
      'resolves HLS variants and marks the stream as sample media',
      () async {
        final EpisodeStream stream = await provider.resolve(
          provider.testLibrary,
          (await provider.episodes(provider.testLibrary)).first,
        );
        expect(stream.protocol, StreamProtocol.hls);
        expect(stream.isSample, isTrue);
        expect(stream.notice, isNotNull);
        expect(stream.variants, isNotEmpty);
        expect(
          stream.variants.every(
            (StreamVariant variant) => variant.uri.scheme == 'https',
          ),
          isTrue,
        );
        expect(
          stream.variants.map((StreamVariant v) => v.height),
          containsAll(<int>[1080, 720, 540, 360, 270]),
        );
      },
    );

    test('rejects an unknown episode with a typed failure', () {
      expect(
        () => provider.resolve(
          provider.testLibrary,
          const ProviderEpisode(
            providerId: 'sample',
            seriesId: SamplePlaybackProvider.testLibrarySeriesId,
            episodeId: 'missing',
            number: 9,
            title: 'Missing',
          ),
        ),
        throwsA(isA<ProviderNotFound>()),
      );
    });
  });

  group('EpisodeStream.bestVariant', () {
    final EpisodeStream stream = EpisodeStream(
      protocol: StreamProtocol.hls,
      variants: <StreamVariant>[
        StreamVariant(
          label: '1080p',
          uri: Uri.parse('https://x/1080.m3u8'),
          height: 1080,
        ),
        StreamVariant(
          label: '720p',
          uri: Uri.parse('https://x/720.m3u8'),
          height: 720,
        ),
        StreamVariant(
          label: '480p',
          uri: Uri.parse('https://x/480.m3u8'),
          height: 480,
          isDefault: true,
        ),
        StreamVariant(
          label: '360p',
          uri: Uri.parse('https://x/360.m3u8'),
          height: 360,
        ),
      ],
    );

    test('picks the default variant when no preference is given', () {
      expect(stream.bestVariant()?.label, '480p');
    });

    test('never selects a quality above the preference', () {
      expect(stream.bestVariant(preferredHeight: 720)?.label, '720p');
      expect(stream.bestVariant(preferredHeight: 700)?.label, '480p');
      expect(stream.bestVariant(preferredHeight: 200)?.label, '360p');
    });

    test('falls back to the highest variant when everything is lower', () {
      expect(stream.bestVariant(preferredHeight: 2160)?.label, '1080p');
    });

    test('returns null for an empty stream', () {
      const EpisodeStream empty = EpisodeStream(
        variants: <StreamVariant>[],
        protocol: StreamProtocol.hls,
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.bestVariant(), isNull);
    });
  });

  group('StreamingProviderRegistry', () {
    test('registers built-ins by id and evaluates compatibility', () {
      final StreamingProviderRegistry registry =
          buildStreamingProviderRegistry();
      expect(registry.byId(SamplePlaybackProvider.providerId), isNotNull);
      // Two built-ins since 2.3a: the test library and the experimental
      // AniZone source.
      expect(registry.all, hasLength(2));
      expect(registry.byId('anizone'), isNotNull);
      expect(
        registry.compatibilityOf(SamplePlaybackProvider.providerId),
        ProviderCompatibility.compatible,
      );
      expect(
        registry.compatibilityOf('anizone'),
        ProviderCompatibility.compatible,
      );
    });

    test('refuses duplicate ids', () {
      expect(
        () => StreamingProviderRegistry(<StreamingProvider>[
          FakeStreamingProvider(id: 'dup'),
          FakeStreamingProvider(id: 'dup'),
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('derives requiresNewerApp and unsupportedContract', () {
      final StreamingProviderRegistry registry = StreamingProviderRegistry(
        <StreamingProvider>[
          FakeStreamingProvider(
            id: 'future',
            contract: const ProviderContractRange(min: 9, max: 9),
          ),
          FakeStreamingProvider(
            id: 'retired',
            contract: const ProviderContractRange(min: 0, max: 0),
          ),
        ],
      );
      expect(
        registry.compatibilityOf('future'),
        ProviderCompatibility.requiresNewerApp,
      );
      expect(
        registry.compatibilityOf('retired'),
        ProviderCompatibility.unsupportedContract,
      );
    });

    test('derives unsupportedPlatform for a foreign platform', () {
      final StreamingProviderRegistry registry = StreamingProviderRegistry(
        <StreamingProvider>[
          FakeStreamingProvider(
            id: 'android-only',
            platforms: const <ProviderPlatform>{ProviderPlatform.android},
          ),
        ],
        platform: ProviderPlatform.linux,
      );
      expect(
        registry.compatibilityOf('android-only'),
        ProviderCompatibility.unsupportedPlatform,
      );
    });

    test('enabled() filters by the user set without reordering', () {
      final StreamingProviderRegistry registry = StreamingProviderRegistry(
        <StreamingProvider>[
          FakeStreamingProvider(id: 'a'),
          FakeStreamingProvider(id: 'b'),
        ],
      );
      expect(
        registry.enabled(<String>{'b'}).map((StreamingProvider p) => p.id),
        <String>['b'],
      );
    });
  });
}
