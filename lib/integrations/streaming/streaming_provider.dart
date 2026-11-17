/// The provider abstraction every content source must implement.
///
/// The UI talks to [StreamingProvider] only. Adding, disabling or replacing a
/// provider must never require changes to the home, details or player screens.
library;

import '../../data/models/anime.dart';

/// Optional abilities a provider may implement.
///
/// A provider advertises what it supports up front so the UI can explain gaps
/// instead of failing at playback time.
enum ProviderCapability {
  search('Search'),
  seriesMatching('Title matching'),
  seasons('Season data'),
  episodes('Episode list'),
  streams('Video streams'),
  qualities('Quality selection'),
  subtitles('Subtitle tracks'),
  audioTracks('Audio tracks');

  const ProviderCapability(this.label);

  final String label;
}

/// Whether a provider can service requests right now.
enum ProviderAvailability {
  /// Fully usable.
  ready,

  /// Usable, but only for a small built-in catalogue (sample media).
  limited,

  /// Requires configuration (credentials, endpoint) before use.
  needsConfiguration,

  /// Temporarily failing.
  unavailable,
}

/// Snapshot of a provider's state for the source-management UI.
class ProviderStatus {
  const ProviderStatus({
    required this.availability,
    required this.message,
    this.actionHint,
  });

  final ProviderAvailability availability;

  /// One-line explanation shown in Settings → Sources.
  final String message;

  /// Optional next step for the user (e.g. "Add an API key").
  final String? actionHint;

  bool get isUsable =>
      availability == ProviderAvailability.ready ||
      availability == ProviderAvailability.limited;
}

/// A series as understood by a provider.
class ProviderSeries {
  const ProviderSeries({
    required this.providerId,
    required this.seriesId,
    required this.title,
    this.coverImage,
    this.synopsis,
    this.seasons = const <ProviderSeason>[],
  });

  final String providerId;
  final String seriesId;
  final String title;
  final String? coverImage;
  final String? synopsis;
  final List<ProviderSeason> seasons;

  bool get hasSeasons => seasons.isNotEmpty;
}

/// One season of a provider series.
class ProviderSeason {
  const ProviderSeason({
    required this.seriesId,
    required this.seasonId,
    required this.label,
    required this.index,
  });

  final String seriesId;
  final String seasonId;
  final String label;

  /// Zero-based ordering index.
  final int index;
}

/// One playable episode.
class ProviderEpisode {
  const ProviderEpisode({
    required this.providerId,
    required this.seriesId,
    required this.episodeId,
    required this.number,
    required this.title,
    this.seasonId,
    this.duration,
    this.thumbnail,
    this.description,
  });

  final String providerId;
  final String seriesId;
  final String episodeId;
  final int number;
  final String title;
  final String? seasonId;
  final Duration? duration;
  final String? thumbnail;
  final String? description;
}

/// Container/protocol of a resolved stream.
enum StreamProtocol { hls, dash, progressive }

/// A selectable quality of one episode.
class StreamVariant {
  const StreamVariant({
    required this.label,
    required this.uri,
    this.height,
    this.isDefault = false,
    this.protocol = StreamProtocol.hls,
  });

  /// Human label, e.g. `1080p`.
  final String label;
  final Uri uri;

  /// Vertical resolution when known — drives sorting and the quality menu.
  final int? height;
  final bool isDefault;
  final StreamProtocol protocol;
}

/// An external subtitle track.
class SubtitleTrackInfo {
  const SubtitleTrackInfo({
    required this.label,
    required this.uri,
    this.language,
    this.isDefault = false,
  });

  final String label;
  final Uri uri;
  final String? language;
  final bool isDefault;
}

/// A selectable audio track.
class AudioTrackInfo {
  const AudioTrackInfo({
    required this.label,
    this.language,
    this.isDefault = false,
  });

  final String label;
  final String? language;
  final bool isDefault;
}

