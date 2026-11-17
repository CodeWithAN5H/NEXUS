/// User preferences, persisted locally.
///
/// Every field here is wired to real behaviour — settings that only exist in the
/// UI are not included.
library;

/// Poster grid density.
enum GridDensity {
  comfortable('Comfortable', 0.30),
  compact('Compact', 0.24);

  const GridDensity(this.label, this.posterWidthFactor);

  final String label;

  /// Poster width as a fraction of the available width for a phone column.
  final double posterWidthFactor;
}

/// Subtitle text size in the player.
enum SubtitleSize {
  small('Small', 0.85),
  medium('Medium', 1.0),
  large('Large', 1.25);

  const SubtitleSize(this.label, this.scale);

  final String label;
  final double scale;
}

/// An immutable snapshot of all preferences.
class AppSettings {
  const AppSettings({
    this.autoplayNext = true,
    this.rememberPosition = true,
    this.preferredQualityHeight = 0,
    this.subtitleSize = SubtitleSize.medium,
    this.preferredAudioLanguage,
    this.enabledProviderIds = const <String>{'sample'},
    this.gridDensity = GridDensity.comfortable,
    this.reduceMotion = false,
  });

  /// Defaults used on first launch and for any missing key.
  static const AppSettings defaults = AppSettings();

  /// When true the player queues the next episode automatically.
  final bool autoplayNext;

  /// When true playback positions are written to the database.
  final bool rememberPosition;

  /// Preferred maximum vertical resolution; `0` means "auto".
  final int preferredQualityHeight;

  final SubtitleSize subtitleSize;

  /// `ja`, `en`, … or `null` for "match the source".
  final String? preferredAudioLanguage;

  /// Providers the user has enabled.
  final Set<String> enabledProviderIds;

  final GridDensity gridDensity;

  /// Shortens or disables non-essential animation.
  final bool reduceMotion;

  String get qualityLabel =>
      preferredQualityHeight == 0 ? 'Auto' : '${preferredQualityHeight}p';

  AppSettings copyWith({
    bool? autoplayNext,
    bool? rememberPosition,
    int? preferredQualityHeight,
    SubtitleSize? subtitleSize,
    String? preferredAudioLanguage,
    bool clearAudioLanguage = false,
    Set<String>? enabledProviderIds,
    GridDensity? gridDensity,
    bool? reduceMotion,
  }) {
    return AppSettings(
      autoplayNext: autoplayNext ?? this.autoplayNext,
      rememberPosition: rememberPosition ?? this.rememberPosition,
      preferredQualityHeight:
          preferredQualityHeight ?? this.preferredQualityHeight,
      subtitleSize: subtitleSize ?? this.subtitleSize,
      preferredAudioLanguage: clearAudioLanguage
          ? null
          : (preferredAudioLanguage ?? this.preferredAudioLanguage),
      enabledProviderIds: enabledProviderIds ?? this.enabledProviderIds,
      gridDensity: gridDensity ?? this.gridDensity,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  /// Storage keys. Changing one requires a migration or a defaults reset.
  static const String keyAutoplay = 'playback.autoplay_next';
  static const String keyRememberPosition = 'playback.remember_position';
  static const String keyQuality = 'playback.quality_height';
  static const String keySubtitleSize = 'subtitles.size';
  static const String keyAudioLanguage = 'audio.language';
  static const String keyProviders = 'sources.enabled';
  static const String keyGridDensity = 'appearance.grid_density';
  static const String keyReduceMotion = 'appearance.reduce_motion';

  factory AppSettings.fromMap(Map<String, String> values) {
    final AppSettings d = AppSettings.defaults;
    final String? providers = values[keyProviders];

    return AppSettings(
      autoplayNext: _bool(values[keyAutoplay]) ?? d.autoplayNext,
      rememberPosition:
          _bool(values[keyRememberPosition]) ?? d.rememberPosition,
      preferredQualityHeight:
          int.tryParse(values[keyQuality] ?? '') ?? d.preferredQualityHeight,
      subtitleSize: SubtitleSize.values.firstWhere(
        (SubtitleSize size) => size.name == values[keySubtitleSize],
        orElse: () => d.subtitleSize,
      ),
      preferredAudioLanguage: (values[keyAudioLanguage]?.isEmpty ?? true)
          ? null
          : values[keyAudioLanguage],
      enabledProviderIds: providers == null
          ? d.enabledProviderIds
          : providers
                .split(',')
                .map((String id) => id.trim())
                .where((String id) => id.isNotEmpty)
                .toSet(),
      gridDensity: GridDensity.values.firstWhere(
        (GridDensity density) => density.name == values[keyGridDensity],
        orElse: () => d.gridDensity,
      ),
      reduceMotion: _bool(values[keyReduceMotion]) ?? d.reduceMotion,
    );
  }

  Map<String, String> toMap() {
    return <String, String>{
      keyAutoplay: '$autoplayNext',
      keyRememberPosition: '$rememberPosition',
      keyQuality: '$preferredQualityHeight',
      keySubtitleSize: subtitleSize.name,
      keyAudioLanguage: preferredAudioLanguage ?? '',
      keyProviders: enabledProviderIds.join(','),
      keyGridDensity: gridDensity.name,
      keyReduceMotion: '$reduceMotion',
    };
  }

  static bool? _bool(String? value) {
    if (value == null) return null;
    if (value == 'true') return true;
    if (value == 'false') return false;
    return null;
  }
}
