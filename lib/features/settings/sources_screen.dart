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
import '../../data/services/provider_lifecycle_service.dart';
import '../../integrations/providers/provider_failure.dart';
import '../../integrations/providers/provider_state.dart';
import '../../integrations/streaming/sample_provider.dart';
import '../../integrations/streaming/streaming_provider.dart';
import '../player/playback_request.dart';

/// Source management: install, configure, enable, test and remove providers.
class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<StreamingProvider> builtIns = <StreamingProvider>[
      for (final StreamingProvider provider
          in ref.watch(streamingProviderRegistryProvider).all)
        if (provider.origin == ProviderOrigin.builtIn) provider,
    ];
    final AsyncValue<List<InstalledProvider>> installed = ref.watch(
      installedProvidersProvider,
    );

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
                    message:
                        'NEXUS ships with a built-in test source only. Add a '
                        'declarative provider manifest you are authorised to '
                        'use; it cannot run code or read files.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Add source',
                    icon: Icons.add_rounded,
                    dense: true,
                    onPressed: () => context.push('/sources/import'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Built-in', style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.xs),
                  for (final StreamingProvider provider in builtIns)
                    _BuiltInCard(provider: provider),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: <Widget>[
                      Text(
                        'Installed sources',
                        style: AppTypography.sectionTitle,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      if (installed.value != null)
                        MetaChip(label: '${installed.value!.length}'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AsyncValueView<List<InstalledProvider>>(
                    value: installed,
                    onRetry: () => ref.invalidate(installedProvidersProvider),
                    builder:
                        (
                          BuildContext context,
                          List<InstalledProvider> entries,
                        ) {
                          if (entries.isEmpty) {
                            return const InlineMessage(
                              message:
                                  'No user-added sources yet. Installed '
                                  'manifests appear here with their '
                                  'configuration and status.',
                            );
                          }
                          return Column(
                            children: <Widget>[
                              for (final InstalledProvider entry in entries)
                                _UserSourceCard(entry: entry),
                            ],
                          );
                        },
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
}

/// Generic playback test: the screen knows nothing about which provider it is
/// talking to beyond the [StreamingProvider] contract.
Future<void> _testPlayback(
  BuildContext context,
  StreamingProvider provider,
) async {
  try {
    final ProviderStatusSnapshot snapshot = await provider.probe();
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
        isSample: snapshot.availability == ProviderAvailability.limited,
      ),
    );
  } on ProviderFailure catch (error) {
    if (context.mounted) {
      showNexusMessage(context, error.message, isError: true);
    }
  } catch (error) {
    if (context.mounted) showNexusFailure(context, error);
  }
}

class _BuiltInCard extends ConsumerWidget {
  const _BuiltInCard({required this.provider});

  final StreamingProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> enabled = ref
        .watch(appSettingsProvider)
        .enabledProviderIds;
    final ProviderState? state = switch (ref.watch(
      providerStateProvider(provider.id),
    )) {
      AsyncData<ProviderState>(:final ProviderState value) => value,
      _ => null,
    };
    final (Color color, String label) = _chip(state);

    return _SourceCard(
      title: provider.name,
      description: provider.description,
      meta: 'v${provider.version} · ${provider.attribution}',
      tag: 'Built-in',
      testOnly: provider is SamplePlaybackProvider,
      chipLabel: label,
      chipColor: color,
      enabled: enabled.contains(provider.id),
      onToggle: (bool _) =>
          ref.read(settingsProvider.notifier).toggleProvider(provider.id),
      capabilities: provider.capabilities,
      message: state?.message,
      messageIsError:
          state?.presentation == ProviderPresentationState.unavailable,
      actions: <Widget>[
        SecondaryButton(
          label: 'Test playback',
          icon: Icons.play_arrow_rounded,
          dense: true,
          onPressed: enabled.contains(provider.id)
              ? () => _testPlayback(context, provider)
              : null,
        ),
      ],
    );
  }

  static (Color, String) _chip(ProviderState? state) {
    if (state == null) return (AppColors.textMuted, 'Checking…');
    return switch (state.presentation) {
      ProviderPresentationState.usable =>
        state.observedAvailability == ProviderAvailability.limited
            ? (AppColors.warning, 'Test content only')
            : (AppColors.success, 'Ready'),
      ProviderPresentationState.needsSetup => (
        AppColors.warning,
        'Setup required',
      ),
      ProviderPresentationState.rejectedConfiguration => (
        AppColors.error,
        'Sign-in rejected',
      ),
      ProviderPresentationState.incompatible => (
        AppColors.textMuted,
        'Incompatible',
      ),
      ProviderPresentationState.unavailable => (
        AppColors.error,
        'Temporarily unavailable',
      ),
      ProviderPresentationState.disabled => (AppColors.textMuted, 'Off'),
    };
  }
}

class _UserSourceCard extends ConsumerWidget {
  const _UserSourceCard({required this.entry});

  final InstalledProvider entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Without a readable manifest there is no descriptor to derive a state from,
    // so the card reports the failure directly instead of pretending to check.
    final ProviderState? state = entry.isValid
        ? switch (ref.watch(providerStateProvider(entry.id))) {
            AsyncData<ProviderState>(:final ProviderState value) => value,
            _ => null,
          }
        : null;

    final bool usable = state?.presentation == ProviderPresentationState.usable;
    final bool hasConfig = (entry.manifest?.config.isNotEmpty) ?? false;
    final (Color color, String label) = entry.isValid
        ? _chip(state)
        : (AppColors.error, 'Invalid source');

    final List<String> diagnostics = <String>[
      if (entry.failure != null) entry.failure!.message,
      for (final error in entry.errors.take(6))
        error.path.isEmpty ? error.message : '${error.path}: ${error.message}',
    ];

    return _SourceCard(
      title: entry.manifest?.name ?? entry.id,
      description: entry.manifest?.description ?? 'Installed source.',
      meta: entry.manifest == null
          ? entry.id
          : 'v${entry.manifest!.version} · ${entry.manifest!.attribution}',
      tag: 'User-added',
      chipLabel: label,
      chipColor: color,
      enabled: entry.record.enabled,
      onToggle: (bool value) =>
          _setEnabled(context, ref, entry: entry, enabled: value),
      capabilities:
          entry.manifest?.providerCapabilities ?? const <ProviderCapability>{},
      message: state?.message ?? entry.failure?.message,
      messageIsError:
          !entry.isValid ||
          state?.presentation == ProviderPresentationState.unavailable ||
          state?.presentation == ProviderPresentationState.incompatible,
      diagnostics: diagnostics,
      actions: <Widget>[
        if (hasConfig)
          SecondaryButton(
            label: 'Configure',
            icon: Icons.tune_rounded,
            dense: true,
            onPressed: () => context.push(
              '/sources/${Uri.encodeComponent(entry.id)}/configure',
            ),
          ),
        if (usable)
          SecondaryButton(
            label: 'Test playback',
            icon: Icons.play_arrow_rounded,
            dense: true,
            onPressed: () {
              final StreamingProvider? provider = ref
                  .read(streamingProviderRegistryProvider)
                  .registrationFor(entry.id)
                  ?.provider;
              if (provider == null) {
                showNexusMessage(
                  context,
                  'This source is not registered right now.',
                  isError: true,
                );
                return;
              }
              _testPlayback(context, provider);
            },
          ),
        SecondaryButton(
          label: 'Remove',
          icon: Icons.delete_outline_rounded,
          dense: true,
          onPressed: () => _confirmRemove(context, ref, entry),
        ),
      ],
    );
  }

  static (Color, String) _chip(ProviderState? state) {
    if (state == null) return (AppColors.textMuted, 'Checking…');
    return switch (state.presentation) {
      ProviderPresentationState.usable => (AppColors.success, 'Ready'),
      ProviderPresentationState.needsSetup => (
        AppColors.warning,
        'Setup required',
      ),
      ProviderPresentationState.rejectedConfiguration => (
        AppColors.error,
        'Sign-in rejected',
      ),
      ProviderPresentationState.incompatible => (
        AppColors.textMuted,
        'Incompatible',
      ),
      ProviderPresentationState.unavailable => (
        AppColors.error,
        'Temporarily unavailable',
      ),
      ProviderPresentationState.disabled => (AppColors.textMuted, 'Off'),
    };
  }
}

