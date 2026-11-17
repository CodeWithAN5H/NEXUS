import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/navigation_destinations.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/responsive.dart';
import '../../data/models/app_settings.dart';
import '../../data/providers/app_providers.dart';

/// Every setting here is wired to real behaviour.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    final SettingsController controller = ref.read(settingsProvider.notifier);

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: NexusPagePadding(
            top: AppSpacing.md,
            child: Row(
              children: <Widget>[
                if (!context.usesDesktopShell) ...<Widget>[
                  GestureDetector(
                    onTap: () => context.go(profileDestination.path),
                    child: const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.xs),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
                Text('Settings', style: AppTypography.headline),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: NexusContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: 'Appearance',
                  children: <Widget>[
                    _ChoiceTile<GridDensity>(
                      label: 'Poster grid density',
                      subtitle:
                          'How tightly posters pack in Explore and Library',
                      value: settings.gridDensity,
                      valueLabel: settings.gridDensity.label,
                      options: GridDensity.values,
                      labelOf: (GridDensity value) => value.label,
                      onSelected: controller.setGridDensity,
                    ),
                    _SwitchTile(
                      label: 'Reduce motion',
                      subtitle:
                          'Shortens transitions and disables hover scaling',
                      value: settings.reduceMotion,
                      onChanged: controller.setReduceMotion,
                    ),
                  ],
                ),
                _Section(
                  title: 'Playback',
                  children: <Widget>[
                    _SwitchTile(
                      label: 'Autoplay next episode',
                      subtitle: 'Start the next episode when one finishes',
                      value: settings.autoplayNext,
                      onChanged: controller.setAutoplayNext,
                    ),
                    _SwitchTile(
                      label: 'Remember playback position',
                      subtitle: 'Resume episodes where you left off',
                      value: settings.rememberPosition,
                      onChanged: controller.setRememberPosition,
                    ),
                    _ChoiceTile<int>(
                      label: 'Default quality',
                      subtitle:
                          'Upper limit; the player picks the closest track',
                      value: settings.preferredQualityHeight,
                      valueLabel: settings.qualityLabel,
                      options: const <int>[0, 1080, 720, 480, 360],
                      labelOf: (int value) => value == 0 ? 'Auto' : '${value}p',
                      onSelected: controller.setPreferredQuality,
                    ),
                  ],
                ),
                _Section(
                  title: 'Subtitles',
                  children: <Widget>[
                    _ChoiceTile<SubtitleSize>(
                      label: 'Subtitle size',
                      subtitle: 'Applies to every embedded and sidecar track',
                      value: settings.subtitleSize,
                      valueLabel: settings.subtitleSize.label,
                      options: SubtitleSize.values,
                      labelOf: (SubtitleSize value) => value.label,
                      onSelected: controller.setSubtitleSize,
                    ),
                  ],
                ),
                _Section(
                  title: 'Audio',
                  children: <Widget>[
                    _ChoiceTile<String>(
                      label: 'Preferred audio language',
                      subtitle: 'Used when a source offers multiple tracks',
                      value: settings.preferredAudioLanguage ?? 'auto',
                      valueLabel: _languageLabel(
                        settings.preferredAudioLanguage,
                      ),
                      options: const <String>['auto', 'ja', 'en'],
                      labelOf: _languageLabel,
                      onSelected: (String value) =>
                          controller.setPreferredAudioLanguage(
                            value == 'auto' ? null : value,
                          ),
                    ),
                  ],
                ),
                _Section(
                  title: 'Sources',
                  children: <Widget>[
                    _ActionTile(
                      label: 'Manage sources',
                      subtitle:
                          '${settings.enabledProviderIds.length} provider'
                          '${settings.enabledProviderIds.length == 1 ? '' : 's'} '
                          'enabled · status, capabilities and test playback',
                      onTap: () => context.push('/sources'),
                    ),
                  ],
                ),
                _Section(
                  title: 'AniList',
                  children: <Widget>[
                    _ActionTile(
                      label: 'Account connection',
                      subtitle: 'Not connected — list sync is planned for v0.4',
                      onTap: () => _showAniListInfo(context),
                    ),
                  ],
                ),
                _Section(
                  title: 'About',
                  children: <Widget>[
                    _ActionTile(
                      label: 'Version',
                      subtitle:
                          '${AppConstants.appVersion} (${AppConstants.versionCode})',
                      onTap: () {},
                      showChevron: false,
                    ),
                    _ActionTile(
                      label: 'Open source licences',
                      subtitle: 'Flutter, media_kit, Drift and other packages',
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: AppConstants.appName,
                        applicationVersion: AppConstants.appVersion,
                        applicationLegalese:
                            'Metadata by AniList. Playback test media courtesy '
                            'of Apple and Mux.',
                      ),
                    ),
                    _ActionTile(
                      label: 'AniList',
                      subtitle: 'anilist.co — metadata provider',
                      onTap: () => launchUrl(
                        Uri.parse('https://anilist.co'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _languageLabel(String? code) {
    return switch (code) {
      'ja' => 'Japanese',
      'en' => 'English',
      _ => 'Auto',
    };
  }

  Future<void> _showAniListInfo(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('AniList connection'),
        content: const Text(
          'NEXUS already reads metadata from AniList. Signing in to sync your '
          'lists, scores and progress across devices is planned for v0.4, once '
          'the local library and player are stable.\n\nNo credentials are '
          'stored in this build.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              title.toUpperCase(),
              style: AppTypography.caption.copyWith(
                fontSize: 10.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  children[i],
                  if (i != children.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TileFrame extends StatelessWidget {
  const _TileFrame({
    required this.label,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String label;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: AppTypography.bodyStrong),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      label: label,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.textPrimary,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.surfaceSecondary,
        inactiveThumbColor: AppColors.textMuted,
      ),
    );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.valueLabel,
    required this.options,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final String subtitle;
  final T value;
  final String valueLabel;
  final List<T> options;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: label,
      color: AppColors.surfaceElevated,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<T>>[
        for (final T option in options)
          PopupMenuItem<T>(
            value: option,
            child: Row(
              children: <Widget>[
                Icon(
                  option == value
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: option == value
                      ? AppColors.accent
                      : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(labelOf(option), style: AppTypography.body),
              ],
            ),
          ),
      ],
      child: _TileFrame(
        label: label,
        subtitle: subtitle,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              valueLabel,
              style: AppTypography.bodyStrong.copyWith(
                color: AppColors.accent,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.showChevron = true,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      label: label,
      subtitle: subtitle,
      onTap: onTap,
      trailing: showChevron
          ? const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            )
          : const SizedBox.shrink(),
    );
  }
}
