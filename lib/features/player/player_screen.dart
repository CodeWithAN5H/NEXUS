import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../data/models/app_settings.dart';
import '../../data/providers/app_providers.dart';
import '../../data/providers/content_providers.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../integrations/playback/playback_session.dart';
import '../../integrations/providers/provider_failure.dart';
import '../../integrations/providers/provider_resolver.dart';
import '../../integrations/streaming/streaming_provider.dart';
import 'playback_request.dart';
import 'widgets/player_controls.dart';

/// Immersive playback with custom controls, resume, auto-next and track menus.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({required this.request, super.key});

  final PlaybackRequest request;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final PlaybackSession _session = PlaybackSession();
  final ValueNotifier<Duration> _position = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> _duration = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<bool> _playing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _buffering = ValueNotifier<bool>(false);
  final ValueNotifier<double> _volume = ValueNotifier<double>(100);

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  late PlaybackRequest _request;
  late AppSettings _settings;
  late final HistoryRepository _history = ref.read(historyRepositoryProvider);
  late final LibraryRepository _library = ref.read(libraryRepositoryProvider);

  EpisodeStream? _stream;
  List<StreamVariant> _variants = const <StreamVariant>[];
  StreamVariant? _variant;
  List<ProviderEpisode> _episodes = const <ProviderEpisode>[];
  Object? _error;
  bool _loading = true;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  double _lastVolume = 100;
  double _rate = 1;
  double _brightness = 1;
  String? _seekFeedback;
  Timer? _hideTimer;
  Timer? _progressTimer;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _settings = ref.read(appSettingsProvider);
    _attachListeners();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 5),
      (Timer _) => unawaited(_saveProgress()),
    );
    _startHideTimer();
    unawaited(_load());
  }

  void _attachListeners() {
    _subscriptions.add(
      _session.positionStream.listen(
        (Duration value) => _position.value = value,
      ),
    );
    _subscriptions.add(
      _session.durationStream.listen(
        (Duration value) => _duration.value = value,
      ),
    );
    _subscriptions.add(
      _session.playingStream.listen((bool value) {
        _playing.value = value;
        if (value) {
          _startHideTimer();
        } else {
          setState(() => _controlsVisible = true);
          unawaited(_saveProgress());
        }
      }),
    );
    _subscriptions.add(
      _session.bufferingStream.listen((bool value) => _buffering.value = value),
    );
    _subscriptions.add(
      _session.completedStream.listen((bool done) {
        if (done) unawaited(_onCompleted());
      }),
    );
    _subscriptions.add(
      _session.errorStream.listen((String message) {
        if (!mounted) return;
        setState(() {
          _error = ProviderUpstreamError(
            providerId: _request.providerId,
            message: message,
          );
          _loading = false;
        });
      }),
    );
    _subscriptions.add(
      _session.tracksStream.listen((Tracks tracks) {
        if (!mounted) return;
        final String? preferred = _settings.preferredAudioLanguage;
        if (preferred != null &&
            (tracks.audio.length > 1) &&
            _session.currentTrack.audio.id !=
                _session.audioForLanguage(preferred)?.id) {
          final AudioTrack? match = _session.audioForLanguage(preferred);
          if (match != null) unawaited(_session.selectAudio(match));
        }
      }),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      StreamingProvider? provider = ref
          .read(streamingProviderRegistryProvider)
          .byId(_request.providerId);
      ProviderSeries? resolvedSeries;

      // A saved resume hint can outlive the provider that produced it. Re-resolve
      // the title instead of failing the player (PROVIDER_TESTS T-R15).
      if (provider == null) {
        final SourceLookup lookup = await ref.read(
          sourceLookupProvider(_request.animeId).future,
        );
        final SourceResolution? again = lookup.resolution;
        if (again == null) {
          throw ProviderNotFound(
            providerId: _request.providerId,
            message:
                'The source this title was saved with is no longer available, '
                'and no other source has it.',
          );
        }
        provider = again.provider;
        resolvedSeries = again.series;
        _request = _request.copyWith(seriesId: again.series.seriesId);
      }

      final ProviderSeries series =
          resolvedSeries ??
          ProviderSeries(
            providerId: provider.id,
            seriesId: _request.seriesId,
            title: _request.animeTitle,
          );
      final List<ProviderEpisode> episodes = await provider.episodes(series);
      if (episodes.isEmpty) {
        throw ProviderNotFound(
          providerId: provider.id,
          message: 'This source returned no episodes for the title.',
        );
      }
      final ProviderEpisode episode = episodes.firstWhere(
        (ProviderEpisode item) => item.number == _request.episodeNumber,
        orElse: () => episodes.first,
      );

      final EpisodeStream stream = await provider.resolve(series, episode);
      final StreamVariant variant = await _session.load(
        stream,
        preferredHeight: _settings.preferredQualityHeight == 0
            ? null
            : _settings.preferredQualityHeight,
        startAt: await _resumePosition(episode.number),
      );

      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _stream = stream;
        _variants = stream.variants;
        _variant = variant;
        _request = _request.copyWith(episodeNumber: episode.number);
        _loading = false;
      });
      await _session.setRate(_rate);
    } on ProviderFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<Duration?> _resumePosition(int episodeNumber) async {
    if (!_settings.rememberPosition) return null;
    try {
      final progress = await _history.progressFor(
        _request.animeId,
        episodeNumber,
      );
      if (progress == null) return null;
      if (progress.isNearlyFinished) return null;
      return progress.position;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onCompleted() async {
    await _saveProgress();
    if (!mounted) return;
    final ProviderEpisode? next = _nextEpisode;
    if (_settings.autoplayNext && next != null) {
      await _playEpisode(next);
      return;
    }
    setState(() => _controlsVisible = true);
    if (next == null && mounted) {
      showNexusMessage(context, 'You have reached the last episode available.');
    }
  }

  ProviderEpisode? get _nextEpisode {
    for (final ProviderEpisode episode in _episodes) {
      if (episode.number > _request.episodeNumber) return episode;
    }
    return null;
  }

  Future<void> _playEpisode(ProviderEpisode episode) async {
    await _saveProgress();
    if (!mounted) return;
    setState(() {
      _request = _request.copyWith(
        episodeNumber: episode.number,
        episodeTitle: episode.title,
      );
      _position.value = Duration.zero;
      _duration.value = Duration.zero;
      _rate = 1;
    });
    await _load();
  }

  // ── Progress ───────────────────────────────────────────────────────────────

  Future<void> _saveProgress() async {
    if (!_settings.rememberPosition) return;
    final Duration position = _position.value;
    final Duration duration = _duration.value;
    if (duration <= Duration.zero) return;
    try {
      await _history.record(
        animeId: _request.animeId,
        episodeNumber: _request.episodeNumber,
        title: _request.animeTitle,
        position: position,
        duration: duration,
        episodeTitle: _request.episodeTitle,
        coverImage: _request.coverImage,
        bannerImage: _request.bannerImage,
        totalEpisodes: _request.totalEpisodes,
        providerId: _request.providerId,
        seriesId: _request.seriesId,
      );

      final bool finished =
          position.inMilliseconds >= (duration.inMilliseconds * 0.9).round();
      if (finished) {
        await _library.markEpisodeWatched(
          _request.animeId,
          _request.episodeNumber,
          totalEpisodes: _request.totalEpisodes,
        );
      }
    } catch (_) {
      // Progress persistence must never interrupt playback.
    }
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _playing.value) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _startHideTimer();
  }

  Future<void> _togglePlay() async {
    await _session.playOrPause();
    _startHideTimer();
  }

  Future<void> _seekBy(Duration delta) async {
    await _session.seekBy(delta);
  }

  void _showSeekFeedback(Duration delta) {
    _feedbackTimer?.cancel();
    setState(() {
      _seekFeedback =
          '${delta.isNegative ? '−' : '+'}${delta.inSeconds.abs()}s';
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekFeedback = null);
    });
  }

  Future<void> _handleDoubleTap(double dx, double width) async {
    final Duration delta = const Duration(seconds: 10);
    if (dx < width / 3) {
      await _seekBy(-delta);
      _showSeekFeedback(-delta);
    } else if (dx > width * 2 / 3) {
      await _seekBy(delta);
      _showSeekFeedback(delta);
    } else {
      await _togglePlay();
    }
  }

  Future<void> _setVolume(double value) async {
    _volume.value = value;
    await _session.setVolume(value);
  }

  Future<void> _toggleMute() async {
    if (_volume.value > 0) {
      _lastVolume = _volume.value;
      await _setVolume(0);
    } else {
      await _setVolume(_lastVolume == 0 ? 100 : _lastVolume);
    }
  }

  Future<void> _applyBrightness(double delta) async {
    _brightness = (_brightness + delta).clamp(0.15, 1.0);
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(
        _brightness,
      );
    } catch (_) {
      // Brightness control is not available on every platform (notably Windows).
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleFullscreen() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (_fullscreen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
          DeviceOrientation.portraitUp,
        ]);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }
    if (mounted) setState(() => _fullscreen = !_fullscreen);
  }

  // ── Menus ──────────────────────────────────────────────────────────────────

  Future<void> _showQualityMenu() async {
    if (_variants.isEmpty) return;
    final StreamVariant? selected = await showPlayerMenu<StreamVariant>(
      context: context,
      title: 'Quality',
      options: qualityItems(_variants, _variant),
      footer: _stream?.isSample ?? false
          ? 'Sample stream renditions published for HLS testing.'
          : null,
    );
    if (selected == null || !mounted) return;
    final Duration resumeAt = _position.value;
    final EpisodeStream? stream = _stream;
    if (stream == null) return;
    final StreamVariant variant = await _session.load(
      EpisodeStream(
        variants: <StreamVariant>[selected],
        protocol: stream.protocol,
        subtitles: stream.subtitles,
        audioTracks: stream.audioTracks,
        headers: stream.headers,
        isSample: stream.isSample,
        notice: stream.notice,
      ),
      startAt: resumeAt,
    );
    if (!mounted) return;
    setState(() => _variant = variant);
  }

  Future<void> _showSubtitleMenu() async {
    final List<SubtitleTrack> embedded = _session.tracks.subtitle
        .where((SubtitleTrack track) => track.id != 'auto' && track.id != 'no')
        .toList(growable: false);
    final List<SubtitleTrackInfo> external =
        _stream?.subtitles ?? const <SubtitleTrackInfo>[];

    final List<({String label, String? subtitle, Object? value, bool selected})>
    options =
        <({String label, String? subtitle, Object? value, bool selected})>[
          (
            label: 'Off',
            subtitle: null,
            value: null,
            selected: _session.currentTrack.subtitle.id == 'no',
          ),
          for (final SubtitleTrack track in embedded)
            (
              label: track.title ?? track.language ?? 'Track ${track.id}',
              subtitle: track.codec ?? 'Embedded',
              value: track,
              selected: _session.currentTrack.subtitle.id == track.id,
            ),
          for (final SubtitleTrackInfo track in external)
            (
              label: track.label,
              subtitle: track.language ?? 'External',
              value: track,
              selected: false,
            ),
        ];

    final Object? selected = await showPlayerMenu<Object>(
      context: context,
      title: 'Subtitles',
      options: options,
    );
    if (!mounted) return;
    if (selected == null) {
      await _session.selectSubtitle(null);
      return;
    }
    if (selected is SubtitleTrack) {
      await _session.selectSubtitle(selected);
    } else if (selected is SubtitleTrackInfo) {
      await _session.addExternalSubtitle(selected);
    }
    if (mounted) setState(() {});
  }

  Future<void> _showAudioMenu() async {
    final List<AudioTrack> tracks = _session.tracks.audio
        .where((AudioTrack track) => track.id != 'auto' && track.id != 'no')
        .toList(growable: false);
    if (tracks.isEmpty) {
      showNexusMessage(context, 'This stream has a single audio track.');
      return;
    }
    final AudioTrack? selected = await showPlayerMenu<AudioTrack>(
      context: context,
      title: 'Audio',
      options:
          <
            ({String label, String? subtitle, AudioTrack? value, bool selected})
          >[
            for (final AudioTrack track in tracks)
              (
                label: track.title ?? track.language ?? 'Track ${track.id}',
                subtitle: track.codec,
                value: track,
                selected: _session.currentTrack.audio.id == track.id,
              ),
          ],
    );
    if (selected == null) return;
    await _session.selectAudio(selected);
    if (mounted) setState(() {});
  }

  Future<void> _showSpeedMenu() async {
    const List<double> speeds = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];
    final double? selected = await showPlayerMenu<double>(
      context: context,
      title: 'Playback speed',
      options:
          <({String label, String? subtitle, double? value, bool selected})>[
            for (final double speed in speeds)
              (
                label: speed == 1 ? 'Normal' : '$speed×',
                subtitle: null,
                value: speed,
                selected: (_rate - speed).abs() < 0.01,
              ),
          ],
    );
    if (selected == null) return;
    _rate = selected;
    await _session.setRate(selected);
    if (mounted) setState(() {});
  }

  Future<void> _showEpisodeMenu() async {
    if (_episodes.isEmpty) return;
    final ProviderEpisode? selected = await showPlayerMenu<ProviderEpisode>(
      context: context,
      title: 'Episodes',
      options:
          <
            ({
              String label,
              String? subtitle,
              ProviderEpisode? value,
              bool selected,
            })
          >[
            for (final ProviderEpisode episode in _episodes)
              (
                label: '${episode.number}. ${episode.title}',
                subtitle: episode.description,
                value: episode,
                selected: episode.number == _request.episodeNumber,
              ),
          ],
    );
    if (selected == null || selected.number == _request.episodeNumber) return;
    await _playEpisode(selected);
  }

  // ── Keyboard ───────────────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      unawaited(_togglePlay());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      unawaited(_seekBy(const Duration(seconds: -10)));
      _showSeekFeedback(const Duration(seconds: -10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      unawaited(_seekBy(const Duration(seconds: 10)));
      _showSeekFeedback(const Duration(seconds: 10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      unawaited(_setVolume((_volume.value + 5).clamp(0, 100)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      unawaited(_setVolume((_volume.value - 5).clamp(0, 100)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      unawaited(_toggleFullscreen());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      unawaited(_toggleMute());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_fullscreen) {
        unawaited(_toggleFullscreen());
      } else {
        _exit();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _exit() {
    unawaited(_saveProgress());
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _feedbackTimer?.cancel();
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _position.dispose();
    _duration.dispose();
    _playing.dispose();
    _buffering.dispose();
    _volume.dispose();
    unawaited(_session.dispose());
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      unawaited(
        SystemChrome.setPreferredOrientations(<DeviceOrientation>[
          DeviceOrientation.portraitUp,
        ]),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double subtitleScale = _settings.subtitleSize.scale;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) unawaited(_saveProgress());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Video(
                    controller: _session.videoController,
                    controls: null,
                    fit: BoxFit.contain,
                    fill: Colors.black,
                    subtitleViewConfiguration: SubtitleViewConfiguration(
                      style: TextStyle(
                        height: 1.35,
                        fontSize: 22 * subtitleScale,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        backgroundColor: Colors.black.withValues(alpha: 0.55),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTapDown: (TapDownDetails details) => unawaited(
                        _handleDoubleTap(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        ),
                      ),
                      onDoubleTap: () {},
                      onVerticalDragUpdate: (DragUpdateDetails details) {
                        final double dx = details.localPosition.dx;
                        final double delta = -details.delta.dy / 220;
                        if (dx < constraints.maxWidth / 2) {
                          unawaited(_applyBrightness(delta));
                        } else {
                          unawaited(
                            _setVolume(
                              (_volume.value + delta * 100).clamp(0, 100),
                            ),
                          );
                        }
                        setState(() => _controlsVisible = true);
                      },
                    ),
                  ),
                  if (_seekFeedback != null)
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.75),
                            borderRadius: AppRadius.cardRadius,
                          ),
                          child: Text(
                            _seekFeedback!,
                            style: AppTypography.headline.copyWith(
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_loading)
                    const Center(
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  if (_error != null)
                    _PlayerError(error: _error!, onRetry: _load, onBack: _exit),
                  if (!_loading && _error == null)
                    Positioned.fill(
                      child: ValueListenableBuilder<Duration>(
                        valueListenable: _position,
                        builder: (BuildContext context, Duration position, _) {
                          return ValueListenableBuilder<Duration>(
                            valueListenable: _duration,
                            builder: (BuildContext context, Duration duration, _) {
                              return ValueListenableBuilder<bool>(
                                valueListenable: _playing,
                                builder: (BuildContext context, bool playing, _) {
                                  return ValueListenableBuilder<bool>(
                                    valueListenable: _buffering,
                                    builder: (BuildContext context, bool buffering, _) {
                                      return ValueListenableBuilder<double>(
                                        valueListenable: _volume,
                                        builder:
                                            (
                                              BuildContext context,
                                              double volume,
                                              _,
                                            ) {
                                              return PlayerControls(
                                                state: PlayerControlsState(
                                                  title: _request.animeTitle,
                                                  subtitle:
                                                      '$_request.label'
                                                      '${_request.episodeTitle == null ? '' : ' · ${_request.episodeTitle}'}',
                                                  playing: playing,
                                                  buffering: buffering,
                                                  position: position,
                                                  duration: duration,
                                                  visible: _controlsVisible,
                                                  qualityLabel:
                                                      _variant?.label ?? 'Auto',
                                                  subtitleLabel: 'CC',
                                                  audioLabel: 'Audio',
                                                  speed: _rate,
                                                  volume: volume,
                                                  hasNext: _nextEpisode != null,
                                                  fullscreen: _fullscreen,
                                                  notice: _stream?.notice,
                                                  isSample:
                                                      _stream?.isSample ??
                                                      false,
                                                ),
                                                actions: PlayerControlsActions(
                                                  onBack: _exit,
                                                  onTogglePlay: () =>
                                                      unawaited(_togglePlay()),
                                                  onSeek: (Duration value) =>
                                                      unawaited(
                                                        _session.seek(value),
                                                      ),
                                                  onSeekBack: () => unawaited(
                                                    _seekBy(
                                                      const Duration(
                                                        seconds: -10,
                                                      ),
                                                    ),
                                                  ),
                                                  onSeekForward: () =>
                                                      unawaited(
                                                        _seekBy(
                                                          const Duration(
                                                            seconds: 10,
                                                          ),
                                                        ),
                                                      ),
                                                  onNext: () {
                                                    final ProviderEpisode?
                                                    next = _nextEpisode;
                                                    if (next != null) {
                                                      unawaited(
                                                        _playEpisode(next),
                                                      );
                                                    }
                                                  },
                                                  onQuality: () => unawaited(
                                                    _showQualityMenu(),
                                                  ),
                                                  onSubtitles: () => unawaited(
                                                    _showSubtitleMenu(),
                                                  ),
                                                  onAudio: () => unawaited(
                                                    _showAudioMenu(),
                                                  ),
                                                  onSpeed: () => unawaited(
                                                    _showSpeedMenu(),
                                                  ),
                                                  onEpisodes: () => unawaited(
                                                    _showEpisodeMenu(),
                                                  ),
                                                  onFullscreen: () => unawaited(
                                                    _toggleFullscreen(),
                                                  ),
                                                  onToggleMute: () =>
                                                      unawaited(_toggleMute()),
                                                  onVolume: (double value) =>
                                                      unawaited(
                                                        _setVolume(value),
                                                      ),
                                                ),
                                              );
                                            },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final Object value = error;
    final String message = value is ProviderFailure
        ? value.message
        : value.toString();
    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 34,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Playback failed',
                style: AppTypography.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Text(
                  message,
                  style: AppTypography.body,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextButton(onPressed: onBack, child: const Text('Go back')),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
