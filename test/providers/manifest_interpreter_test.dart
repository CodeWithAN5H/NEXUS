import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/integrations/providers/provider_failure.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_http.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_streaming_provider.dart';
import 'package:nexus/integrations/streaming/streaming_provider.dart';

import 'support/manifest_fixtures.dart';

ManifestStreamingProvider buildProvider({
  Map<String, dynamic>? manifest,
  Map<String, String> config = testConfig,
  required FakeManifestTransport transport,
  ManifestRequestGate? gate,
  Future<void> Function(Duration)? delay,
  DateTime Function()? clock,
}) {
  return ManifestStreamingProvider(
    manifest: parseManifest(manifest ?? minimalManifest()),
    config: config,
    transport: transport,
    gate: gate,
    delay: delay ?? (Duration _) async {},
    clock: clock,
  );
}

/// Returns the failure a call produced, failing the test if it returned instead.
Future<ProviderFailure> captureFailure(Future<Object?> Function() body) async {
  try {
    await body();
  } on ProviderFailure catch (failure) {
    return failure;
  }
  fail('Expected a ProviderFailure, but the call succeeded.');
}

FakeManifestTransport searchTransport(
  Object? Function(Uri uri) body, {
  List<ManifestTransportRequest>? sink,
}) {
  return FakeManifestTransport((ManifestTransportRequest request) {
    sink?.add(request);
    return FakeManifestResponse.json(body(request.uri));
  });
}

