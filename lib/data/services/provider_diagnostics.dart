import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../integrations/providers/provider_failure.dart';
import '../../integrations/providers/provider_redaction.dart';

/// What a diagnostic entry is about, so a failure can be told apart from a
/// working probe without reading the text.
enum ProviderDiagnosticCategory {
  availability('Availability'),
  configuration('Configuration'),
  compatibility('Compatibility'),
  authentication('Sign-in'),
  network('Network'),
  upstream('Upstream'),
  timeout('Timeout'),
  manifest('Manifest'),
  unsupported('Capability'),
  lifecycle('Lifecycle');

  const ProviderDiagnosticCategory(this.label);

  final String label;
}

/// One redacted observation. There is deliberately no request body, header map
/// or credential field: those are never collected in the first place.
class ProviderDiagnosticEntry {
  const ProviderDiagnosticEntry({
    required this.at,
    required this.category,
    required this.message,
  });

  final DateTime at;
  final ProviderDiagnosticCategory category;
  final String message;

  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.toIso8601String(),
    'category': category.name,
    'message': message,
  };
}

/// Opt-in set plus the bounded, in-memory history per provider.
class ProviderDiagnosticsState {
  const ProviderDiagnosticsState({
    this.optedIn = const <String>{},
    this.entries = const <String, List<ProviderDiagnosticEntry>>{},
  });

  final Set<String> optedIn;
  final Map<String, List<ProviderDiagnosticEntry>> entries;

  bool isOptedIn(String providerId) => optedIn.contains(providerId);

  List<ProviderDiagnosticEntry> forProvider(String providerId) =>
      entries[providerId] ?? const <ProviderDiagnosticEntry>[];

  ProviderDiagnosticsState copyWith({
    Set<String>? optedIn,
    Map<String, List<ProviderDiagnosticEntry>>? entries,
  }) {
    return ProviderDiagnosticsState(
      optedIn: optedIn ?? this.optedIn,
      entries: entries ?? this.entries,
    );
  }
}

/// In-memory diagnostics. Nothing is persisted, uploaded or written to a log;
/// closing the app discards everything.
class ProviderDiagnosticsController extends Notifier<ProviderDiagnosticsState> {
  /// Enough to see a pattern, small enough to read and to copy by hand.
  static const int maxEntriesPerProvider = 20;
  static const int maxMessageLength = 400;

  @override
  ProviderDiagnosticsState build() => const ProviderDiagnosticsState();

  bool isOptedIn(String providerId) => state.isOptedIn(providerId);

  /// Turning diagnostics off also forgets what was collected: opt-in is the
  /// permission to retain observations, not just to collect new ones.
  void setOptIn(String providerId, bool enabled) {
    final Set<String> optedIn = <String>{...state.optedIn};
    final Map<String, List<ProviderDiagnosticEntry>> entries =
        <String, List<ProviderDiagnosticEntry>>{...state.entries};
    if (enabled) {
      optedIn.add(providerId);
    } else {
      optedIn.remove(providerId);
      entries.remove(providerId);
    }
    state = state.copyWith(optedIn: optedIn, entries: entries);
  }

  /// Records one observation, but only while this provider is opted in.
  ///
  /// Returns whether it was stored, which is what the UI uses to decide between
  /// "no diagnostics yet" and "diagnostics are off".
  bool record(
    String providerId, {
    required ProviderDiagnosticCategory category,
    required String message,
    Iterable<String> secrets = const <String>[],
    DateTime? at,
  }) {
    if (!state.isOptedIn(providerId)) return false;

    final ProviderDiagnosticEntry entry = ProviderDiagnosticEntry(
      at: at ?? DateTime.now(),
      category: category,
      message: ProviderDiagnosticsRedaction.message(message, secrets: secrets),
    );
    final List<ProviderDiagnosticEntry> existing = <ProviderDiagnosticEntry>[
      ...state.forProvider(providerId),
      entry,
    ];
    final List<ProviderDiagnosticEntry> capped =
        existing.length > maxEntriesPerProvider
        ? existing.sublist(existing.length - maxEntriesPerProvider)
        : existing;

    state = state.copyWith(
      entries: <String, List<ProviderDiagnosticEntry>>{
        ...state.entries,
        providerId: List<ProviderDiagnosticEntry>.unmodifiable(capped),
      },
    );
    return true;
  }

  void clear(String providerId) {
    if (!state.entries.containsKey(providerId)) return;
    final Map<String, List<ProviderDiagnosticEntry>> entries =
        <String, List<ProviderDiagnosticEntry>>{...state.entries}
          ..remove(providerId);
    state = state.copyWith(entries: entries);
  }

