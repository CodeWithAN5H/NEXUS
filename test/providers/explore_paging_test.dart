import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/errors/app_failure.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/data/models/explore_filter.dart';
import 'package:nexus/data/models/media_page.dart';
import 'package:nexus/data/providers/app_providers.dart';
import 'package:nexus/data/providers/content_providers.dart';
import 'package:nexus/data/repositories/metadata_repository.dart';

import 'support/fake_providers.dart';

Anime _anime(int id) => Anime(id: id, title: 'Title $id');

MediaPage _page(int first, int last, {required bool hasNextPage}) {
  return MediaPage(
    items: <Anime>[for (int id = first; id <= last; id++) _anime(id)],
    hasNextPage: hasNextPage,
  );
}

ProviderContainer _container(FakeMetadataProvider provider) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      metadataRepositoryProvider.overrideWithValue(
        MetadataRepository(provider),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ExploreResults> _settle(ProviderContainer container) async {
  await container.read(exploreResultsProvider.future);
  return container.read(exploreResultsProvider).requireValue;
}

ExploreResults _state(ProviderContainer container) =>
    container.read(exploreResultsProvider).requireValue;

void main() {
  group('explore paging', () {
    test('page 1 is loaded for the current filter', () async {
      final FakeMetadataProvider provider = FakeMetadataProvider(
        pageResults: <int, MediaPage>{
          1: _page(1, 24, hasNextPage: true),
          2: _page(25, 48, hasNextPage: false),
        },
      );
      final ProviderContainer container = _container(provider);

      final ExploreResults results = await _settle(container);

      expect(results.items.length, 24);
      expect(results.page, 1);
      expect(results.hasNextPage, isTrue);
      expect(results.loadingMore, isFalse);
      expect(results.hasMoreFailure, isFalse);
      expect(provider.pagesRequested, <int>[1]);
    });

    test('loadMore appends the next page in page order', () async {
      final FakeMetadataProvider provider = FakeMetadataProvider(
        pageResults: <int, MediaPage>{
          1: _page(1, 24, hasNextPage: true),
          2: _page(25, 48, hasNextPage: true),
        },
      );
      final ProviderContainer container = _container(provider);
      await _settle(container);

      await container.read(exploreResultsProvider.notifier).loadMore();

      final ExploreResults results = _state(container);
      expect(results.items.length, 48);
      expect(results.items.first.id, 1);
      expect(results.items[24].id, 25);
      expect(results.page, 2);
      expect(results.loadingMore, isFalse);
      expect(provider.pagesRequested, <int>[1, 2]);
    });

    test(
      'an id returned on two pages is kept once, in first-seen order',
      () async {
        // AniList re-ranks between requests, so page 2 can legitimately repeat
        // titles from page 1.
        final FakeMetadataProvider provider = FakeMetadataProvider(
          pageResults: <int, MediaPage>{
            1: _page(1, 24, hasNextPage: true),
            2: _page(20, 30, hasNextPage: false),
          },
        );
        final ProviderContainer container = _container(provider);
        await _settle(container);

        await container.read(exploreResultsProvider.notifier).loadMore();

        final ExploreResults results = _state(container);
        final List<int> ids = <int>[
          for (final Anime anime in results.items) anime.id,
        ];
        expect(ids.length, ids.toSet().length, reason: 'ids must be unique');
        expect(results.items.length, 30);
        expect(ids.take(24), List<int>.generate(24, (int i) => i + 1));
        expect(ids.skip(24), <int>[25, 26, 27, 28, 29, 30]);
      },
    );

    test('no request is made after the final page', () async {
      final FakeMetadataProvider provider = FakeMetadataProvider(
        pageResults: <int, MediaPage>{
          1: _page(1, 24, hasNextPage: true),
          2: _page(25, 30, hasNextPage: false),
        },
      );
      final ProviderContainer container = _container(provider);
      await _settle(container);
      final ExploreResultsController controller = container.read(
        exploreResultsProvider.notifier,
      );

      await controller.loadMore();
      expect(_state(container).hasNextPage, isFalse);

      await controller.loadMore();
      await controller.loadMore();

      expect(provider.pagesRequested, <int>[1, 2]);
      expect(_state(container).items.length, 30);
    });

    test('loadMore during the initial load is ignored', () async {
      final Completer<void> gate = Completer<void>();
      final FakeMetadataProvider provider = FakeMetadataProvider(
        pageResults: <int, MediaPage>{
          1: _page(1, 24, hasNextPage: true),
          2: _page(25, 48, hasNextPage: false),
        },
        pageGates: <int, Completer<void>>{1: gate},
      );
      final ProviderContainer container = _container(provider);
      // Do not await: the first page is still in flight.
      container.read(exploreResultsProvider);

      await container.read(exploreResultsProvider.notifier).loadMore();
      expect(provider.pagesRequested, <int>[1]);

      gate.complete();
      await _settle(container);
      expect(provider.pagesRequested, <int>[1]);
    });

    test('concurrent loadMore calls issue one request', () async {
      final Completer<void> gate = Completer<void>();
      final FakeMetadataProvider provider = FakeMetadataProvider(
        pageResults: <int, MediaPage>{
          1: _page(1, 24, hasNextPage: true),
          2: _page(25, 48, hasNextPage: true),
        },
        pageGates: <int, Completer<void>>{2: gate},
      );
      final ProviderContainer container = _container(provider);
      await _settle(container);
      final ExploreResultsController controller = container.read(
        exploreResultsProvider.notifier,
      );

      final Future<void> first = controller.loadMore();
      final Future<void> second = controller.loadMore();

      expect(provider.pagesRequested, <int>[1, 2]);
      expect(_state(container).loadingMore, isTrue);
      expect(_state(container).items.length, 24, reason: 'tiles stay visible');

      gate.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(provider.pagesRequested, <int>[1, 2]);
      expect(_state(container).items.length, 48);
      expect(_state(container).loadingMore, isFalse);
    });

    test('a failed append keeps the loaded pages and retries', () async {
      final FakeMetadataProvider provider = FakeMetadataProvider(
        pageResults: <int, MediaPage>{
          1: _page(1, 24, hasNextPage: true),
          2: _page(25, 48, hasNextPage: false),
        },
        pageFailures: <int, Object>{2: const ParseFailure('page 2 failed')},
      );
      final ProviderContainer container = _container(provider);
      await _settle(container);
      final ExploreResultsController controller = container.read(
        exploreResultsProvider.notifier,
      );

      await controller.loadMore();

      ExploreResults failed = _state(container);
      expect(failed.moreFailure, isA<ParseFailure>());
      expect(failed.hasMoreFailure, isTrue);
      expect(failed.items.length, 24, reason: 'page 1 must survive a failure');
      expect(failed.loadingMore, isFalse);
      expect(
        container.read(exploreResultsProvider),
        isA<AsyncData<ExploreResults>>(),
        reason: 'a later page failing is not a screen-level error',
      );

      provider.pageFailures.remove(2);
      await controller.retryLoadMore();

      failed = _state(container);
      expect(failed.hasMoreFailure, isFalse);
      expect(failed.items.length, 48);
      expect(failed.page, 2);
    });

    test('retryLoadMore without a failure makes no request', () async {
      final FakeMetadataProvider provider = FakeMetadataProvider(
        pageResults: <int, MediaPage>{1: _page(1, 24, hasNextPage: true)},
      );
      final ProviderContainer container = _container(provider);
      await _settle(container);

      await container.read(exploreResultsProvider.notifier).retryLoadMore();

      expect(provider.pagesRequested, <int>[1]);
    });

    test(
      'a page that resolves after the filter changed is discarded',
      () async {
        final Completer<void> gate = Completer<void>();
        final FakeMetadataProvider provider = FakeMetadataProvider(
          pageResults: <int, MediaPage>{
            1: _page(1, 24, hasNextPage: true),
            2: _page(25, 48, hasNextPage: true),
          },
          pageGates: <int, Completer<void>>{2: gate},
        );
        final ProviderContainer container = _container(provider);
        await _settle(container);
        final ExploreResultsController controller = container.read(
          exploreResultsProvider.notifier,
        );

        final Future<void> inFlight = controller.loadMore();
        expect(provider.pagesRequested, <int>[1, 2]);

        container.read(exploreFilterProvider.notifier).setQuery('other');
        await _settle(container);

        gate.complete();
        await inFlight;

        final ExploreResults results = _state(container);
        expect(results.filter.query, 'other');
        expect(results.page, 1, reason: 'the stale page was not merged');
        expect(results.items.length, 24);
        expect(provider.pagesRequested, <int>[1, 2, 1]);
      },
    );

    test('changing the filter replaces the accumulation with page 1', () async {
      final FakeMetadataProvider provider = FakeMetadataProvider(
        pageResults: <int, MediaPage>{
          1: _page(1, 24, hasNextPage: true),
          2: _page(25, 48, hasNextPage: true),
        },
      );
      final ProviderContainer container = _container(provider);
      await _settle(container);
      await container.read(exploreResultsProvider.notifier).loadMore();
      expect(_state(container).items.length, 48);

      container.read(exploreFilterProvider.notifier).toggleGenre('Action');
      final ExploreResults results = await _settle(container);

      expect(results.page, 1);
      expect(results.items.length, 24);
      expect(results.filter.genres, <String>{'Action'});
    });

    test("paging stops before AniList's 5 000-entry depth limit", () async {
      // 24 posters per page: page 208 is the last one inside the cap, so page
      // 209 (which AniList answers with HTTP 400) must never be requested.
      const int pageSize = ExploreResultsController.pageSize;
      final Map<int, MediaPage> pages = <int, MediaPage>{
        for (int page = 1; page <= 220; page++)
          page: MediaPage(items: <Anime>[_anime(page)], hasNextPage: true),
      };
      final FakeMetadataProvider provider = FakeMetadataProvider(
        pageResults: pages,
      );
      final ProviderContainer container = _container(provider);
      await _settle(container);
      final ExploreResultsController controller = container.read(
        exploreResultsProvider.notifier,
      );

      for (int attempt = 0; attempt < 230; attempt++) {
        await controller.loadMore();
      }

      expect(provider.pagesRequested.contains(209), isFalse);
      expect(provider.pagesRequested.last, 208);
      final ExploreResults results = _state(container);
      expect(results.page, 208);
      expect(results.hasNextPage, isFalse);
      expect(results.items.length, 208);
      expect(208 * pageSize, lessThanOrEqualTo(5000));
      expect(209 * pageSize, greaterThan(5000));
    });
  });

  group('repository paging', () {
    test('each page is requested once and cached separately', () async {
      final FakeMetadataProvider provider = FakeMetadataProvider(
        pageResults: <int, MediaPage>{
          1: _page(1, 24, hasNextPage: true),
          2: _page(25, 48, hasNextPage: false),
        },
      );
      final MetadataRepository repository = MetadataRepository(provider);

      final MediaPage first = await repository.browse(
        const ExploreFilter(),
        page: 1,
      );
      final MediaPage again = await repository.browse(
        const ExploreFilter(),
        page: 1,
      );
      final MediaPage second = await repository.browse(
        const ExploreFilter(),
        page: 2,
      );

      expect(first.items.length, 24);
      expect(again.items.length, 24);
      expect(second.items.length, 24);
      expect(second.items.first.id, 25);
      expect(provider.pagesRequested, <int>[1, 2]);
      expect(provider.browseCalls, 2);
    });
  });
}
