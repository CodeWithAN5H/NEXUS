import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/ids.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/app_providers.dart';
import '../../integrations/streaming/streaming_provider.dart';
import '../player/playback_request.dart';

/// Source management: enable, inspect and test content providers.
class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<StreamingProvider> providers = ref.watch(
      configuredProvidersProvider,
    );
    final Set<String> enabled = ref
        .watch(appSettingsProvider)
        .enabledProviderIds;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: NexusPagePadding(
              top: AppSpacing.md,
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/settings'),
                    child: const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.xs),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text('Sources', style: AppTypography.headline),
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
                  const InlineMessage(
                    tone: InlineTone.info,
                    icon: Icons.info_outline_rounded,
                    message:
                        'NEXUS ships without an anime streaming source. The '
                        'provider interface is complete; register an authorised '
                        'provider to add real content.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final StreamingProvider provider in providers)
                    _ProviderCard(
                      provider: provider,
                      enabled: enabled.contains(provider.id),
                      onToggle: () => ref
                          .read(settingsProvider.notifier)
                          .toggleProvider(provider.id),
                      onTest: () => _testPlayback(context, ref, provider),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Generic playback test: the screen knows nothing about which provider it is
  /// talking to beyond the [StreamingProvider] contract.
  Future<void> _testPlayback(
    BuildContext context,
    WidgetRef ref,
    StreamingProvider provider,
  ) async {
    try {
      final List<ProviderSeries> results = await provider.search('');
      if (results.isEmpty) {
        if (context.mounted) {
          showNexusMessage(
            context,
            'This provider has no catalogue to test.',
            isError: true,
          );
        }
        return;
      }
      final ProviderSeries series = results.first;
      final List<ProviderEpisode> episodes = await provider.episodes(series);
      if (episodes.isEmpty) {
        if (context.mounted) {
          showNexusMessage(
            context,
            'This provider returned no episodes.',
            isError: true,
          );
        }
        return;
      }
      if (!context.mounted) {
        return;
      }
      final ProviderEpisode episode = episodes.first;
      await context.push(
        '/watch',
        extra: PlaybackRequest(
          animeId: localIdFor(
            'provider-series',
            '${provider.id}:${series.seriesId}',
          ),
          animeTitle: series.title,
          providerId: provider.id,
          seriesId: series.seriesId,
          episodeNumber: episode.number,
          episodeTitle: episode.title,
          coverImage: series.coverImage,
          totalEpisodes: episodes.length,
          isSample:
              provider.status.availability == ProviderAvailability.limited,
        ),
      );
    } on ProviderException catch (error) {
      if (context.mounted) {
        showNexusMessage(context, error.message, isError: true);
      }
    } catch (error) {
      if (context.mounted) showNexusFailure(context, error);
    }
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.enabled,
    required this.onToggle,
    required this.onTest,
  });

  final StreamingProvider provider;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final ProviderStatus status = provider.status;
    final (Color color, String label) = switch (status.availability) {
      ProviderAvailability.ready => (AppColors.success, 'Ready'),
      ProviderAvailability.limited => (AppColors.warning, 'Test content only'),
      ProviderAvailability.needsConfiguration => (
        AppColors.warning,
        'Setup required',
      ),
      ProviderAvailability.unavailable => (AppColors.error, 'Unavailable'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
              Expanded(
                child: Text(provider.name, style: AppTypography.sectionTitle),
              ),
              MetaChip(
                label: label,
                color: color,
                background: color.withValues(alpha: 0.12),
              ),
              const SizedBox(width: AppSpacing.xs),
              Switch(
                value: enabled,
                onChanged: (_) => onToggle(),
                activeThumbColor: AppColors.textPrimary,
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.surfaceSecondary,
                inactiveThumbColor: AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(provider.description, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final ProviderCapability capability in provider.capabilities)
                MetaChip(label: capability.label),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${status.message} · ${provider.attribution}',
            style: AppTypography.caption.copyWith(fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              SecondaryButton(
                label: 'Test playback',
                icon: Icons.play_arrow_rounded,
                dense: true,
                onPressed: enabled ? onTest : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
