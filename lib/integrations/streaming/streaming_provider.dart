/// The streaming provider abstraction every content source must implement.
///
/// The UI talks to [StreamingProvider] only. Adding, disabling or replacing a
/// provider must never require changes to the home, details or player screens.
library;

import '../../data/models/anime.dart';
import '../providers/provider_descriptor.dart';
import '../providers/provider_state.dart';

// The platform types a provider author needs are available from this file, so
// adapters do not import the whole platform layer.
export '../providers/provider_descriptor.dart'
    show
        MetadataCapability,
        ProviderCapability,
        ProviderConfigField,
        ProviderConfigType,
        ProviderContract,
        ProviderContractRange,
        ProviderKind,
        ProviderOrigin,
        ProviderPlatform;
export '../providers/provider_state.dart'
    show ProviderAvailability, ProviderStatusSnapshot;

/// A series as understood by a provider.
class ProviderSeries {
  const ProviderSeries({
    required this.providerId,
    required this.seriesId,
    required this.title,
    this.coverImage,
    this.synopsis,
    this.year,
    this.seasons = const <ProviderSeason>[],
  });

  final String providerId;
  final String seriesId;
  final String title;
  final String? coverImage;
  final String? synopsis;

  /// Release year when the provider declares one — used to stop a remake being
  /// served as the original.
  final int? year;
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

/// A replaceable source of episodes and streams.
///
/// Implementations must not fabricate content: if a capability is unsupported,
/// [capabilities] must say so and the corresponding method must throw
/// `ProviderUnsupported` rather than returning invented data.
///
/// Every failure crossing this boundary is a `ProviderFailure`.
abstract class StreamingProvider extends ProviderDescriptor {
  const StreamingProvider();

  @override
  ProviderKind get kind => ProviderKind.streaming;

  @override
  Set<ProviderPlatform> get platforms => const <ProviderPlatform>{
    ProviderPlatform.android,
    ProviderPlatform.windows,
    ProviderPlatform.linux,
  };

  @override
  ProviderContractRange get contract => ProviderContractRange.current;

  @override
  ProviderOrigin get origin => ProviderOrigin.builtIn;

  @override
  List<ProviderConfigField> get configuration => const <ProviderConfigField>[];

  /// What this provider can actually do.
  Set<ProviderCapability> get capabilities;

  /// Refreshes the availability observation. Must never throw: a provider that
  /// cannot answer is `unavailable`, not an exception.
  Future<ProviderStatusSnapshot> probe();

  /// Free-text search within the provider catalogue.
  Future<List<ProviderSeries>> search(String query, {int page = 1});

  /// Attempts to match a metadata title to a provider series.
  /// Returns `null` when the provider has no matching entry — never a guess.
  Future<ProviderSeries?> match(Anime anime);

  /// Seasons available for [series].
  Future<List<ProviderSeason>> seasons(ProviderSeries series);

  /// Episodes for [series], optionally limited to [seasonId], absolutely
  /// numbered and ordered.
  Future<List<ProviderEpisode>> episodes(
    ProviderSeries series, {
    String? seasonId,
  });

  /// Resolves playable streams for [episode].
  Future<EpisodeStream> resolve(ProviderSeries series, ProviderEpisode episode);

  /// Releases HTTP clients, timers and cached tokens. Must be idempotent, and
  /// must never close a client owned by the app.
  Future<void> dispose();
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
  bool get supportsSeriesMatching =>
      capabilities.contains(ProviderCapability.seriesMatching);
}
