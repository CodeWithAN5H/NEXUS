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
import '../../data/services/provider_diagnostics.dart';
import '../../data/services/provider_lifecycle_service.dart';
import '../../integrations/providers/provider_failure.dart';
import '../../integrations/providers/provider_state.dart';
import '../../integrations/streaming/sample_provider.dart';
import '../../integrations/streaming/streaming_provider.dart';
import '../player/playback_request.dart';
import 'provider_source_actions.dart';
import 'widgets/provider_diagnostics_sheet.dart';

/// Source management: install, configure, order, test, diagnose and remove.
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
    final List<InstalledProvider> entries =
        installed.value ?? const <InstalledProvider>[];

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
                      if (installed.hasValue)
                        MetaChip(label: '${entries.length}'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AsyncValueView<List<InstalledProvider>>(
                    value: installed,
                    onRetry: () => ref.invalidate(installedProvidersProvider),
                    builder:
                        (BuildContext context, List<InstalledProvider> loaded) {
                          if (loaded.isEmpty) {
                            return const InlineMessage(
                              message:
                                  'No user-added sources yet. Installed '
                                  'manifests appear here with their state, '
                                  'configuration, priority and diagnostics. '
                                  'NEXUS never adds one for you.',
                            );
                          }
                          return Column(
                            children: <Widget>[
                              for (
                                int index = 0;
                                index < loaded.length;
                                index++
                              )
                                _UserSourceCard(
                                  entry: loaded[index],
                                  position: index + 1,
                                  canMoveUp: index > 0,
                                  canMoveDown: index < loaded.length - 1,
                                  showPriority: loaded.length > 1,
                                ),
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
    final bool enabled = ref
        .watch(appSettingsProvider)
        .enabledProviderIds
        .contains(provider.id);
    final ProviderState? state = switch (ref.watch(
      providerStateProvider(provider.id),
    )) {
      AsyncData<ProviderState>(:final ProviderState value) => value,
      _ => null,
    };
    final (Color color, String label) = _chip(state);
    final ProviderActionSet actions = state == null
        ? ProviderSourceActions.forLoading(
            isUserAdded: false,
            hasConfiguration: provider.configuration.isNotEmpty,
          )
        : ProviderSourceActions.forState(
            presentation: state.presentation,
            isUserAdded: false,
            hasConfiguration: provider.configuration.isNotEmpty,
            canTestPlayback:
                state.presentation == ProviderPresentationState.usable &&
                provider.capabilities.contains(ProviderCapability.search),
          );

    return _SourceCard(
      title: provider.name,
      description: provider.description,
      meta: 'v${provider.version} · ${provider.attribution}',
      tag: 'Built-in',
      testOnly: provider is SamplePlaybackProvider,
      chipLabel: label,
      chipColor: color,
      enabled: enabled,
      onToggle: (bool value) =>
          ref.read(settingsProvider.notifier).toggleProvider(provider.id),
      capabilities: provider.capabilities,
      message: state?.message,
      messageIsError:
          state?.presentation == ProviderPresentationState.unavailable,
      actions: _SourceActionButtons(
        actions: actions,
        onConfigure: () => showNexusMessage(
          context,
          'This built-in source has no configurable fields.',
        ),
        onEnable: () =>
            ref.read(settingsProvider.notifier).toggleProvider(provider.id),
        onRetry: () => ref.invalidate(providerStateProvider(provider.id)),
        onTestPlayback: () => _testPlayback(context, provider),
        onDetails: () =>
            showProviderDiagnosticsSheet(context, providerId: provider.id),
        onRemove: null,
      ),
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
  const _UserSourceCard({
    required this.entry,
    required this.position,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.showPriority,
  });

  final InstalledProvider entry;
  final int position;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool showPriority;

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

    final bool hasConfig = (entry.manifest?.config.isNotEmpty) ?? false;
    final bool testable =
        (entry.manifest?.providerCapabilities.contains(
          ProviderCapability.search,
        )) ??
        false;
    final bool usable = state?.presentation == ProviderPresentationState.usable;
    final (Color color, String label) = entry.isValid
        ? _chip(state)
        : (AppColors.error, 'Invalid source');
    final ProviderActionSet actions = state == null
        ? ProviderSourceActions.forLoading(
            isUserAdded: true,
            hasConfiguration: hasConfig,
          )
        : ProviderSourceActions.forState(
            presentation: state.presentation,
            isUserAdded: true,
            hasConfiguration: hasConfig,
            canTestPlayback: usable && testable,
          );

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
      diagnostics: <String>[
        if (!entry.isValid && entry.failure != null) entry.failure!.message,
        for (final error in entry.errors.take(5))
          error.path.isEmpty
              ? error.message
              : '${error.path}: ${error.message}',
      ],
      priority: showPriority
          ? _PriorityControls(
              position: position,
              canMoveUp: canMoveUp,
              canMoveDown: canMoveDown,
              onMoveUp: () => _move(context, ref, entry: entry, delta: -1),
              onMoveDown: () => _move(context, ref, entry: entry, delta: 1),
            )
          : null,
      actions: _SourceActionButtons(
        actions: actions,
        onConfigure: hasConfig
            ? () => context.push(
                '/sources/${Uri.encodeComponent(entry.id)}/configure',
              )
            : null,
        onEnable: () => _setEnabled(context, ref, entry: entry, enabled: true),
        onRetry: () async {
          ref.invalidate(providerStateProvider(entry.id));
          await ref.read(userStreamingProvidersProvider.notifier).refresh();
        },
        onTestPlayback: () {
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
        onDetails: () =>
            showProviderDiagnosticsSheet(context, providerId: entry.id),
        onRemove: () => _confirmRemove(context, ref, entry),
      ),
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

class _PriorityControls extends StatelessWidget {
  const _PriorityControls({
    required this.position,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int position;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MetaChip(label: 'Priority $position'),
        const SizedBox(width: AppSpacing.xs),
        NexusIconButton(
          icon: Icons.arrow_upward_rounded,
          tooltip: 'Move up',
          size: 28,
          iconSize: 16,
          onPressed: canMoveUp ? onMoveUp : null,
        ),
        const SizedBox(width: AppSpacing.xs),
        NexusIconButton(
          icon: Icons.arrow_downward_rounded,
          tooltip: 'Move down',
          size: 28,
          iconSize: 16,
          onPressed: canMoveDown ? onMoveDown : null,
        ),
      ],
    );
  }
}

/// Renders exactly the actions the current state allows.
class _SourceActionButtons extends StatelessWidget {
  const _SourceActionButtons({
    required this.actions,
    required this.onConfigure,
    required this.onEnable,
    required this.onRetry,
    required this.onTestPlayback,
    required this.onDetails,
    required this.onRemove,
  });

  final ProviderActionSet actions;
  final VoidCallback? onConfigure;
  final VoidCallback? onEnable;
  final VoidCallback? onRetry;
  final VoidCallback? onTestPlayback;
  final VoidCallback onDetails;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final List<Widget> buttons = <Widget>[];
    for (final ProviderAction action in actions.all) {
      switch (action) {
        case ProviderAction.configure:
          if (onConfigure == null) continue;
          buttons.add(
            SecondaryButton(
              label: 'Configure',
              icon: Icons.tune_rounded,
              dense: true,
              onPressed: onConfigure,
            ),
          );
        case ProviderAction.enable:
          if (onEnable == null) continue;
          buttons.add(
            SecondaryButton(
              label: 'Enable',
              icon: Icons.toggle_on_outlined,
              dense: true,
              onPressed: onEnable,
            ),
          );
        case ProviderAction.retry:
          if (onRetry == null) continue;
          buttons.add(
            SecondaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              dense: true,
              onPressed: onRetry,
            ),
          );
        case ProviderAction.testPlayback:
          if (onTestPlayback == null) continue;
          buttons.add(
            SecondaryButton(
              label: 'Test playback',
              icon: Icons.play_arrow_rounded,
              dense: true,
              onPressed: onTestPlayback,
            ),
          );
        case ProviderAction.details:
          buttons.add(
            SecondaryButton(
              label: 'Details',
              icon: Icons.info_outline_rounded,
              dense: true,
              onPressed: onDetails,
            ),
          );
        case ProviderAction.remove:
          if (onRemove == null) continue;
          buttons.add(
            SecondaryButton(
              label: 'Remove',
              icon: Icons.delete_outline_rounded,
              dense: true,
              onPressed: onRemove,
            ),
          );
      }
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: buttons,
    );
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
        .read(providerManagementServiceProvider)
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

Future<void> _move(
  BuildContext context,
  WidgetRef ref, {
  required InstalledProvider entry,
  required int delta,
}) async {
  try {
    await ref
        .read(providerManagementServiceProvider)
        .moveUserProvider(entry.id, delta: delta);
    ref.invalidate(installedProvidersProvider);
    ref.invalidate(providerRecordsProvider);
    await ref.read(userStreamingProvidersProvider.notifier).refresh();
  } on ProviderLifecycleFailure catch (error) {
    if (context.mounted) {
      showNexusMessage(context, error.message, isError: true);
    }
  } on Object {
    if (context.mounted) {
      showNexusMessage(
        context,
        'That order could not be saved.',
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
        'Its configuration, stored credentials and diagnostic history are '
        'deleted, and NEXUS stops contacting it. Your library, history and '
        'playback positions are kept.',
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
    ref.read(providerDiagnosticsProvider.notifier).forget(entry.id);
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

/// One source card. Built-in and user-added providers differ only in the tags,
/// priority controls and actions handed to it, so the screen keeps one visual
/// language.
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
    this.priority,
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
  final Widget actions;
  final bool testOnly;
  final String? message;
  final bool messageIsError;
  final List<String> diagnostics;
  final Widget? priority;

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
          if (priority != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            priority!,
          ],
          const SizedBox(height: AppSpacing.sm),
          actions,
        ],
      ),
    );
  }
}