  /// Called when a source is removed: history must not outlive its provider.
  void forget(String providerId) {
    final Set<String> optedIn = <String>{...state.optedIn}..remove(providerId);
    final Map<String, List<ProviderDiagnosticEntry>> entries =
        <String, List<ProviderDiagnosticEntry>>{...state.entries}
          ..remove(providerId);
    state = state.copyWith(optedIn: optedIn, entries: entries);
  }
}

/// Which axis a failure belongs to, from its type only — never its text.
ProviderDiagnosticCategory providerFailureCategory(Object error) {
  return switch (error) {
    ProviderNotConfigured() => ProviderDiagnosticCategory.configuration,
    ProviderAuthRejected() => ProviderDiagnosticCategory.authentication,
    ProviderTimeout() => ProviderDiagnosticCategory.timeout,
    ProviderOriginRejected() => ProviderDiagnosticCategory.network,
    ProviderManifestInvalid() => ProviderDiagnosticCategory.manifest,
    ProviderUnsupported() => ProviderDiagnosticCategory.unsupported,
    ProviderRateLimited() ||
    ProviderGeoRestricted() ||
    ProviderUpstreamError() ||
    ProviderParseFailure() ||
    ProviderInvalidStream() ||
    ProviderNotFound() => ProviderDiagnosticCategory.upstream,
    ProviderCancelled() => ProviderDiagnosticCategory.lifecycle,
    _ => ProviderDiagnosticCategory.upstream,
  };
}

/// Redaction for anything that reaches a diagnostics row or its export.
///
/// This is defence in depth, not the only protection: provider failures already
/// avoid credentials, and no response body or header value is ever collected.
abstract final class ProviderDiagnosticsRedaction {
  const ProviderDiagnosticsRedaction._();

  static final RegExp _controlCharacters = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );
  static final RegExp _url = RegExp(r'(https?://[^\s?#]+)(\?[^\s#]*)?(#\S*)?');
  static final RegExp _bearer = RegExp(
    r'\b(bearer)\s+[A-Za-z0-9\-._~+/]+=*',
    caseSensitive: false,
  );
  static final RegExp _headerValue = RegExp(
    r'\b(authorization|proxy-authorization|cookie|set-cookie|x-api-key|api[-_]?key|token|secret|password)\b\s*[:=]\s*[^\s,;]+',
    caseSensitive: false,
  );
  static final RegExp _longToken = RegExp(r'\b[A-Za-z0-9_\-]{32,}\b');

  /// One line, bounded, with URLs, tokens, header values and known secrets
  /// removed.
  static String message(
    String raw, {
    Iterable<String> secrets = const <String>[],
  }) {
    String text = ProviderRedaction.scrub(raw, secrets);
    text = text.replaceAll(_controlCharacters, ' ');
    text = text.replaceAllMapped(_url, (Match match) {
      // Rebuild from the parsed URI so userinfo (`user:pass@host`), the query
      // and the fragment all disappear; only scheme, host, port and path survive.
      final Uri? uri = Uri.tryParse(match[0]!);
      return uri == null
          ? '<redacted-url>'
          : ProviderRedaction.describeUri(uri);
    });
    text = text.replaceAllMapped(_bearer, (Match match) => '${match[1]} ***');
    text = text.replaceAllMapped(
      _headerValue,
      (Match match) => '${match[1]}: ***',
    );
    text = text.replaceAll(_longToken, '***');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > ProviderDiagnosticsController.maxMessageLength) {
      text =
          '${text.substring(0, ProviderDiagnosticsController.maxMessageLength - 1)}…';
    }
    return text;
  }

  /// The exact text a user copies. It names the source and the state that was
  /// observed, and contains no credential, header value or response body.
  static String exportText({
    required String providerId,
    required String name,
    required String version,
    required String origin,
    required String stateSummary,
    required List<ProviderDiagnosticEntry> entries,
    required DateTime generatedAt,
  }) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('NEXUS provider diagnostics')
      ..writeln('Source: $name ($providerId)')
      ..writeln('Version: $version · $origin')
      ..writeln('State: $stateSummary')
      ..writeln('Generated: ${generatedAt.toIso8601String()}')
      ..writeln('Contains no credentials, request headers or response bodies.')
      ..writeln();
    if (entries.isEmpty) {
      buffer.writeln('No diagnostic entries recorded.');
    } else {
      for (final ProviderDiagnosticEntry entry in entries) {
        buffer.writeln(
          '${entry.at.toIso8601String()} · ${entry.category.label} · '
          '${message(entry.message)}',
        );
      }
    }
    return buffer.toString();
  }
}

/// Opt-in diagnostics for the Sources screen.
final NotifierProvider<ProviderDiagnosticsController, ProviderDiagnosticsState>
providerDiagnosticsProvider =
    NotifierProvider<ProviderDiagnosticsController, ProviderDiagnosticsState>(
      ProviderDiagnosticsController.new,
    );
