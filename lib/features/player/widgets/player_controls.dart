import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../integrations/streaming/streaming_provider.dart';

/// Immutable snapshot rendered by [PlayerControls].
class PlayerControlsState {
  const PlayerControlsState({
    required this.title,
    required this.playing,
    required this.buffering,
    required this.position,
    required this.duration,
    required this.visible,
    required this.qualityLabel,
    required this.subtitleLabel,
    required this.audioLabel,
    required this.speed,
    required this.volume,
    required this.hasNext,
    required this.fullscreen,
    this.subtitle,
    this.notice,
    this.isSample = false,
  });

  final String title;
  final String? subtitle;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final bool visible;
  final String qualityLabel;
  final String subtitleLabel;
  final String audioLabel;
  final double speed;
  final double volume;
  final bool hasNext;
  final bool fullscreen;
  final String? notice;
  final bool isSample;
}

/// Callbacks used by [PlayerControls].
class PlayerControlsActions {
  const PlayerControlsActions({
    required this.onBack,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onNext,
    required this.onQuality,
    required this.onSubtitles,
    required this.onAudio,
    required this.onSpeed,
    required this.onEpisodes,
    required this.onFullscreen,
    required this.onToggleMute,
    required this.onVolume,
  });

  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onNext;
  final VoidCallback onQuality;
  final VoidCallback onSubtitles;
  final VoidCallback onAudio;
  final VoidCallback onSpeed;
  final VoidCallback onEpisodes;
  final VoidCallback onFullscreen;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;
}

/// The player chrome: top bar, transport controls and bottom menu bar.
class PlayerControls extends StatelessWidget {
  const PlayerControls({required this.state, required this.actions, super.key});

  final PlayerControlsState state;
  final PlayerControlsActions actions;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !state.visible,
      child: AnimatedOpacity(
        opacity: state.visible ? 1 : 0,
        duration: AppDurations.normal,
        child: Stack(
          children: <Widget>[
            // Scrims keep the controls legible over bright frames.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        AppColors.background.withValues(alpha: 0.8),
                        AppColors.transparent,
                        AppColors.transparent,
                        AppColors.background.withValues(alpha: 0.9),
                      ],
                      stops: const <double>[0, 0.25, 0.6, 1],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _TopBar(state: state, actions: actions),
                  const Spacer(),
                  if (state.buffering)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  _CenterControls(state: state, actions: actions),
                  const Spacer(),
                  _BottomBar(state: state, actions: actions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.actions});

  final PlayerControlsState state;
  final PlayerControlsActions actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: <Widget>[
          _CircleIcon(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: actions.onBack,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  state.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong.copyWith(fontSize: 15),
                ),
                if (state.subtitle != null)
                  Text(
                    state.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
              ],
            ),
          ),
          if (state.isSample)
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.18),
                borderRadius: AppRadius.pillRadius,
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'SAMPLE',
                style: AppTypography.caption.copyWith(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.warning,
                ),
              ),
            ),
          _CircleIcon(
            icon: Icons.list_rounded,
            tooltip: 'Episodes',
            onPressed: actions.onEpisodes,
          ),
        ],
      ),
    );
  }
}

class _CenterControls extends StatelessWidget {
  const _CenterControls({required this.state, required this.actions});