Future<void> _setEnabled(
  BuildContext context,
  WidgetRef ref, {
  required InstalledProvider entry,
  required bool enabled,
}) async {
  try {
    await ref
        .read(providerLifecycleServiceProvider)
        .setEnabled(entry.id, enabled);
    ref.invalidate(installedProvidersProvider);
    ref.invalidate(providerRecordsProvider);
    ref.invalidate(providerStateProvider(entry.id));
    await ref.read(userStreamingProvidersProvider.notifier).refresh();
  } on ProviderLifecycleFailure catch (error) {
    if (context.mounted) {
      showNexusMessage(context, error.message, isError: true);
    }
  } on Object {
    if (context.mounted) {
      showNexusMessage(
        context,
        'That change could not be saved.',
        isError: true,
      );
    }
  }
}

Future<void> _confirmRemove(
  BuildContext context,
  WidgetRef ref,
  InstalledProvider entry,
) async {
  final String name = entry.manifest?.name ?? entry.id;
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Remove $name?'),
      content: const Text(
        'Its configuration and stored credentials are deleted, and NEXUS stops '
        'contacting it. Your library, history and playback positions are kept.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(providerLifecycleServiceProvider).remove(entry.id);
    ref.invalidate(installedProvidersProvider);
    ref.invalidate(providerRecordsProvider);
    ref.invalidate(providerStateProvider(entry.id));
    await ref.read(userStreamingProvidersProvider.notifier).refresh();
    if (context.mounted) showNexusMessage(context, '$name was removed.');
  } on ProviderLifecycleFailure catch (error) {
    if (context.mounted) {
      showNexusMessage(context, error.message, isError: true);
    }
  } on Object {
    if (context.mounted) {
      showNexusMessage(
        context,
        'That source could not be removed.',
        isError: true,
      );
    }
  }
}

