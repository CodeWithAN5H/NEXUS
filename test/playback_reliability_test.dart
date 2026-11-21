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

  group('isAtPlaybackEnd', () {
    const Duration duration = Duration(minutes: 24);

    test('a seek that lands on the duration counts as the end', () {
      expect(
        isAtPlaybackEnd(
          position: duration,
          duration: duration,
          completed: false,
        ),
        isTrue,
      );
    });

    test('a completed media counts as the end at any position', () {
      expect(
        isAtPlaybackEnd(
          position: const Duration(minutes: 3),
          duration: duration,
          completed: true,
        ),
        isTrue,
      );
    });

    test('the last seconds of ordinary playback are not the end', () {
      // A tolerant end would make a pause press there restart the episode.
      expect(
        isAtPlaybackEnd(
          position: duration - const Duration(milliseconds: 200),
          duration: duration,
          completed: false,
        ),
        isFalse,
      );
      expect(
        isAtPlaybackEnd(
          position: duration - playbackEndTolerance,
          duration: duration,
          completed: false,
        ),
        isFalse,
      );
    });

    test('a position past the duration is the end', () {
      expect(
        isAtPlaybackEnd(
          position: duration + const Duration(seconds: 3),
          duration: duration,
          completed: false,
        ),
        isTrue,
      );
    });

    test('ordinary playback is not the end', () {
      expect(
        isAtPlaybackEnd(
          position: const Duration(minutes: 23),
          duration: duration,
          completed: false,
        ),
        isFalse,
      );
    });

    test('an unknown duration is never the end', () {
      expect(
        isAtPlaybackEnd(
          position: Duration.zero,
          duration: Duration.zero,
          completed: false,
        ),
        isFalse,
      );
    });
  });

  group('clampSeekTarget', () {
    const Duration duration = Duration(minutes: 24);

    test('seeking to the exact duration stops before the end', () {
      expect(
        clampSeekTarget(target: duration, duration: duration),
        duration - playbackEndTolerance,
      );
    });

    test('seeking past the end stops before the end', () {
      expect(
        clampSeekTarget(target: duration * 2, duration: duration),
        duration - playbackEndTolerance,
      );
    });

    test('seeking close to the end is left alone', () {
      final Duration nearEnd = duration - playbackEndTolerance;
      expect(clampSeekTarget(target: nearEnd, duration: duration), nearEnd);
    });

    test('a seek into the last seconds lands on the last playable point', () {
      // Honoured, but from the earliest point that still decodes to the end.
      expect(
        clampSeekTarget(
          target: duration - const Duration(seconds: 1),
          duration: duration,
        ),
        duration - playbackEndTolerance,
      );
    });

    test('seeking back from the end is left alone', () {
      final Duration target = duration - const Duration(minutes: 5);
      expect(clampSeekTarget(target: target, duration: duration), target);
    });

    test('negative targets clamp to zero', () {
      expect(
        clampSeekTarget(
          target: const Duration(seconds: -30),
          duration: duration,
        ),
        Duration.zero,
      );
    });

    test('an unknown duration is not clamped', () {
      const Duration target = Duration(minutes: 3);
      expect(clampSeekTarget(target: target, duration: Duration.zero), target);
    });
  });

  group('playbackPlayAction', () {
    const Duration duration = Duration(minutes: 24);

    test('play at the end restarts instead of sending an ignored play', () {
      // A dead track can report playing=true, so the position decides.
      expect(
        playbackPlayAction(
          position: duration,
          duration: duration,
          completed: false,
        ),
        PlaybackPlayAction.restart,
      );
    });

    test('play after a completion restarts the episode', () {
      expect(
        playbackPlayAction(
          position: duration,
          duration: duration,
          completed: true,
        ),
        PlaybackPlayAction.restart,
      );
    });

    test('pressing play mid-episode is a normal transport call', () {
      expect(
        playbackPlayAction(
          position: duration - const Duration(minutes: 5),
          duration: duration,
          completed: false,
        ),
        PlaybackPlayAction.transport,
      );
    });

    test('pausing in the final seconds does not restart the episode', () {
      expect(
        playbackPlayAction(
          position: duration - const Duration(seconds: 1),
          duration: duration,
          completed: false,
        ),
        PlaybackPlayAction.transport,
      );
    });
  });

  group('isPlaybackCompletion', () {
    const Duration duration = Duration(minutes: 24);

    test('a completion at the end of the media is believed', () {
      expect(
        isPlaybackCompletion(
          position: duration,
          duration: duration,
          completed: true,
        ),
        isTrue,
      );
    });

    test('mpv parking a fraction short of the duration still completes', () {
      expect(
        isPlaybackCompletion(
          position: duration - const Duration(milliseconds: 700),
          duration: duration,
          completed: true,
        ),
        isTrue,
      );
    });

    test('a completion reported mid-episode is not believed', () {
      // A dropped connection raises mpv's eof flag; the episode did not end.
      expect(
        isPlaybackCompletion(
          position: const Duration(minutes: 1),
          duration: duration,
          completed: true,
        ),
        isFalse,
      );
    });

    test('a completion with an unknown duration is not believed', () {
      expect(
        isPlaybackCompletion(
          position: const Duration(minutes: 1),
          duration: Duration.zero,
          completed: true,
        ),
        isFalse,
      );
    });

    test('a position at the end without the flag is not a completion', () {
      expect(
        isPlaybackCompletion(
          position: duration,
          duration: duration,
          completed: false,
        ),
        isFalse,
      );
    });
  });

  group('playbackCompletionAction', () {
    test('autoplay on with a next episode advances', () {
      expect(
        playbackCompletionAction(autoplayNext: true, hasNextEpisode: true),
        PlaybackCompletionAction.advance,
      );
    });

    test('autoplay off with a next episode stays', () {
      expect(
        playbackCompletionAction(autoplayNext: false, hasNextEpisode: true),
        PlaybackCompletionAction.stay,
      );
    });

    test('autoplay on at the last episode stays', () {
      expect(
        playbackCompletionAction(autoplayNext: true, hasNextEpisode: false),
        PlaybackCompletionAction.stay,
      );
    });

    test('autoplay off at the last episode stays', () {
      expect(
        playbackCompletionAction(autoplayNext: false, hasNextEpisode: false),
        PlaybackCompletionAction.stay,
      );
    });
  });

  group('PlaybackCompletionGate', () {
    test('the first completion of a load is claimed', () {
      final PlaybackCompletionGate gate = PlaybackCompletionGate();
      expect(gate.claim(7), isTrue);
    });

    test('a repeated completion of the same load cannot advance again', () {
      final PlaybackCompletionGate gate = PlaybackCompletionGate();
      expect(gate.claim(7), isTrue);
      expect(gate.claim(7), isFalse);
      expect(gate.claim(7), isFalse);
    });

    test('the next load may complete once too', () {
      final PlaybackCompletionGate gate = PlaybackCompletionGate();
      expect(gate.claim(7), isTrue);
      expect(gate.claim(8), isTrue);
      expect(gate.claim(8), isFalse);
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
