import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/errors/app_failure.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/integrations/anilist/anilist_metadata_provider.dart';
import 'package:nexus/integrations/providers/metadata_provider.dart';
import 'package:nexus/integrations/providers/provider_failure.dart';
import 'package:nexus/integrations/providers/provider_registries.dart';
import 'package:nexus/integrations/providers/title_matching.dart';
import 'package:nexus/integrations/streaming/sample_provider.dart';
import 'package:nexus/integrations/streaming/streaming_provider.dart';

import 'support/fake_providers.dart';

void main() {
  group('T-A03 capability honesty', () {
    test('a declared capability is honoured', () async {
      final FakeStreamingProvider provider = FakeStreamingProvider(
        id: 'fake.full',
        series: const ProviderSeries(
          providerId: 'fake.full',
          seriesId: 's1',
          title: 'A Title',
        ),
      );
      expect(await provider.search(''), isNotEmpty);
      final List<ProviderEpisode> episodes = await provider.episodes(
        provider.series!,
      );
      expect(episodes, isNotEmpty);
      expect(
        (await provider.resolve(provider.series!, episodes.first)).variants,
        isEmpty,
      );
    });

    test('an undeclared capability throws ProviderUnsupported', () async {
      final FakeStreamingProvider provider = FakeStreamingProvider(
        id: 'fake.search-only',
        capabilities: const <ProviderCapability>{ProviderCapability.search},
      );
      const ProviderSeries series = ProviderSeries(
        providerId: 'fake.search-only',
        seriesId: 's1',
        title: 'A Title',
      );
      expect(
        () => provider.episodes(series),
        throwsA(isA<ProviderUnsupported>()),
      );
      expect(
        () => provider.resolve(
          series,
          const ProviderEpisode(
            providerId: 'fake.search-only',
            seriesId: 's1',
            episodeId: 'e1',
            number: 1,
            title: 'Episode 1',
          ),
        ),
        throwsA(isA<ProviderUnsupported>()),
      );
    });
  });

  group('T-A06 empty catalogue', () {
    test('returns no results, no match and no failure', () async {
      final FakeStreamingProvider provider = FakeStreamingProvider(
        id: 'fake.empty',
      );
      expect(await provider.search('anything'), isEmpty);
      expect(
        await provider.match(const Anime(id: 1, title: 'Anything')),
        isNull,
      );
    });
  });

  group('T-A07 ambiguous titles', () {
    test('two equal titles are reported, never picked arbitrarily', () {
      final TitleMatchResult result = selectUniqueSeries(const <ProviderSeries>[
        ProviderSeries(
          providerId: 'a',
          seriesId: '1',
          title: "Frieren: Beyond Journey's End",
        ),
        ProviderSeries(
          providerId: 'b',
          seriesId: '2',
          title: "Frieren: Beyond Journey's End",
        ),
      ], "Frieren: Beyond Journey's End");
      expect(result.kind, TitleMatchKind.ambiguous);
      expect(result.series, isNull);
      expect(result.candidates, hasLength(2));
    });

    test('punctuation and spacing do not defeat a unique match', () {
      final TitleMatchResult result = selectUniqueSeries(const <ProviderSeries>[
        ProviderSeries(
          providerId: 'a',
          seriesId: '1',
          title: 'frieren beyond journeys end',
        ),
      ], "Frieren: Beyond Journey's End");
      expect(result.kind, TitleMatchKind.single);
      expect(result.series?.seriesId, '1');
    });

    test('a conflicting year prevents a remake being served', () {
      final TitleMatchResult result = selectUniqueSeries(
        const <ProviderSeries>[
          ProviderSeries(
            providerId: 'a',
            seriesId: '1',
            title: 'Fullmetal Alchemist',
            year: 2003,
          ),
        ],
        'Fullmetal Alchemist',
        year: 2009,
      );
      expect(result.kind, TitleMatchKind.none);
    });

    test('no resemblance means no match', () {
      expect(
        selectUniqueSeries(const <ProviderSeries>[
          ProviderSeries(providerId: 'a', seriesId: '1', title: 'Other Show'),
        ], 'Frieren').kind,
        TitleMatchKind.none,
      );
    });
  });

  group('T-A08 typed failures', () {
    test('arbitrary errors are wrapped at the contract boundary', () {
      expect(
        ProviderFailure.from(Exception('boom'), providerId: 'a'),
        isA<ProviderParseFailure>(),
      );
      expect(
        ProviderFailure.from(TimeoutException('slow'), providerId: 'a'),
        isA<ProviderTimeout>(),
      );
      expect(
        ProviderFailure.from(const NetworkFailure('offline'), providerId: 'a'),
        isA<ProviderUpstreamError>(),
      );
      const ProviderTimeout timeout = ProviderTimeout(providerId: 'a');
      expect(ProviderFailure.from(timeout, providerId: 'a'), same(timeout));
    });

    test(
      'every failure maps to an AppFailure with the documented retry flag',
      () {
        final Map<ProviderFailure, bool> expected = <ProviderFailure, bool>{
          const ProviderNotConfigured(providerId: 'a'): false,
          const ProviderAuthRejected(providerId: 'a'): false,
          const ProviderNotFound(providerId: 'a'): false,
          const ProviderRateLimited(
            providerId: 'a',
            retryAfter: Duration(seconds: 30),
          ): true,
          const ProviderGeoRestricted(providerId: 'a'): false,
          const ProviderUpstreamError(providerId: 'a', status: 500): true,
          const ProviderTimeout(providerId: 'a'): true,
          const ProviderParseFailure(providerId: 'a'): false,
          const ProviderUnsupported(providerId: 'a', feature: 'subtitles'):
              false,
          const ProviderCancelled(providerId: 'a'): false,
          const ProviderOriginRejected(providerId: 'a'): false,
          const ProviderInvalidStream(providerId: 'a'): false,
          const ProviderManifestInvalid(providerId: 'a'): false,
        };

        for (final MapEntry<ProviderFailure, bool> entry in expected.entries) {
          expect(entry.key.isRetryable, entry.value, reason: entry.key.code);
          expect(entry.key.toAppFailure(), isA<AppFailure>());
          expect(entry.key.toAppFailure().message, entry.key.message);
        }
      },
    );

    test('codes are stable and machine-readable', () {
      expect(const ProviderTimeout(providerId: 'a').code, 'provider.timeout');
      expect(
        const ProviderRateLimited(
          providerId: 'a',
          retryAfter: Duration(seconds: 1),
        ).code,
        'provider.rateLimited',
      );
    });

    test('cancelled maps to the existing silent failure', () {
      expect(
        const ProviderCancelled(providerId: 'a').toAppFailure(),
        isA<CancelledFailure>(),
      );
    });
  });

  group('T-A05 lifecycle', () {
    test('dispose is idempotent on the sample provider', () async {
      const SamplePlaybackProvider provider = SamplePlaybackProvider();
      await provider.dispose();
      await provider.dispose();
    });

    test('an AniList metadata provider disposes idempotently', () async {
      final AniListMetadataProvider provider = fakeAniListProvider();
      expect((await provider.probe()).availability, ProviderAvailability.ready);
      await provider.dispose();
      await provider.dispose();
      expect(
        (await provider.probe()).availability,
        ProviderAvailability.unavailable,
      );
    });
  });

  group('T-A09 independent registries', () {
    test('a metadata provider is never offered as a streaming source', () {
      final MetadataProviderRegistry metadata = MetadataProviderRegistry(
        <MetadataProvider>[FakeMetadataProvider()],
      );
      final StreamingProviderRegistry streaming = StreamingProviderRegistry(
        <StreamingProvider>[],
      );

      expect(metadata.byId('fake.metadata'), isNotNull);
      expect(streaming.byId('fake.metadata'), isNull);
      expect(streaming.all, isEmpty);
      expect(metadata.primary?.kind, ProviderKind.metadata);
    });

    test('a streaming provider is never a metadata catalogue', () {
      final StreamingProviderRegistry streaming = StreamingProviderRegistry(
        <StreamingProvider>[FakeStreamingProvider(id: 'fake.stream')],
      );
      final MetadataProviderRegistry metadata = MetadataProviderRegistry(
        <MetadataProvider>[],
      );
      expect(streaming.byId('fake.stream'), isNotNull);
      expect(metadata.byId('fake.stream'), isNull);
      expect(metadata.primary, isNull);
    });
  });
}