void main() {
  group('Search mapping (T-B01–T-B10)', () {
    test('T-B01 maps three series and stamps the provider id', () async {
      final FakeManifestTransport transport = FakeManifestTransport((
        ManifestTransportRequest request,
      ) {
        expect(request.uri.host, 'api.example.com');
        expect(request.uri.path, '/search');
        expect(request.uri.queryParameters['q'], 'frieren');
        expect(request.uri.queryParameters['page'], '1');
        return FakeManifestResponse.json(<String, dynamic>{
          'results': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 's1',
              'title': 'Frieren: Beyond Journey\'s End',
              'poster': 'https://img.example-cdn.net/1.jpg',
              'year': 2023,
            },
            <String, dynamic>{
              'id': 's2',
              'title': 'Frieren Special',
              'poster': 'http://insecure.example-cdn.net/2.jpg',
              'year': '2024',
            },
            <String, dynamic>{'id': 3, 'title': 'Frieren Recap'},
          ],
        });
      });
      final ManifestStreamingProvider provider = buildProvider(
        transport: transport,
      );

      final List<ProviderSeries> results = await provider.search('frieren');
      await provider.dispose();

      expect(results, hasLength(3));
      expect(results.first.providerId, 'dev.example.minimal');
      expect(results.first.seriesId, 's1');
      expect(results.first.title, 'Frieren: Beyond Journey\'s End');
      expect(results.first.coverImage, 'https://img.example-cdn.net/1.jpg');
      expect(results.first.year, 2023);
      // http images are dropped rather than loaded insecurely.
      expect(results[1].coverImage, isNull);
      expect(results[1].year, 2024);
      // Numeric ids are stringified, never guessed.
      expect(results[2].seriesId, '3');
    });

    test('T-B02 an empty result is an empty list, not a failure', () async {
      final ManifestStreamingProvider provider = buildProvider(
        transport: searchTransport(
          (Uri _) => <String, dynamic>{'results': <Object?>[]},
        ),
      );
      expect(await provider.search('nothing'), isEmpty);
      await provider.dispose();
    });

    test(
      'T-B03 HTTP 500 is an upstream failure, retried once for GET',
      () async {
        final FakeManifestTransport transport = FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{}, status: 500),
        );
        final ManifestStreamingProvider provider = buildProvider(
          transport: transport,
        );

        final ProviderFailure failure = await captureFailure(
          () => provider.search('x'),
        );
        await provider.dispose();

        expect(failure, isA<ProviderUpstreamError>());
        expect((failure as ProviderUpstreamError).status, 500);
        expect(failure.isRetryable, isTrue);
        expect(transport.sent, hasLength(2));
      },
    );

    test('T-B04 a timeout is a ProviderTimeout after one retry', () async {
      final FakeManifestTransport transport = FakeManifestTransport(
        (ManifestTransportRequest _) => FakeManifestResponse.never(),
      );
      final Map<String, dynamic> manifest = minimalManifest();
      (manifest['net'] as Map<String, dynamic>)['timeoutMs'] = 1000;
      final ManifestStreamingProvider provider = buildProvider(
        manifest: manifest,
        transport: transport,
      );

      final ProviderFailure failure = await captureFailure(
        () => provider.search('x'),
      );
      await provider.dispose();

      expect(failure, isA<ProviderTimeout>());
      expect(transport.sent, hasLength(2));
    });

    test('T-B05 a socket error is mapped once, never rethrown raw', () async {
      final FakeManifestTransport transport = FakeManifestTransport(
        (ManifestTransportRequest _) => throw const SocketException('offline'),
      );
      final ManifestStreamingProvider provider = buildProvider(
        transport: transport,
      );

      final ProviderFailure failure = await captureFailure(
        () => provider.search('x'),
      );
      await provider.dispose();

      expect(failure, isA<ProviderUpstreamError>());
      expect(failure.isRetryable, isFalse);
      expect(transport.sent, hasLength(1));
    });

    test(
      'T-B06 malformed JSON is a parse failure naming the provider',
      () async {
        final ManifestStreamingProvider provider = buildProvider(
          transport: FakeManifestTransport(
            (ManifestTransportRequest _) =>
                FakeManifestResponse.raw('{"results": ['),
          ),
        );

        final ProviderFailure failure = await captureFailure(
          () => provider.search('x'),
        );
        await provider.dispose();

        expect(failure, isA<ProviderParseFailure>());
        expect(failure.providerId, 'dev.example.minimal');
      },
    );

    test(
      'T-B07 an object where a list is expected is a parse failure',
      () async {
        final ManifestStreamingProvider provider = buildProvider(
          transport: searchTransport(
            (Uri _) => <String, dynamic>{'results': <String, dynamic>{}},
          ),
        );
        expect(
          await captureFailure(() => provider.search('x')),
          isA<ProviderParseFailure>(),
        );
        await provider.dispose();
      },
    );

    test('T-B08 an item missing a required field is dropped', () async {
      final ManifestStreamingProvider provider = buildProvider(
        transport: searchTransport(
          (Uri _) => <String, dynamic>{
            'results': <Map<String, dynamic>>[
              <String, dynamic>{'id': 's1', 'title': 'One'},
              <String, dynamic>{'id': 's2'},
              <String, dynamic>{'id': 's3', 'title': 'Three'},
            ],
          },
        ),
      );

      final List<ProviderSeries> results = await provider.search('x');
      await provider.dispose();

      expect(results.map((ProviderSeries s) => s.seriesId), <String>[
        's1',
        's3',
      ]);
    });

    test(
      'T-B09 every item malformed is a parse failure, not an empty list',
      () async {
        final ManifestStreamingProvider provider = buildProvider(
          transport: searchTransport(
            (Uri _) => <String, dynamic>{
              'results': <Map<String, dynamic>>[
                <String, dynamic>{'id': 's1'},
                <String, dynamic>{'id': 's2'},
              ],
            },
          ),
        );

        expect(
          await captureFailure(() => provider.search('x')),
          isA<ProviderParseFailure>(),
        );
        await provider.dispose();
      },
    );

    test('T-B10 lists are truncated at maxResults', () async {
      final ManifestStreamingProvider provider = buildProvider(
        transport: searchTransport(
          (Uri _) => <String, dynamic>{
            'results': <Map<String, dynamic>>[
              for (int i = 0; i < 120; i++)
                <String, dynamic>{'id': 's$i', 'title': 'Title $i'},
            ],
          },
        ),
      );

      final List<ProviderSeries> results = await provider.search('x');
      await provider.dispose();

      expect(results, hasLength(30));
      expect(results.last.seriesId, 's29');
    });
  });

  group('Title matching (T-B11–T-B15)', () {
    Map<String, dynamic> matchManifest(String strategy) {
      final Map<String, dynamic> manifest = minimalManifest();
      final Map<String, dynamic> match =
          (manifest['requests'] as Map<String, dynamic>)['match']
              as Map<String, dynamic>;
      match['strategy'] = strategy;
      return manifest;
    }

    FakeManifestTransport candidates(List<Map<String, dynamic>> results) {
      return searchTransport((Uri _) => <String, dynamic>{'results': results});
    }

    test('T-B11 exactTitle accepts an identical title', () async {
      final ManifestStreamingProvider provider = buildProvider(
        manifest: matchManifest('exactTitle'),
        transport: candidates(<Map<String, dynamic>>[
          <String, dynamic>{'id': 's1', 'title': 'Frieren'},
        ]),
      );

      final ProviderSeries? series = await provider.match(
        const Anime(id: 1, title: 'Frieren'),
      );
      await provider.dispose();

      expect(series?.seriesId, 's1');
    });

    test(
      'T-B12 normalisedTitle accepts punctuation and case differences',
      () async {
        final ManifestStreamingProvider provider = buildProvider(
          manifest: matchManifest('normalisedTitle'),
          transport: candidates(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': 's1',
              'title': 'frieren beyond journeys end',
            },
          ]),
        );

        final ProviderSeries? series = await provider.match(
          const Anime(id: 1, title: "Frieren: Beyond Journey's End"),
        );
        await provider.dispose();

        expect(series?.seriesId, 's1');
      },
    );

    test('T-B13 the year guard rejects a remake', () async {
      final ManifestStreamingProvider provider = buildProvider(
        manifest: matchManifest('normalisedTitleAndYear'),
        transport: candidates(<Map<String, dynamic>>[
          <String, dynamic>{'id': 's1', 'title': 'Frieren', 'year': 2019},
        ]),
      );

      final ProviderSeries? series = await provider.match(
        const Anime(id: 1, title: 'Frieren', seasonYear: 2023),
      );
      await provider.dispose();

      expect(series, isNull);
    });

    test('T-B14 no resemblance returns null, never a best guess', () async {
      final ManifestStreamingProvider provider = buildProvider(
        manifest: matchManifest('normalisedTitle'),
        transport: candidates(<Map<String, dynamic>>[
          <String, dynamic>{'id': 's1', 'title': 'Completely Different'},
        ]),
      );

      expect(
        await provider.match(const Anime(id: 1, title: 'Frieren')),
        isNull,
      );
      await provider.dispose();
    });

    test('T-B15 duplicate candidates are ambiguous, not auto-picked', () async {
      final ManifestStreamingProvider provider = buildProvider(
        manifest: matchManifest('normalisedTitle'),
        transport: candidates(<Map<String, dynamic>>[
          <String, dynamic>{'id': 's1', 'title': 'Frieren'},
          <String, dynamic>{'id': 's2', 'title': 'Frieren'},
        ]),
      );

      final ProviderSeries? series = await provider.match(
        const Anime(id: 1, title: 'Frieren'),
      );
      final List<ProviderSeries> ambiguous = provider.lastAmbiguousMatch;
      await provider.dispose();

      expect(series, isNull);
      expect(ambiguous, hasLength(2));
    });
  });
}
