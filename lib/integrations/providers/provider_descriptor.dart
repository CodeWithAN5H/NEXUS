/// Shared provider envelope for both provider kinds.
///
/// Normative specification: `docs/PROVIDERS.md` §3. A *metadata* provider
/// answers "what is this title?"; a *streaming* provider answers "where can I
/// watch it?". They share identity, versioning, compatibility and configuration
/// declarations, but not their capability sets — which is why `capabilities` is
/// declared by each kind rather than here.
library;

import 'dart:io';

/// Which side of the platform a provider belongs to.
enum ProviderKind { metadata, streaming }

/// Where a provider came from.
enum ProviderOrigin {
  /// Compiled into the app and registered in the bootstrap file.
  builtIn,

  /// Installed by the user as a declarative manifest (v0.2 Tier B).
  userAdded,
}

/// Abilities a *streaming* provider may implement.
///
/// Capabilities gate the UI and the resolver; they are not suggestions. A
/// provider that lacks [subtitles] must return an empty subtitle list rather
/// than an empty sheet.
enum ProviderCapability {
  search('Search'),
  seriesMatching('Title matching'),
  seasons('Season data'),
  episodes('Episode list'),
  streams('Video streams'),
  qualities('Quality selection'),
  subtitles('Subtitle tracks'),
  audioTracks('Audio tracks'),
  continueWatching('Resume position');

  const ProviderCapability(this.label);

  final String label;
}

/// Abilities a *metadata* provider may implement.
enum MetadataCapability {
  trending('Trending'),
  seasonal('Seasonal'),
  topRated('Top rated'),
  recentlyUpdated('Recently updated'),
  search('Search'),
  filters('Filters'),
  details('Details'),
  relations('Relations'),
  genres('Genres'),
  streamingEpisodes('Streaming episodes'),
  airSchedule('Air schedule'),
  externalIds('External IDs');

  const MetadataCapability(this.label);

  final String label;
}

/// The platforms a provider can run on.
enum ProviderPlatform { android, windows, linux }

/// The provider-platform contract this build implements.
///
/// Increment [current] only for a breaking change to a provider contract.
/// Provider documents declare a range they support, so an old adapter keeps
/// working across app updates that only add capabilities.
abstract final class ProviderContract {
  static const int current = 1;
}

/// The inclusive contract range a provider was written against.
class ProviderContractRange {
  const ProviderContractRange({
    this.min = ProviderContract.current,
    this.max = ProviderContract.current,
  });

  /// The range this build implements.
  static const ProviderContractRange current = ProviderContractRange();

  final int min;
  final int max;

  bool supports(int version) => version >= min && version <= max;

  @override
  String toString() => min == max ? '$min' : '$min–$max';
}

/// Whether this build can run a provider at all.
///
/// Evaluated once at registration; never re-derived from a live request.
enum ProviderCompatibility {
  compatible,
  requiresNewerApp,
  unsupportedContract,
  unsupportedPlatform;

  bool get isCompatible => this == ProviderCompatibility.compatible;
}

/// Computes the compatibility axis for one provider.
///
/// * A provider that does not support the running platform is
///   [ProviderCompatibility.unsupportedPlatform].
/// * A provider whose range starts above [contractVersion] needs a newer app.
/// * A provider whose range ends below [contractVersion] uses a contract this
///   build has retired.
ProviderCompatibility evaluateCompatibility({
  required ProviderContractRange contract,
  required Set<ProviderPlatform> platforms,
  required ProviderPlatform platform,
  int contractVersion = ProviderContract.current,
}) {
  if (!platforms.contains(platform)) {
    return ProviderCompatibility.unsupportedPlatform;
  }
  if (contract.min > contractVersion) {
    return ProviderCompatibility.requiresNewerApp;
  }
  if (contract.max < contractVersion) {
    return ProviderCompatibility.unsupportedContract;
  }
  return ProviderCompatibility.compatible;
}

/// The platform this process is running on.
///
/// Uses `dart:io` rather than `defaultTargetPlatform` so the resolver and its
/// tests agree; there is no web target.
ProviderPlatform get currentProviderPlatform {
  if (Platform.isAndroid) return ProviderPlatform.android;
  if (Platform.isWindows) return ProviderPlatform.windows;
  return ProviderPlatform.linux;
}

/// Input type of a declared configuration field.
enum ProviderConfigType {
  text,
  url,
  secret,
  choice,
  boolean;

  /// Whether values of this type must be kept out of SQLite and diagnostics.
  bool get isSecret => this == ProviderConfigType.secret;
}

/// One declared configuration field.
///
/// Settings → Sources renders the form from this declaration; no screen holds
/// provider-specific fields.
class ProviderConfigField {
  const ProviderConfigField({
    required this.key,
    required this.label,
    this.type = ProviderConfigType.text,
    this.required = false,
    this.hint,
    this.defaultValue,
    this.placeholder,
    this.choices = const <String>[],
    this.pattern,
    this.maxLength = 4096,
  });

  final String key;
  final String label;
  final ProviderConfigType type;
  final bool required;
  final String? hint;
  final String? defaultValue;
  final String? placeholder;
  final List<String> choices;

  /// Optional regular expression the whole value must match.
  final String? pattern;

  /// Upper bound on the stored value's length.
  final int maxLength;
}

/// Everything both provider kinds declare about themselves.
abstract class ProviderDescriptor {
  const ProviderDescriptor();

  /// Stable identifier, permanent once released (`anilist`, `sample`,
  /// `dev.example.catalog`). Changing it is a new provider.
  String get id;

  /// Display name.
  String get name;

  /// One-line description shown in Settings → Sources.
  String get description;

  /// The provider's own version.
  String get version;

  ProviderKind get kind;

  /// Built in, or installed by the user.
  ProviderOrigin get origin;

  /// Provider-contract range the implementation was written against.
  ProviderContractRange get contract;

  /// Platforms this provider can run on.
  Set<ProviderPlatform> get platforms;

  /// Declared configuration fields, rendered as a form.
  List<ProviderConfigField> get configuration;

  /// Attribution/licence line shown wherever the content is presented.
  String get attribution;
}
