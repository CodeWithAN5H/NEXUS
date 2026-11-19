import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/errors/app_failure.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/data/models/explore_filter.dart';
import 'package:nexus/data/models/media_page.dart';
import 'package:nexus/data/repositories/metadata_repository.dart';
import 'package:nexus/integrations/anilist/anilist_metadata_provider.dart';
import 'package:nexus/integrations/providers/metadata_provider.dart';
import 'package:nexus/integrations/providers/provider_descriptor.dart';
import 'package:nexus/integrations/providers/provider_registries.dart';

import 'support/fake_providers.dart';

const Anime _frieren = Anime(
  id: 154587,
  title: "Frieren: Beyond Journey's End",
  episodes: 28,
);

void main() {
  group('T-A09 metadata is independent of streaming', () {
    test(
      'rails, search and details work with zero streaming providers',
      () async {
        final StreamingProviderRegistry streaming = StreamingProviderRegistry(
          const <Never>[],
        );
        expect(streaming.all, isEmpty);

        final MetadataProviderRegistry metadata = MetadataProviderRegistry(
          <MetadataProvider>[
            FakeMetadataProvider(items: const <Anime>[_frieren]),
          ],
        );
        final MetadataRepository repository = MetadataRepository(
          metadata.primary!,
        );

        final MediaPage trending = await repository.trending(perPage: 12);
        expect(trending.items.single.title, _frieren.title);

        final MediaPage search = await repository.search('Frieren');
        expect(search.items, hasLength(1));

        final Anime details = await repository.details(_frieren.id);
        expect(details.id, _frieren.id);

        final List<String> genres = await repository.genres();
        expect(genres, contains('Action'));

        final MediaPage seasonal = await repository.seasonal(
          season: AnimeSeason.winter,
          year: 2024,
        );
        expect(seasonal.items, hasLength(1));

        final MediaPage browse = await repository.browse(const ExploreFilter());
        expect(browse.items, hasLength(1));
      },
    );

    test('the repository caches identical requests', () async {
      final FakeMetadataProvider provider = FakeMetadataProvider(
        items: const <Anime>[_frieren],
      );
      final MetadataRepository repository = MetadataRepository(provider);

      await repository.details(_frieren.id);
      await repository.details(_frieren.id);
      expect(
        provider.detailCalls,
        1,
        reason: 'the TTL cache stays above the interface',
      );
    });
  });

  group('T-A10 AniList behind the interface', () {
    test(
      'the wrapper describes itself as metadata, never as a stream source',
      () {
        final AniListMetadataProvider provider = fakeAniListProvider();
        expect(provider.id, 'anilist');
        expect(provider.kind, ProviderKind.metadata);
        expect(provider.origin, ProviderOrigin.builtIn);
        expect(provider.configuration, isEmpty);
        expect(provider.capabilities, contains(MetadataCapability.details));
        expect(provider.capabilities, contains(MetadataCapability.trending));
        expect(provider.attribution, isNotEmpty);
      },
    );

    test('the registry prefers the first compatible catalogue', () {
      final MetadataProviderRegistry registry = MetadataProviderRegistry(
        <MetadataProvider>[fakeAniListProvider(), FakeMetadataProvider()],
      );
      expect(registry.primary?.id, 'anilist');
      expect(
        registry.compatibilityOf('anilist'),
        ProviderCompatibility.compatible,
      );
    });

    test(
      'no library file outside integrations/anilist imports AniListClient',
      () {
        final List<String> offenders = <String>[];
        for (final FileSystemEntity entity in Directory(
          'lib',
        ).listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final String path = entity.path.replaceAll('\\', '/');
          if (path.startsWith('lib/integrations/anilist/')) continue;
          if (entity.readAsStringSync().contains('anilist_client.dart')) {
            offenders.add(path);
          }
        }
        expect(
          offenders,
          isEmpty,
          reason: 'MetadataRepository must depend on the interface',
        );
      },
    );
  });

  group('metadata failure handling', () {
    test(
      'catalogue failures surface as AppFailure through the repository',
      () async {
        final FakeMetadataProvider provider = FakeMetadataProvider(
          failure: const ParseFailure('bad payload'),
        );
        final MetadataRepository repository = MetadataRepository(provider);
        await expectLater(repository.trending(), throwsA(isA<ParseFailure>()));
      },
    );

    test('an empty registry has no primary catalogue', () {
      expect(MetadataProviderRegistry(<MetadataProvider>[]).primary, isNull);
    });
  });
}
