import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/integrations/streaming/provider_registry_bootstrap.dart';
import 'package:nexus/integrations/streaming/sample_provider.dart';
import 'package:nexus/integrations/streaming/source_manager.dart';
import 'package:nexus/integrations/streaming/streaming_provider.dart';

const Anime _realAnime = Anime(
  id: 154587,
  title: "Frieren: Beyond Journey's End",
);

void main() {
  const SamplePlaybackProvider provider = SamplePlaybackProvider();

  group('SamplePlaybackProvider contract', () {
    test('advertises its capabilities and limited availability', () {
      expect(provider.id, SamplePlaybackProvider.providerId);
      expect(provider.capabilities, contains(ProviderCapability.episodes));
      expect(provider.capabilities, contains(ProviderCapability.streams));
      expect(provider.capabilities, contains(ProviderCapability.qualities));
      expect(provider.status.availability, ProviderAvailability.limited);
      expect(provider.status.isUsable, isTrue);
    });

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

    test('rejects an unknown episode id', () async {
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
        throwsA(isA<ProviderException>()),
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

  group('SourceManager', () {
    final SourceManager manager = SourceManager(
      buildProviderRegistry(),
      <String>{SamplePlaybackProvider.providerId},
    );

    test('registers the sample provider by id', () {
      final ProviderRegistry registry = buildProviderRegistry();
      expect(registry.byId(SamplePlaybackProvider.providerId), isNotNull);
      expect(registry.all, hasLength(1));
    });

    test('reports no source for real anime metadata', () async {
      final SourceLookup lookup = await manager.lookup(_realAnime);
      expect(lookup.hasSource, isFalse);
      expect(lookup.resolution, isNull);
      expect(lookup.attempted, 1);
    });

    test('exposes no providers when the user disables everything', () async {
      final SourceManager disabled = SourceManager(
        buildProviderRegistry(),
        const <String>{},
      );
      expect(disabled.enabledProviders, isEmpty);
      final SourceLookup lookup = await disabled.lookup(_realAnime);
      expect(lookup.attempted, 0);
      expect(lookup.hasSource, isFalse);
    });

    test('sorts episodes for a resolved source', () async {
      final ProviderSeries series = SamplePlaybackProvider().testLibrary;
      final List<ProviderEpisode> episodes = await manager.episodesFor(
        SourceResolution(provider: provider, series: series),
      );
      expect(episodes.first.number, lessThan(episodes.last.number));
    });
  });
}
