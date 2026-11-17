import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/navigation_destinations.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/responsive.dart';
import '../../data/models/library.dart';
import '../../data/providers/app_providers.dart';
import '../../data/providers/content_providers.dart';

/// Local profile, viewing statistics and account links.
///
/// NEXUS works without an account: everything here is derived from local data.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<LibraryEntry> entries = switch (ref.watch(
      allLibraryEntriesProvider,
    )) {
      AsyncData<List<LibraryEntry>>(:final List<LibraryEntry> value) => value,
      _ => const <LibraryEntry>[],
    };
    final List<WatchProgress> history = switch (ref.watch(historyProvider)) {
      AsyncData<List<WatchProgress>>(:final List<WatchProgress> value) => value,
      _ => const <WatchProgress>[],
    };

    final int watching = entries
        .where((LibraryEntry e) => e.status == LibraryStatus.watching)
        .length;
    final int completed = entries
        .where((LibraryEntry e) => e.status == LibraryStatus.completed)
        .length;
    final int episodesWatched = entries.fold<int>(
      0,
      (int sum, LibraryEntry entry) => sum + entry.watchedEpisodes,
    );
    final Duration watchedTime = history.fold<Duration>(
      Duration.zero,
      (Duration sum, WatchProgress item) => sum + item.position,
    );

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: NexusPagePadding(
            top: AppSpacing.md,
            child: Row(
              children: <Widget>[
                const NexusWordmark(size: 24),
                const Spacer(),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => context.go(settingsDestination.path),
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: NexusContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppDecorations.accentGradient,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 30,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Local profile', style: AppTypography.headline),
                          const SizedBox(height: 2),
                          Text(
                            'No account needed · data stays on this device',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    _Stat(value: '${entries.length}', label: 'Saved'),
                    _Stat(value: '$watching', label: 'Watching'),
                    _Stat(value: '$completed', label: 'Completed'),
                    _Stat(value: _formatHours(watchedTime), label: 'Tracked'),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$episodesWatched episodes marked as watched across your library.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.lg),
                _LinkTile(
                  icon: Icons.history_rounded,
                  title: 'Watch history',
                  subtitle: history.isEmpty
                      ? 'Nothing watched yet'
                      : '${history.length} recorded position'
                            '${history.length == 1 ? '' : 's'}',
                  onTap: () => context.go(historyDestination.path),
                ),
                _LinkTile(
                  icon: Icons.tune_rounded,
                  title: 'Sources',
                  subtitle:
                      '${ref.watch(appSettingsProvider).enabledProviderIds.length} '
                      'enabled · manage providers',
                  onTap: () => context.push('/sources'),
                ),
                _LinkTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Appearance, playback, subtitles, audio',
                  onTap: () => context.go(settingsDestination.path),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.sync_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'AniList connection',
                            style: AppTypography.bodyStrong,
                          ),
                          const Spacer(),
                          const MetaChipLabel(),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Signing in to AniList and syncing lists arrives in '
                        'v0.4. Metadata is already powered by AniList, so every '
                        'score and synopsis you see comes from their API.',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'NEXUS ${AppConstants.appVersion}',
                    style: AppTypography.caption,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatHours(Duration duration) {
    if (duration.inMinutes < 60) return '${duration.inMinutes}m';
    return '${(duration.inMinutes / 60).toStringAsFixed(1)}h';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: AppTypography.headline.copyWith(fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

/// Small "coming soon" marker used instead of a fake toggle.
class MetaChipLabel extends StatelessWidget {
  const MetaChipLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'v0.4',
        style: AppTypography.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 19, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppTypography.bodyStrong),
                    const SizedBox(height: 1),
                    Text(subtitle, style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
