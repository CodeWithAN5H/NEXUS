import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/database/nexus_database.dart';
import 'package:nexus/data/models/library.dart';
import 'package:nexus/data/providers/app_providers.dart';
import 'package:nexus/data/repositories/history_repository.dart';
import 'package:nexus/integrations/playback/playback_reliability.dart';

/// The player reads autoplay from the settings provider when an episode ends,
/// so these cover the value that decision actually sees.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('autoplay seen at completion', () {
    late NexusDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = NexusDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    /// The decision the player takes, using the setting in force right now.
    PlaybackCompletionAction decide() => playbackCompletionAction(
      autoplayNext: container.read(appSettingsProvider).autoplayNext,
      hasNextEpisode: true,
    );

    test(
      'autoplay disabled before the player opens does not advance',
      () async {
        await container.read(settingsProvider.future);
        await container.read(settingsProvider.notifier).setAutoplayNext(false);

        expect(decide(), PlaybackCompletionAction.stay);
      },
    );

    test('autoplay enabled before the player opens advances', () async {
      await container.read(settingsProvider.future);
      await container.read(settingsProvider.notifier).setAutoplayNext(true);

      expect(decide(), PlaybackCompletionAction.advance);
    });

    test(
      'disabling autoplay while the player is open prevents advancement',
      () async {
        await container.read(settingsProvider.future);
        // What a player that cached settings at open would keep using.
        final bool atOpen = container.read(appSettingsProvider).autoplayNext;
        expect(atOpen, isTrue);

        await container.read(settingsProvider.notifier).setAutoplayNext(false);

        expect(container.read(appSettingsProvider).autoplayNext, isFalse);
        expect(decide(), PlaybackCompletionAction.stay);
      },
    );

    test(
      'enabling autoplay while the player is open allows advancement',
      () async {
        await container.read(settingsProvider.future);
        await container.read(settingsProvider.notifier).setAutoplayNext(false);
        final bool atOpen = container.read(appSettingsProvider).autoplayNext;
        expect(atOpen, isFalse);

        await container.read(settingsProvider.notifier).setAutoplayNext(true);

        expect(decide(), PlaybackCompletionAction.advance);
      },
    );

    test('a value still loading at open is not what completion sees', () async {
      // Reading before the async load settles yields the default (autoplay on);
      // completion reads again, after the stored value is available.
      expect(container.read(appSettingsProvider).autoplayNext, isTrue);
      await container.read(settingsProvider.future);
      await container.read(settingsProvider.notifier).setAutoplayNext(false);

      expect(decide(), PlaybackCompletionAction.stay);
    });
  });

  group('progress writes do not move Continue Watching on', () {
    late NexusDatabase db;
    late HistoryRepository history;

    setUp(() {
      db = NexusDatabase(NativeDatabase.memory());
      history = HistoryRepository(db);
    });

    tearDown(() async => db.close());

    Future<void> record(int episode, Duration position) => history.record(
      animeId: 20,
      episodeNumber: episode,
      title: 'Naruto',
      position: position,
      duration: const Duration(minutes: 24),
    );

    test('near-end progress keeps the episode being watched', () async {
      await record(5, const Duration(minutes: 22));

      final List<WatchProgress> rail = await history
          .watchContinueWatching()
          .first;

      expect(rail.single.episodeNumber, 5);
      expect(rail.single.position, const Duration(minutes: 22));
    });

    test(
      'repeated progress writes for one episode stay on that episode',
      () async {
        for (final Duration position in <Duration>[
          const Duration(minutes: 1),
          const Duration(minutes: 6),
          const Duration(minutes: 12),
          const Duration(minutes: 20),
          const Duration(minutes: 23),
        ]) {
          await record(7, position);
        }

        final List<WatchProgress> rail = await history
            .watchContinueWatching()
            .first;

        expect(rail.single.episodeNumber, 7);
        expect(rail.single.position, const Duration(minutes: 23));
      },
    );

    test(
      'a late save from an earlier episode cannot take over the rail',
      () async {
        await record(7, const Duration(minutes: 20));
        // A completion save arriving out of order for the previous episode.
        await record(6, const Duration(minutes: 24));

        final List<WatchProgress> rail = await history
            .watchContinueWatching()
            .first;

        expect(rail.single.episodeNumber, 7);
      },
    );

    test('the stored resume position is exactly what was written', () async {
      await record(3, const Duration(minutes: 7, seconds: 41));

      final WatchProgress? progress = await history.progressFor(20, 3);

      expect(progress!.position, const Duration(minutes: 7, seconds: 41));
    });
  });
}
