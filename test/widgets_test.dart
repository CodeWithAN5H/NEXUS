import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus/app/navigation_destinations.dart';
import 'package:nexus/core/errors/app_failure.dart';
import 'package:nexus/core/theme/app_theme.dart';
import 'package:nexus/core/widgets/anime_poster.dart';
import 'package:nexus/core/widgets/buttons.dart';
import 'package:nexus/core/widgets/chips.dart';
import 'package:nexus/core/widgets/navigation_bar.dart';
import 'package:nexus/core/widgets/states.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/features/player/widgets/player_controls.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(backgroundColor: const Color(0xFF101014), body: child),
  );
}

const Anime _frieren = Anime(
  id: 154587,
  title: 'Frieren',
  averageScore: 93,
  format: 'TV',
  seasonYear: 2023,
  episodes: 28,
);

void main() {
  group('AnimePoster', () {
    testWidgets('renders title, score and meta line', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(Center(child: AnimePoster(anime: _frieren, width: 140))),
      );
      await tester.pump();

      expect(find.text('Frieren'), findsOneWidget);
      expect(find.text('9.3'), findsOneWidget);
      expect(find.text('TV · 2023'), findsOneWidget);
    });

    testWidgets('shows progress and badge when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: AnimePoster(
              anime: _frieren,
              width: 140,
              progress: 0.5,
              badge: 'EP 6',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('EP 6'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('invokes onTap when the artwork is pressed', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          Center(
            child: AnimePoster(
              anime: _frieren,
              width: 140,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Frieren'));
      expect(taps, 1);
    });
  });

  group('GenreChip', () {
    testWidgets('reports taps', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          Center(
            child: GenreChip(
              label: 'Fantasy',
              selected: true,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      expect(find.text('Fantasy'), findsOneWidget);
      await tester.tap(find.text('Fantasy'));
      expect(taps, 1);
    });
  });

  group('states', () {
    testWidgets('EmptyState shows its copy and action', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            title: 'No titles found',
            message: 'Try a different spelling.',
            action: SecondaryButton(label: 'Clear', onPressed: () => taps++),
          ),
        ),
      );
      expect(find.text('No titles found'), findsOneWidget);
      expect(find.text('Try a different spelling.'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      expect(taps, 1);
    });

    testWidgets('ErrorState offers retry only for retryable failures', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await tester.pumpWidget(
        _wrap(
          ErrorState(
            failure: const NetworkFailure('No connection.'),
            onRetry: () => retries++,
          ),
        ),
      );
      expect(find.text('Connection problem'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);

      await tester.pumpWidget(
        _wrap(
          ErrorState(
            failure: const NotFoundFailure('Gone.', cause: null),
            onRetry: () => retries++,
          ),
        ),
      );
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('InlineMessage renders its tone', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const InlineMessage(
            message: 'Sample content only',
            tone: InlineTone.warning,
          ),
        ),
      );
      expect(find.text('Sample content only'), findsOneWidget);
    });
  });

  group('NexusBottomBar', () {
    testWidgets('highlights the active branch and reports selection', (
      WidgetTester tester,
    ) async {
      AppDestination? selected;
      await tester.pumpWidget(
        _wrap(
          Align(
            alignment: Alignment.bottomCenter,
            child: NexusBottomBar(
              destinations: mobileDestinations,
              activeBranchIndex: 0,
              onSelect: (AppDestination destination) => selected = destination,
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.text('Explore'));
      expect(selected, exploreDestination);
    });

    testWidgets('keeps Profile active for settings and history branches', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Align(
            alignment: Alignment.bottomCenter,
            child: NexusBottomBar(
              destinations: mobileDestinations,
              activeBranchIndex: 5,
              onSelect: (AppDestination _) {},
            ),
          ),
        ),
      );
      expect(find.byIcon(profileDestination.activeIcon), findsOneWidget);
    });
  });

  group('PlayerControls', () {
    PlayerControlsState state({
      bool playing = false,
      bool visible = true,
      bool hasNext = true,
      String qualityLabel = '1080p',
    }) {
      return PlayerControlsState(
        title: 'Frieren',
        subtitle: 'Episode 1 · The Journey Begins',
        playing: playing,
        buffering: false,
        position: const Duration(minutes: 12, seconds: 34),
        duration: const Duration(minutes: 24, seconds: 17),
        visible: visible,
        qualityLabel: qualityLabel,
        subtitleLabel: 'CC',
        audioLabel: 'Audio',
        speed: 1,
        volume: 80,
        hasNext: hasNext,
        fullscreen: false,
        notice: 'Sample stream',
        isSample: true,
      );
    }

    PlayerControlsActions actions({
      VoidCallback? onTogglePlay,
      VoidCallback? onSeekForward,
      VoidCallback? onQuality,
      VoidCallback? onNext,
      VoidCallback? onFullscreen,
    }) {
      return PlayerControlsActions(
        onBack: () {},
        onTogglePlay: onTogglePlay ?? () {},
        onSeek: (Duration _) {},
        onSeekBack: () {},
        onSeekForward: onSeekForward ?? () {},
        onNext: onNext ?? () {},
        onQuality: onQuality ?? () {},
        onSubtitles: () {},
        onAudio: () {},
        onSpeed: () {},
        onEpisodes: () {},
        onFullscreen: onFullscreen ?? () {},
        onToggleMute: () {},
        onVolume: (double _) {},
      );
    }

    testWidgets('shows the title, timestamps and sample badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(PlayerControls(state: state(), actions: actions())),
      );
      expect(find.text('Frieren'), findsOneWidget);
      expect(find.text('Episode 1 · The Journey Begins'), findsOneWidget);
      expect(find.text('12:34'), findsOneWidget);
      expect(find.text('24:17'), findsOneWidget);
      expect(find.text('SAMPLE'), findsOneWidget);
      expect(find.text('1080p'), findsOneWidget);
    });

    testWidgets('wires the transport buttons', (WidgetTester tester) async {
      int plays = 0;
      int forwards = 0;
      int qualities = 0;
      await tester.pumpWidget(
        _wrap(
          PlayerControls(
            state: state(),
            actions: actions(
              onTogglePlay: () => plays++,
              onSeekForward: () => forwards++,
              onQuality: () => qualities++,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.tap(find.byIcon(Icons.forward_10_rounded));
      await tester.tap(find.text('1080p'));

      expect(plays, 1);
      expect(forwards, 1);
      expect(qualities, 1);
    });

    testWidgets('ignores input while the chrome is hidden', (
      WidgetTester tester,
    ) async {
      int plays = 0;
      await tester.pumpWidget(
        _wrap(
          PlayerControls(
            state: state(visible: false),
            actions: actions(onTogglePlay: () => plays++),
          ),
        ),
      );
      await tester.tap(
        find.byIcon(Icons.play_arrow_rounded),
        warnIfMissed: false,
      );
      expect(plays, 0);
    });

    Future<void> pumpAt(
      WidgetTester tester,
      Size size, {
      PlayerControlsState? playerState,
      PlayerControlsActions? playerActions,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          PlayerControls(
            state: playerState ?? state(),
            actions: playerActions ?? actions(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'keeps every bottom-bar control on screen at phone portrait width',
      (WidgetTester tester) async {
        int next = 0;
        int fullscreen = 0;
        await pumpAt(
          tester,
          const Size(393, 852),
          playerState: state(qualityLabel: 'Auto (up to 1080p)'),
          playerActions: actions(
            onNext: () => next++,
            onFullscreen: () => fullscreen++,
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Auto (up to 1080p)'), findsOneWidget);
        expect(find.text('CC'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        expect(find.byTooltip('Next episode'), findsOneWidget);
        expect(find.byTooltip('Fullscreen'), findsOneWidget);

        // The regression: these used to be laid out past the right edge.
        final Rect quality = tester.getRect(find.text('Auto (up to 1080p)'));
        final Rect nextRect = tester.getRect(find.byTooltip('Next episode'));
        final Rect fullscreenRect = tester.getRect(
          find.byTooltip('Fullscreen'),
        );
        expect(quality.right, lessThanOrEqualTo(393));
        expect(nextRect.right, lessThanOrEqualTo(393));
        expect(fullscreenRect.right, lessThanOrEqualTo(393));

        await tester.tap(find.byTooltip('Next episode'));
        await tester.tap(find.byTooltip('Fullscreen'));
        expect(next, 1);
        expect(fullscreen, 1);
      },
    );

    testWidgets('fits a narrower portrait width without overflow', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const Size(360, 740),
        playerState: state(qualityLabel: 'Auto (up to 1080p)'),
      );

      expect(tester.takeException(), isNull);
      final Rect fullscreenRect = tester.getRect(find.byTooltip('Fullscreen'));
      expect(fullscreenRect.right, lessThanOrEqualTo(360));
      final Rect quality = tester.getRect(find.text('Auto (up to 1080p)'));
      expect(quality.right, lessThanOrEqualTo(360));
    });

    testWidgets('keeps the single-row layout in landscape', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const Size(875, 393),
        playerState: state(qualityLabel: 'Auto (up to 1080p)'),
      );

      expect(tester.takeException(), isNull);
      final double ccY = tester.getCenter(find.text('CC')).dy;
      final double qualityY = tester
          .getCenter(find.text('Auto (up to 1080p)'))
          .dy;
      expect(qualityY, closeTo(ccY, 1));
      expect(
        tester.getRect(find.byTooltip('Fullscreen')).right,
        lessThanOrEqualTo(875),
      );
    });
  });
}
