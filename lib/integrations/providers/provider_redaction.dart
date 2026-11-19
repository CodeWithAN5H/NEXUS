/// Redaction helpers for anything a provider could put in a log line or a
/// diagnostic (PROVIDER_SECURITY.md §3.4, checklist item S4).
///
/// None of these helpers log. They exist so the few places the adapter does
/// describe a request (validation messages, diagnostics) cannot leak a query
/// token, a header value or a configured secret.
class ProviderRedaction {
  const ProviderRedaction._();

  /// A URL safe to describe: scheme, host and path only.
  ///
  /// The query string is replaced wholesale rather than parsed: a token can sit
  /// in any parameter name, and `?redacted` is enough to say "there was a query".
  static String describeUri(Uri uri) {
    final StringBuffer buffer = StringBuffer()
      ..write(uri.scheme)
      ..write('://')
      ..write(uri.host);
    if (uri.hasPort) {
      buffer
        ..write(':')
        ..write(uri.port);
    }
    buffer.write(uri.path.isEmpty ? '/' : uri.path);
    if (uri.hasQuery) buffer.write('?redacted');
    return buffer.toString();
  }

  /// Header names without their values.
  static Map<String, String> describeHeaders(Map<String, String> headers) {
    return <String, String>{
      for (final String name in headers.keys) name: '***',
    };
  }

  /// Replaces every configured secret that occurs in [text] with `***`.
  ///
  /// Only non-empty secrets are considered, so an unconfigured field cannot
  /// turn ordinary text into stars. Callers pass secrets rather than reading
  /// them from a global, so nothing is retained.
  static String scrub(String text, Iterable<String> secrets) {
    String result = text;
    for (final String secret in secrets) {
      if (secret.isEmpty) continue;
      result = result.replaceAll(secret, '***');
    }
    return result;
  }
}
