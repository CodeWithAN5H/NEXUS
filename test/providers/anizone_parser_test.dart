import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/integrations/streaming/anizone/anizone_parser.dart';

/// Every fixture is a captured response from 20 Nov 2026, with the payload
/// bytes left exactly as AniZone served them.
String _fixture(String name) =>
    File('test/fixtures/anizone/$name').readAsStringSync();

void main() {
  group('JavaScript JSON argument decoding', () {
    test('decodes \\u0022-escaped quotes', () {
      expect(
        decodeJsonArgument(r'{\u0022slug\u0022:\u0022spjuxray\u0022}'),
        '{"slug":"spjuxray"}',
      );
    });

    test('keeps a doubly escaped sequence literal', () {
      // `\\u0022` is a backslash-u sequence *inside* the JSON string, not a
      // quote, so it must survive as text.
      expect(
        decodeJsonArgument(r'{\u0022a\u0022:\u0022x\\u0022y\u0022}'),
        r'{"a":"x\u0022y"}',
      );
    });

    test('normalises every form of escaped slash', () {
      expect(normaliseUrl(r'https:\/\/a.test\/p'), 'https://a.test/p');
      expect(normaliseUrl(r'https:\\/\\/a.test'), 'https://a.test');
      expect(normaliseUrl('  https://a.test/x  '), 'https://a.test/x');
    });

    test('parses duration text and rejects nonsense', () {
      expect(parseDuration('23:37'), const Duration(minutes: 23, seconds: 37));
      expect(
        parseDuration('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(parseDuration(''), isNull);
      expect(parseDuration('soon'), isNull);
      expect(parseDuration('1:2:3:4'), isNull);
    });
  });

  group('search page', () {
    late List<AniZoneEntry> entries;

    setUp(() {
      entries = parseSearchItems(_fixture('search_naruto.html'));
    });

    test('extracts every entry with its identity', () {
      expect(
        entries.map((AniZoneEntry entry) => entry.slug),
        containsAll(<String>['bsagbos2', 'spjuxray', 'dkpkuwbc']),
      );
    });

    test('maps title, year, format, episode count and cover', () {
      final AniZoneEntry naruto = entries.firstWhere(
        (AniZoneEntry entry) => entry.slug == 'spjuxray',
      );
      expect(naruto.title, 'Naruto');
      expect(naruto.year, 2002);
      expect(naruto.format, 'TV Series');
      expect(naruto.episodeCount, 220);
      expect(naruto.coverImage, startsWith('https://'));
      expect(naruto.titles, contains('Naruto'));
    });

    test('keeps sequel identities distinct', () {
      final Set<String> slugs = entries
          .map((AniZoneEntry entry) => entry.slug)
          .toSet();
      expect(slugs.contains('bsagbos2'), isTrue); // Boruto (2017)
      expect(slugs.contains('dkpkuwbc'), isTrue); // Shippuuden (2007)
      expect(slugs.contains('spjuxray'), isTrue); // Naruto (2002)
    });

    test('a page without the payload is a failure, not an empty result', () {
      expect(
        () => parseSearchItems('<html><body>maintenance</body></html>'),
        throwsA(isA<AniZonePayloadException>()),
      );
    });
  });

  group('series page', () {
    late AniZoneSeriesPage page;

    setUp(() {
      page = parseSeriesPage(_fixture('series_naruto.html'));
    });

    test('reads the first 24 episodes in order', () {
      expect(page.episodes.length, 24);
      expect(
        page.episodes.map((AniZoneEpisode episode) => episode.number),
        orderedEquals(<int>[for (int i = 1; i <= 24; i++) i]),
      );
    });

    test('maps title, duration and thumbnail', () {
      final AniZoneEpisode first = page.episodes.first;
      expect(first.number, 1);
      expect(first.title, isNotEmpty);
      expect(first.duration, const Duration(minutes: 23, seconds: 37));
      expect(first.thumbnail, anyOf(isNull, startsWith('https://')));
    });

    test('carries what the continuation needs', () {
      expect(page.hasMore, isTrue);
      expect(page.cursor, isNotEmpty);
      expect(page.csrfToken, isNotEmpty);
      expect(page.snapshot, contains('anime-detail'));
    });
  });

  group('Livewire continuation', () {
    test('reads episodes, cursor and snapshot from the dispatch', () {
      final AniZoneLivewirePage page = parseLivewirePage(
        _fixture('livewire_page2.json'),
      );
      expect(
        page.episodes.map((AniZoneEpisode episode) => episode.number),
        orderedEquals(<int>[25, 26, 27]),
      );
      expect(page.hasMore, isTrue);
      expect(page.cursor, isNotEmpty);
      expect(page.snapshot, isNotNull);
    });

    test('a response without components is a failure', () {
      expect(
        () => parseLivewirePage('{"components":[]}'),
        throwsA(isA<AniZonePayloadException>()),
      );
    });

    test('a response without the items-loaded dispatch is a failure', () {
      expect(
        () => parseLivewirePage(
          '{"components":[{"snapshot":"{}","effects":{"dispatches":[]}}]}',
        ),
        throwsA(isA<AniZonePayloadException>()),
      );
    });

    test('a non-JSON body is a failure', () {
      expect(
        () => parseLivewirePage('<html>nope</html>'),
        throwsA(isA<AniZonePayloadException>()),
      );
    });
  });

  group('episode page', () {
    late AniZoneEpisodeSource source;

    setUp(() {
      source = parseEpisodeSource(_fixture('episode_naruto_1.html'));
    });

    test('extracts the HLS master playlist over https', () {
      expect(source.master.scheme, 'https');
      expect(source.master.host, 'seiryuu.vid-cdn.xyz');
      expect(source.master.path, endsWith('/master.m3u8'));
    });

    test('maps SRT subtitles with language and default flag', () {
      expect(source.subtitles.length, 2);
      final AniZoneSubtitle english = source.subtitles.first;
      expect(english.format, 'srt');
      expect(english.language, 'en');
      expect(english.isDefault, isTrue);
      expect(english.uri.scheme, 'https');
      expect(english.label, contains('English'));
    });

    test('reads chapter and storyboard tracks when present', () {
      expect(source.chapters, isNotNull);
      expect(source.storyboard, isNotNull);
    });

    test('a page without a player payload is a failure', () {
      expect(
        () => parseEpisodeSource('<div id="player"></div>'),
        throwsA(isA<AniZonePayloadException>()),
      );
    });

    test('a payload without a stream URL is a failure', () {
      expect(
        () => parseEpisodeSource(
          r'''<div x-data="vidstackPlayer(JSON.parse('{\u0022src\u0022:null}'))"></div>''',
        ),
        throwsA(isA<AniZonePayloadException>()),
      );
    });

    test('a non-https stream URL is refused', () {
      expect(
        () => parseEpisodeSource(
          r'''<div x-data="vidstackPlayer(JSON.parse('{\u0022src\u0022:\u0022http:\\\/\\\/evil.test\\\/a.m3u8\u0022}'))"></div>''',
        ),
        throwsA(isA<AniZonePayloadException>()),
      );
    });

    test('subtitles without a usable URL are dropped, not faked', () {
      final AniZoneEpisodeSource parsed = parseEpisodeSource(
        r'''<div x-data="vidstackPlayer(JSON.parse('{\u0022src\u0022:\u0022https:\\\/\\\/cdn.test\\\/a.m3u8\u0022,\u0022subtitles\u0022:[{\u0022title\u0022:\u0022Bad\u0022,\u0022file\u0022:\u0022javascript:alert(1)\u0022}]}'))"></div>''',
      );
      expect(parsed.subtitles, isEmpty);
    });
  });

  group('HLS master playlist', () {
    late AniZoneMasterPlaylist master;

    setUp(() {
      master = parseMasterPlaylist(
        _fixture('master.m3u8'),
        masterUri: Uri.parse(
          'https://seiryuu.vid-cdn.xyz/b0209a18/master.m3u8',
        ),
      );
    });

    test('reads every video rendition with its height', () {
      expect(
        master.renditions.map((AniZoneRendition rendition) => rendition.height),
        orderedEquals(<int>[360, 720, 1080]),
      );
      expect(master.maxHeight, 1080);
      expect(
        master.renditions.first.uri.path,
        endsWith('/video/360/playlist.m3u8'),
      );
    });

    test('reads the audio groups the player can switch between', () {
      expect(master.audioGroups.length, 2);
      expect(master.audioGroups.first.label, 'Japanese');
      expect(master.audioGroups.first.language, 'ja');
      expect(master.audioGroups.first.isDefault, isTrue);
      expect(master.audioGroups.last.label, 'English');
      expect(master.audioGroups.last.isDefault, isFalse);
    });

    test('a document that is not a playlist yields nothing', () {
      final AniZoneMasterPlaylist empty = parseMasterPlaylist(
        '<html>error</html>',
        masterUri: Uri.parse('https://cdn.test/a.m3u8'),
      );
      expect(empty.renditions, isEmpty);
      expect(empty.audioGroups, isEmpty);
      expect(empty.maxHeight, isNull);
    });

    test('a comma inside a quoted NAME does not split the attributes', () {
      final AniZoneMasterPlaylist parsed = parseMasterPlaylist(
        '#EXTM3U\n'
        '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="English, Dub",'
        'LANGUAGE="en",DEFAULT=NO\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=640x360\n'
        'v360.m3u8\n',
        masterUri: Uri.parse('https://cdn.test/x/master.m3u8'),
      );
      expect(parsed.audioGroups.single.label, 'English, Dub');
      expect(parsed.renditions.single.height, 360);
      expect(
        parsed.renditions.single.uri.toString(),
        'https://cdn.test/x/v360.m3u8',
      );
    });
  });
}
