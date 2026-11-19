import '../../providers/provider_failure.dart';

/// Placeholder substitution for manifest request templates
/// (`docs/PROVIDER_MANIFEST.md` §6.2).
///
/// There are no expressions, filters, arithmetic or conditionals here: a
/// placeholder is looked up and inserted, or binding fails. Values placed in a
/// path or query component are percent-encoded, and header values are rejected
/// outright if the substituted result could break the header — injection is
/// impossible by construction, not by escaping.
class TemplateBinder {
  TemplateBinder({required this.values});

  /// Placeholder name → substituted value. Secrets are present here because the
  /// platform (not a mapping expression) builds the request.
  final Map<String, String> values;

  static final RegExp _placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9_.]*)\}');

  /// Maximum length of a substituted header value, in bytes.
  static const int maxHeaderBytes = 1024;

  /// Every `{name}` occurring in [template], in order of appearance.
  static List<String> placeholdersIn(String template) => <String>[
    for (final RegExpMatch match in _placeholder.allMatches(template))
      match.group(1)!,
  ];

  /// Substitutes into a URL template.
  ///
  /// Path and query placeholders are percent-encoded, so a series id containing
  /// `/` or `&` cannot change the request shape. Two kinds of value are inserted
  /// verbatim because they *are* URLs, not URL components: `{baseUrl}`, and a
  /// `{config.*}` field whose value is an absolute HTTPS URL (the self-hosted
  /// base URL declared by a `url` field).
  ///
  /// Throws [ProviderManifestInvalid] when a placeholder has no value — that can
  /// only happen if validation was bypassed, and the request must not go out.
  String bindUriComponent(
    String template, {
    required String providerId,
    required String path,
  }) {
    return template.replaceAllMapped(_placeholder, (Match match) {
      final String name = match.group(1)!;
      final String? value = values[name];
      if (value == null) {
        throw ProviderManifestInvalid(
          providerId: providerId,
          message:
              'The manifest used a placeholder ($name) that has no value here, '
              'so the request was not sent.',
        );
      }
      if (name == 'baseUrl' || _isAbsoluteHttps(value)) return value;
      return Uri.encodeComponent(value);
    });
  }

  /// Substitutes a value that will be percent-encoded once, by `Uri.replace`
  /// when the query is assembled. Control characters are still refused.
  String bindQueryValue(
    String template, {
    required String providerId,
    required String name,
  }) {
    final String result = template.replaceAllMapped(_placeholder, (
      Match match,
    ) {
      final String? value = values[match.group(1)!];
      if (value == null) {
        throw ProviderManifestInvalid(
          providerId: providerId,
          message:
              'The manifest used a placeholder that has no value here, so the '
              'request was not sent.',
        );
      }
      return value;
    });
    if (_hasUnsafeHeaderCharacter(result)) {
      throw ProviderManifestInvalid(
        providerId: providerId,
        message:
            'A configured value produced an unusable query value for '
            '"$name", so the request was not sent.',
      );
    }
    return result;
  }

  static bool _isAbsoluteHttps(String value) {
    final Uri? uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  /// Substitutes into a header value and refuses anything unsafe.
  String bindHeader(
    String template, {
    required String providerId,
    required String headerName,
  }) {
    final String result = template.replaceAllMapped(_placeholder, (
      Match match,
    ) {
      final String? value = values[match.group(1)!];
      if (value == null) {
        throw ProviderManifestInvalid(
          providerId: providerId,
          message:
              'A request header could not be built from the manifest, so the '
              'request was not sent.',
        );
      }
      return value;
    });

    if (_hasUnsafeHeaderCharacter(result)) {
      // The value is deliberately not echoed: it may contain a configured
      // secret, and the failure copy must be safe to display.
      throw ProviderManifestInvalid(
        providerId: providerId,
        message:
            'A configured value produced an unsafe value for the header '
            '"$headerName", so the request was not sent.',
      );
    }
    if (result.codeUnits.length > maxHeaderBytes) {
      throw ProviderManifestInvalid(
        providerId: providerId,
        message:
            'The value for the "$headerName" header is longer than '
            '$maxHeaderBytes bytes, so the request was not sent.',
      );
    }
    return result;
  }

  /// Substitutes into a flat POST body value without URI encoding.
  String bindScalar(
    String template, {
    required String providerId,
    required String field,
  }) {
    final String result = template.replaceAllMapped(_placeholder, (
      Match match,
    ) {
      final String? value = values[match.group(1)!];
      if (value == null) {
        throw ProviderManifestInvalid(
          providerId: providerId,
          message: 'The request body could not be built from the manifest.',
        );
      }
      return value;
    });
    if (result.length > 4096) {
      throw ProviderManifestInvalid(
        providerId: providerId,
        message: 'A request body field is longer than the limit.',
      );
    }
    return result;
  }

  /// CR, LF and other control characters make a header ambiguous; refuse them
  /// rather than relying on the HTTP client to sanitise them.
  static bool _hasUnsafeHeaderCharacter(String value) {
    for (final int unit in value.codeUnits) {
      if (unit < 0x20 || unit == 0x7f) return true;
    }
    return false;
  }
}