/// Everything needed to start playback.
class EpisodeStream {
  const EpisodeStream({
    required this.variants,
    required this.protocol,
    this.subtitles = const <SubtitleTrackInfo>[],
    this.audioTracks = const <AudioTrackInfo>[],
    this.headers = const <String, String>{},
    this.isSample = false,
    this.notice,
  });

  final List<StreamVariant> variants;
  final StreamProtocol protocol;
  final List<SubtitleTrackInfo> subtitles;
  final List<AudioTrackInfo> audioTracks;

  /// Extra HTTP headers required by the origin (Referer, User-Agent…).
  final Map<String, String> headers;

  /// True when this is demo/public-domain media rather than catalogue content.
  /// The player surfaces this so sample playback is never mistaken for a real
  /// episode.
  final bool isSample;

  /// Optional line shown above the player controls.
  final String? notice;

  bool get isEmpty => variants.isEmpty;

  /// Variant matching [preferredHeight] as closely as possible (never above).
  StreamVariant? bestVariant({int? preferredHeight}) {
    if (variants.isEmpty) return null;
    if (preferredHeight == null) {
      return variants.firstWhere(
        (StreamVariant variant) => variant.isDefault,
        orElse: () => variants.first,
      );
    }
    final List<StreamVariant> sorted = <StreamVariant>[...variants]
      ..sort(
        (StreamVariant a, StreamVariant b) =>
            (b.height ?? 0).compareTo(a.height ?? 0),
      );
    for (final StreamVariant variant in sorted) {
      final int height = variant.height ?? 0;
      if (height <= preferredHeight) return variant;
    }
    return sorted.last;
  }
}

/// Raised when a provider cannot resolve a title or episode.
class ProviderException implements Exception {
  const ProviderException(this.message, {this.isRetryable = true});

  final String message;
  final bool isRetryable;

  @override
  String toString() => 'ProviderException: $message';
}

/// A replaceable source of episodes and streams.
///
/// Implementations must not fabricate content: if a capability is unsupported,
/// [capabilities] must say so and the corresponding method must throw
/// [ProviderException] rather than returning invented data.
abstract class StreamingProvider {
  /// Stable identifier persisted in preferences (`sample`, …).
  String get id;

  /// Display name.
  String get name;

  /// One-line description for the sources screen.
  String get description;

  /// Attribution/licence note shown where content is presented.
  String get attribution;

  /// What this provider can actually do.
  Set<ProviderCapability> get capabilities;

  /// Current readiness.
  ProviderStatus get status;

  /// Free-text search within the provider catalogue.
  Future<List<ProviderSeries>> search(String query);

  /// Attempts to match a metadata title to a provider series.
  /// Returns `null` when the provider has no matching entry.
  Future<ProviderSeries?> match(Anime anime);

  /// Seasons available for [series].
  Future<List<ProviderSeason>> seasons(ProviderSeries series);

  /// Episodes for [series], optionally limited to [seasonId].
  Future<List<ProviderEpisode>> episodes(
    ProviderSeries series, {
    String? seasonId,
  });

  /// Resolves playable streams for [episode].
  Future<EpisodeStream> resolve(ProviderSeries series, ProviderEpisode episode);
}

/// Convenience helpers so screens never branch on capability sets by hand.
extension StreamingProviderCapabilities on StreamingProvider {
  bool get supportsSearch => capabilities.contains(ProviderCapability.search);
  bool get supportsEpisodes =>
      capabilities.contains(ProviderCapability.episodes);
  bool get supportsStreams => capabilities.contains(ProviderCapability.streams);
  bool get supportsSeasons => capabilities.contains(ProviderCapability.seasons);
  bool get supportsSubtitles =>
      capabilities.contains(ProviderCapability.subtitles);
  bool get supportsAudioTracks =>
      capabilities.contains(ProviderCapability.audioTracks);
  bool get supportsQualities =>
      capabilities.contains(ProviderCapability.qualities);
}