  final PlayerControlsState state;
  final PlayerControlsActions actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _CircleIcon(
          icon: Icons.replay_10_rounded,
          tooltip: 'Back 10s',
          size: 46,
          iconSize: 24,
          onPressed: actions.onSeekBack,
        ),
        const SizedBox(width: AppSpacing.lg),
        GestureDetector(
          onTap: actions.onTogglePlay,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Icon(
              state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 34,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        _CircleIcon(
          icon: Icons.forward_10_rounded,
          tooltip: 'Forward 10s',
          size: 46,
          iconSize: 24,
          onPressed: actions.onSeekForward,
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.actions});

  final PlayerControlsState state;
  final PlayerControlsActions actions;

  @override
  Widget build(BuildContext context) {
    final double max = state.duration.inMilliseconds.toDouble();
    final double value = state.position.inMilliseconds
        .clamp(0, state.duration.inMilliseconds)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (state.notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                state.notice!,
                style: AppTypography.caption.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: <Widget>[
              Text(
                Formatters.clock(state.position),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.surfaceElevated,
                    thumbColor: AppColors.accentHover,
                    overlayColor: AppColors.accent.withValues(alpha: 0.16),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: max <= 0 ? 0 : value,
                    max: max <= 0 ? 1 : max,
                    onChanged: (double next) =>
                        actions.onSeek(Duration(milliseconds: next.round())),
                  ),
                ),
              ),
              Text(
                Formatters.clock(state.duration),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              _CircleIcon(
                icon: state.volume <= 0
                    ? Icons.volume_off_rounded
                    : (state.volume < 50
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded),
                tooltip: 'Mute',
                onPressed: actions.onToggleMute,
              ),
              SizedBox(
                width: 84,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    activeTrackColor: AppColors.textSecondary,
                    inactiveTrackColor: AppColors.surfaceElevated,
                    thumbColor: AppColors.textPrimary,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: state.volume.clamp(0, 100),
                    max: 100,
                    onChanged: actions.onVolume,
                  ),
                ),
              ),
              const Spacer(),
              _TextAction(
                label: state.subtitleLabel,
                onPressed: actions.onSubtitles,
              ),
              _TextAction(label: state.audioLabel, onPressed: actions.onAudio),
              _TextAction(
                label:
                    '${state.speed.toStringAsFixed(state.speed % 1 == 0 ? 0 : 2)}×',
                onPressed: actions.onSpeed,
              ),
              _TextAction(
                label: state.qualityLabel,
                onPressed: actions.onQuality,
              ),
              if (state.hasNext)
                _CircleIcon(
                  icon: Icons.skip_next_rounded,
                  tooltip: 'Next episode',
                  onPressed: actions.onNext,
                ),
              _CircleIcon(
                icon: state.fullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                tooltip: 'Fullscreen',
                onPressed: actions.onFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 36,
    this.iconSize = 19,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing selectable options with a check mark.
Future<T?> showPlayerMenu<T>({
  required BuildContext context,
  required String title,
  required List<({String label, String? subtitle, T? value, bool selected})>
  options,
  String? footer,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    isScrollControlled: true,
    builder: (BuildContext context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Text(title, style: AppTypography.sectionTitle),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (BuildContext context, int index) {
                final option = options[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    option.label,
                    style: AppTypography.bodyStrong.copyWith(
                      color: option.selected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: option.subtitle == null
                      ? null
                      : Text(option.subtitle!, style: AppTypography.caption),
                  trailing: option.selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.accent,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(option.value),
                );
              },
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(footer, style: AppTypography.caption),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// Convenience for menus that only need a label.
List<({String label, String? subtitle, int? value, bool selected})> menuItems(
  List<String> labels, {
  int? selectedIndex,
  List<String?>? subtitles,
}) {
  return <({String label, String? subtitle, int? value, bool selected})>[
    for (int i = 0; i < labels.length; i++)
      (
        label: labels[i],
        subtitle: subtitles != null && i < subtitles.length
            ? subtitles[i]
            : null,
        value: i,
        selected: selectedIndex == i,
      ),
  ];
}

/// Quality options built from provider variants.
List<({String label, String? subtitle, StreamVariant? value, bool selected})>
qualityItems(List<StreamVariant> variants, StreamVariant? current) {
  return <
    ({String label, String? subtitle, StreamVariant? value, bool selected})
  >[
    for (final StreamVariant variant in variants)
      (
        label: variant.label,
        subtitle: variant.protocol.name.toUpperCase(),
        value: variant,
        selected: identical(variant, current) || variant.uri == current?.uri,
      ),
  ];
}
