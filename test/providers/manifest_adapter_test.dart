import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/integrations/providers/provider_failure.dart';
import 'package:nexus/integrations/providers/provider_record.dart';
import 'package:nexus/integrations/providers/provider_redaction.dart';
import 'package:nexus/integrations/providers/provider_registries.dart';
import 'package:nexus/integrations/providers/provider_resolver.dart';
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

Future<ProviderFailure> captureFailure(Future<Object?> Function() body) async {
  try {
    await body();
  } on ProviderFailure catch (failure) {
    return failure;
  }
  fail('Expected a ProviderFailure, but the call succeeded.');
}

const ProviderSeries testSeries = ProviderSeries(
  providerId: 'dev.example.minimal',
  seriesId: 's1',
  title: 'Frieren',
);

const ProviderEpisode testEpisode = ProviderEpisode(
  providerId: 'dev.example.minimal',
  seriesId: 's1',
  episodeId: 'e1',
  number: 1,
  title: 'Episode 1',
);

ProviderSeries seriesWithId(String id) => ProviderSeries(
  providerId: 'dev.example.full',
  seriesId: id,
  title: 'Frieren',
);

void main() {
  group('Season and episode mapping (T-B17–T-B20)', () {
    test('T-B17 absolute numbering is preserved', () async {
      final ManifestStreamingProvider provider = buildProvider(
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{
                'episodes': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'e1',
                    'number': 1,
                    'title': 'First',
                    'runtime': '24:00',
                  },
                  <String, dynamic>{
                    'id': 'e2',
                    'number': 2,
                    'title': 'Second',
                    'runtime': 1425,
                  },
                ],
              }),
        ),
      );

      final List<ProviderEpisode> episodes = await provider.episodes(
        testSeries,
      );
      await provider.dispose();

      expect(episodes.map((ProviderEpisode e) => e.number), <int>[1, 2]);
      expect(episodes.first.duration, const Duration(minutes: 24));
      expect(episodes[1].duration, const Duration(seconds: 1425));
      expect(episodes.first.seasonId, isNull);
    });

    test('T-B18 season-relative numbering becomes absolute', () async {
      final ManifestStreamingProvider provider = buildProvider(
        manifest: fullManifest(),
        transport: FakeManifestTransport((ManifestTransportRequest request) {
          if (request.uri.path == '/v2/series/s1/seasons') {
            return FakeManifestResponse.json(<String, dynamic>{
              'seasons': <Map<String, dynamic>>[
                <String, dynamic>{
                  'slug': 's1',
                  'name': 'Season 1',
                  'order': 0,
                  'count': 12,
                },
                <String, dynamic>{
                  'slug': 's2',
                  'name': 'Season 2',
                  'order': 1,
                  'count': 24,
                },
              ],
            });
          }
          return FakeManifestResponse.json(<String, dynamic>{
            'episodes': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'e1',
                'episode': 1,
                'title': 'Season two opener',
                'season': 's2',
              },
            ],
          });
        }),
      );

      final List<ProviderEpisode> episodes = await provider.episodes(
        seriesWithId('s1'),
        seasonId: 's2',
      );
      await provider.dispose();

      expect(episodes.single.number, 13);
      expect(episodes.single.seasonId, 's2');
    });

    test(
      'T-B19 a missing earlier-season count fails instead of inventing',
      () async {
        final ManifestStreamingProvider provider = buildProvider(
          manifest: fullManifest(),
          transport: FakeManifestTransport((ManifestTransportRequest request) {
            if (request.uri.path.endsWith('/seasons')) {
              return FakeManifestResponse.json(<String, dynamic>{
                'seasons': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'slug': 's1',
                    'name': 'Season 1',
                    'order': 0,
                  },
                  <String, dynamic>{
                    'slug': 's2',
                    'name': 'Season 2',
                    'order': 1,
                  },
                ],
              });
            }
            return FakeManifestResponse.json(<String, dynamic>{
              'episodes': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'e1',
                  'episode': 1,
                  'title': 'E1',
                  'season': 's2',
                },
              ],
            });
          }),
        );

        final ProviderFailure failure = await captureFailure(
          () => provider.episodes(seriesWithId('s1'), seasonId: 's2'),
        );
        await provider.dispose();

        expect(failure, isA<ProviderParseFailure>());
        expect(failure.message, contains('episode count'));
      },
    );

    test('T-B20 an empty episode list is not a failure', () async {
      final ManifestStreamingProvider provider = buildProvider(
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) => FakeManifestResponse.json(
            <String, dynamic>{'episodes': <Object?>[]},
          ),
        ),
      );
      expect(await provider.episodes(testSeries), isEmpty);
      await provider.dispose();
    });

    test('seasons map to provider seasons with labels and indexes', () async {
      final ManifestStreamingProvider provider = buildProvider(
        manifest: fullManifest(),
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{
                'seasons': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'slug': 's1',
                    'name': 'Season 1',
                    'order': 0,
                    'count': 12,
                  },
                ],
              }),
        ),
      );

      final List<ProviderSeason> seasons = await provider.seasons(
        seriesWithId('s1'),
      );
      await provider.dispose();

      expect(seasons.single.seasonId, 's1');
      expect(seasons.single.label, 'Season 1');
      expect(seasons.single.index, 0);
    });
  });

  group('Resolve mapping (T-B21–T-B25, T-B27–T-B29)', () {
    Map<String, dynamic> sourceVariant(
      String uri, {
      int? height,
      String label = '1080p',
      bool? isDefault,
    }) {
      return <String, dynamic>{
        'quality': label,
        'url': uri,
        'height': ?height,
        'default': ?isDefault,
      };
    }

    test('T-B21 no sources yields an empty stream, not an error', () async {
      final ManifestStreamingProvider provider = buildProvider(
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) => FakeManifestResponse.json(
            <String, dynamic>{'sources': <Object?>[]},
          ),
        ),
      );

      final EpisodeStream stream = await provider.resolve(
        testSeries,
        testEpisode,
      );
      await provider.dispose();

      expect(stream.isEmpty, isTrue);
    });

    test('T-B22 a plain-HTTP variant is dropped; all invalid fails', () async {
      final ManifestStreamingProvider provider = buildProvider(
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{
                'sources': <Map<String, dynamic>>[
                  sourceVariant('http://cdn.example-cdn.net/a.m3u8'),
                ],
              }),
        ),
      );

      expect(
        await captureFailure(() => provider.resolve(testSeries, testEpisode)),
        isA<ProviderInvalidStream>(),
      );
      await provider.dispose();
    });

    test('T-B23 a variant on an undeclared host is dropped', () async {
      final ManifestStreamingProvider provider = buildProvider(
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{
                'sources': <Map<String, dynamic>>[
                  sourceVariant('https://evil.test/a.m3u8'),
                  sourceVariant('https://cdn.example-cdn.net/ok.m3u8'),
                ],
              }),
        ),
      );

      final EpisodeStream stream = await provider.resolve(
        testSeries,
        testEpisode,
      );
      await provider.dispose();

      expect(stream.variants, hasLength(1));
      expect(stream.variants.single.uri.host, 'cdn.example-cdn.net');
    });

    test(
      'T-B24 file, intent, data and about URLs never reach the player',
      () async {
        final ManifestStreamingProvider provider = buildProvider(
          transport: FakeManifestTransport(
            (ManifestTransportRequest _) =>
                FakeManifestResponse.json(<String, dynamic>{
                  'sources': <Map<String, dynamic>>[
                    sourceVariant('file:///etc/passwd'),
                    sourceVariant('intent://scan/#Intent;scheme=zxing;end'),
                    sourceVariant('data:text/html;base64,PHNjcmlwdD4='),
                    sourceVariant('about:blank'),
                    sourceVariant('javascript:alert(1)'),
                  ],
                }),
          ),
        );

        expect(
          await captureFailure(() => provider.resolve(testSeries, testEpisode)),
          isA<ProviderInvalidStream>(),
        );
        await provider.dispose();
      },
    );

    test('T-B25 variants sort by height and honour the preference', () async {
      final Map<String, dynamic> manifest = minimalManifest();
      final Map<String, dynamic> variants =
          ((manifest['requests'] as Map<String, dynamic>)['resolve']
                  as Map<String, dynamic>)['variants']
              as Map<String, dynamic>;
      (variants['map'] as Map<String, dynamic>)['isDefault'] = r'$.default';
      final ManifestStreamingProvider provider = buildProvider(
        manifest: manifest,
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{
                'sources': <Map<String, dynamic>>[
                  sourceVariant(
                    'https://cdn.example-cdn.net/360.m3u8',
                    height: 360,
                    label: '360p',
                  ),
                  sourceVariant(
                    'https://cdn.example-cdn.net/720.m3u8',
                    height: 720,
                    label: '720p',
                    isDefault: true,
                  ),
                  sourceVariant(
                    'https://cdn.example-cdn.net/1080.m3u8',
                    height: 1080,
                    label: '1080p',
                  ),
                ],
              }),
        ),
      );

      final EpisodeStream stream = await provider.resolve(
        testSeries,
        testEpisode,
      );
      await provider.dispose();

      expect(stream.variants, hasLength(3));
      expect(stream.bestVariant()?.height, 720);
      expect(stream.bestVariant(preferredHeight: 720)?.height, 720);
      expect(stream.bestVariant(preferredHeight: 900)?.height, 720);
      expect(stream.bestVariant(preferredHeight: 200)?.height, 360);
      expect(stream.protocol, StreamProtocol.hls);
    });

    test(
      'T-B26 no subtitle capability means no subtitle request and no tracks',
      () async {
        final FakeManifestTransport transport = FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{
                'sources': <Map<String, dynamic>>[
                  sourceVariant('https://cdn.example-cdn.net/a.m3u8'),
                ],
              }),
        );
        final ManifestStreamingProvider provider = buildProvider(
          transport: transport,
        );

        final EpisodeStream stream = await provider.resolve(
          testSeries,
          testEpisode,
        );
        await provider.dispose();

        expect(stream.subtitles, isEmpty);
        expect(stream.audioTracks, isEmpty);
        expect(transport.sent, hasLength(1));
      },
    );

    test('T-B27 subtitle tracks map label, language and default', () async {
      final ManifestStreamingProvider provider = buildProvider(
        manifest: fullManifest(),
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{
                'sources': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'quality': <String, dynamic>{
                      'label': '1080p',
                      'height': 1080,
                    },
                    'file': 'https://cdn.example-cdn.net/a.m3u8',
                    'type': 'hls',
                    'default': true,
                  },
                ],
                'tracks': <String, dynamic>{
                  'text': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'name': 'English',
                      'file': 'https://cdn.example-cdn.net/en.vtt',
                      'lang': 'en',
                      'default': true,
                    },
                    <String, dynamic>{
                      'name': 'Spanish',
                      'file': 'https://cdn.example-cdn.net/es.vtt',
                      'lang': 'es-CL',
                    },
                  ],
                  'audio': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'name': 'Japanese',
                      'lang': 'ja',
                      'default': true,
                    },
                  ],
                },
              }),
        ),
      );

      final EpisodeStream stream = await provider.resolve(
        seriesWithId('s1'),
        const ProviderEpisode(
          providerId: 'dev.example.full',
          seriesId: 's1',
          episodeId: 'e1',
          number: 1,
          title: 'Episode',
        ),
      );
      await provider.dispose();

      expect(stream.subtitles, hasLength(2));
      expect(stream.subtitles.first.label, 'English');
      expect(stream.subtitles.first.language, 'en');
      expect(stream.subtitles.first.isDefault, isTrue);
      expect(stream.subtitles[1].language, 'es-CL');
      expect(stream.audioTracks.single.label, 'Japanese');
      expect(stream.audioTracks.single.language, 'ja');
      expect(stream.variants.single.height, 1080);
      expect(stream.variants.single.protocol, StreamProtocol.hls);
    });

    test('T-B29 a subtitle with an empty URI is dropped alone', () async {
      final ManifestStreamingProvider provider = buildProvider(
        manifest: fullManifest(),
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{
                'sources': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'quality': <String, dynamic>{'label': '720p'},
                    'file': 'https://cdn.example-cdn.net/a.m3u8',
                  },
                ],
                'tracks': <String, dynamic>{
                  'text': <Map<String, dynamic>>[
                    <String, dynamic>{'name': 'Broken', 'file': ''},
                    <String, dynamic>{
                      'name': 'Working',
                      'file': 'https://cdn.example-cdn.net/en.vtt',
                    },
                  ],
                },
              }),
        ),
      );

      final EpisodeStream stream = await provider.resolve(
        seriesWithId('s1'),
        const ProviderEpisode(
          providerId: 'dev.example.full',
          seriesId: 's1',
          episodeId: 'e1',
          number: 1,
          title: 'Episode',
        ),
      );
      await provider.dispose();

      expect(stream.subtitles.single.label, 'Working');
      expect(stream.variants, hasLength(1));
    });
  });

  group('Status policy (T-B31–T-B33)', () {
    test(
      'T-B31 rate limiting carries the hinted delay and is not retried',
      () async {
        final FakeManifestTransport transport = FakeManifestTransport(
          (ManifestTransportRequest _) => FakeManifestResponse.json(
            <String, dynamic>{},
            status: 429,
            headers: <String, String>{'Retry-After': '30'},
          ),
        );
        final ManifestStreamingProvider provider = buildProvider(
          transport: transport,
        );

        final ProviderFailure failure = await captureFailure(
          () => provider.search('x'),
        );
        await provider.dispose();

        expect(failure, isA<ProviderRateLimited>());
        expect((failure as ProviderRateLimited).retryAfter.inSeconds, 30);
        expect(transport.sent, hasLength(1));
      },
    );

    test('T-B32 an absurd Retry-After is clamped', () async {
      final ManifestStreamingProvider provider = buildProvider(
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) => FakeManifestResponse.json(
            <String, dynamic>{},
            status: 429,
            headers: <String, String>{'Retry-After': '999999'},
          ),
        ),
      );

      final ProviderFailure failure = await captureFailure(
        () => provider.search('x'),
      );
      await provider.dispose();

      expect((failure as ProviderRateLimited).retryAfter.inSeconds, 300);
    });

    test('T-B33 451 is reported as geo-restricted', () async {
      final ManifestStreamingProvider provider = buildProvider(
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{}, status: 451),
        ),
      );

      expect(
        await captureFailure(() => provider.search('x')),
        isA<ProviderGeoRestricted>(),
      );
      await provider.dispose();
    });

    test('notFoundStatus produces ProviderNotFound, not a retry', () async {
      final Map<String, dynamic> manifest = minimalManifest();
      final Map<String, dynamic> search =
          (manifest['requests'] as Map<String, dynamic>)['search']
              as Map<String, dynamic>;
      search['notFoundStatus'] = <int>[404];
      final FakeManifestTransport transport = FakeManifestTransport(
        (ManifestTransportRequest _) =>
            FakeManifestResponse.json(<String, dynamic>{}, status: 404),
      );
      final ManifestStreamingProvider provider = buildProvider(
        manifest: manifest,
        transport: transport,
      );

      expect(
        await captureFailure(() => provider.search('x')),
        isA<ProviderNotFound>(),
      );
      await provider.dispose();
      expect(transport.sent, hasLength(1));
    });

    test('401 is an auth failure and is not retried', () async {
      final FakeManifestTransport transport = FakeManifestTransport(
        (ManifestTransportRequest _) =>
            FakeManifestResponse.json(<String, dynamic>{}, status: 401),
      );
      final ManifestStreamingProvider provider = buildProvider(
        transport: transport,
      );

      expect(
        await captureFailure(() => provider.search('x')),
        isA<ProviderAuthRejected>(),
      );
      await provider.dispose();
      expect(transport.sent, hasLength(1));
    });
  });

  group('Redirects and allowlist (T-B34–T-B37)', () {
    test('T-B34 a redirect inside the allowlist is followed', () async {
      final FakeManifestTransport transport = FakeManifestTransport((
        ManifestTransportRequest request,
      ) {
        if (request.uri.path == '/search') {
          return FakeManifestResponse.redirect('/search2?q=x');
        }
        return FakeManifestResponse.json(<String, dynamic>{
          'results': <Map<String, dynamic>>[
            <String, dynamic>{'id': 's1', 'title': 'Moved'},
          ],
        });
      });
      final ManifestStreamingProvider provider = buildProvider(
        transport: transport,
      );

      final List<ProviderSeries> results = await provider.search('x');
      await provider.dispose();

      expect(results.single.title, 'Moved');
      expect(transport.sent, hasLength(2));
      expect(transport.sent.last.uri.path, '/search2');
    });

    test('T-B35 a redirect outside the allowlist is refused before the second request', () async {
      final FakeManifestTransport transport = FakeManifestTransport(
        (ManifestTransportRequest _) =>
            FakeManifestResponse.redirect('https://evil.test/steal'),
      );
      final ManifestStreamingProvider provider = buildProvider(
        transport: transport,
      );

      final ProviderFailure failure = await captureFailure(
        () => provider.search('x'),
      );
      await provider.dispose();

      expect(failure, isA<ProviderOriginRejected>());
      expect(
        transport.sent.map((ManifestTransportRequest r) => r.uri.host),
        <String>['api.example.com'],
      );
    });

    test('T-B36 a redirect downgrade to HTTP is refused', () async {
      final ManifestStreamingProvider provider = buildProvider(
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.redirect('http://api.example.com/search'),
        ),
      );

      expect(
        await captureFailure(() => provider.search('x')),
        isA<ProviderOriginRejected>(),
      );
      await provider.dispose();
    });

    test('T-B37 redirect chains stop at maxRedirects', () async {
      final FakeManifestTransport transport = FakeManifestTransport(
        (ManifestTransportRequest _) => FakeManifestResponse.redirect('/loop'),
      );
      final ManifestStreamingProvider provider = buildProvider(
        transport: transport,
      );

      final ProviderFailure failure = await captureFailure(
        () => provider.search('x'),
      );
      await provider.dispose();

      expect(failure, isA<ProviderUpstreamError>());
      expect(failure.message, contains('too many times'));
      expect(transport.sent, hasLength(4)); // 3 hops + the refused one
    });

    test('a redirect drops credentials when the host changes', () async {
      final Map<String, dynamic> manifest = fullManifest();
      (manifest['net'] as Map<String, dynamic>)['origins'] = <String>[
        'https://api.example.com',
        'https://media.example.com',
      ];
      final FakeManifestTransport transport = FakeManifestTransport((
        ManifestTransportRequest request,
      ) {
        if (request.uri.host == 'api.example.com') {
          return FakeManifestResponse.redirect(
            'https://media.example.com/v2/search',
          );
        }
        return FakeManifestResponse.json(<String, dynamic>{
          'data': <String, dynamic>{'items': <Object?>[]},
        });
      });
      final ManifestStreamingProvider provider = buildProvider(
        manifest: manifest,
        transport: transport,
      );

      await provider.search('x');
      await provider.dispose();

      expect(transport.sent, hasLength(2));
      expect(
        transport.sent.first.headers.keys.map((String k) => k.toLowerCase()),
        contains('x-api-key'),
      );
      expect(
        transport.sent.last.headers.keys.map((String k) => k.toLowerCase()),
        isNot(contains('x-api-key')),
      );
    });
  });

  group('Secrets, redaction and hardening (T-B40, T-B45)', () {
    test('T-B40 a media URL never carries the API key', () async {
      final FakeManifestTransport transport = FakeManifestTransport(
        (ManifestTransportRequest _) =>
            FakeManifestResponse.json(<String, dynamic>{
              'sources': <Map<String, dynamic>>[
                <String, dynamic>{
                  'quality': <String, dynamic>{'label': '1080p'},
                  'file': 'https://cdn.example-cdn.net/a.m3u8',
                },
              ],
            }),
      );
      final ManifestStreamingProvider provider = buildProvider(
        manifest: fullManifest(),
        transport: transport,
      );

      final EpisodeStream stream = await provider.resolve(
        seriesWithId('s1'),
        const ProviderEpisode(
          providerId: 'dev.example.full',
          seriesId: 's1',
          episodeId: 'e1',
          number: 1,
          title: 'Episode',
        ),
      );
      await provider.dispose();

      expect(stream.headers, <String, String>{
        'Referer': 'https://example.com/',
      });
      expect(
        stream.headers.values.join(),
        isNot(contains(testConfig['apiKey']!)),
      );
      for (final StreamVariant variant in stream.variants) {
        expect(variant.uri.toString(), isNot(contains(testConfig['apiKey']!)));
      }
      // The API request itself did carry the declared header.
      expect(
        transport.sent.single.headers.values.join(),
        contains(testConfig['apiKey']!),
      );
    });

    test(
      'T-B45 a CRLF in a configured value is refused before sending',
      () async {
        final FakeManifestTransport transport = FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{
                'data': <String, dynamic>{'items': <Object?>[]},
              }),
        );
        final ManifestStreamingProvider provider = buildProvider(
          manifest: fullManifest(),
          config: <String, String>{
            'baseUrl': 'https://api.example.com',
            'apiKey': 'x\r\nX-Evil: 1',
          },
          transport: transport,
        );

        final ProviderFailure failure = await captureFailure(
          () => provider.search('x'),
        );
        await provider.dispose();

        expect(failure, isA<ProviderManifestInvalid>());
        expect(transport.sent, isEmpty);
        expect(failure.message, isNot(contains('X-Evil')));
        expect(failure.message, isNot(contains('\r')));
        expect(failure.message, isNot(contains('\n')));
      },
    );

    test('redaction hides queries and scrubs configured secrets', () {
      final Uri uri = Uri.parse(
        'https://api.example.com/v2/search?q=frieren&apiKey=unit-test-secret-value',
      );
      expect(
        ProviderRedaction.describeUri(uri),
        'https://api.example.com/v2/search?redacted',
      );
      expect(ProviderRedaction.describeUri(uri), isNot(contains('frieren')));

      expect(
        ProviderRedaction.scrub('token=unit-test-secret-value failed', <String>[
          testConfig['apiKey']!,
        ]),
        'token=*** failed',
      );
      expect(
        ProviderRedaction.describeHeaders(<String, String>{'X-Api-Key': 'abc'}),
        <String, String>{'X-Api-Key': '***'},
      );
    });

    test('a 500 message never contains the credential', () async {
      final FakeManifestTransport transport = FakeManifestTransport(
        (ManifestTransportRequest _) =>
            FakeManifestResponse.json(<String, dynamic>{}, status: 500),
      );
      final ManifestStreamingProvider provider = buildProvider(
        manifest: fullManifest(),
        transport: transport,
      );

      final ProviderFailure failure = await captureFailure(
        () => provider.search('x'),
      );
      await provider.dispose();

      expect(leaksSecret(failure.message), isFalse);
      expect(leaksSecret(failure.toString()), isFalse);
    });
  });

  group('Pacing, cancellation and disposal (T-B41, T-B43)', () {
    test('T-B41 requests are paced per provider', () async {
      final List<Duration> delays = <Duration>[];
      final Map<String, dynamic> manifest = minimalManifest();
      (manifest['net'] as Map<String, dynamic>)['minRequestIntervalMs'] = 300;
      final ManifestStreamingProvider provider = buildProvider(
        manifest: manifest,
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) => FakeManifestResponse.json(
            <String, dynamic>{'results': <Object?>[]},
          ),
        ),
        delay: (Duration duration) async => delays.add(duration),
        clock: () => DateTime.utc(2026, 1, 1),
      );

      await provider.search('a');
      await provider.search('b');
      await provider.dispose();

      expect(delays, hasLength(1));
      expect(delays.single, const Duration(milliseconds: 300));
    });

    test('T-B43 dispose cancels in-flight work and is idempotent', () async {
      final FakeManifestTransport transport = FakeManifestTransport(
        (ManifestTransportRequest _) => FakeManifestResponse.never(),
      );
      final ManifestStreamingProvider provider = buildProvider(
        transport: transport,
      );

      final Future<List<ProviderSeries>> inFlight = provider.search('x');
      await provider.dispose();
      await expectLater(inFlight, throwsA(isA<ProviderCancelled>()));
      expect(transport.closed, isTrue);

      // A second dispose must not throw, and later calls are refused.
      await provider.dispose();
      expect(
        await captureFailure(() => provider.search('x')),
        isA<ProviderCancelled>(),
      );
    });

    test('the concurrency gate admits at most its capacity', () async {
      final ManifestRequestGate gate = ManifestRequestGate(2);
      int active = 0;
      int peak = 0;

      Future<void> task() {
        return gate.run<void>(() async {
          active++;
          peak = active > peak ? active : peak;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          active--;
        });
      }

      await Future.wait<void>(<Future<void>>[task(), task(), task(), task()]);
      expect(peak, 2);
      expect(gate.active, 0);
    });
  });

  group('Probe and configuration', () {
    test(
      'a manifest without a probe section checks connectivity only',
      () async {
        final FakeManifestTransport transport = FakeManifestTransport((
          ManifestTransportRequest request,
        ) {
          expect(request.uri.path, '/');
          return FakeManifestResponse.json(<String, dynamic>{});
        });
        final ManifestStreamingProvider provider = buildProvider(
          transport: transport,
        );

        final ProviderStatusSnapshot snapshot = await provider.probe();
        await provider.dispose();

        expect(snapshot.availability, ProviderAvailability.ready);
        expect(transport.sent, hasLength(1));
      },
    );

    test('a probe failure is reported, never thrown', () async {
      final ManifestStreamingProvider provider = buildProvider(
        manifest: fullManifest(),
        transport: FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{}, status: 401),
        ),
      );

      final ProviderStatusSnapshot snapshot = await provider.probe();
      await provider.dispose();

      expect(snapshot.availability, ProviderAvailability.unavailable);
      expect(snapshot.message, contains('sign-in'));
      expect(snapshot.actionHint, contains('credentials'));
    });

    test(
      'missing required configuration is a setup state, not a request',
      () async {
        final FakeManifestTransport transport = FakeManifestTransport(
          (ManifestTransportRequest _) =>
              FakeManifestResponse.json(<String, dynamic>{
                'data': <String, dynamic>{'items': <Object?>[]},
              }),
        );
        final ManifestStreamingProvider provider = buildProvider(
          manifest: fullManifest(),
          config: const <String, String>{'baseUrl': 'https://api.example.com'},
          transport: transport,
        );

        final ProviderStatusSnapshot snapshot = await provider.probe();
        expect(snapshot.availability, ProviderAvailability.unavailable);
        expect(snapshot.message, contains('Setup required'));

        expect(
          await captureFailure(() => provider.search('x')),
          isA<ProviderNotConfigured>(),
        );
        await provider.dispose();
        expect(transport.sent, isEmpty);
      },
    );
  });

  group('Loading and isolation', () {
    test('one broken manifest does not affect the others', () {
      const ManifestProviderFactory factory = ManifestProviderFactory();
      final List<String> documents = <String>[
        manifestExample('valid-minimal.json'),
        '{ this is not json',
        manifestExample('valid-full.json'),
      ];
      final List<ManifestProviderLoad> loads = <ManifestProviderLoad>[
        for (final String document in documents) factory.create(document),
      ];

      expect(loads[0].isUsable, isTrue);
      expect(loads[0].provider!.id, 'dev.example.minimal');
      expect(loads[1].isUsable, isFalse);
      expect(loads[1].failure, isA<ProviderManifestInvalid>());
      expect(loads[2].isUsable, isTrue);
      expect(loads[2].provider!.id, 'dev.example.full');
    });

    test('the factory reports the validation rows for an invalid document', () {
      const ManifestProviderFactory factory = ManifestProviderFactory();
      final ManifestProviderLoad load = factory.create(
        manifestExample('invalid-unbacked-capability.json'),
      );

      expect(load.isUsable, isFalse);
      expect(load.errors, isNotEmpty);
      expect(load.status.name, 'invalid');
      expect(load.failure!.providerId, 'manifest');
    });

    test(
      'a manifest provider resolves like a built-in at the resolver',
      () async {
        final ManifestStreamingProvider provider = buildProvider(
          transport: FakeManifestTransport((ManifestTransportRequest request) {
            if (request.uri.path == '/') {
              return FakeManifestResponse.json(<String, dynamic>{});
            }
            return FakeManifestResponse.json(<String, dynamic>{
              'results': <Map<String, dynamic>>[
                <String, dynamic>{'id': 's1', 'title': 'Frieren'},
              ],
            });
          }),
        );

        final ProviderResolver resolver = ProviderResolver(
          registry: StreamingProviderRegistry(<StreamingProvider>[provider]),
          records: <ProviderRecord>[
            ProviderRecord(
              providerId: 'dev.example.minimal',
              origin: ProviderOrigin.userAdded,
              enabled: true,
              priority: 0,
              installedAt: DateTime.utc(2026, 1, 1),
              config: <String, String>{'baseUrl': 'https://api.example.com'},
            ),
          ],
        );

        final SourceLookup lookup = await resolver.lookup(
          const Anime(id: 1, title: 'Frieren'),
        );
        await provider.dispose();

        expect(lookup.hasSource, isTrue);
        expect(lookup.resolution!.provider.id, 'dev.example.minimal');
        expect(lookup.resolution!.series.seriesId, 's1');
        expect(lookup.failures, isEmpty);
      },
    );
  });
}
