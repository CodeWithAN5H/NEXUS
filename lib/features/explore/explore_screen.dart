import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/anime_poster.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/filter_panel.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/states.dart';
import '../../data/models/anime.dart';
import '../../data/models/explore_filter.dart';
import '../../data/providers/app_providers.dart';
import '../../data/providers/content_providers.dart';
import '../../integrations/anilist/anilist_client.dart';

/// Search, filter and browse catalogue metadata.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(exploreFilterProvider).query;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    // 350 ms debounce keeps AniList requests to one per pause in typing.
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(exploreFilterProvider.notifier).setQuery(value);
    });
  }

  Future<void> _onSubmitted(String value) async {
    _debounce?.cancel();
    ref.read(exploreFilterProvider.notifier).setQuery(value);
    if (value.trim().length >= 2) {
      await ref.read(searchHistoryRepositoryProvider).record(value);
    }
  }

  void _applyRecentSearch(String query) {
    _searchController.text = query;
    ref.read(exploreFilterProvider.notifier).setQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    final ExploreFilter filter = ref.watch(exploreFilterProvider);
    final AsyncValue<MediaPage> results = ref.watch(exploreResultsProvider);
    final AsyncValue<List<String>> genres = ref.watch(genresProvider);
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
                Text('Explore', style: AppTypography.headline),
                const Spacer(),
                _FilterButton(
                  count: filter.activeFacetCount,
                  onPressed: () => showFilterPanel(context),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: NexusPagePadding(
            top: AppSpacing.md,
            child: NexusSearchField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              onSubmitted: _onSubmitted,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: NexusPagePadding(
            top: AppSpacing.sm,
            child: SizedBox(
              height: 36,
              child: AsyncValueView<List<String>>(
                value: genres,
                compact: true,
                loading: const LoadingSkeleton(height: 32),
                onRetry: () => ref.invalidate(genresProvider),
                builder: (BuildContext context, List<String> items) =>
                    ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: items.length,
                      separatorBuilder: (BuildContext context, int _) =>
                          const SizedBox(width: AppSpacing.xs),
                      itemBuilder: (BuildContext context, int index) {
                        final String genre = items[index];
                        return GenreChip(
                          label: genre,
                          dense: true,
                          selected: filter.genres.contains(genre),
                          onTap: () => ref
                              .read(exploreFilterProvider.notifier)
                              .toggleGenre(genre),
                        );
                      },
                    ),
              ),
            ),
          ),
        ),
        if (!filter.hasSearchQuery)
          SliverToBoxAdapter(
            child: _RecentSearches(onSelected: _applyRecentSearch),
          ),
        SliverToBoxAdapter(
          child: NexusPagePadding(
            top: AppSpacing.sm,
            child: Row(
              children: <Widget>[
                Text(
                  filter.hasSearchQuery
                      ? 'Results for “${filter.query.trim()}”'
                      : 'Popular now',
                  style: AppTypography.sectionTitle,
                ),
                const Spacer(),
                if (filter.hasActiveFilters)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Text(
                      '${filter.activeFacetCount} filter'
                      '${filter.activeFacetCount == 1 ? '' : 's'}',
                      style: AppTypography.caption,
                    ),
                  ),
              ],
            ),
          ),
        ),
        switch (results) {
          AsyncData<MediaPage>(:final MediaPage value) =>
            value.items.isEmpty
                ? SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No titles found',
                      message: filter.hasSearchQuery
                          ? 'Nothing matched “${filter.query.trim()}”. Try a '
                                'different spelling or clear your filters.'
                          : 'No titles matched the selected filters.',
                      action: SecondaryButton(
                        label: 'Clear filters',
                        icon: Icons.filter_alt_off_rounded,
                        onPressed: () {
                          _searchController.clear();
                          ref.read(exploreFilterProvider.notifier).reset();
                        },
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      AppSpacing.sm,
                      gutter,
                      AppSpacing.xl,
                    ),
                    sliver: SliverGrid(
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
                        final Anime anime = value.items[index];
                        return AnimePoster(
                          anime: anime,
                          width: tileWidth,
                          onTap: () => context.push('/anime/${anime.id}'),
                        );
                      }, childCount: value.items.length),
                    ),
                  ),
          AsyncError<MediaPage>(:final Object error) => SliverToBoxAdapter(
            child: AsyncValueView<MediaPage>(
              value: AsyncError<MediaPage>(error, StackTrace.current),
              onRetry: () {
                ref.read(metadataRepositoryProvider).invalidate('browse:');
                ref.invalidate(exploreResultsProvider);
              },
              builder: (BuildContext context, MediaPage _) =>
                  const SizedBox.shrink(),
            ),
          ),
          _ => SliverPadding(
            padding: EdgeInsets.all(gutter),
            sliver: SliverGrid(
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
                childCount: columns * 3,
              ),
            ),
          ),
        },
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        NexusIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'Filters',
          isActive: count > 0,
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: AppTypography.caption.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<String>> recent = ref.watch(recentSearchesProvider);
    final List<String> items = switch (recent) {
      AsyncData<List<String>>(:final List<String> value) => value,
      _ => const <String>[],
    };
    if (items.isEmpty) return const SizedBox.shrink();

    return NexusPagePadding(
      top: AppSpacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Recent searches', style: AppTypography.label),
              const Spacer(),
              GestureDetector(
                onTap: () => ref.read(searchHistoryRepositoryProvider).clear(),
                child: Text(
                  'Clear',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final String query in items)
                GestureDetector(
                  onTap: () => onSelected(query),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppRadius.pillRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.history_rounded,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          query,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
