/// Everything the player needs to start a session.
///
/// The player never receives a raw URL: it asks the provider for streams, so
/// playback stays provider-agnostic and headers/qualities are applied uniformly.
class PlaybackRequest {
  const PlaybackRequest({
    required this.animeId,
    required this.animeTitle,
    required this.providerId,
    required this.seriesId,
    required this.episodeNumber,
    this.episodeTitle,
    this.coverImage,
    this.bannerImage,
    this.totalEpisodes,
    this.isSample = false,
  });

  /// Id used for local progress. AniList ids are positive; the built-in test
  /// library uses a negative namespace.
  final int animeId;

  final String animeTitle;
  final String providerId;
  final String seriesId;
  final int episodeNumber;
  final String? episodeTitle;
  final String? coverImage;
  final String? bannerImage;
  final int? totalEpisodes;

  /// True for the built-in playback test library, shown as a badge in the player.
  final bool isSample;

  String get label => 'Episode $episodeNumber';

  PlaybackRequest copyWith({
    int? episodeNumber,
    String? episodeTitle,
    String? seriesId,
  }) {
    return PlaybackRequest(
      animeId: animeId,
      animeTitle: animeTitle,
      providerId: providerId,
      seriesId: seriesId ?? this.seriesId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      coverImage: coverImage,
      bannerImage: bannerImage,
      totalEpisodes: totalEpisodes,
      isSample: isSample,
    );
  }
}
