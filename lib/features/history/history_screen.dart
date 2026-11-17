import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors/app_failure.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/nexus_image.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/states.dart';
import '../../data/models/library.dart';
import '../../data/providers/app_providers.dart';
import '../../data/providers/content_providers.dart';
import '../player/playback_request.dart';

/// Everything the user has started watching, newest first.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WatchProgress>> history = ref.watch(historyProvider);

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: NexusPagePadding(
            top: AppSpacing.md,
            child: Row(
              children: <Widget>[
                Text('History', style: AppTypography.headline),
                const Spacer(),
                if ((history.value ?? const <WatchProgress>[]).isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        ref.read(historyRepositoryProvider).clearAll(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Clear all'),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.pageGutter,
            AppSpacing.md,
            context.pageGutter,
            AppSpacing.xl,
          ),
          sliver: switch (history) {
            AsyncData<List<WatchProgress>>(:final List<WatchProgress> value) =>
              value.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No watch history yet',
                        message:
                            'Episodes you start playing are recorded here with '
                            'your exact position, so you can pick up where you '
                            'left off.',
                        action: SecondaryButton(
                          label: 'Find something to watch',
                          icon: Icons.search_rounded,
                          onPressed: () => context.go('/explore'),
                        ),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: value.length,
                      separatorBuilder: (BuildContext context, int _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (BuildContext context, int index) =>
                          _HistoryRow(progress: value[index]),
                    ),
            AsyncError<List<WatchProgress>>(:final Object error) =>
              SliverToBoxAdapter(
                child: ErrorState(
                  failure: AppFailure.from(error),
                  onRetry: () => ref.invalidate(historyProvider),
                ),
              ),
            _ => SliverList.separated(
              itemCount: 4,
              separatorBuilder: (BuildContext context, int _) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (BuildContext context, int _) =>
                  const LoadingSkeleton(height: 76),
            ),
          },
        ),
      ],
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.progress});

  final WatchProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm - 2),
              child: SizedBox(
                width: 92,
                height: 52,
                child: NexusImage(
                  url: progress.bannerImage ?? progress.coverImage,
                  fallbackIcon: Icons.play_circle_outline_rounded,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    progress.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Episode ${progress.episodeNumber} · '
                    '${Formatters.clock(progress.position)} / '
                    '${Formatters.clock(progress.duration)} · '
                    '${Formatters.percent(progress.fraction)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    Formatters.relativeDate(progress.updatedAt),
                    style: AppTypography.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove from history',
              onPressed: () => ref
                  .read(historyRepositoryProvider)
                  .deleteEntry(progress.animeId, progress.episodeNumber),
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final String? providerId = progress.providerId;
    final String? seriesId = progress.seriesId;
    if (providerId == null || seriesId == null) {
      context.push('/anime/${progress.animeId}');
      return;
    }
    context.push(
      '/watch',
      extra: PlaybackRequest(
        animeId: progress.animeId,
        animeTitle: progress.title,
        providerId: providerId,
        seriesId: seriesId,
        episodeNumber: progress.episodeNumber,
        episodeTitle: progress.episodeTitle,
        coverImage: progress.coverImage,
        bannerImage: progress.bannerImage,
        totalEpisodes: progress.totalEpisodes,
        isSample: progress.animeId < 0,
      ),
    );
  }
}
