/// How a raw media_kit/mpv error line should be treated.
///
/// media_kit forwards *every* mpv log line at level `error` to
/// `player.stream.error` (prefixes `file`, `ffmpeg`, `vd`, `ad`, `cplayer`,
/// `stream`). Those are log messages, not terminal player state: a `vd`/`ad`
/// line can be emitted when one hardware decoder fails and mpv immediately
/// falls back to software decoding while playback continues.
enum PlaybackErrorKind {
  /// Codec/decoder line (`vd`, `ad`, hardware decoder init). Recoverable when
  /// the session has already rendered frames.
  decoder,

  /// Opening/streaming/player failure. Terminal only when playback is stalled.
  playback,
}

const List<String> _decoderMarkers = <String>[
  'codec',
  'decoder',
  'hwdec',
  'mediacodec',
  'videotoolbox',
  'vaapi',
  'd3d11va',
  'dxva',
  'avcodec',
];

/// Classifies one raw error line without looking at player state.
PlaybackErrorKind classifyPlaybackError(String message) {
  final String lower = message.toLowerCase();
  for (final String marker in _decoderMarkers) {
    if (lower.contains(marker)) return PlaybackErrorKind.decoder;
  }
  return PlaybackErrorKind.playback;
}

/// Decides whether an error line should replace the player with the fatal
/// overlay.
///
/// The decision is dominated by observed playback health rather than by the
/// text alone, because mpv reports recoverable decoder failures as errors.
bool shouldSurfacePlaybackError({
  required PlaybackErrorKind kind,
  required bool hasProgressed,
  required bool progressingNow,
  required bool playing,
}) {
  // Playback has advanced past position zero at some point in this attempt:
  // a decoder line means one decoder was replaced, not that playback died.
  if (hasProgressed && kind == PlaybackErrorKind.decoder) return false;

  // Still advancing right now — the player is rendering, so never kill it.
  if (progressingNow) return false;

  // A paused player should not turn a transport hiccup into a fatal screen.
  if (!playing) return false;

  return true;
}

/// Watches a playing session for a stall. An error line that arrives while
/// buffered frames still advance is not fatal yet, but the same failure becomes
/// terminal when the buffer drains and the position stops moving.
class PlaybackStallTracker {
  PlaybackStallTracker({this.stallThreshold = 4});

  /// Consecutive two-second samples without meaningful progress.
  final int stallThreshold;

  /// How many samples the watchdog watches before giving up.
  static const int maxSamples = 30;

  Duration _lastPosition = Duration.zero;
  int _stalledSamples = 0;
  int _samples = 0;

  int get samples => _samples;

  /// Feeds one sample. Returns true when the session is considered stalled.
  bool observe(Duration position, {required bool playing}) {
    if (!playing) return false;
    _samples++;
    if (position > _lastPosition + const Duration(milliseconds: 200)) {
      _lastPosition = position;
      _stalledSamples = 0;
      return false;
    }
    _stalledSamples++;
    return _stalledSamples >= stallThreshold;
  }

  bool get expired => _samples >= maxSamples;
}

/// Monotonic token that distinguishes the current playback attempt from a
/// superseded one. Late completions from an older load compare their token and
/// drop themselves instead of overwriting newer state.
class PlaybackAttempts {
  int _current = 0;

  int get current => _current;

  /// Starts a new attempt and returns its token.
  int begin() => ++_current;

  bool isCurrent(int attempt) => attempt == _current;

  /// Invalidates every in-flight attempt (used on disposal).
  void invalidate() => _current++;
}
