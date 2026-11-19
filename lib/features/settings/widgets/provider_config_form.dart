import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/chips.dart';
import '../../../integrations/providers/provider_descriptor.dart';
import '../../../integrations/streaming/manifest/provider_manifest.dart';

/// What the user has typed, separated by where it must be stored.
///
/// [values] is ordinary configuration (SQLite); [secrets] is destined for the
/// keystore and must never be written to the database.
class ProviderConfigDraft {
  const ProviderConfigDraft({
    required this.values,
    required this.secrets,
    required this.clearSecrets,
  });

  final Map<String, String> values;
  final Map<String, String> secrets;

  /// Secrets the user explicitly removed.
  final Set<String> clearSecrets;
}

/// Renders a configuration form from a manifest's declared fields.
///
/// One widget serves installation and later editing, so both paths validate and
/// behave identically. It knows nothing about any provider id or service; the
/// caller submits the draft.
class ProviderConfigForm extends StatefulWidget {
  const ProviderConfigForm({
    required this.manifest,
    required this.onChanged,
    this.initialValues = const <String, String>{},
    this.presentSecrets = const <String>{},
    this.errors = const <String, String>{},
    super.key,
  });

  final ProviderManifest manifest;

  /// Non-secret saved values.
  final Map<String, String> initialValues;

  /// Secret fields that already hold a value. Their value is never read here.
  final Set<String> presentSecrets;

  final ValueChanged<ProviderConfigDraft> onChanged;

  /// Field key → message, from the validator after a submit attempt.
  final Map<String, String> errors;

  @override
  State<ProviderConfigForm> createState() => _ProviderConfigFormState();
}

class _ProviderConfigFormState extends State<ProviderConfigForm> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, bool> _booleans = <String, bool>{};
  final Map<String, String> _choices = <String, String>{};
  final Map<String, TextEditingController> _secretControllers =
      <String, TextEditingController>{};

  /// Secret fields where the user chose "Replace".
  final Set<String> _replacing = <String>{};
  final Set<String> _cleared = <String>{};

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    for (final ManifestConfigField field in widget.manifest.config) {
      if (field.type.isSecret) {
        _secretControllers[field.key] = TextEditingController();
        continue;
      }
      final String initial = widget.initialValues[field.key] ?? '';
      switch (field.type) {
        case ProviderConfigType.boolean:
          _booleans[field.key] = initial == 'true';
        case ProviderConfigType.choice:
          if (field.choices.contains(initial)) _choices[field.key] = initial;
        case ProviderConfigType.text:
        case ProviderConfigType.url:
        case ProviderConfigType.secret:
          _controllers[field.key] = TextEditingController(text: initial);
      }
    }
  }

  @override
  void didUpdateWidget(covariant ProviderConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new manifest (or a re-review of a different one) rebuilds the fields.
    if (!identical(oldWidget.manifest, widget.manifest)) {
      for (final TextEditingController controller in _controllers.values) {
        controller.dispose();
      }
      for (final TextEditingController controller
          in _secretControllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      _secretControllers.clear();
      _booleans.clear();
      _choices.clear();
      _replacing.clear();
      _cleared.clear();
      _initializeFields();
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in _secretControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final Map<String, String> values = <String, String>{};
    final Map<String, String> secrets = <String, String>{};
    for (final ManifestConfigField field in widget.manifest.config) {
      if (field.type.isSecret) {
        final String typed = _secretControllers[field.key]?.text.trim() ?? '';
        if (typed.isNotEmpty) secrets[field.key] = typed;
        continue;
      }
      switch (field.type) {
        case ProviderConfigType.boolean:
          final bool? value = _booleans[field.key];
          if (value != null) values[field.key] = '$value';
        case ProviderConfigType.choice:
          final String? value = _choices[field.key];
          if (value != null && value.isNotEmpty) values[field.key] = value;
        case ProviderConfigType.text:
        case ProviderConfigType.url:
        case ProviderConfigType.secret:
          final String value = _controllers[field.key]?.text.trim() ?? '';
          if (value.isNotEmpty) values[field.key] = value;
      }
    }
    widget.onChanged(
      ProviderConfigDraft(
        values: values,
        secrets: secrets,
        clearSecrets: <String>{
          for (final String key in _cleared)
            if (!secrets.containsKey(key)) key,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final ManifestConfigField field in widget.manifest.config)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _field(context, field),
          ),
      ],
    );
  }

  Widget _field(BuildContext context, ManifestConfigField field) {
    final String? error = widget.errors[field.key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(field.label, style: AppTypography.caption),
            if (field.required)
              Text(
                ' *',
                style: AppTypography.caption.copyWith(color: AppColors.accent),
              ),
            const Spacer(),
            if (field.type.isSecret)
              MetaChip(
                label: 'Stored in keystore',
                color: AppColors.textMuted,
                background: AppColors.surfaceSecondary,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ..._control(field, error),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              error,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          )
        else if (field.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              field.hint!,
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _control(ManifestConfigField field, String? error) {
    switch (field.type) {
      case ProviderConfigType.boolean:
        return <Widget>[
          Row(
            children: <Widget>[
              ChoiceChip(
                label: const Text('True'),
                selected: _booleans[field.key] == true,
                onSelected: (_) {
                  setState(() => _booleans[field.key] = true);
                  _emit();
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              ChoiceChip(
                label: const Text('False'),
                selected: _booleans[field.key] == false,
                onSelected: (_) {
                  setState(() => _booleans[field.key] = false);
                  _emit();
                },
              ),
            ],
          ),
        ];
      case ProviderConfigType.choice:
        return <Widget>[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final String choice in field.choices)
                ChoiceChip(
                  label: Text(choice),
                  selected: _choices[field.key] == choice,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _choices[field.key] = choice;
                      } else {
                        _choices.remove(field.key);
                      }
                    });
                    _emit();
                  },
                ),
            ],
          ),
        ];
      case ProviderConfigType.text:
      case ProviderConfigType.url:
        return <Widget>[
          TextField(
            controller: _controllers[field.key],
            keyboardType: field.type == ProviderConfigType.url
                ? TextInputType.url
                : TextInputType.text,
            style: AppTypography.body,
            onChanged: (_) => _emit(),
            decoration: _decoration(
              hint: field.placeholder ?? field.hint,
              error: error,
            ),
          ),
        ];
      case ProviderConfigType.secret:
        final bool saved =
            widget.presentSecrets.contains(field.key) &&
            !_cleared.contains(field.key);
        if (saved && !_replacing.contains(field.key)) {
          return <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Saved securely. Its value is never shown again.',
                    style: AppTypography.caption,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _replacing.add(field.key)),
                  child: const Text('Replace'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _cleared.add(field.key);
                      _replacing.remove(field.key);
                      _secretControllers[field.key]?.clear();
                    });
                    _emit();
                  },
                  child: const Text('Remove'),
                ),
              ],
            ),
          ];
        }
        return <Widget>[
          TextField(
            controller: _secretControllers[field.key],
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: AppTypography.body,
            onChanged: (_) => _emit(),
            decoration: _decoration(
              hint: field.placeholder ?? 'Paste the credential',
              error: error,
            ),
          ),
        ];
    }
  }

  InputDecoration _decoration({String? hint, String? error}) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: AppRadius.cardRadius,
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surfaceSecondary,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      enabledBorder: border(error == null ? AppColors.border : AppColors.error),
      focusedBorder: border(error == null ? AppColors.accent : AppColors.error),
    );
  }
}
