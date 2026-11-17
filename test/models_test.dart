import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/data/models/app_settings.dart';
import 'package:nexus/data/models/explore_filter.dart';
import 'package:nexus/data/models/library.dart';

Map<String, dynamic> aniListMediaFixture({
  Map<String, dynamic>? title,
  int? episodes = 12,
  String? status = 'RELEASING',
}) {
  return <String, dynamic>{
    'id': 154587,
    'title':
        title ??
        <String, dynamic>{
          'romaji': 'Sousou no Frieren',
          'english': "Frieren: Beyond Journey's End",
          'native': '葬送のフリーレン',
        },
    'coverImage': <String, dynamic>{
      'extraLarge': 'https://img.example/xl.jpg',
      'large': 'https://img.example/l.jpg',
      'color': '#8a6fd1',
    },
    'bannerImage': 'https://img.example/banner.jpg',
    'averageScore': 93,
    'popularity': 782000,
    'favourites': 41000,
    'format': 'TV',
    'status': status,
    'season': 'FALL',
    'seasonYear': 2023,
    'episodes': episodes,
    'duration': 24,
    'genres': <String>['Adventure', 'Drama', 'Fantasy'],
    'description': '<i>A mage</i> reflects on her journey.',
    'siteUrl': 'https://anilist.co/anime/154587',
    'isAdult': false,
    'studios': <String, dynamic>{
      'nodes': <dynamic>[
        <String, dynamic>{'name': 'Madhouse'},
      ],
    },
    'nextAiringEpisode': <String, dynamic>{
      'episode': 8,
      'airingAt': 1765000000,
      'timeUntilAiring': 172800,
    },
    'relations': <String, dynamic>{
      'edges': <dynamic>[
        <String, dynamic>{
          'relationType': 'SEQUEL',
          'node': <String, dynamic>{
            'id': 163132,
            'type': 'ANIME',
            'format': 'TV',
            'title': <String, dynamic>{
              'romaji': 'Frieren 2nd Season',
              'english': 'Frieren Season 2',
            },
            'coverImage': <String, dynamic>{
              'large': 'https://img.example/rel.jpg',
              'medium': 'https://img.example/rel-m.jpg',
            },
          },
        },
      ],
    },
  };
}

