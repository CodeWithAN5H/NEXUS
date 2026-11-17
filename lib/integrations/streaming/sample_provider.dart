import '../../data/models/anime.dart';
import 'streaming_provider.dart';

/// A built-in provider that exposes *test media only*.
///
/// NEXUS ships without an anime streaming source: the project deliberately does
/// not implement unauthorised aggregators. To keep playback a first-class,
/// verifiable feature, this provider serves the public example streams that
/// Apple and Mux publish for HLS testing. Every episode is labelled as a sample
/// in the UI, and [match] never claims a real anime title.
///
/// Replacing this with an authorised provider is a matter of registering another
/// [StreamingProvider] — no screen needs to change.
class SamplePlaybackProvider implements StreamingProvider {
  const SamplePlaybackProvider();

  static const String providerId = 'sample';

  /// Negative id namespace so sample playback never collides with AniList ids
  /// when progress is stored locally.
  static const int testLibraryAnimeId = -1001;
  static const String testLibrarySeriesId = 'playback-tests';
  static const String seasonId = 'season-1';

  static const String _appleBase =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4';
  static const String _muxBase = 'https://test-streams.mux.dev/x36xhzz';

  @override
  String get id => providerId;

  @override
  String get name => 'Playback Test Library';

  @override
  String get description =>
      'Public HLS example streams from Apple and Mux, bundled to verify '
      'playback, quality switching, subtitle and audio-track selection. '
      'This is not an anime catalogue.';

  @override
  String get attribution => 'Apple HLS example stream · Mux test streams';

  @override
  Set<ProviderCapability> get capabilities => const <ProviderCapability>{
    ProviderCapability.search,
    ProviderCapability.seriesMatching,
    ProviderCapability.seasons,
    ProviderCapability.episodes,
    ProviderCapability.streams,
    ProviderCapability.qualities,
    ProviderCapability.subtitles,
    ProviderCapability.audioTracks,
  };

  @override
  ProviderStatus get status => const ProviderStatus(
    availability: ProviderAvailability.limited,
    message: 'Ready — test streams only, no anime content.',
    actionHint: 'Open the test library from Settings → Sources.',
  );

  /// The demo series shown when the test library is opened.
  ProviderSeries get testLibrary => ProviderSeries(
    providerId: providerId,
    seriesId: testLibrarySeriesId,
    title: 'NEXUS Playback Tests',
    synopsis:
        'Two public example streams used to verify the player on Android and '
        'Windows. Neither is an anime episode.',
    seasons: const <ProviderSeason>[
      ProviderSeason(
        seriesId: testLibrarySeriesId,
        seasonId: seasonId,
        label: 'Season 1',
        index: 0,
      ),
    ],
  );

  List<ProviderEpisode> get testEpisodes => const <ProviderEpisode>[
    ProviderEpisode(
      providerId: providerId,
      seriesId: testLibrarySeriesId,
      seasonId: seasonId,
      episodeId: 'bipbop',
      number: 1,
      title: 'BipBop — adaptive multi-track stream',
      description:
          'Apple HLS example: 8 renditions up to 1080p60, AAC and AC-3 audio, '
          'embedded subtitles and closed captions.',
    ),
    ProviderEpisode(
      providerId: providerId,
      seriesId: testLibrarySeriesId,
      seasonId: seasonId,
      episodeId: 'big-buck-bunny',
      number: 2,
      title: 'Big Buck Bunny — 1080p HLS',
      description:
          'Mux test stream: five renditions from 240p to 1080p, used to verify '
          'quality switching and seeking.',
    ),
  ];

  @override
  Future<List<ProviderSeries>> search(String query) async {
    final String needle = query.trim().toLowerCase();
    final ProviderSeries series = testLibrary;
    if (needle.isEmpty || series.title.toLowerCase().contains(needle)) {
      return <ProviderSeries>[series];
    }
    return const <ProviderSeries>[];
  }

  /// This provider never claims an AniList title: doing so would present sample
  /// video as if it were the requested anime.
  @override
  Future<ProviderSeries?> match(Anime anime) async => null;

  @override
  Future<List<ProviderSeason>> seasons(ProviderSeries series) async =>
      series.seasons.isNotEmpty ? series.seasons : testLibrary.seasons;

  @override
  Future<List<ProviderEpisode>> episodes(
    ProviderSeries series, {
    String? seasonId,
  }) async {
    if (series.seriesId != testLibrarySeriesId) {
      return const <ProviderEpisode>[];
    }
    if (seasonId == null) return testEpisodes;
    return testEpisodes
        .where((ProviderEpisode episode) => episode.seasonId == seasonId)
        .toList(growable: false);
  }

  @override
  Future<EpisodeStream> resolve(
    ProviderSeries series,
    ProviderEpisode episode,
  ) async {
    if (series.seriesId != testLibrarySeriesId) {
      throw const ProviderException('Unknown series for this provider.');
    }
    switch (episode.episodeId) {
      case 'bipbop':
        return EpisodeStream(
          protocol: StreamProtocol.hls,
          isSample: true,
          notice: 'Sample stream — subtitles and audio tracks are embedded.',
          variants: <StreamVariant>[
            _variant('1080p', '$_appleBase/v9/prog_index.m3u8', 1080),
            _variant('1080p (6 Mbps)', '$_appleBase/v7/prog_index.m3u8', 1080),
            _variant('720p', '$_appleBase/v6/prog_index.m3u8', 720),
            _variant(
              '540p',
              '$_appleBase/v5/prog_index.m3u8',
              540,
              isDefault: true,
            ),
            _variant('432p', '$_appleBase/v4/prog_index.m3u8', 432),
            _variant('360p', '$_appleBase/v3/prog_index.m3u8', 360),
            _variant('270p', '$_appleBase/v2/prog_index.m3u8', 270),
          ],
        );
      case 'big-buck-bunny':
        return EpisodeStream(
          protocol: StreamProtocol.hls,
          isSample: true,
          notice: 'Sample stream — used to verify quality switching.',
          variants: <StreamVariant>[
            _variant(
              '1080p',
              '$_muxBase/url_8/193039199_mp4_h264_aac_fhd_7.m3u8',
              1080,
            ),
            _variant(
              '720p',
              '$_muxBase/url_0/193039199_mp4_h264_aac_hd_7.m3u8',
              720,
            ),
            _variant(
              '480p',
              '$_muxBase/url_6/193039199_mp4_h264_aac_hq_7.m3u8',
              480,
            ),
            _variant(
              '288p',
              '$_muxBase/url_4/193039199_mp4_h264_aac_7.m3u8',
              288,
            ),
            _variant(
              '240p',
              '$_muxBase/url_2/193039199_mp4_h264_aac_ld_7.m3u8',
              240,
              isDefault: true,
            ),
          ],
        );
      default:
        throw const ProviderException(
          'This episode has no stream.',
          isRetryable: false,
        );
    }
  }

  static StreamVariant _variant(
    String label,
    String uri,
    int height, {
    bool isDefault = false,
  }) {
    return StreamVariant(
      label: label,
      uri: Uri.parse(uri),
      height: height,
      isDefault: isDefault,
      protocol: StreamProtocol.hls,
    );
  }
}
