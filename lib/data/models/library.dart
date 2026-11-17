/// User-owned state: library entries and resumable watch progress.
library;

/// The five library buckets shown in the reference design.
enum LibraryStatus {
  watching('watching', 'Watching'),
  completed('completed', 'Completed'),
  onHold('on_hold', 'On Hold'),
  dropped('dropped', 'Dropped'),
  planToWatch('plan_to_watch', 'Plan to Watch');

  const LibraryStatus(this.storageValue, this.label);

  /// Stable identifier written to SQLite. Never change these strings without a
  /// database migration.
  final String storageValue;

  /// Human-readable tab label.
  final String label;

  static LibraryStatus fromStorage(String? value) {
    for (final LibraryStatus status in LibraryStatus.values) {
      if (status.storageValue == value) return status;
    }
    return LibraryStatus.watching;
  }
}

/// A title the user has saved, with local viewing progress.
class LibraryEntry {
  const LibraryEntry({
    required this.animeId,
    required this.title,
    required this.status,
    this.coverImage,
    this.bannerImage,
    this.animeScore,
    this.totalEpisodes,
    this.watchedEpisodes = 0,
    this.userScore,
    this.format,
    this.seasonYear,
    this.createdAt,
    this.updatedAt,
  });

  final int animeId;
  final String title;
  final LibraryStatus status;
  final String? coverImage;
  final String? bannerImage;

  /// AniList average score (0-100) for display on cards.
  final int? animeScore;

  final int? totalEpisodes;

  /// Number of episodes the user has finished.
  final int watchedEpisodes;

  /// The user's own 0-100 rating.
  final int? userScore;

  final String? format;
  final int? seasonYear;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get progressFraction {
    final int? total = totalEpisodes;
    if (total == null || total <= 0) return 0;
    return (watchedEpisodes / total).clamp(0.0, 1.0);
  }

  bool get isComplete =>
      totalEpisodes != null && watchedEpisodes >= (totalEpisodes ?? 0);

  LibraryEntry copyWith({
    LibraryStatus? status,
    int? watchedEpisodes,
    int? userScore,
    int? totalEpisodes,
    DateTime? updatedAt,
  }) {
    return LibraryEntry(
      animeId: animeId,
      title: title,
      status: status ?? this.status,
      coverImage: coverImage,
      bannerImage: bannerImage,
      animeScore: animeScore,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      userScore: userScore ?? this.userScore,
      format: format,
      seasonYear: seasonYear,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A resumable playback position for one episode.
class WatchProgress {
  const WatchProgress({
    required this.animeId,
    required this.episodeNumber,
    required this.title,
    required this.position,
    required this.duration,
    required this.updatedAt,
    this.coverImage,
    this.bannerImage,
    this.totalEpisodes,
    this.episodeTitle,
    this.providerId,
    this.seriesId,
  });

  final int animeId;
  final int episodeNumber;
  final String title;
  final String? episodeTitle;
  final String? coverImage;
  final String? bannerImage;
  final int? totalEpisodes;

  /// Source that produced this position, so the rail can resume directly.
  final String? providerId;
  final String? seriesId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  double get fraction {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Remaining time, used for "12 min left" hints.
  Duration get remaining =>
      duration - position < Duration.zero ? Duration.zero : duration - position;

  /// Near the end — the player should offer the next episode instead of resuming.
  bool get isNearlyFinished => fraction >= 0.95;
}