/// One source card. Built-in and user-added providers differ only in the tags
/// and actions handed to it, so the screen keeps one visual language.
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.title,
    required this.description,
    required this.meta,
    required this.tag,
    required this.chipLabel,
    required this.chipColor,
    required this.enabled,
    required this.onToggle,
    required this.capabilities,
    required this.actions,
    this.testOnly = false,
    this.message,
    this.messageIsError = false,
    this.diagnostics = const <String>[],
  });

  final String title;
  final String description;
  final String meta;
  final String tag;
  final String chipLabel;
  final Color chipColor;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final Set<ProviderCapability> capabilities;
  final List<Widget> actions;
  final bool testOnly;
  final String? message;
  final bool messageIsError;
  final List<String> diagnostics;

  @override
  Widget build(BuildContext context) {
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
              Expanded(child: Text(title, style: AppTypography.sectionTitle)),
              MetaChip(
                label: chipLabel,
                color: chipColor,
                background: chipColor.withValues(alpha: 0.12),
              ),
              const SizedBox(width: AppSpacing.xs),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: AppColors.textPrimary,
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.surfaceSecondary,
                inactiveThumbColor: AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(description, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              MetaChip(label: tag),
              if (testOnly)
                MetaChip(
                  label: 'Test only',
                  color: AppColors.warning,
                  background: AppColors.warning.withValues(alpha: 0.12),
                ),
              for (final ProviderCapability capability in capabilities)
                MetaChip(label: capability.label),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message ?? meta,
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              color: messageIsError ? AppColors.error : null,
            ),
          ),
          if (diagnostics.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            for (final String line in diagnostics)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  line,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.error,
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: actions,
          ),
        ],
      ),
    );
  }
}
