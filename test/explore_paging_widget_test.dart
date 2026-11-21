import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus/core/theme/app_theme.dart';
import 'package:nexus/core/widgets/anime_poster.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/data/models/media_page.dart';
import 'package:nexus/data/providers/app_providers.dart';
import 'package:nexus/data/providers/content_providers.dart';
import 'package:nexus/data/repositories/metadata_repository.dart';
import 'package:nexus/features/explore/explore_screen.dart';

import 'providers/support/fake_providers.dart';

const String _endOfResults = "You've reached the end";

Anime _anime(int id) => Anime(id: id, title: 'Title $id');

MediaPage _page(int first, int last, {required bool hasNextPage}) {
  return MediaPage(
    items: <Anime>[for (int id = first; id <= last; id++) _anime(id)],
    hasNextPage: hasNextPage,
  );
}

/// Pumps Explore at phone width with a scripted catalogue and no database.
Future<ProviderContainer> _pumpExplore(
  WidgetTester tester,
  FakeMetadataProvider provider,
) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final ProviderContainer container = ProviderContainer(
    overrides: [
      metadataRepositoryProvider.overrideWithValue(
        MetadataRepository(provider),
      ),
      recentSearchesProvider.overrideWith(
        (Ref ref) => Stream<List<String>>.value(const <String>[]),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: ExploreScreen()),
      ),
    ),
  );
  // Page 1 resolves after the first frame; the skeleton animates forever, so
  // every wait here is explicit rather than pumpAndSettle.
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  testWidgets('scrolling appends the next page, then ends quietly', (
    WidgetTester tester,
  ) async {
    final FakeMetadataProvider provider = FakeMetadataProvider(
      pageResults: <int, MediaPage>{
        1: _page(1, 24, hasNextPage: true),
        2: _page(25, 30, hasNextPage: false),
      },
    );
    final ProviderContainer container = await _pumpExplore(tester, provider);

    expect(find.byType(AnimePoster), findsWidgets);
    expect(
      container.read(exploreResultsProvider).requireValue.items.length,
      24,
    );
    expect(find.text(_endOfResults), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pump();
    await tester.pump();

    expect(provider.pagesRequested, <int>[1, 2]);
    expect(
      container.read(exploreResultsProvider).requireValue.items.length,
      30,
    );

    // Reach the bottom so the footer is laid out.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pump();
    await tester.pump();

    expect(find.text(_endOfResults), findsOneWidget);
    expect(provider.pagesRequested, <int>[1, 2], reason: 'the list has ended');
  });

  testWidgets('the footer spinner shows while the next page loads', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    final FakeMetadataProvider provider = FakeMetadataProvider(
      pageResults: <int, MediaPage>{
        1: _page(1, 24, hasNextPage: true),
        2: _page(25, 48, hasNextPage: false),
      },
      pageGates: <int, Completer<void>>{2: gate},
    );
    final ProviderContainer container = await _pumpExplore(tester, provider);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pump();

    expect(provider.pagesRequested, <int>[1, 2]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AnimePoster), findsWidgets);
    expect(
      container.read(exploreResultsProvider).requireValue.items.length,
      24,
      reason: 'tiles stay visible while the next page loads',
    );

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      container.read(exploreResultsProvider).requireValue.items.length,
      48,
    );
  });
}
