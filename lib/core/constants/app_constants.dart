/// Application-wide constants. Values that could reasonably change between
/// releases live here rather than being scattered through the UI.
abstract final class AppConstants {
  static const String appName = 'NEXUS';
  static const String tagline = 'Stream. Discover. Enjoy.';
  static const String appVersion = '0.2.0-alpha.2';
  static const int versionCode = 3;

  /// AniList GraphQL endpoint (metadata only — never video).
  static const String anilistEndpoint = 'https://graphql.anilist.co';
  static const String anilistSiteBase = 'https://anilist.co/anime/';

  /// Default page size for metadata requests.
  static const int defaultPageSize = 20;

  /// Network timeout applied to metadata requests.
  static const Duration networkTimeout = Duration(seconds: 25);

  /// File name of the local SQLite database (without extension).
  static const String databaseName = 'nexus';

  /// Current schema version of the local database. Bump together with a
  /// migration in `NexusDatabase.migration` — never in isolation.
  static const int databaseSchemaVersion = 2;

  /// How many items each home rail shows.
  static const int homeRailLength = 12;

  /// Minimum duration a continue-watching entry must have before it is offered
  /// as resumable progress.
  static const Duration minimumResumePosition = Duration(seconds: 15);
}
