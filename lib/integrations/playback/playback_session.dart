import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../providers/provider_failure.dart';
import '../streaming/streaming_provider.dart';
import 'playback_reliability.dart';

/// The app's playback abstraction.
///
/// Everything above this class deals in [EpisodeStream] and plain values; only
/// this file imports `media_kit`. Replacing the engine (for example with a
/// platform-native player) means reimplementing this one class — the player UI,
/// progress tracking and provider contracts stay untouched.
class PlaybackSession {
  PlaybackSession();

  final Player player = Player();

  /// Built lazily from [player]; media_kit requires both to reference the same
  /// Player instance.
  late final VideoController videoController = VideoController(player);

  Stream<Duration> get positionStream => player.stream.position;
  Stream<Duration> get durationStream => player.stream.duration;
  Stream<bool> get playingStream => player.stream.playing;
  Stream<bool> get bufferingStream => player.stream.buffering;
  Stream<bool> get completedStream => player.stream.completed;
  Stream<Tracks> get tracksStream => player.stream.tracks;
  Stream<Track> get trackStream => player.stream.track;
  Stream<String> get errorStream => player.stream.error;

  Duration get position => player.state.position;
  Duration get duration => player.state.duration;
  bool get isPlaying => player.state.playing;
  double get volume => player.state.volume;
  double get rate => player.state.rate;
  Tracks get tracks => player.state.tracks;
  Track get currentTrack => player.state.track;

  Uri? _loadedUri;

  /// URI of the variant currently loaded, for diagnostics.
  Uri? get loadedUri => _loadedUri;

  /// Tracks the current load so a superseded load cannot seek a newer session.
  final PlaybackAttempts _attempts = PlaybackAttempts();

  /// Token of the load currently owning the player.
  int get generation => _attempts.current;

  /// Opens [stream], choosing the best variant for [preferredHeight].
  ///
  /// Position cannot be passed to `open`, so a resume offset is applied as soon
  /// as the player reports a duration.
  Future<StreamVariant> load(
    EpisodeStream stream, {
    int? preferredHeight,
    Duration? startAt,
    String audioLanguage = 'auto',
  }) async {
    final StreamVariant? variant = stream.bestVariant(
      preferredHeight: preferredHeight,
    );
    if (variant == null) {
      throw const ProviderInvalidStream(
        providerId: 'playback',
        message: 'This source returned no playable stream for the episode.',
      );
    }

    _loadedUri = variant.uri;
    final int attempt = _attempts.begin();
    await player.open(
      Media(variant.uri.toString(), httpHeaders: stream.headers),
      play: true,
    );
    // A newer load owns the player now: never seek the wrong media.
    if (!_attempts.isCurrent(attempt)) return variant;

    if (startAt != null && startAt > const Duration(seconds: 2)) {
      unawaited(_seekWhenReady(startAt, attempt: attempt));
    }
    return variant;
  }

  Future<void> _seekWhenReady(Duration target, {required int attempt}) async {
    final Completer<void> completer = Completer<void>();
    late final StreamSubscription<Duration> subscription;
    subscription = durationStream.listen((Duration duration) {
      if (duration > Duration.zero && !completer.isCompleted) {
        completer.complete();
      }
    });
    // Never block for more than 8 seconds waiting for a duration.
    await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
    await subscription.cancel();
    if (!completer.isCompleted) return;
    // The resume decision is only valid while its own load is current.
    if (!_attempts.isCurrent(attempt)) return;
    // Clamp so a previously finished episode does not seek past the end.
    final Duration duration = player.state.duration;
    final Duration safe = target >= duration
        ? duration - const Duration(seconds: 5)
        : target;
    if (safe > Duration.zero) {
      await player.seek(safe);
    }
  }

  Future<void> play() => player.play();
  Future<void> pause() => player.pause();
  Future<void> playOrPause() => player.playOrPause();
  Future<void> seek(Duration position) => player.seek(position);
  Future<void> seekBy(Duration delta) {
    final Duration target = player.state.position + delta;
    final Duration duration = player.state.duration;
    final Duration clamped = target < Duration.zero
        ? Duration.zero
        : (duration > Duration.zero && target > duration ? duration : target);
    return player.seek(clamped);
  }

  Future<void> setVolume(double value) =>
      player.setVolume(value.clamp(0.0, 100.0));

  Future<void> setRate(double value) => player.setRate(value.clamp(0.25, 4.0));

  /// Selects an embedded subtitle track, or disables subtitles with `null`.
  Future<void> selectSubtitle(SubtitleTrack? track) =>
      player.setSubtitleTrack(track ?? SubtitleTrack.no());

  /// Loads an external subtitle file.
  Future<void> addExternalSubtitle(SubtitleTrackInfo track) =>
      player.setSubtitleTrack(
        SubtitleTrack.uri(
          track.uri.toString(),
          title: track.label,
          language: track.language,
        ),
      );

  /// Selects an embedded audio track, or mutes track selection with `null`.
  Future<void> selectAudio(AudioTrack? track) =>
      player.setAudioTrack(track ?? AudioTrack.auto());

  /// Best matching audio track for a preferred language code.
  AudioTrack? audioForLanguage(String? language) {
    if (language == null || language.isEmpty) return null;
    for (final AudioTrack track in tracks.audio) {
      final String? code = track.language?.toLowerCase();
      if (code == null) continue;
      if (code.startsWith(language.toLowerCase())) return track;
    }
    return null;
  }

  Future<void> dispose() {
    // Late resumes must not touch a disposed player.
    _attempts.invalidate();
    return player.dispose();
  }
}
