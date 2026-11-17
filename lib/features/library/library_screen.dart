import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors/app_failure.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/anime_poster.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/nexus_image.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/states.dart';
import '../../data/models/anime.dart';
import '../../data/models/library.dart';
import '../../data/providers/content_providers.dart';
import '../../data/repositories/library_repository.dart';

/// The user's saved titles, grouped by status.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LibraryView view = ref.watch(libraryViewControllerProvider);
    final LibraryViewController controller = ref.read(
      libraryViewControllerProvider.notifier,
    );
    final AsyncValue<List<LibraryEntry>> entries = ref.watch(
      libraryEntriesProvider,
    );
    final Map<LibraryStatus, int> counts = switch (ref.watch(
      libraryCountsProvider,
    )) {
      AsyncData<Map<LibraryStatus, int>>(
        :final Map<LibraryStatus, int> value,
      ) =>
        value,
      _ => const <LibraryStatus, int>{},
    };

    final double gutter = context.pageGutter;
    final int columns = context.gridColumns();
    final double available = MediaQuery.sizeOf(context).width - gutter * 2;
    final double tileWidth =
        (available - AppSpacing.sm * (columns - 1)) / columns;

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: NexusPagePadding(
            top: AppSpacing.md,
            child: Row(
              children: <Widget>[
                Text('My Library', style: AppTypography.headline),
                const Spacer(),
                NexusIconButton(
                  icon: view.layout == LibraryLayout.grid
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  tooltip: view.layout == LibraryLayout.grid
                      ? 'List view'
                      : 'Grid view',
                  onPressed: controller.toggleLayout,
                ),
                const SizedBox(width: AppSpacing.xs),
                _SortButton(onSelected: controller.setSort, current: view.sort),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: NexusPagePadding(
            top: AppSpacing.md,
            child: NexusSearchField(
              controller: _searchController,
              hintText: 'Search your library…',
              dense: true,
              onChanged: controller.setQuery,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: NexusPagePadding(
            top: AppSpacing.sm,
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: LibraryStatus.values.length,
                separatorBuilder: (BuildContext context, int _) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (BuildContext context, int index) {
                  final LibraryStatus status = LibraryStatus.values[index];
                  final bool selected = view.status == status;
                  return GestureDetector(
                    onTap: () => controller.setStatus(status),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accent
                            : AppColors.surfaceSecondary,
                        borderRadius: AppRadius.pillRadius,
                        border: Border.all(
                          color: selected ? AppColors.accent : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            status.label,
                            style: AppTypography.label.copyWith(
                              color: selected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                          CountBadge(
                            count: counts[status] ?? 0,
                            highlighted: selected,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            AppSpacing.md,
            gutter,
            AppSpacing.xl,
          ),
          sliver: switch (entries) {
            AsyncData<List<LibraryEntry>>(:final List<LibraryEntry> value) =>
              value.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.bookmark_border_rounded,
                        title: view.query.isEmpty
                            ? 'Nothing in ${view.status.label}'
                            : 'No matches',
                        message: view.query.isEmpty
                            ? 'Titles you save as ${view.status.label} appear '
                                  'here. Browse Explore to find something new.'
                            : 'No saved title matches “${view.query}”.',
                        action: view.query.isEmpty
                            ? SecondaryButton(
                                label: 'Explore anime',
                                icon: Icons.search_rounded,
                                onPressed: () => context.go('/explore'),
                              )
                            : null,
                      ),
                    )
                  : view.layout == LibraryLayout.grid
                  ? SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: tileWidth / (tileWidth * 1.5 + 46),
                      ),
                      delegate: SliverChildBuilderDelegate((
                        BuildContext context,
                        int index,
                      ) {
                        final LibraryEntry entry = value[index];
                        return AnimePoster(
                          anime: _asAnime(entry),
                          width: tileWidth,
                          progress: entry.progressFraction > 0
                              ? entry.progressFraction
                              : null,
                          badge: entry.watchedEpisodes > 0
                              ? 'EP ${entry.watchedEpisodes}'
                              : null,
                          onTap: () => context.push('/anime/${entry.animeId}'),
                        );
                      }, childCount: value.length),
                    )
                  : SliverList.separated(
                      itemCount: value.length,
                      separatorBuilder: (BuildContext context, int _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (BuildContext context, int index) =>
                          _LibraryRow(entry: value[index]),
                    ),
            AsyncError<List<LibraryEntry>>(:final Object error) =>
              SliverToBoxAdapter(
                child: ErrorState(failure: AppFailure.from(error)),
              ),
            _ => SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: tileWidth / (tileWidth * 1.5 + 46),
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => LoadingSkeleton(
                  width: tileWidth,
                  height: tileWidth * 1.5,
                  borderRadius: AppRadius.posterRadius,
                ),
                childCount: columns * 2,
              ),
            ),
          },
        ),
      ],
    );
  }

  Anime _asAnime(LibraryEntry entry) {
    return Anime(
      id: entry.animeId,
      title: entry.title,
      coverImage: entry.coverImage,
      bannerImage: entry.bannerImage,
      averageScore: entry.animeScore,
      format: entry.format,
      seasonYear: entry.seasonYear,
      episodes: entry.totalEpisodes,
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.onSelected, required this.current});

  final ValueChanged<LibrarySort> onSelected;
  final LibrarySort current;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LibrarySort>(
      tooltip: 'Sort library',
      color: AppColors.surfaceElevated,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<LibrarySort>>[
        for (final LibrarySort sort in LibrarySort.values)
          PopupMenuItem<LibrarySort>(
            value: sort,
            child: Row(
              children: <Widget>[
                Icon(
                  sort == current
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: sort == current
                      ? AppColors.accent
                      : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(sort.label, style: AppTypography.body),
              ],
            ),
          ),
      ],
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Icon(Icons.sort_rounded, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/anime/${entry.animeId}'),
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
                width: 54,
                height: 80,
                child: NexusImage(url: entry.coverImage),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.status.label} · '
                    '${Formatters.progress(entry.watchedEpisodes, entry.totalEpisodes)}',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: entry.progressFraction,
                      minHeight: 3,
                      backgroundColor: AppColors.surfaceSecondary,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (entry.animeScore != null)
              ScoreChip(label: Formatters.score(entry.animeScore)),
          ],
        ),
      ),
    );
  }
}
