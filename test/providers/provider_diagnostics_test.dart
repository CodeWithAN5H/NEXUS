import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/services/provider_diagnostics.dart';
import 'package:nexus/integrations/providers/provider_failure.dart';

void main() {
  const String secret = 'sk-live-abcdefghijklmnopqrstuvwxyz012345';
  const String token = 'A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0';

  group('redaction', () {
    test('removes URL query strings and fragments but keeps the host', () {
      final String redacted = ProviderDiagnosticsRedaction.message(
        'GET https://api.example.com/v1/series?token=$token&user=42#frag',
      );
      expect(redacted, contains('https://api.example.com/v1/series'));
      expect(redacted, contains('?redacted'));
      expect(redacted, isNot(contains('token=')));
      expect(redacted, isNot(contains(token)));
      expect(redacted, isNot(contains('user=42')));
      expect(redacted, isNot(contains('frag')));
    });

    test('removes URL userinfo as well as the query', () {
      final String redacted = ProviderDiagnosticsRedaction.message(
        'GET https://user:pass@api.example.com/v1?token=$token',
      );
      expect(redacted, contains('https://api.example.com/v1?redacted'));
      expect(redacted, isNot(contains('user')));
      expect(redacted, isNot(contains('pass')));
      expect(redacted, isNot(contains(token)));
    });

    test('removes bearer tokens and header values', () {
      final String redacted = ProviderDiagnosticsRedaction.message(
        'Authorization: Bearer $token X-Api-Key: $secret cookie=session=abc123',
      );
      expect(redacted, isNot(contains(token)));
      expect(redacted, isNot(contains(secret)));
      expect(redacted, isNot(contains('abc123')));
      expect(redacted, contains('Authorization'));
      expect(redacted, contains('X-Api-Key'));
    });

    test('removes long opaque tokens even without a key name', () {
      final String redacted = ProviderDiagnosticsRedaction.message(
        'upstream replied $token for this request',
      );
      expect(redacted, isNot(contains(token)));
      expect(redacted, contains('upstream replied'));
    });

    test('scrubs supplied secret values, including short ones', () {
      final String redacted = ProviderDiagnosticsRedaction.message(
        'the key hunter2 was rejected',
        secrets: const <String>['hunter2'],
      );
      expect(redacted, isNot(contains('hunter2')));
      expect(redacted, contains('***'));
    });

    test('strips control characters, collapses lines and truncates', () {
      final String control = ProviderDiagnosticsRedaction.message(
        'line\u0000one\nline\u0007two',
      );
      expect(control, 'line one line two');

      // A long *sentence* is truncated; a long opaque run is redacted instead
      // (asserted in the token test above).
      final String long = ProviderDiagnosticsRedaction.message(
        List<String>.filled(300, 'word').join(' '),
      );
      expect(long.length, lessThanOrEqualTo(400));
      expect(long, endsWith('…'));
    });

    test('never turns an ordinary message into stars', () {
      expect(
        ProviderDiagnosticsRedaction.message('Search returned 40 results.'),
        'Search returned 40 results.',
      );
    });
  });

  group('opt-in store', () {
    late ProviderContainer container;
    late ProviderDiagnosticsController diagnostics;

    setUp(() {
      container = ProviderContainer();
      diagnostics = container.read(providerDiagnosticsProvider.notifier);
      addTearDown(container.dispose);
    });

    test('nothing is recorded until the source is opted in', () {
      final bool stored = diagnostics.record(
        'dev.example.full',
        category: ProviderDiagnosticCategory.availability,
        message: 'ready',
      );
      expect(stored, isFalse);
      expect(
        container
            .read(providerDiagnosticsProvider)
            .forProvider('dev.example.full'),
        isEmpty,
      );
    });

    test('records per provider, newest last, and can be cleared', () {
      diagnostics.setOptIn('dev.example.full', true);
      diagnostics.record(
        'dev.example.full',
        category: ProviderDiagnosticCategory.availability,
        message: 'ready',
        at: DateTime.utc(2026, 11, 19, 10),
      );
      diagnostics.record(
        'dev.example.full',
        category: ProviderDiagnosticCategory.timeout,
        message: 'no answer',
        at: DateTime.utc(2026, 11, 19, 10, 1),
      );
      diagnostics.record(
        'other.source',
        category: ProviderDiagnosticCategory.upstream,
        message: 'irrelevant',
      );

      final List<ProviderDiagnosticEntry> entries = container
          .read(providerDiagnosticsProvider)
          .forProvider('dev.example.full');
      expect(entries, hasLength(2));
      expect(entries.first.category, ProviderDiagnosticCategory.availability);
      expect(entries.last.category, ProviderDiagnosticCategory.timeout);
      expect(
        container.read(providerDiagnosticsProvider).forProvider('other.source'),
        isEmpty,
      );

      diagnostics.clear('dev.example.full');
      expect(
        container
            .read(providerDiagnosticsProvider)
            .forProvider('dev.example.full'),
        isEmpty,
      );
      expect(
        container
            .read(providerDiagnosticsProvider)
            .isOptedIn('dev.example.full'),
        isTrue,
        reason: 'clearing history does not turn recording off',
      );
    });

    test('history is capped and the oldest entry is dropped', () {
      diagnostics.setOptIn('dev.example.full', true);
      for (
        int i = 0;
        i < ProviderDiagnosticsController.maxEntriesPerProvider + 5;
        i++
      ) {
        diagnostics.record(
          'dev.example.full',
          category: ProviderDiagnosticCategory.availability,
          message: 'check $i',
        );
      }
      final List<ProviderDiagnosticEntry> entries = container
          .read(providerDiagnosticsProvider)
          .forProvider('dev.example.full');
      expect(
        entries,
        hasLength(ProviderDiagnosticsController.maxEntriesPerProvider),
      );
      expect(entries.first.message, 'check 5');
    });

    test('turning diagnostics off forgets the history', () {
      diagnostics.setOptIn('dev.example.full', true);
      diagnostics.record(
        'dev.example.full',
        category: ProviderDiagnosticCategory.availability,
        message: 'ready',
      );
      diagnostics.setOptIn('dev.example.full', false);

      final ProviderDiagnosticsState state = container.read(
        providerDiagnosticsProvider,
      );
      expect(state.isOptedIn('dev.example.full'), isFalse);
      expect(state.forProvider('dev.example.full'), isEmpty);
    });

    test('forgetting a removed source clears opt-in and history', () {
      diagnostics.setOptIn('dev.example.full', true);
      diagnostics.record(
        'dev.example.full',
        category: ProviderDiagnosticCategory.availability,
        message: 'ready',
      );
      diagnostics.forget('dev.example.full');

      final ProviderDiagnosticsState state = container.read(
        providerDiagnosticsProvider,
      );
      expect(state.isOptedIn('dev.example.full'), isFalse);
      expect(state.forProvider('dev.example.full'), isEmpty);
    });
  });

  group('failure categories', () {
    test('map every typed failure to the axis it belongs to', () {
      const String id = 'dev.example.full';
      expect(
        providerFailureCategory(const ProviderNotConfigured(providerId: id)),
        ProviderDiagnosticCategory.configuration,
      );
      expect(
        providerFailureCategory(const ProviderAuthRejected(providerId: id)),
        ProviderDiagnosticCategory.authentication,
      );
      expect(
        providerFailureCategory(const ProviderTimeout(providerId: id)),
        ProviderDiagnosticCategory.timeout,
      );
      expect(
        providerFailureCategory(const ProviderOriginRejected(providerId: id)),
        ProviderDiagnosticCategory.network,
      );
      expect(
        providerFailureCategory(const ProviderManifestInvalid(providerId: id)),
        ProviderDiagnosticCategory.manifest,
      );
      expect(
        providerFailureCategory(
          const ProviderUnsupported(providerId: id, feature: 'search'),
        ),
        ProviderDiagnosticCategory.unsupported,
      );
      expect(
        providerFailureCategory(
          const ProviderUpstreamError(providerId: id, status: 500),
        ),
        ProviderDiagnosticCategory.upstream,
      );
      expect(
        providerFailureCategory(StateError('unexpected')),
        ProviderDiagnosticCategory.upstream,
      );
    });
  });

  group('export', () {
    test('names the source and includes redacted entries only', () {
      final DateTime at = DateTime.utc(2026, 11, 19, 12);
      final String text = ProviderDiagnosticsRedaction.exportText(
        providerId: 'dev.example.full',
        name: 'Example Full',
        version: '2.1.0',
        origin: 'user-added',
        stateSummary: 'Ready',
        generatedAt: at,
        entries: <ProviderDiagnosticEntry>[
          ProviderDiagnosticEntry(
            at: at,
            category: ProviderDiagnosticCategory.availability,
            message:
                'ready · https://api.example.com/health?key=$secret · '
                'Authorization: Bearer $token',
          ),
        ],
      );

      expect(text, contains('NEXUS provider diagnostics'));
      expect(text, contains('Example Full (dev.example.full)'));
      expect(text, contains('v'.isEmpty ? '' : 'Version: 2.1.0'));
      expect(text, contains('Contains no credentials'));
      expect(text, contains('?redacted'));
      expect(text, isNot(contains(secret)));
      expect(text, isNot(contains(token)));
      expect(text, isNot(contains('key=')));
      expect(text, isNot(contains('"body"')));
    });

    test('an empty history exports a clear sentence, not an empty file', () {
      final String text = ProviderDiagnosticsRedaction.exportText(
        providerId: 'sample',
        name: 'Playback Test Library',
        version: '1.0.0',
        origin: 'built-in',
        stateSummary: 'Ready',
        generatedAt: DateTime.utc(2026, 11, 19),
        entries: const <ProviderDiagnosticEntry>[],
      );
      expect(text, contains('No diagnostic entries recorded.'));
    });
  });
}
