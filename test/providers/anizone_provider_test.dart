import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/database/nexus_database.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/data/repositories/provider_store.dart';
import 'package:nexus/integrations/providers/provider_descriptor.dart';
import 'package:nexus/integrations/providers/provider_failure.dart';
import 'package:nexus/integrations/providers/provider_record.dart';
import 'package:nexus/integrations/providers/provider_registry_bootstrap.dart';
import 'package:nexus/integrations/streaming/anizone/anizone_client.dart';
import 'package:nexus/integrations/streaming/anizone/anizone_provider.dart';
import 'package:nexus/integrations/streaming/streaming_provider.dart';

String _fixture(String name) =>
    File('test/fixtures/anizone/$name').readAsStringSync();

const Anime _naruto = Anime(
  id: 20,
  title: 'Naruto',
  romajiTitle: 'Naruto',
  englishTitle: 'Naruto',
  seasonYear: 2002,
  format: 'TV',
);

const Anime _shippuden = Anime(
  id: 1735,
  title: 'Naruto Shippuden',
  romajiTitle: 'Naruto: Shippuuden',
  englishTitle: 'Naruto Shippuden',
  seasonYear: 2007,
  format: 'TV',
);

/// A [AniZoneClient] that answers from fixtures and records what was asked.
class _FakeAniZoneClient extends AniZoneClient {
  _FakeAniZoneClient({
    this.searchPages = const <String, String>{},
    this.seriesPage,
    this.episodePage,
    this.playlist,
    this.continuation,
    this.searchError,
    this.seriesError,
    this.playlistError,
    this.continuationError,
  }) : super(minRequestInterval: Duration.zero, delay: (Duration _) async {});

  final Map<String, String> searchPages;
  final String? seriesPage;
  final String? episodePage;
  final String? playlist;
  final String? continuation;
  final ProviderFailure? searchError;
  final ProviderFailure? seriesError;
  final ProviderFailure? playlistError;
  final ProviderFailure? continuationError;

  int searchCalls = 0;
  int continuationCalls = 0;
  int closeCalls = 0;
  bool _closed = false;

  @override
  Future<String> fetchSearch(String query) async {
    searchCalls++;
    final ProviderFailure? failure = searchError;
    if (failure != null) throw failure;
    final String? body = searchPages[query];
    if (body == null) throw ProviderNotFound(providerId: providerId);
    return body;
  }

  @override
  Future<String> fetchSeriesPage(String slug) async {
    final ProviderFailure? failure = seriesError;
    if (failure != null) throw failure;
    final String? body = seriesPage;
    if (body == null) throw ProviderNotFound(providerId: providerId);
    return body;
  }

  @override
  Future<String> fetchEpisodePage(String slug, int episode) async {
    final String? body = episodePage;
    if (body == null) throw ProviderNotFound(providerId: providerId);
    return body;
  }

  @override
  Future<String> fetchPlaylist(Uri uri) async {
    final ProviderFailure? failure = playlistError;
    if (failure != null) throw failure;
    final String? body = playlist;
    if (body == null) throw ProviderNotFound(providerId: providerId);
    return body;
  }

  @override
  Future<String> fetchEpisodePageContinuation({
    required String slug,
    required String snapshot,
    required String csrfToken,
    required String cursor,
  }) async {
    continuationCalls++;
    final ProviderFailure? failure = continuationError;
    if (failure != null) throw failure;
    final String? body = continuation;
    if (body == null) throw ProviderNotFound(providerId: providerId);
    return body;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    closeCalls++;
  }
}

