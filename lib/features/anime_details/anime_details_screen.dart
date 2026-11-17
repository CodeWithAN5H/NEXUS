import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/anime_poster.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/episode_tile.dart';
import '../../core/widgets/nexus_image.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/states.dart';
import '../../data/models/anime.dart';
import '../../data/models/library.dart';
import '../../data/providers/app_providers.dart';
import '../../data/providers/content_providers.dart';
import '../../integrations/streaming/source_manager.dart';
import '../../integrations/streaming/streaming_provider.dart';
import '../player/playback_request.dart';

/// Metadata, source availability, episodes and related titles for one anime.
class AnimeDetailsScreen extends ConsumerStatefulWidget {
  const AnimeDetailsScreen({required this.animeId, super.key});

  final int animeId;

  @override
  ConsumerState<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends ConsumerState<AnimeDetailsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Anime> details = ref.watch(
      animeDetailsProvider(widget.animeId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AsyncValueView<Anime>(
        value: details,
        onRetry: () {
          ref.read(metadataRepositoryProvider).invalidate('anime:');
          ref.invalidate(animeDetailsProvider(widget.animeId));
        },
        loading: const _DetailsSkeleton(),
        builder: (BuildContext context, Anime anime) => _DetailsBody(
          anime: anime,
          selectedTab: _tab,
          onTabChanged: (int tab) => setState(() => _tab = tab),
        ),
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  const _DetailsBody({
    required this.anime,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final Anime anime;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryEntry? entry = switch (ref.watch(
      libraryEntryProvider(anime.id),
    )) {
      AsyncData<LibraryEntry?>(:final LibraryEntry? value) => value,
      _ => null,
    };
    final AsyncValue<SourceLookup> lookup = ref.watch(
      sourceLookupProvider(anime.id),
    );
    final double backdropHeight = context.usesDesktopShell ? 360 : 300;

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          expandedHeight: backdropHeight,
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.transparent,
          leadingWidth: 56,
          leading: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Center(
              child: NexusIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                background: AppColors.background.withValues(alpha: 0.55),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
              ),
            ),
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Center(
                child: NexusIconButton(
                  icon: entry == null
                      ? Icons.bookmark_border_rounded
                      : Icons.bookmark_rounded,
                  tooltip: entry == null ? 'Add to library' : 'In your library',
                  isActive: entry != null,
                  background: AppColors.background.withValues(alpha: 0.55),
                  onPressed: () => _toggleLibrary(context, ref, anime, entry),
                ),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                NexusImage(
                  url: anime.bannerImage ?? anime.coverImage,
                  alignment: Alignment.topCenter,
                  placeholderColor: parseHexColor(anime.coverColor),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppDecorations.backdropScrim,
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
                _HeaderBlock(anime: anime),
                const SizedBox(height: AppSpacing.md),
                _Actions(anime: anime, entry: entry, lookup: lookup),
                const SizedBox(height: AppSpacing.lg),
                _Synopsis(text: Formatters.plainText(anime.description)),
                const SizedBox(height: AppSpacing.lg),
                _TabBar(selected: selectedTab, onChanged: onTabChanged),
                const SizedBox(height: AppSpacing.md),
                switch (selectedTab) {
                  0 => _EpisodesTab(anime: anime, entry: entry),
                  1 => _InfoTab(anime: anime),
                  _ => _RelatedTab(relations: anime.relations),
                },
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleLibrary(
    BuildContext context,
    WidgetRef ref,
    Anime anime,
    LibraryEntry? entry,
  ) async {
    final repo = ref.read(libraryRepositoryProvider);
    try {
      if (entry == null) {
        await repo.save(anime, status: LibraryStatus.planToWatch);
        if (context.mounted) {
          showNexusMessage(context, 'Added to Plan to Watch');
        }
      } else {
        await repo.remove(anime.id);
        if (context.mounted) showNexusMessage(context, 'Removed from library');
      }
    } catch (error) {
      if (context.mounted) showNexusFailure(context, error);
    }
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: AppRadius.posterRadius,
          child: SizedBox(
            width: 104,
            height: 156,
            child: NexusImage(
              url: anime.coverImage,
              placeholderColor: parseHexColor(anime.coverColor),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                anime.displayTitle,
                style: AppTypography.headline,
                maxLines: 3,
              ),
              if (anime.alternativeTitles.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  anime.alternativeTitles.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  if (anime.averageScore != null)
                    MetaChip(
                      icon: Icons.star_rounded,
                      label: Formatters.score(anime.averageScore),
                      color: AppColors.accent,
                      background: AppColors.accent.withValues(alpha: 0.12),
                    ),
                  if (anime.format != null) MetaChip(label: anime.format!),
                  if (anime.seasonYear != null)
                    MetaChip(label: '$anime.seasonYear'),
                  if (anime.releaseLabel != null)
                    MetaChip(
                      label: anime.releaseLabel!,
                      color: anime.status == 'RELEASING'
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  if (anime.popularity != null)
                    MetaChip(
                      icon: Icons.trending_up_rounded,
                      label: Formatters.compactCount(anime.popularity),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final String genre in anime.genres.take(4))
                    GenreChip(label: genre, dense: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.anime,
    required this.entry,
    required this.lookup,
  });

  final Anime anime;
  final LibraryEntry? entry;
  final AsyncValue<SourceLookup> lookup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SourceLookup? result = switch (lookup) {
      AsyncData<SourceLookup>(:final SourceLookup value) => value,
      _ => null,
    };
    final bool resolving = lookup.isLoading;
    final bool hasSource = result?.hasSource ?? false;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        PrimaryButton(
          label: hasSource ? 'Watch Now' : 'Watch',
          icon: Icons.play_arrow_rounded,
          isLoading: resolving,
          onPressed: hasSource && result?.resolution != null
              ? () => _openPlayer(context, ref, result!.resolution!)
              : null,
        ),
        SecondaryButton(
          label: entry == null ? 'Add to Library' : 'In Library',
          icon: entry == null ? Icons.add_rounded : Icons.check_rounded,
          onPressed: () => _pickStatus(context, ref),
        ),
        if (!resolving && !hasSource)
          SecondaryButton(
            label: 'Sources',
            icon: Icons.tune_rounded,
            onPressed: () => context.push('/sources'),
          ),
        if (anime.siteUrl != null)
          NexusIconButton(
            icon: Icons.open_in_new_rounded,
            tooltip: 'Open on AniList',
            onPressed: () => launchUrl(
              Uri.parse(anime.siteUrl!),
              mode: LaunchMode.externalApplication,
            ),
          ),
      ],
    );
  }

  Future<void> _pickStatus(BuildContext context, WidgetRef ref) async {
    final ({LibraryStatus? status, bool remove})? selected =
        await showModalBottomSheet<({LibraryStatus? status, bool remove})>(
          context: context,
          backgroundColor: AppColors.surfaceElevated,
          builder: (BuildContext context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text('Library status', style: AppTypography.sectionTitle),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final LibraryStatus status in LibraryStatus.values)
                  ListTile(
                    title: Text(
                      status.label,
                      style: AppTypography.bodyStrong.copyWith(
                        color: entry?.status == status
                            ? AppColors.accent
                            : AppColors.textPrimary,
                      ),
                    ),
                    trailing: entry?.status == status
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.accent,
                          )
                        : null,
                    onTap: () =>
                        Navigator.of(context)
                            .pop((status: status, remove: false)),
                  ),
                if (entry != null)
                  ListTile(
                    title: Text(
                      'Remove from library',
                      style: AppTypography.bodyStrong.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    onTap: () =>
                        Navigator.of(context).pop((status: null, remove: true)),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );

    if (selected == null || !context.mounted) return;
    final repo = ref.read(libraryRepositoryProvider);
    final LibraryStatus? target = selected.status;
    try {
      if (selected.remove) {
        await repo.remove(anime.id);
        if (context.mounted) showNexusMessage(context, 'Removed from library');
      } else if (target == null) {
        return;
      } else if (entry == null) {
        await repo.save(anime, status: target);
        if (context.mounted) {
          showNexusMessage(context, 'Saved as ${target.label}');
        }
      } else {
        await repo.updateStatus(anime.id, target);
        if (context.mounted) {
          showNexusMessage(context, 'Moved to ${target.label}');
        }
      }
    } catch (error) {
      if (context.mounted) showNexusFailure(context, error);
    }
  }

  Future<void> _openPlayer(
    BuildContext context,
    WidgetRef ref,
    SourceResolution resolution,
  ) async {
    final List<ProviderEpisode> episodes = await ref
        .read(sourceManagerProvider)
        .episodesFor(resolution);
    if (!context.mounted) return;
    if (episodes.isEmpty) {
      showNexusMessage(
        context,
        '${resolution.provider.name} returned no episodes for this title.',
        isError: true,
      );
      return;
    }

    final int libraryProgress = entry?.watchedEpisodes ?? 0;
    final int target = (libraryProgress + 1).clamp(1, episodes.length);
    final ProviderEpisode firstEpisode = episodes.firstWhere(
      (ProviderEpisode episode) => episode.number == target,
      orElse: () => episodes.first,
    );
    final bool isSample =
        resolution.provider.status.availability == ProviderAvailability.limited;

    await context.push(
      '/watch',
      extra: PlaybackRequest(
        animeId: anime.id,
        animeTitle: anime.displayTitle,
        providerId: resolution.provider.id,
        seriesId: resolution.series.seriesId,
        episodeNumber: firstEpisode.number,
        episodeTitle: firstEpisode.title,
        coverImage: anime.coverImage,
        bannerImage: anime.bannerImage,
        totalEpisodes: anime.episodes ?? episodes.length,
        isSample: isSample,
      ),
    );
  }
}

class _Synopsis extends StatefulWidget {
  const _Synopsis({required this.text});

  final String text;

  @override
  State<_Synopsis> createState() => _SynopsisState();
}

class _SynopsisState extends State<_Synopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return Text(
        'No synopsis is available for this title.',
        style: AppTypography.body,
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.text,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: AppTypography.body,
          ),
          const SizedBox(height: 4),
          Text(
            _expanded ? 'Show less' : 'Read more',
            style: AppTypography.caption.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  static const List<String> _labels = <String>[
    'Episodes',
    'Details',
    'Related',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < _labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _labels[i],
                    style: AppTypography.bodyStrong.copyWith(
                      color: selected == i
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight: selected == i
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: AppDurations.fast,
                    height: 2,
                    width: selected == i ? 26 : 0,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EpisodesTab extends ConsumerWidget {
  const _EpisodesTab({required this.anime, required this.entry});

  final Anime anime;
  final LibraryEntry? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SourceLookup> lookup = ref.watch(
      sourceLookupProvider(anime.id),
    );
    final Map<int, WatchProgress> progress = switch (ref.watch(
      episodeProgressProvider(anime.id),
    )) {
      AsyncData<Map<int, WatchProgress>>(
        :final Map<int, WatchProgress> value,
      ) =>
        value,
      _ => const <int, WatchProgress>{},
    };

    return AsyncValueView<SourceLookup>(
      value: lookup,
      compact: true,
      onRetry: () => ref.invalidate(sourceLookupProvider(anime.id)),
      loading: const LoadingSkeleton(height: 120),
      builder: (BuildContext context, SourceLookup result) {
        final SourceResolution? resolution = result.resolution;
        if (resolution == null) {
          return EmptyState(
            compact: true,
            icon: Icons.play_disabled_rounded,
            title: 'No source available',
            message:
                'None of your enabled sources has this title. NEXUS ships with '
                'no anime streaming source — you can verify playback with the '
                'built-in test library, or register an authorised provider.',
            action: SecondaryButton(
              label: 'Manage sources',
              icon: Icons.tune_rounded,
              onPressed: () => context.push('/sources'),
            ),
          );
        }
        return FutureBuilder<List<ProviderEpisode>>(
          future: ref.read(sourceManagerProvider).episodesFor(resolution),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<ProviderEpisode>> snapshot,
              ) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingSkeleton(height: 120);
                }
                final List<ProviderEpisode> episodes =
                    snapshot.data ?? const <ProviderEpisode>[];
                if (episodes.isEmpty) {
                  return EmptyState(
                    compact: true,
                    icon: Icons.list_alt_rounded,
                    title: 'No episodes listed',
                    message:
                        '${resolution.provider.name} matched this title but '
                        'returned no episodes.',
                  );
                }
                return Column(
                  children: <Widget>[
                    for (final ProviderEpisode episode in episodes)
                      EpisodeTile(
                        number: episode.number,
                        title: episode.title,
                        duration: episode.duration,
                        thumbnail: episode.thumbnail,
                        progress: progress[episode.number]?.fraction,
                        watched:
                            (progress[episode.number]?.fraction ?? 0) >= 0.9 ||
                            (entry?.watchedEpisodes ?? 0) >= episode.number,
                        onTap: () => context.push(
                          '/watch',
                          extra: PlaybackRequest(
                            animeId: anime.id,
                            animeTitle: anime.displayTitle,
                            providerId: resolution.provider.id,
                            seriesId: resolution.series.seriesId,
                            episodeNumber: episode.number,
                            episodeTitle: episode.title,
                            coverImage: anime.coverImage,
                            bannerImage: anime.bannerImage,
                            totalEpisodes: anime.episodes ?? episodes.length,
                            isSample:
                                resolution.provider.status.availability ==
                                ProviderAvailability.limited,
                          ),
                        ),
                      ),
                  ],
                );
              },
        );
      },
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> rows = <(String, String)>[
      ('Format', anime.format ?? '—'),
      ('Episodes', anime.episodes?.toString() ?? '—'),
      ('Episode length', Formatters.episodeLength(anime.duration)),
      ('Status', anime.statusLabel ?? '—'),
      ('Season', Formatters.season(anime.season, anime.seasonYear)),
      ('Studio', anime.studios.isEmpty ? '—' : anime.studios.join(', ')),
      ('Popularity', Formatters.compactCount(anime.popularity)),
      ('Favourites', Formatters.compactCount(anime.favourites)),
      ('Genres', anime.genres.isEmpty ? '—' : anime.genres.join(', ')),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 120,
                    child: Text(rows[i].$1, style: AppTypography.caption),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      style: AppTypography.bodyStrong.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RelatedTab extends StatelessWidget {
  const _RelatedTab({required this.relations});

  final List<AnimeRelation> relations;

  @override
  Widget build(BuildContext context) {
    if (relations.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: Icons.hub_outlined,
        title: 'No related titles',
        message: 'AniList has no relations recorded for this title.',
      );
    }
    final double width = context.railPosterWidth;
    return AnimeRail(
      items: <Anime>[
        for (final AnimeRelation relation in relations)
          Anime(
            id: relation.id,
            title: relation.title,
            coverImage: relation.coverImage,
            format: relation.format,
            genres: <String>[relation.relationLabel],
          ),
      ],
      posterWidth: width,
      onTap: (Anime anime) => context.push('/anime/${anime.id}'),
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          const LoadingSkeleton(height: 300, borderRadius: BorderRadius.zero),
          Padding(
            padding: EdgeInsets.all(context.pageGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                LoadingSkeleton(width: 240, height: 24),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: 160, height: 14),
                SizedBox(height: AppSpacing.lg),
                LoadingSkeleton(height: 64),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
