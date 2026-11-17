import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/navigation_destinations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/anime_poster.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/continue_watching_card.dart';
import '../../core/widgets/nexus_image.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/states.dart';
import '../../data/models/anime.dart';
import '../../data/models/explore_filter.dart';
import '../../data/models/library.dart';
import '../../data/providers/app_providers.dart';
import '../../data/providers/content_providers.dart';
import '../../integrations/anilist/anilist_client.dart';
import '../player/playback_request.dart';

/// Discovery home: featured title, resume rail and curated metadata rails.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(metadataRepositoryProvider).invalidate();
    ref.invalidate(trendingProvider);
    ref.invalidate(recentlyUpdatedProvider);
    ref.invalidate(seasonalProvider);
    ref.invalidate(topRatedProvider);
    await ref.read(trendingProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({AnimeSeason season, int year}) current = ref.watch(
      currentSeasonProvider,
    );

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: () => _refresh(ref),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: NexusPagePadding(
              top: AppSpacing.md,
              child: const _HomeHeader(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          const SliverToBoxAdapter(child: _FeaturedCarousel()),
          SliverToBoxAdapter(child: _ContinueWatchingSection()),
          SliverToBoxAdapter(
            child: _MediaRailSection(
              title: 'Trending Anime',
              provider: trendingProvider,
            ),
          ),
          SliverToBoxAdapter(
            child: _MediaRailSection(
              title: 'Recently Updated',
              provider: recentlyUpdatedProvider,
            ),
          ),
          SliverToBoxAdapter(
            child: _MediaRailSection(
              title: '${current.season.label} ${current.year} Anime',
              provider: seasonalProvider,
            ),
          ),
          SliverToBoxAdapter(
            child: _MediaRailSection(
              title: 'Top Rated',
              provider: topRatedProvider,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const NexusWordmark(size: 26),
        const Spacer(),
        NexusIconButton(
          icon: Icons.search_rounded,
          tooltip: 'Search',
          onPressed: () => context.go(exploreDestination.path),
        ),
        const SizedBox(width: AppSpacing.xs),
        GestureDetector(
          onTap: () => context.go(profileDestination.path),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppDecorations.accentGradient,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 19,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cinematic hero for the top trending titles.
class _FeaturedCarousel extends ConsumerStatefulWidget {
  const _FeaturedCarousel();

  @override
  ConsumerState<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends ConsumerState<_FeaturedCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MediaPage> trending = ref.watch(trendingProvider);
    final double height = context.heroHeight;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.pageGutter),
      child: SizedBox(
        height: height,
        child: AsyncValueView<MediaPage>(
          value: trending,
          onRetry: () => ref.invalidate(trendingProvider),
          loading: LoadingSkeleton(
            height: height,
            borderRadius: AppRadius.cardRadius,
          ),
          builder: (BuildContext context, MediaPage page) {
            final List<Anime> featured = page.items
                .take(5)
                .toList(growable: false);
            if (featured.isEmpty) {
              return EmptyState(
                title: 'Nothing featured right now',
                message: 'AniList returned no trending titles. Pull down to refresh.',
                action: SecondaryButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onPressed: () => ref.invalidate(trendingProvider),
                ),
              );
            }

            return Stack(
              children: <Widget>[
                PageView.builder(
                  controller: _controller,
                  itemCount: featured.length,
                  onPageChanged: (int index) => setState(() => _page = index),
                  itemBuilder: (BuildContext context, int index) =>
                      _FeaturedSlide(anime: featured[index]),
                ),
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.md,
                  child: Row(
                    children: <Widget>[
                      for (int i = 0; i < featured.length; i++)
                        AnimatedContainer(
                          duration: AppDurations.normal,
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _page ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppColors.accent
                                : AppColors.textPrimary.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeaturedSlide extends StatelessWidget {
  const _FeaturedSlide({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    final String? image = anime.bannerImage ?? anime.coverImage;
    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          NexusImage(url: image, alignment: Alignment.topCenter),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppDecorations.backdropScrim),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'FEATURED',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    anime.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    if (anime.averageScore != null) ...<Widget>[
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        Formatters.score(anime.averageScore),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        <String>[
                          if (anime.seasonYear != null) '${anime.seasonYear}',
                          if (anime.genres.isNotEmpty)
                            anime.genres.take(3).join(' · '),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    PrimaryButton(
                      label: 'Watch Now',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => context.push('/anime/${anime.id}'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SecondaryButton(
                      label: 'More Info',
                      onPressed: () => context.push('/anime/${anime.id}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WatchProgress>> progress = ref.watch(
      continueWatchingProvider,
    );
    final List<WatchProgress> items = switch (progress) {
      AsyncData<List<WatchProgress>>(:final List<WatchProgress> value) => value,
      _ => const <WatchProgress>[],
    };
    if (items.isEmpty) return const SizedBox.shrink();

    final double cardWidth = context.usesDesktopShell ? 268 : 214;

    return NexusPagePadding(
      top: AppSpacing.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Continue Watching',
            onSeeAll: () => context.go('/history'),
          ),
          ContinueWatchingRail(
            items: items,
            cardWidth: cardWidth,
            onTap: (WatchProgress progress) => _resume(context, progress),
            onRemove: (WatchProgress progress) => ref
                .read(historyRepositoryProvider)
                .deleteEntry(progress.animeId, progress.episodeNumber),
          ),
        ],
      ),
    );
  }

  void _resume(BuildContext context, WatchProgress progress) {
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

class _MediaRailSection extends ConsumerWidget {
  const _MediaRailSection({required this.title, required this.provider});

  final String title;
  final FutureProvider<MediaPage> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MediaPage> value = ref.watch(provider);
    final double posterWidth = context.railPosterWidth;
    final Set<int> savedIds = switch (ref.watch(savedAnimeIdsProvider)) {
      AsyncData<Set<int>>(:final Set<int> value) => value,
      _ => const <int>{},
    };

    return NexusPagePadding(
      top: AppSpacing.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: title,
            onSeeAll: () => context.go(exploreDestination.path),
          ),
          AsyncValueView<MediaPage>(
            value: value,
            onRetry: () => ref.invalidate(provider),
            loading: RailSkeleton(posterWidth: posterWidth),
            builder: (BuildContext context, MediaPage page) {
              if (page.items.isEmpty) {
                return EmptyState(
                  compact: true,
                  title: 'Nothing to show',
                  message: 'No titles were returned for this rail.',
                );
              }
              return AnimeRail(
                items: page.items,
                posterWidth: posterWidth,
                savedIds: savedIds,
                onTap: (Anime anime) => context.push('/anime/${anime.id}'),
                onToggleSaved: (Anime anime) => _toggleSaved(
                  context,
                  ref,
                  anime,
                  savedIds.contains(anime.id),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSaved(
    BuildContext context,
    WidgetRef ref,
    Anime anime,
    bool isSaved,
  ) async {
    try {
      if (isSaved) {
        await ref.read(libraryRepositoryProvider).remove(anime.id);
        if (context.mounted) showNexusMessage(context, 'Removed from library');
      } else {
        await ref.read(libraryRepositoryProvider).save(anime);
        if (context.mounted) {
          showNexusMessage(context, 'Added to Plan to Watch');
        }
      }
    } catch (error) {
      if (context.mounted) showNexusFailure(context, error);
    }
  }
}