/// Builds the Livewire continuation the site returns, for pagination tests.
String _livewire({
  int start = 25,
  int count = 3,
  bool hasMore = false,
  String? cursor = 'cursor-3',
}) {
  return jsonEncode(<String, Object?>{
    'components': <Object?>[
      <String, Object?>{
        'snapshot': '{"memo":{"name":"pages.anime-detail"}}',
        'effects': <String, Object?>{
          'dispatches': <Object?>[
            <String, Object?>{
              'name': 'items-loaded',
              'params': <String, Object?>{
                'items': <Object?>[
                  for (int index = 0; index < count; index++)
                    <String, Object?>{
                      'slug': '${start + index}',
                      'url':
                          'http://anizone.to/anime/spjuxray/${start + index}',
                      'title_list': <String, Object?>{
                        '1': 'Episode ${start + index}',
                      },
                      'duration': '23:30',
                      'videos_count': 1,
                    },
                ],
                'nextCursor': hasMore ? cursor : null,
                'hasMore': hasMore,
              },
            },
          ],
        },
      },
    ],
  });
}

void main() {
  group('search', () {
    test('maps every entry onto the provider contract', () async {
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        searchPages: <String, String>{'Naruto': _fixture('search_naruto.html')},
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);

      final List<ProviderSeries> results = await provider.search(' Naruto ');

      expect(results.length, 3);
      final ProviderSeries naruto = results.firstWhere(
        (ProviderSeries series) => series.seriesId == 'spjuxray',
      );
      expect(naruto.providerId, 'anizone');
      expect(naruto.title, 'Naruto');
      expect(naruto.year, 2002);
      expect(naruto.coverImage, startsWith('https://'));
      expect(naruto.seasons, isEmpty);
    });

    test('later pages are empty rather than a duplicate first page', () async {
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        searchPages: <String, String>{'Naruto': _fixture('search_naruto.html')},
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);

      expect(await provider.search('Naruto', page: 2), isEmpty);
      expect(client.searchCalls, 0);
    });

    test('an empty query never reaches the network', () async {
      final _FakeAniZoneClient client = _FakeAniZoneClient();
      final AniZoneProvider provider = AniZoneProvider(client: client);

      expect(await provider.search('   '), isEmpty);
      expect(client.searchCalls, 0);
    });
  });

  group('matching', () {
    test('picks the exact title and year, not a sequel', () async {
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        searchPages: <String, String>{'Naruto': _fixture('search_naruto.html')},
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);

      final ProviderSeries? match = await provider.match(_naruto);

      expect(match, isNotNull);
      expect(match!.seriesId, 'spjuxray');
      expect(match.year, 2002);
    });

    test('matches a sequel to its own entry, not the original', () async {
      final String body = _fixture('search_naruto.html');
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        searchPages: <String, String>{
          'Naruto Shippuden': body,
          'Naruto: Shippuuden': body,
          'Naruto': body,
        },
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);

      final ProviderSeries? match = await provider.match(_shippuden);

      expect(match, isNotNull);
      expect(match!.seriesId, 'dkpkuwbc');
      expect(match.year, 2007);
    });

    test('a year that contradicts every candidate returns no match', () async {
      const Anime remake = Anime(
        id: 1,
        title: 'Naruto',
        seasonYear: 2015,
        format: 'TV',
      );
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        searchPages: <String, String>{'Naruto': _fixture('search_naruto.html')},
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);

      expect(await provider.match(remake), isNull);
    });

    test('equally plausible candidates are ambiguous, never a guess', () async {
      const String twoOfThem =
          r'''<div x-data="{ items: JSON.parse('[{\u0022slug\u0022:\u0022aaa\u0022,\u0022main_title\u0022:\u0022Naruto\u0022},{\u0022slug\u0022:\u0022bbb\u0022,\u0022main_title\u0022:\u0022Naruto\u0022}]') }"></div>''';
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        searchPages: <String, String>{'Naruto': twoOfThem},
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);

      expect(await provider.match(_naruto), isNull);
    });

    test('a different format is not matched', () async {
      const String movieOnly =
          r'''<div x-data="{ items: JSON.parse('[{\u0022slug\u0022:\u0022naruto-movie\u0022,\u0022main_title\u0022:\u0022Naruto\u0022,\u0022type\u0022:\u0022Movie\u0022}]') }"></div>''';
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        searchPages: <String, String>{'Naruto': movieOnly},
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);

      expect(await provider.match(_naruto), isNull);
    });

    test('nothing found is null, an unreachable source is a failure', () async {
      final _FakeAniZoneClient empty = _FakeAniZoneClient(
        searchPages: <String, String>{
          'Naruto': "<div x-data=\"{ items: JSON.parse('[]') }\"></div>",
        },
      );
      expect(await AniZoneProvider(client: empty).match(_naruto), isNull);

      final _FakeAniZoneClient broken = _FakeAniZoneClient(
        searchError: const ProviderUpstreamError(
          providerId: 'anizone',
          message: 'down',
        ),
      );
      expect(
        AniZoneProvider(client: broken).match(_naruto),
        throwsA(isA<ProviderUpstreamError>()),
      );
    });

    test('a changed page is reported as a parse failure', () async {
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        searchPages: <String, String>{'Naruto': '<html>revamped</html>'},
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);

      expect(provider.match(_naruto), throwsA(isA<ProviderParseFailure>()));
    });

    test('season data is declared unsupported, not invented', () async {
      final AniZoneProvider provider = AniZoneProvider(
        client: _FakeAniZoneClient(),
      );
      expect(
        provider.seasons(
          const ProviderSeries(
            providerId: 'anizone',
            seriesId: 'spjuxray',
            title: 'Naruto',
          ),
        ),
        throwsA(isA<ProviderUnsupported>()),
      );
    });
  });

  group('episodes', () {
    const ProviderSeries narutoSeries = ProviderSeries(
      providerId: 'anizone',
      seriesId: 'spjuxray',
      title: 'Naruto',
      year: 2002,
    );

    test('paginates, de-duplicates and orders', () async {
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        seriesPage: _fixture('series_naruto.html'),
        continuation: _livewire(start: 25, count: 3),
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);

      final List<ProviderEpisode> episodes = await provider.episodes(
        narutoSeries,
      );

      expect(episodes.length, 27);
      expect(client.continuationCalls, 1);
      expect(
        episodes.map((ProviderEpisode episode) => episode.number),
        orderedEquals(<int>[for (int i = 1; i <= 27; i++) i]),
      );
      expect(episodes.first.providerId, 'anizone');
      expect(episodes.first.episodeId, '1');
      expect(episodes.first.duration, const Duration(minutes: 23, seconds: 37));
      expect(provider.episodeNotice('spjuxray'), isNull);
    });

    test('an overlapping page does not duplicate an episode', () async {
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        seriesPage: _fixture('series_naruto.html'),
        continuation: _livewire(start: 24, count: 2),
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);

      final List<ProviderEpisode> episodes = await provider.episodes(
        narutoSeries,
      );

      expect(episodes.length, 25);
      expect(
        episodes
            .map((ProviderEpisode episode) => episode.number)
            .toSet()
            .length,
        25,
      );
    });

    test(
      'a failing later page returns what it has, with an honest note',
      () async {
        final _FakeAniZoneClient client = _FakeAniZoneClient(
          seriesPage: _fixture('series_naruto.html'),
          continuationError: const ProviderUpstreamError(
            providerId: 'anizone',
            status: 502,
          ),
        );
        final AniZoneProvider provider = AniZoneProvider(client: client);

        final List<ProviderEpisode> episodes = await provider.episodes(
          narutoSeries,
        );

        expect(episodes.length, 24);
        final String? notice = provider.episodeNotice('spjuxray');
        expect(notice, isNotNull);
        expect(notice, contains('incomplete'));
        expect(notice, contains('24'));
      },
    );

    test('a page limit stops the walk and says so', () async {
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        seriesPage: _fixture('series_naruto.html'),
        continuation: _livewire(start: 25, count: 3, hasMore: true),
      );
      final AniZoneProvider provider = AniZoneProvider(
        client: client,
        maxEpisodePages: 1,
      );

      final List<ProviderEpisode> episodes = await provider.episodes(
        narutoSeries,
      );

      expect(episodes.length, 24);
      expect(client.continuationCalls, 0);
      expect(provider.episodeNotice('spjuxray'), contains('first 24 episodes'));
    });

    test(
      'a failure on the first page is a failure, not an empty list',
      () async {
        final AniZoneProvider provider = AniZoneProvider(
          client: _FakeAniZoneClient(
            seriesError: const ProviderUpstreamError(providerId: 'anizone'),
          ),
        );

        expect(
          provider.episodes(narutoSeries),
          throwsA(isA<ProviderUpstreamError>()),
        );
      },
    );
  });

  group('resolve', () {
    const ProviderSeries narutoSeries = ProviderSeries(
      providerId: 'anizone',
      seriesId: 'spjuxray',
      title: 'Naruto',
    );
    const ProviderEpisode firstEpisode = ProviderEpisode(
      providerId: 'anizone',
      seriesId: 'spjuxray',
      episodeId: '1',
      number: 1,
      title: 'Enter: Naruto Uzumaki!',
    );

    test(
      'keeps the master playlist, its header, subtitles and audio groups',
      () async {
        final _FakeAniZoneClient client = _FakeAniZoneClient(
          episodePage: _fixture('episode_naruto_1.html'),
          playlist: _fixture('master.m3u8'),
        );
        final AniZoneProvider provider = AniZoneProvider(client: client);

        final EpisodeStream stream = await provider.resolve(
          narutoSeries,
          firstEpisode,
        );

        expect(stream.protocol, StreamProtocol.hls);
        expect(stream.headers['User-Agent'], AniZoneClient.defaultUserAgent);
        expect(stream.variants.length, 1);
        expect(stream.variants.single.isDefault, isTrue);
        expect(stream.variants.single.height, 1080);
        expect(stream.variants.single.label, 'Auto (up to 1080p)');
        expect(stream.variants.single.uri.host, 'seiryuu.vid-cdn.xyz');
        expect(
          stream.subtitles.map((SubtitleTrackInfo track) => track.language),
          everyElement('en'),
        );
        expect(stream.subtitles.length, 2);
        expect(stream.subtitles.first.label, contains('English'));
        expect(stream.subtitles.first.isDefault, isTrue);
        expect(
          stream.audioTracks.map((AudioTrackInfo track) => track.label),
          orderedEquals(<String>['Japanese', 'English']),
        );
        expect(stream.audioTracks.first.isDefault, isTrue);
        expect(stream.notice, isNotNull);
        expect(stream.isSample, isFalse);
      },
    );

    test('an unreadable playlist still yields a playable master', () async {
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        episodePage: _fixture('episode_naruto_1.html'),
        playlistError: const ProviderUpstreamError(providerId: 'anizone'),
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);

      final EpisodeStream stream = await provider.resolve(
        narutoSeries,
        firstEpisode,
      );

      expect(stream.variants.single.label, 'Auto');
      expect(stream.variants.single.height, isNull);
      expect(stream.audioTracks, isEmpty);
      expect(stream.subtitles.length, 2);
    });

    test('a changed episode page is a parse failure', () async {
      final AniZoneProvider provider = AniZoneProvider(
        client: _FakeAniZoneClient(episodePage: '<div id="player"></div>'),
      );

      expect(
        provider.resolve(narutoSeries, firstEpisode),
        throwsA(isA<ProviderParseFailure>()),
      );
    });

    test('a missing episode is a not-found failure', () async {
      final AniZoneProvider provider = AniZoneProvider(
        client: _FakeAniZoneClient(),
      );

      expect(
        provider.resolve(narutoSeries, firstEpisode),
        throwsA(isA<ProviderNotFound>()),
      );
    });
  });

  group('probe and lifecycle', () {
    test('a healthy source is ready', () async {
      final AniZoneProvider provider = AniZoneProvider(
        client: _FakeAniZoneClient(
          searchPages: <String, String>{'a': _fixture('search_naruto.html')},
        ),
      );

      final ProviderStatusSnapshot snapshot = await provider.probe();

      expect(snapshot.availability, ProviderAvailability.ready);
      expect(snapshot.canServe, isTrue);
      expect(snapshot.message, isNotEmpty);
    });

    test('a failing source is unavailable and never throws', () async {
      final AniZoneProvider provider = AniZoneProvider(
        client: _FakeAniZoneClient(
          searchError: const ProviderTimeout(providerId: 'anizone'),
        ),
      );

      final ProviderStatusSnapshot snapshot = await provider.probe();

      expect(snapshot.availability, ProviderAvailability.unavailable);
      expect(snapshot.canServe, isFalse);
    });

    test('dispose closes the client once and forgets notices', () async {
      final _FakeAniZoneClient client = _FakeAniZoneClient();
      final AniZoneProvider provider = AniZoneProvider(client: client);

      await provider.dispose();
      await provider.dispose();

      expect(client.closeCalls, 1);
    });
  });

  group('registration', () {
    test(
      'is registered, compatible and does not replace the test library',
      () async {
        final registry = buildStreamingProviderRegistry();

        expect(registry.byId('anizone'), isA<AniZoneProvider>());
        expect(
          registry.compatibilityOf('anizone'),
          ProviderCompatibility.compatible,
        );
        expect(registry.byId('sample'), isNotNull);
        await registry.byId('anizone')!.dispose();
      },
    );

    test('a new installation starts with AniZone disabled', () async {
      final NexusDatabase db = NexusDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final ProviderStore store = ProviderStore(db);
      final registry = buildStreamingProviderRegistry();

      await store.syncBuiltIns(
        registry.all,
        enabledIds: const <String>{'sample'},
      );
      final List<ProviderRecord> records = await store.loadAll();

      final ProviderRecord anizone = records.firstWhere(
        (ProviderRecord record) => record.providerId == 'anizone',
      );
      expect(anizone.enabled, isFalse);
      expect(anizone.origin, ProviderOrigin.builtIn);
      final ProviderRecord sample = records.firstWhere(
        (ProviderRecord record) => record.providerId == 'sample',
      );
      expect(sample.enabled, isTrue);
      await registry.byId('anizone')!.dispose();
    });
  });

  group('selected-episode fast path', () {
    test('AniZone describes a number without touching the network', () async {
      // The client fails every request: success proves nothing was fetched.
      final _FakeAniZoneClient client = _FakeAniZoneClient(
        seriesError: const ProviderUpstreamError(
          providerId: 'anizone',
          message: 'offline',
        ),
        playlistError: const ProviderUpstreamError(
          providerId: 'anizone',
          message: 'offline',
        ),
      );
      final AniZoneProvider provider = AniZoneProvider(client: client);
      const ProviderSeries series = ProviderSeries(
        providerId: 'anizone',
        seriesId: 'spjuxray',
        title: 'Naruto',
      );

      final ProviderEpisode? episode = await provider.episodeByNumber(
        series,
        42,
      );

      expect(episode, isNotNull);
      expect(episode!.number, 42);
      expect(episode.episodeId, '42');
      expect(episode.seriesId, 'spjuxray');
      expect(episode.providerId, 'anizone');
      expect(client.continuationCalls, 0);
    });

    test('providers without a fast path ask for the full list', () async {
      final registry = buildStreamingProviderRegistry();
      final sample = registry.byId('sample')!;

      expect(
        await sample.episodeByNumber(
          const ProviderSeries(
            providerId: 'sample',
            seriesId: 'series-1',
            title: 'Sample',
          ),
          1,
        ),
        isNull,
      );
      await sample.dispose();
    });
  });
}
