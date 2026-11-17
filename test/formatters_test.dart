import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/utils/formatters.dart';
import 'package:nexus/core/utils/ids.dart';

void main() {
  group('Formatters.score', () {
    test('converts AniList 0-100 scores to one decimal', () {
      expect(Formatters.score(86), '8.6');
      expect(Formatters.score(100), '10.0');
      expect(Formatters.score(0), '0.0');
    });

    test('renders a dash for missing scores', () {
      expect(Formatters.score(null), '—');
    });
  });

  group('Formatters.clock', () {
    test('formats sub-hour positions as m:ss', () {
      expect(
        Formatters.clock(const Duration(minutes: 12, seconds: 34)),
        '12:34',
      );
      expect(Formatters.clock(const Duration(seconds: 5)), '0:05');
    });

    test('formats hour-long positions as h:mm:ss', () {
      expect(
        Formatters.clock(const Duration(hours: 1, minutes: 2, seconds: 44)),
        '1:02:44',
      );
    });

    test('clamps negative positions to zero', () {
      expect(Formatters.clock(const Duration(seconds: -30)), '0:00');
    });
  });

  group('Formatters.plainText', () {
    test('strips markup and decodes entities from AniList synopses', () {
      const String html =
          '<i>Frieren</i> continues her journey.<br><br>An elf&apos;s tale &amp; more';
      final String text = Formatters.plainText(html);
      expect(text, contains('Frieren continues her journey.'));
      expect(text, contains("An elf's tale & more"));
      expect(text, isNot(contains('<')));
      expect(text, isNot(contains('&apos;')));
    });

    test('converts paragraph breaks into blank lines', () {
      expect(
        Formatters.plainText('<p>First</p><p>Second</p>'),
        'First\n\nSecond',
      );
    });

    test('returns an empty string for null input', () {
      expect(Formatters.plainText(null), '');
    });
  });

  group('Formatters.season', () {
    test('title-cases the season and appends the year', () {
      expect(Formatters.season('SPRING', 2024), 'Spring 2024');
      expect(Formatters.season(null, 2020), '2020');
      expect(Formatters.season('FALL', null), 'Fall');
      expect(Formatters.season(null, null), '—');
    });
  });

  group('Formatters.relativeDate', () {
    final DateTime now = DateTime(2026, 5, 10, 12);

    test('describes recent times relatively', () {
      expect(
        Formatters.relativeDate(
          now.subtract(const Duration(seconds: 10)),
          now: now,
        ),
        'just now',
      );
      expect(
        Formatters.relativeDate(
          now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        '1 minute ago',
      );
      expect(
        Formatters.relativeDate(
          now.subtract(const Duration(hours: 3)),
          now: now,
        ),
        '3 hours ago',
      );
      expect(
        Formatters.relativeDate(
          now.subtract(const Duration(days: 2)),
          now: now,
        ),
        '2 days ago',
      );
    });
  });

  group('Formatters.progress / percent', () {
    test('formats episode progress', () {
      expect(Formatters.progress(3, 12), 'Ep 3 of 12');
      expect(Formatters.progress(3, null), 'Ep 3');
    });

    test('formats fractions as whole percentages and clamps', () {
      expect(Formatters.percent(0.655), '66%');
      expect(Formatters.percent(1.4), '100%');
      expect(Formatters.percent(-1), '0%');
    });
  });

  group('stable local ids', () {
    test('are deterministic, negative and distinct from AniList ids', () {
      final int first = localIdFor('provider-series', 'sample:playback-tests');
      final int second = localIdFor('provider-series', 'sample:playback-tests');
      expect(first, second);
      expect(first, lessThan(0));
      expect(isLocalId(first), isTrue);
      expect(localIdFor('provider-series', 'other'), isNot(first));
    });
  });
}
