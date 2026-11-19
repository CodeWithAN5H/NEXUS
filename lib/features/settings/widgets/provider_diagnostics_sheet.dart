import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/states.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/services/provider_diagnostics.dart';
import '../../../data/services/provider_lifecycle_service.dart';
import '../../../integrations/providers/provider_descriptor.dart';
import '../../../integrations/providers/provider_registries.dart';
import '../../../integrations/providers/provider_failure.dart';
import '../../../integrations/providers/provider_state.dart';
import '../../../integrations/streaming/streaming_provider.dart';

/// Details and opt-in diagnostics for one source.
///
/// It renders the same three axes the card does, never a credential, and copies
/// only what is already redacted. Nothing is sent anywhere.
Future<void> showProviderDiagnosticsSheet(
  BuildContext context, {
  required String providerId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: ProviderDiagnosticsSheet(providerId: providerId),
    ),
  );
}

class ProviderDiagnosticsSheet extends ConsumerStatefulWidget {
  const ProviderDiagnosticsSheet({required this.providerId, super.key});

  final String providerId;

  @override
  ConsumerState<ProviderDiagnosticsSheet> createState() =>
      _ProviderDiagnosticsSheetState();
}

class _ProviderDiagnosticsSheetState
    extends ConsumerState<ProviderDiagnosticsSheet> {
  bool _checking = false;

  Future<void> _runCheck() async {
    final ProviderDiagnosticsController diagnostics = ref.read(
      providerDiagnosticsProvider.notifier,
    );
    if (!diagnostics.isOptedIn(widget.providerId)) return;

    setState(() => _checking = true);
    try {
      final ProviderRegistration<StreamingProvider>? registration = ref
          .read(streamingProviderRegistryProvider)
          .registrationFor(widget.providerId);
      if (registration == null) {
        diagnostics.record(
          widget.providerId,
          category: ProviderDiagnosticCategory.configuration,
          message:
              'The source is not registered right now: it is disabled, not '
              'configured, or its manifest is invalid.',
        );
        return;
      }
      try {
        final ProviderStatusSnapshot snapshot = await registration.provider
            .probe()
            .timeout(const Duration(seconds: 10));
        diagnostics.record(
          widget.providerId,
          category: ProviderDiagnosticCategory.availability,
          message: '${snapshot.availability.name}: ${snapshot.message}',
        );
      } on Object catch (error) {
        diagnostics.record(
          widget.providerId,
          category: providerFailureCategory(error),
          message: error is ProviderFailure
              ? error.message
              : 'The check did not complete.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _copy(
    ProviderDescriptor descriptor,
    ProviderState? state,
  ) async {
    final List<ProviderDiagnosticEntry> entries = ref
        .read(providerDiagnosticsProvider)
        .forProvider(widget.providerId);
    final String text = ProviderDiagnosticsRedaction.exportText(
      providerId: descriptor.id,
      name: descriptor.name,
      version: descriptor.version,
      origin: descriptor.origin == ProviderOrigin.userAdded
          ? 'user-added'
          : 'built-in',
      stateSummary: state == null
          ? 'Unknown'
          : '${state.presentation.label} · compatibility '
                '${state.compatibility.name} · configuration '
                '${state.configuration.name} · availability '
                '${state.availability.availability.name}',
      entries: entries,
      generatedAt: DateTime.now(),
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Copy diagnostics?'),
        content: const Text(
          'Only the timestamps, categories and redacted messages shown here are '
          'copied. Credentials, request headers and response bodies are not '
          'included. Nothing is uploaded.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Copy'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showNexusMessage(context, 'Diagnostics copied to the clipboard.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<InstalledProvider> installed =
        ref.watch(installedProvidersProvider).value ??
        const <InstalledProvider>[];
    InstalledProvider? entry;
    for (final InstalledProvider candidate in installed) {
      if (candidate.id == widget.providerId) {
        entry = candidate;
        break;
      }
    }
    final ProviderRegistration<StreamingProvider>? registration = ref
        .watch(streamingProviderRegistryProvider)
        .registrationFor(widget.providerId);
    final ProviderDescriptor? descriptor =
        entry?.descriptor ?? registration?.provider;
    final ProviderState? state = switch (ref.watch(
      providerStateProvider(widget.providerId),
    )) {
      AsyncData<ProviderState>(:final ProviderState value) => value,
      _ => null,
    };
    final ProviderDiagnosticsState diagnostics = ref.watch(
      providerDiagnosticsProvider,
    );
    final bool optedIn = diagnostics.isOptedIn(widget.providerId);
    final List<ProviderDiagnosticEntry> entries = diagnostics.forProvider(
      widget.providerId,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      descriptor?.name ?? widget.providerId,
                      style: AppTypography.headline,
                    ),
                  ),
                  NexusIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    size: 32,
                    iconSize: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                descriptor == null
                    ? widget.providerId
                    : '${descriptor.id} · v${descriptor.version} · '
                          '${descriptor.origin == ProviderOrigin.userAdded ? 'User-added' : 'Built-in'}',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              if (descriptor != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(descriptor.attribution, style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    MetaChip(
                      label:
                          'Compatibility: ${state?.compatibility.name ?? 'unknown'}',
                    ),
                    MetaChip(
                      label:
                          'Configuration: ${state?.configuration.name ?? 'unknown'}',
                    ),
                    MetaChip(
                      label:
                          'Availability: ${state?.availability.availability.name ?? 'unknown'}',
                    ),
                  ],
                ),
                if (state != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(state.message, style: AppTypography.caption),
                  if (state.availability.observedAt.millisecondsSinceEpoch > 0)
                    Text(
                      'Observed ${state.availability.observedAt.toIso8601String()}',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ],
              if (entry != null && !entry.isValid) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                InlineMessage(
                  tone: InlineTone.error,
                  icon: Icons.error_outline_rounded,
                  message:
                      entry.failure?.message ??
                      'This source\'s manifest is invalid.',
                ),
                for (final error in entry.errors.take(8))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      error.path.isEmpty
                          ? error.message
                          : '${error.path}: ${error.message}',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Diagnostics',
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                  Switch(
                    value: optedIn,
                    onChanged: (bool value) {
                      ref
                          .read(providerDiagnosticsProvider.notifier)
                          .setOptIn(widget.providerId, value);
                      if (value) {
                        ref
                            .read(providerDiagnosticsProvider.notifier)
                            .record(
                              widget.providerId,
                              category: ProviderDiagnosticCategory.lifecycle,
                              message:
                                  'Diagnostics enabled for this source. '
                                  'Nothing is uploaded; history lives only in '
                                  'this app session.',
                            );
                      }
                    },
                    activeThumbColor: AppColors.textPrimary,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.surfaceSecondary,
                    inactiveThumbColor: AppColors.textMuted,
                  ),
                ],
              ),
              Text(
                optedIn
                    ? 'Recording is on for this source only. Entries are '
                          'redacted and kept in memory until you clear them or '
                          'the app closes.'
                    : 'Diagnostics are off. Turn them on to record redacted '
                          'checks for this source.',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  SecondaryButton(
                    label: 'Run check',
                    icon: Icons.refresh_rounded,
                    dense: true,
                    onPressed: optedIn && !_checking ? _runCheck : null,
                  ),
                  SecondaryButton(
                    label: 'Copy diagnostics',
                    icon: Icons.copy_rounded,
                    dense: true,
                    onPressed: optedIn && descriptor != null
                        ? () => _copy(descriptor, state)
                        : null,
                  ),
                  if (entries.isNotEmpty)
                    SecondaryButton(
                      label: 'Clear',
                      icon: Icons.clear_all_rounded,
                      dense: true,
                      onPressed: () => ref
                          .read(providerDiagnosticsProvider.notifier)
                          .clear(widget.providerId),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (!optedIn)
                const InlineMessage(
                  message:
                      'No diagnostics are collected while this is off. The '
                      'status above comes from the current state, not from a '
                      'stored history.',
                )
              else if (entries.isEmpty)
                const InlineMessage(
                  message:
                      'No checks recorded yet. Run a check, or retry the source '
                      'from its card.',
                )
              else
                for (final ProviderDiagnosticEntry entry
                    in entries.reversed) ...<Widget>[
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    padding: const EdgeInsets.all(AppSpacing.sm),
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
                            MetaChip(label: entry.category.label),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                entry.at.toIso8601String(),
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(entry.message, style: AppTypography.caption),
                      ],
                    ),
                  ),
                ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
