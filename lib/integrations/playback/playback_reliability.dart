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

/// How much runway a seek must leave before the end of the media.
///
/// mpv parks on the last decoded frame when a file ends, which is up to most of
/// a second short of the container duration. A seek that lands inside this
/// window therefore has nothing left to decode and ends the file immediately,
/// which is the case [clampSeekTarget] avoids.
const Duration playbackEndTolerance = Duration(seconds: 2);

/// True when the player has nothing left to play.
///
/// `media_kit` only restarts on play while its own `completed` flag is set, and
/// that flag is dropped by `seek()` right after an EOF has raised it. A seek
/// landing on the duration can therefore end the file without leaving
/// `completed` set, so the app recognises the end by position as well.
///
/// Deliberately strict: only `completed` or a position at (or past) the duration
/// count. Treating the last two seconds as "ended" would make a pause press
/// there restart the episode instead of pausing it.
bool isAtPlaybackEnd({
  required Duration position,
  required Duration duration,
  required bool completed,
}) {
  if (completed) return true;
  if (duration <= Duration.zero) return false;
  return position >= duration;
}

/// A seek target that keeps enough runway to finish through playback.
///
/// A seek onto the duration (or into mpv's last undecodable fraction) ends the
/// file during the seek, and `media_kit`'s `seek()` then clears `completed`
/// again: the episode stops without ever completing, so it neither advances nor
/// marks itself watched. Moving the target to the last playable point lets the
/// ending play out normally, so completion and autoplay run exactly as they do
/// for a natural EOF. A seek into the final two seconds is therefore honoured,
/// but from the earliest point that still decodes.
Duration clampSeekTarget({
  required Duration target,
  required Duration duration,
}) {
  if (target < Duration.zero) return Duration.zero;
  if (duration <= Duration.zero) return target;
  final Duration lastPlayable = duration - playbackEndTolerance;
  if (lastPlayable <= Duration.zero) return Duration.zero;
  return target > lastPlayable ? lastPlayable : target;
}

/// What pressing play should do for the current player state.
enum PlaybackPlayAction {
  /// Normal transport: play or toggle the running media.
  transport,

  /// The media is finished: reload it instead of sending an ignored play.
  restart,
}

PlaybackPlayAction playbackPlayAction({
  required Duration position,
  required Duration duration,
  required bool completed,
}) {
  // `playing` is not consulted: media_kit's `play` sets it back to true even
  // when mpv has no frames left, and a real pause near the end reports exactly
  // the same state. The position decides, and a restarted media reports zero.
  if (isAtPlaybackEnd(
    position: position,
    duration: duration,
    completed: completed,
  )) {
    return PlaybackPlayAction.restart;
  }
  return PlaybackPlayAction.transport;
}

/// True when a reported completion really is the end of the media.
///
/// `media_kit` raises `completed` on every mpv `eof-reached` transition without
/// looking at the position. mpv reports that flag when it has no data left,
/// which includes a stream that stopped early — a dropped connection, a
/// truncated HLS playlist or a demuxer failure — so `completed` alone can
/// arrive with the episode only a minute in. Requiring a position at the end of
/// a known duration is what separates a finished episode from a dead stream;
/// the tail tolerance covers mpv parking on the last decoded frame, which is a
/// fraction of a second short of the container duration.
bool isPlaybackCompletion({
  required Duration position,
  required Duration duration,
  required bool completed,
}) {
  if (!completed) return false;
  if (duration <= Duration.zero) return false;
  return position >= duration - playbackEndTolerance;
}

/// What a genuine completion should do next.
enum PlaybackCompletionAction {
  /// Play the following episode.
  advance,

  /// Stay on the finished episode: autoplay is off, or there is no next one.
  stay,
}

/// The autoplay decision, taken from the settings in force when the episode ends.
PlaybackCompletionAction playbackCompletionAction({
  required bool autoplayNext,
  required bool hasNextEpisode,
}) {
  if (autoplayNext && hasNextEpisode) return PlaybackCompletionAction.advance;
  return PlaybackCompletionAction.stay;
}

/// Allows at most one advance per completed load.
///
/// Each load gets its own attempt token, so a duplicate `completed` event —
/// media_kit can publish the same end twice, and a late one can arrive while the
/// next episode is already loading — is recognised and dropped instead of
/// advancing a second episode.
class PlaybackCompletionGate {
  int? _handled;

  /// True the first time [attempt] completes; false for repeats.
  bool claim(int attempt) {
    if (_handled == attempt) return false;
    _handled = attempt;
    return true;
  }
}
