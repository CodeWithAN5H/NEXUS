import 'dart:async';
import 'dart:convert';

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
import '../../data/repositories/provider_store.dart';
import '../../data/services/provider_lifecycle_service.dart';
import '../../integrations/providers/provider_descriptor.dart';
import '../../integrations/streaming/manifest/manifest_error.dart';
import '../../integrations/streaming/manifest/provider_manifest.dart';
import 'widgets/provider_config_form.dart';

/// Paste → validate → review → configure → install.
///
/// Everything before Install is a dry run: [ProviderLifecycleService.preview]
/// writes nothing, and leaving this screen without installing leaves the
/// database and keystore untouched.
class ProviderImportScreen extends ConsumerStatefulWidget {
  const ProviderImportScreen({super.key});

  @override
  ConsumerState<ProviderImportScreen> createState() =>
      _ProviderImportScreenState();
}

class _ProviderImportScreenState extends ConsumerState<ProviderImportScreen> {
  final TextEditingController _json = TextEditingController();

  ProviderInstallPreview? _preview;
  ProviderConfigDraft _draft = const ProviderConfigDraft(
    values: <String, String>{},
    secrets: <String, String>{},
    clearSecrets: <String>{},
  );
  Map<String, String> _fieldErrors = const <String, String>{};
  String? _message;
  bool _busy = false;
  bool _sensitive = false;

  @override
  void dispose() {
    _json.dispose();
    if (_sensitive) SecureScreen.setEnabled(false);
    super.dispose();
  }

  Future<void> _review() async {
    final String text = _json.text.trim();
    if (text.isEmpty) {
      setState(() => _message = 'Paste a provider manifest first.');
      return;
    }
    if (utf8.encode(text).length > ProviderStore.maxManifestBytes) {
      setState(
        () => _message =
            'That document is larger than the 512 KiB manifest limit.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
      _fieldErrors = const <String, String>{};
    });
    try {
      final ProviderInstallPreview preview = await ref
          .read(providerLifecycleServiceProvider)
          .preview(text);
      if (!mounted) return;
      final bool sensitive =
          preview.manifest?.config.any(
            (ManifestConfigField field) => field.type.isSecret,
          ) ??
          false;
      if (sensitive != _sensitive) {
        _sensitive = sensitive;
        // Fire and forget: suppressing capture must never block the form, and a
        // platform without the channel would otherwise leave this await hanging.
        unawaited(SecureScreen.setEnabled(sensitive));
      }
      setState(() {
        _preview = preview;
        _draft = const ProviderConfigDraft(
          values: <String, String>{},
          secrets: <String, String>{},
          clearSecrets: <String>{},
        );
      });
    } on Object {
      if (mounted) {
        setState(
          () => _message =
              'That document could not be read as a provider manifest.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install() async {
    final ProviderInstallPreview? preview = _preview;
    if (preview == null) return;
    setState(() {
      _busy = true;
      _message = null;
      _fieldErrors = const <String, String>{};
    });
    try {
      await ref
          .read(providerLifecycleServiceProvider)
          .install(
            preview,
            values: <String, String>{..._draft.values, ..._draft.secrets},
          );
      ref.invalidate(installedProvidersProvider);
      ref.invalidate(providerRecordsProvider);
      ref.invalidate(providerStateProvider(preview.manifest!.id));
      await ref.read(userStreamingProvidersProvider.notifier).refresh();
      if (!mounted) return;
      showNexusMessage(context, '${preview.manifest!.name} was installed.');
      context.pop();
    } on ProviderLifecycleFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = error.fieldErrors;
        _message = error.message;
      });
    } on Object {
      if (mounted) {
        setState(() => _message = 'That source could not be installed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProviderInstallPreview? preview = _preview;
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
                  Text('Add source', style: AppTypography.headline),
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
                        'Paste a declarative provider manifest. NEXUS checks '
                        'every field before anything is saved — a manifest '
                        'cannot run code or reach files. Fetching manifests '
                        'from a URL is planned for a later milestone.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Manifest', style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _json,
                    minLines: 8,
                    maxLines: 16,
                    style: AppTypography.caption.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                    ),
                    onChanged: (_) {
                      // The reviewed text is the installed text; editing after a
                      // review requires reviewing again.
                      if (_preview != null) {
                        setState(() => _preview = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '{\n  "manifest": "nexus.provider",\n  ...\n}',
                      hintStyle: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.cardRadius,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.cardRadius,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      PrimaryButton(
                        label: 'Review manifest',
                        icon: Icons.fact_check_outlined,
                        dense: true,
                        isLoading: _busy,
                        onPressed: _busy ? null : _review,
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
                  if (_message != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    InlineMessage(
                      tone: InlineTone.error,
                      icon: Icons.error_outline_rounded,
                      message: _message!,
                    ),
                  ],
                  if (preview != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    _ReviewCard(preview: preview),
                    if (preview.manifest != null &&
                        preview.manifest!.config.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Configuration', style: AppTypography.sectionTitle),
                      const SizedBox(height: AppSpacing.xs),
                      ProviderConfigForm(
                        manifest: preview.manifest!,
                        errors: _fieldErrors,
                        onChanged: (ProviderConfigDraft draft) =>
                            _draft = draft,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        PrimaryButton(
                          label: 'Install source',
                          icon: Icons.add_rounded,
                          dense: true,
                          isLoading: _busy,
                          onPressed: preview.canInstall && !_busy
                              ? _install
                              : null,
                        ),
                      ],
                    ),
                  ],
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.preview});

  final ProviderInstallPreview preview;

  @override
  Widget build(BuildContext context) {
    final ProviderManifest? manifest = preview.manifest;
    return Container(
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
                  manifest?.name ?? 'Unreadable manifest',
                  style: AppTypography.sectionTitle,
                ),
              ),
              if (manifest != null) MetaChip(label: 'v${manifest.version}'),
            ],
          ),
          if (manifest != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${manifest.id} · ${manifest.attribution}',
              style: AppTypography.caption.copyWith(fontSize: 11),
            ),
            if (manifest.description != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(manifest.description!, style: AppTypography.caption),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final ProviderCapability capability
                    in manifest.providerCapabilities)
                  MetaChip(label: capability.label),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Provider contract ${manifest.contractRange}',
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (preview.duplicate)
            const InlineMessage(
              tone: InlineTone.error,
              icon: Icons.repeat_rounded,
              message:
                  'A source with this id is already installed. Remove it first '
                  'to replace it.',
            )
          else if (preview.status == ManifestStatus.valid)
            const InlineMessage(
              tone: InlineTone.info,
              icon: Icons.check_circle_outline_rounded,
              message: 'This manifest is valid and compatible with this build.',
            )
          else
            InlineMessage(
              tone: InlineTone.error,
              icon: Icons.error_outline_rounded,
              message: preview.blockingMessage,
            ),
          if (preview.errors.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            for (final ManifestError error in preview.errors.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
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
        ],
      ),
    );
  }
}