void main() {
  group('Anime.fromAniList', () {
    test('maps the fields the UI renders', () {
      final Anime anime = Anime.fromAniList(aniListMediaFixture());

      expect(anime.id, 154587);
      expect(anime.displayTitle, "Frieren: Beyond Journey's End");
      expect(anime.coverImage, 'https://img.example/xl.jpg');
      expect(anime.bannerImage, 'https://img.example/banner.jpg');
      expect(anime.coverColor, '#8a6fd1');
      expect(anime.averageScore, 93);
      expect(anime.episodes, 12);
      expect(anime.duration, 24);
      expect(anime.genres, contains('Fantasy'));
      expect(anime.studios, <String>['Madhouse']);
      expect(anime.seasonYear, 2023);
      expect(anime.statusLabel, 'Releasing');
    });

    test('falls back through title candidates', () {
      final Anime anime = Anime.fromAniList(
        aniListMediaFixture(
          title: <String, dynamic>{
            'romaji': 'Romaji Only',
            'english': '',
            'native': null,
          },
        ),
      );
      expect(anime.displayTitle, 'Romaji Only');
    });

    test('survives missing and malformed fields', () {
      final Anime anime = Anime.fromAniList(<String, dynamic>{
        'id': 1,
        'title': <String, dynamic>{},
        'genres': 'not-a-list',
        'episodes': 'unknown',
      });
      expect(anime.id, 1);
      expect(anime.displayTitle, 'Untitled');
      expect(anime.genres, isEmpty);
      expect(anime.episodes, isNull);
      expect(anime.averageScore, isNull);
    });

    test('parses relations and the next airing episode', () {
      final Anime anime = Anime.fromAniList(aniListMediaFixture());
      expect(anime.relations, hasLength(1));
      expect(anime.relations.first.relationLabel, 'Sequel');
      expect(anime.relations.first.title, 'Frieren Season 2');
      expect(anime.nextEpisode?.episode, 8);
      expect(anime.nextEpisode?.daysUntil, 2);
    });

    test('builds alternative titles without duplicating the display title', () {
      final Anime anime = Anime.fromAniList(aniListMediaFixture());
      expect(anime.alternativeTitles, contains('Sousou no Frieren'));
      expect(anime.alternativeTitles, contains('葬送のフリーレン'));
      expect(
        anime.alternativeTitles.map((String t) => t.toLowerCase()),
        isNot(contains(anime.displayTitle.toLowerCase())),
      );
    });

    test('labels release state for non-releasing titles', () {
      expect(
        Anime.fromAniList(aniListMediaFixture(status: 'FINISHED')).releaseLabel,
        'Finished',
      );
      expect(
        Anime.fromAniList(aniListMediaFixture(status: 'NOT_YET_RELEASED'))
            .releaseLabel,
        'Upcoming',
      );
    });
  });

  group('ExploreFilter', () {
    test('toggles genres on and off', () {
      const ExploreFilter filter = ExploreFilter();
      final ExploreFilter withAction = filter.toggleGenre('Action');
      expect(withAction.genres, <String>{'Action'});
      expect(withAction.toggleGenre('Action').genres, isEmpty);
    });

    test('counts active facets', () {
      final ExploreFilter filter = const ExploreFilter()
          .toggleGenre('Drama')
          .copyWith(year: 2020, season: AnimeSeason.winter);
      expect(filter.activeFacetCount, 3);
      expect(filter.hasActiveFilters, isTrue);
      expect(filter.isDefault, isFalse);
    });

    test('clears filters while keeping the sort order', () {
      final ExploreFilter filter = const ExploreFilter()
          .toggleGenre('Action')
          .copyWith(year: 2019, sort: ExploreSort.topRated);
      final ExploreFilter cleared = filter.cleared();
      expect(cleared.genres, isEmpty);
      expect(cleared.year, isNull);
      expect(cleared.sort, ExploreSort.topRated);
    });

    test('implements value equality', () {
      expect(
        const ExploreFilter().toggleGenre('Action'),
        const ExploreFilter().toggleGenre('Action'),
      );
      expect(
        const ExploreFilter().toggleGenre('Action'),
        isNot(const ExploreFilter().toggleGenre('Drama')),
      );
    });

    test('derives the current anime season from a date', () {
      expect(AnimeSeason.of(DateTime(2026, 2, 1)), AnimeSeason.winter);
      expect(AnimeSeason.of(DateTime(2026, 5, 1)), AnimeSeason.spring);
      expect(AnimeSeason.of(DateTime(2026, 8, 1)), AnimeSeason.summer);
      expect(AnimeSeason.of(DateTime(2026, 11, 1)), AnimeSeason.fall);
    });
  });

  group('Library models', () {
    test('maps stored status strings, defaulting to watching', () {
      expect(LibraryStatus.fromStorage('on_hold'), LibraryStatus.onHold);
      expect(
        LibraryStatus.fromStorage('plan_to_watch'),
        LibraryStatus.planToWatch,
      );
      expect(LibraryStatus.fromStorage('nonsense'), LibraryStatus.watching);
      expect(LibraryStatus.fromStorage(null), LibraryStatus.watching);
    });

    test('computes progress fractions safely', () {
      const LibraryEntry entry = LibraryEntry(
        animeId: 1,
        title: 'Test',
        status: LibraryStatus.watching,
        totalEpisodes: 12,
        watchedEpisodes: 6,
      );
      expect(entry.progressFraction, 0.5);
      expect(entry.isComplete, isFalse);

      const LibraryEntry unknownTotal = LibraryEntry(
        animeId: 2,
        title: 'Test',
        status: LibraryStatus.watching,
        watchedEpisodes: 4,
      );
      expect(unknownTotal.progressFraction, 0);
    });

    test('interprets near-complete watch progress', () {
      final WatchProgress progress = WatchProgress(
        animeId: 1,
        episodeNumber: 3,
        title: 'Test',
        position: Duration(minutes: 23, seconds: 30),
        duration: Duration(minutes: 24),
        updatedAt: DateTime(2026),
      );
      expect(progress.fraction, closeTo(0.979, 0.001));
      expect(progress.isNearlyFinished, isTrue);
      expect(progress.remaining.inSeconds, 30);
    });

    test('handles zero-length durations without dividing by zero', () {
      final WatchProgress progress = WatchProgress(
        animeId: 1,
        episodeNumber: 1,
        title: 'Test',
        position: Duration.zero,
        duration: Duration.zero,
        updatedAt: DateTime(2026),
      );
      expect(progress.fraction, 0);
    });
  });

  group('AppSettings', () {
    test('round-trips through its storage map', () {
      const AppSettings settings = AppSettings(
        autoplayNext: false,
        rememberPosition: false,
        preferredQualityHeight: 720,
        subtitleSize: SubtitleSize.large,
        preferredAudioLanguage: 'ja',
        enabledProviderIds: <String>{'sample', 'other'},
        gridDensity: GridDensity.compact,
        reduceMotion: true,
      );
      final AppSettings restored = AppSettings.fromMap(settings.toMap());
      expect(restored.autoplayNext, isFalse);
      expect(restored.rememberPosition, isFalse);
      expect(restored.preferredQualityHeight, 720);
      expect(restored.subtitleSize, SubtitleSize.large);
      expect(restored.preferredAudioLanguage, 'ja');
      expect(restored.enabledProviderIds, <String>{'sample', 'other'});
      expect(restored.gridDensity, GridDensity.compact);
      expect(restored.reduceMotion, isTrue);
    });

    test('falls back to defaults for unknown values', () {
      final AppSettings restored = AppSettings.fromMap(<String, String>{
        AppSettings.keyQuality: 'nonsense',
        AppSettings.keySubtitleSize: 'huge',
        AppSettings.keyAutoplay: 'maybe',
      });
      expect(restored.preferredQualityHeight, 0);
      expect(restored.subtitleSize, SubtitleSize.medium);
      expect(restored.autoplayNext, isTrue);
    });

    test('clears the audio language explicitly', () {
      const AppSettings settings = AppSettings(preferredAudioLanguage: 'ja');
      expect(
        settings.copyWith(clearAudioLanguage: true).preferredAudioLanguage,
        isNull,
      );
    });
  });
}
