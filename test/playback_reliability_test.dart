import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus/core/theme/app_theme.dart';
import 'package:nexus/core/utils/formatters.dart';
import 'package:nexus/core/widgets/continue_watching_card.dart';
import 'package:nexus/data/models/library.dart';
import 'package:nexus/features/player/playback_request.dart';
import 'package:nexus/integrations/playback/playback_reliability.dart';

const PlaybackRequest _request = PlaybackRequest(
  animeId: 20,
  animeTitle: 'Naruto',
  providerId: 'anizone',
  seriesId: 'spjuxray',
  episodeNumber: 2,
);

void main() {
  group('classifyPlaybackError', () {
    test('a codec failure is a decoder line, not a stream failure', () {
      expect(
        classifyPlaybackError('Could not open codec.'),
        PlaybackErrorKind.decoder,
      );
      expect(
        classifyPlaybackError('[ffmpeg/video] h264: decoder failure'),
        PlaybackErrorKind.decoder,
      );
      expect(
        classifyPlaybackError('Failed to initialize a decoder for hwdec'),
        PlaybackErrorKind.decoder,
      );
    });

    test('opening and transport failures are playback errors', () {
      expect(
        classifyPlaybackError('Failed to open https://cdn.example/master.m3u8'),
        PlaybackErrorKind.playback,
      );
      expect(
        classifyPlaybackError('tcp: Connection reset by peer'),
        PlaybackErrorKind.playback,
      );
    });
  });

  group('shouldSurfacePlaybackError', () {
    test('recoverable codec line after frames rendered is not terminal', () {
      expect(
        shouldSurfacePlaybackError(
          kind: PlaybackErrorKind.decoder,
          hasProgressed: true,
          progressingNow: true,
          playing: true,
        ),
        isFalse,
      );
    });

    test('a codec line with no rendered frames is still fatal', () {
      expect(
        shouldSurfacePlaybackError(
          kind: PlaybackErrorKind.decoder,
          hasProgressed: false,
          progressingNow: false,
          playing: true,
        ),
        isTrue,
      );
    });

    test('a transport failure while stalled and playing is fatal', () {
      expect(
        shouldSurfacePlaybackError(
          kind: PlaybackErrorKind.playback,
          hasProgressed: true,
          progressingNow: false,
          playing: true,
        ),
        isTrue,
      );
    });

    test('a transport line while frames advance is not fatal', () {
      expect(
        shouldSurfacePlaybackError(
          kind: PlaybackErrorKind.playback,
          hasProgressed: true,
          progressingNow: true,
          playing: true,
        ),
        isFalse,
      );
    });

    test('a paused player is not killed by a transient error line', () {
      expect(
        shouldSurfacePlaybackError(
          kind: PlaybackErrorKind.playback,
          hasProgressed: true,
          progressingNow: false,
          playing: false,
        ),
        isFalse,
      );
    });
  });

  group('PlaybackAttempts', () {
    test('a new attempt supersedes the previous token', () {
      final PlaybackAttempts attempts = PlaybackAttempts();
      final int first = attempts.begin();
      expect(attempts.isCurrent(first), isTrue);

      final int second = attempts.begin();
      expect(attempts.isCurrent(first), isFalse);
      expect(attempts.isCurrent(second), isTrue);
      expect(attempts.current, second);
    });

    test('stale completions and errors are rejected after a retry', () {
      final PlaybackAttempts attempts = PlaybackAttempts();
      final int load = attempts.begin();
      // Retry: the previous attempt must no longer be allowed to write state.
      attempts.begin();
      expect(attempts.isCurrent(load), isFalse);
    });

    test('disposal invalidates every in-flight attempt', () {
      final PlaybackAttempts attempts = PlaybackAttempts();
      final int load = attempts.begin();
      attempts.invalidate();
      expect(attempts.isCurrent(load), isFalse);
    });
  });

  group('PlaybackRequest labels', () {
    test('player subtitle names the episode, never the object', () {
      expect(_request.label, 'Episode 2');
      expect(_request.playerSubtitle, 'Episode 2');
      expect(_request.playerSubtitle, isNot(contains('Instance of')));
    });

    test('player subtitle adds the episode title when present', () {
      final PlaybackRequest titled = _request.copyWith(
        episodeTitle: 'Enter: Naruto Uzumaki!',
      );
      expect(titled.playerSubtitle, 'Episode 2 · Enter: Naruto Uzumaki!');
    });
  });

  group('season-year label', () {
    test('renders a plain year, never an object representation', () {
      expect(Formatters.year(2002), '2002');
      expect(Formatters.year(2002), isNot(contains('Instance of')));
      expect(Formatters.year(null), '—');
    });
  });

  group('ContinueWatchingCard meta line', () {
    testWidgets('shows the episode number and never invents a season', (
      WidgetTester tester,
    ) async {
      final WatchProgress progress = WatchProgress(
        animeId: 20,
        episodeNumber: 2,
        title: 'Naruto',
        position: const Duration(seconds: 40),
        duration: const Duration(minutes: 24),
        updatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF101014),
            body: Center(
              child: ContinueWatchingCard(progress: progress, width: 280),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('EP 2'), findsOneWidget);
      expect(find.textContaining('Episode 2'), findsOneWidget);
      expect(find.textContaining('S2'), findsNothing);
    });
  });

  group('PlaybackStallTracker', () {
    test('advancing playback is never reported as stalled', () {
      final PlaybackStallTracker tracker = PlaybackStallTracker();
      Duration position = Duration.zero;
      for (int i = 0; i < 20; i++) {
        position += const Duration(seconds: 2);
        expect(tracker.observe(position, playing: true), isFalse);
      }
    });

    test('buffered progress that stops reports a stall', () {
      final PlaybackStallTracker tracker = PlaybackStallTracker();
      expect(
        tracker.observe(const Duration(seconds: 30), playing: true),
        isFalse,
      );
      // The buffer drains: position no longer advances while "playing".
      bool stalled = false;
      for (int i = 0; i < 4; i++) {
        stalled = tracker.observe(const Duration(seconds: 30), playing: true);
      }
      expect(stalled, isTrue);
    });

    test('a paused player is not treated as stalled', () {
      final PlaybackStallTracker tracker = PlaybackStallTracker();
      for (int i = 0; i < 10; i++) {
        expect(tracker.observe(Duration.zero, playing: false), isFalse);
      }
    });

    test('the watchdog expires instead of watching for ever', () {
      final PlaybackStallTracker tracker = PlaybackStallTracker();
      Duration position = Duration.zero;
      for (int i = 0; i < PlaybackStallTracker.maxSamples; i++) {
        position += const Duration(seconds: 2);
        expect(tracker.observe(position, playing: true), isFalse);
      }
      expect(tracker.expired, isTrue);
    });
  });
}
