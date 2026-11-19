import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/secure_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/app_providers.dart';
import '../../data/services/provider_lifecycle_service.dart';
import '../../integrations/streaming/manifest/provider_manifest.dart';
import 'widgets/provider_config_form.dart';

/// Edit an installed source's configuration after installation.
///
/// Saved secrets are never sent to this screen: only the fact that they exist.
class ProviderConfigScreen extends ConsumerWidget {
  const ProviderConfigScreen({required this.providerId, super.key});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        : context.go('/sources'),
                    child: const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.xs),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text('Source settings', style: AppTypography.headline),
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
                  AsyncValueView<List<InstalledProvider>>(
                    value: installed,
                    onRetry: () => ref.invalidate(installedProvidersProvider),
                    builder:
                        (
                          BuildContext context,
                          List<InstalledProvider> entries,
                        ) {
                          InstalledProvider? entry;
                          for (final InstalledProvider candidate in entries) {
                            if (candidate.id == providerId) {
                              entry = candidate;
                              break;
                            }
                          }
                          if (entry == null || entry.manifest == null) {
                            return EmptyState(
                              title: 'Source not found',
                              message:
                                  'This source is no longer installed. It may '
                                  'have been removed on another screen.',
                              icon: Icons.extension_off_outlined,
                              action: SecondaryButton(
                                label: 'Back to Sources',
                                dense: true,
                                onPressed: () => context.go('/sources'),
                              ),
                            );
                          }
                          return _ConfigEditor(entry: entry);
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

class _ConfigEditor extends ConsumerStatefulWidget {
  const _ConfigEditor({required this.entry});

  final InstalledProvider entry;

  @override
  ConsumerState<_ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends ConsumerState<_ConfigEditor> {
  ProviderConfigDraft _draft = const ProviderConfigDraft(
    values: <String, String>{},
    secrets: <String, String>{},
    clearSecrets: <String>{},
  );
  Map<String, String> _fieldErrors = const <String, String>{};
  String? _message;
  bool _busy = false;

  ProviderManifest get _manifest => widget.entry.manifest!;

  bool get _sensitive =>
      _manifest.config.any((ManifestConfigField field) => field.type.isSecret);

  @override
  void initState() {
    super.initState();
    if (_sensitive) SecureScreen.setEnabled(true);
  }

  @override
  void dispose() {
    if (_sensitive) SecureScreen.setEnabled(false);
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
      _fieldErrors = const <String, String>{};
    });
    try {
      await ref
          .read(providerLifecycleServiceProvider)
          .updateConfiguration(
            widget.entry.id,
            values: _draft.values,
            secrets: _draft.secrets,
            clearSecrets: _draft.clearSecrets,
          );
      ref.invalidate(installedProvidersProvider);
      ref.invalidate(providerRecordsProvider);
      ref.invalidate(providerStateProvider(widget.entry.id));
      await ref.read(userStreamingProvidersProvider.notifier).refresh();
      if (!mounted) return;
      showNexusMessage(context, 'Configuration saved.');
      context.pop();
    } on ProviderLifecycleFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = error.fieldErrors;
        _message = error.message;
      });
    } on Object {
      if (mounted) {
        setState(() => _message = 'That configuration could not be saved.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final InstalledProvider entry = widget.entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
                  Expanded(
                    child: Text(
                      _manifest.name,
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                  MetaChip(label: 'v${_manifest.version}'),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _manifest.description ?? 'Installed source.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_manifest.id} · ${_manifest.attribution}',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_manifest.config.isEmpty)
          const InlineMessage(message: 'This source declares no configuration.')
        else ...<Widget>[
          ProviderConfigForm(
            manifest: _manifest,
            initialValues: entry.config,
            presentSecrets: entry.presentSecrets,
            errors: _fieldErrors,
            onChanged: (ProviderConfigDraft draft) => _draft = draft,
          ),
          if (_sensitive)
            const InlineMessage(
              tone: InlineTone.info,
              icon: Icons.lock_outline_rounded,
              message:
                  'Credentials are written to the device keystore and never to '
                  'the NEXUS database, logs or diagnostics.',
            ),
        ],
        if (_message != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          InlineMessage(
            tone: InlineTone.error,
            icon: Icons.error_outline_rounded,
            message: _message!,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            PrimaryButton(
              label: 'Save configuration',
              icon: Icons.save_outlined,
              dense: true,
              isLoading: _busy,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(width: AppSpacing.xs),
            SecondaryButton(
              label: 'Cancel',
              dense: true,
              onPressed: _busy
                  ? null
                  : () => context.canPop()
                        ? context.pop()
                        : context.go('/sources'),
            ),
          ],
        ),
      ],
    );
  }
}
