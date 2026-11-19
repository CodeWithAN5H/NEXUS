import '../../providers/provider_descriptor.dart';
import 'provider_manifest.dart';

/// Validation of user-entered configuration against a manifest declaration.
///
/// Pure and reusable: the import form, the edit form and the lifecycle service
/// all call this, so the form cannot accept something the service would refuse
/// (or the reverse). It never receives or returns a secret except in the values
/// map the caller passed in.
class ManifestConfigValidator {
  const ManifestConfigValidator._();

  static ManifestConfigResult validate(
    ProviderManifest manifest,
    Map<String, String> input, {
    Set<String> presentSecrets = const <String>{},
  }) {
    final Map<String, String> values = <String, String>{};
    final Map<String, String> errors = <String, String>{};

    for (final ManifestConfigField field in manifest.config) {
      final String? raw = input[field.key];
      final String value = (raw ?? '').trim();

      if (value.isEmpty) {
        if (field.required) {
          final bool secretSatisfied =
              field.type.isSecret && presentSecrets.contains(field.key);
          if (!secretSatisfied) {
            errors[field.key] = 'This field is required.';
          }
        }
        // An optional empty value is simply not stored.
        continue;
      }

      if (value.length > field.maxLength) {
        errors[field.key] =
            'Use at most ${field.maxLength} characters (currently ${value.length}).';
        continue;
      }

      switch (field.type) {
        case ProviderConfigType.url:
          final Uri? uri = Uri.tryParse(value);
          if (uri == null ||
              uri.scheme != 'https' ||
              uri.host.isEmpty ||
              uri.userInfo.isNotEmpty) {
            errors[field.key] = 'Enter an absolute https URL.';
            continue;
          }
        case ProviderConfigType.boolean:
          if (value != 'true' && value != 'false') {
            errors[field.key] = 'Choose true or false.';
            continue;
          }
        case ProviderConfigType.choice:
          if (field.choices.isNotEmpty && !field.choices.contains(value)) {
            errors[field.key] = 'Choose one of the listed values.';
            continue;
          }
        case ProviderConfigType.text:
        case ProviderConfigType.secret:
          break;
      }

      final String? pattern = field.pattern;
      if (pattern != null) {
        final RegExp expression;
        try {
          expression = RegExp(pattern);
        } on FormatException {
          // The validator rejects an invalid pattern at install time; if one is
          // stored anyway, do not block the user on it.
          values[field.key] = value;
          continue;
        }
        if (!expression.hasMatch(value)) {
          errors[field.key] = 'This value does not match the required format.';
          continue;
        }
      }

      values[field.key] = value;
    }

    return ManifestConfigResult(
      values: Map<String, String>.unmodifiable(values),
      errors: Map<String, String>.unmodifiable(errors),
    );
  }
}

/// Outcome of validating configuration values.
class ManifestConfigResult {
  const ManifestConfigResult({required this.values, required this.errors});

  /// Accepted values, trimmed. Secret values are included here when supplied so
  /// the caller can hand them to the keystore immediately; they are never stored
  /// by this object.
  final Map<String, String> values;

  /// Field key → user-facing message. Never contains a value.
  final Map<String, String> errors;

  bool get isValid => errors.isEmpty;
}
