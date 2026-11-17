import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../features/anime_details/anime_details_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/player/playback_request.dart';
import '../features/player/player_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/sources_screen.dart';
import 'app_shell.dart';

/// Branch indices must match `AppDestination.branchIndex` in
/// `navigation_destinations.dart`.
final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (
        BuildContext context,
        GoRouterState state,
        StatefulNavigationShell navigationShell,
      ) => AppShell(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/home',
              builder: (BuildContext context, GoRouterState state) =>
                  const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/explore',
              builder: (BuildContext context, GoRouterState state) =>
                  const ExploreScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/library',
              builder: (BuildContext context, GoRouterState state) =>
                  const LibraryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/profile',
              builder: (BuildContext context, GoRouterState state) =>
                  const ProfileScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/history',
              builder: (BuildContext context, GoRouterState state) =>
                  const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/settings',
              builder: (BuildContext context, GoRouterState state) =>
                  const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/anime/:animeId',
      builder: (BuildContext context, GoRouterState state) {
        final int? id = int.tryParse(state.pathParameters['animeId'] ?? '');
        if (id == null) return const _RouteError(message: 'Invalid title id.');
        return AnimeDetailsScreen(animeId: id);
      },
    ),
    GoRoute(
      path: '/sources',
      builder: (BuildContext context, GoRouterState state) =>
          const SourcesScreen(),
    ),
    GoRoute(
      path: '/watch',
      pageBuilder: (BuildContext context, GoRouterState state) {
        final Object? extra = state.extra;
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) => FadeTransition(opacity: animation, child: child),
          child: extra is PlaybackRequest
              ? PlayerScreen(request: extra)
              : const _RouteError(
                  message:
                      'This player session has no playback request. Open an '
                      'episode from a title or from Settings → Sources.',
                ),
        );
      },
    ),
  ],
  errorBuilder: (BuildContext context, GoRouterState state) =>
      _RouteError(message: 'Nothing lives at ${state.uri} yet.'),
);

class _RouteError extends StatelessWidget {
  const _RouteError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.explore_off_rounded,
                size: 34,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Page not found', style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => context.go('/home'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
