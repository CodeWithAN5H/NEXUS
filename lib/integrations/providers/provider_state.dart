import 'provider_descriptor.dart';

/// Whether a provider can serve a request **right now**.
///
/// Availability is an observation with a timestamp, never persisted as truth.
/// It is deliberately separate from compatibility (fixed by an app update) and
/// configuration (fixed by the user).
enum ProviderAvailability {
  /// Fully usable.
  ready,

  /// Usable, but only for a small built-in catalogue (sample media).
  limited,

  /// Some capabilities currently fail (search works, streams do not).
  degraded,

  /// Temporarily failing.
  unavailable;

  bool get canServe => this != ProviderAvailability.unavailable;
}

/// Whether the user has supplied what the provider needs.
enum ProviderConfigurationState {
  /// No declared fields — usable immediately.
  notRequired,

  /// Required fields are empty.
  incomplete,

  /// All required fields are present.
  configured,

  /// The provider refused the supplied credentials.
  rejected;

  bool get isSatisfied =>
      this == ProviderConfigurationState.notRequired ||
      this == ProviderConfigurationState.configured;

  /// Evaluates the configuration axis from the declaration and stored values.
  ///
  /// Only non-secret values live here; a declared secret is satisfied by its
  /// presence in the keystore, which the caller signals by including the key
  /// with a non-empty placeholder value (never the secret itself).
  static ProviderConfigurationState evaluate(
    List<ProviderConfigField> fields,
    Map<String, String> values,
  ) {
    final List<ProviderConfigField> required = fields
        .where((ProviderConfigField field) => field.required)
        .toList(growable: false);
    if (required.isEmpty) return ProviderConfigurationState.notRequired;
    for (final ProviderConfigField field in required) {
      final String? value = values[field.key];
      if (value == null || value.trim().isEmpty) {
        return ProviderConfigurationState.incomplete;
      }
    }
    return ProviderConfigurationState.configured;
  }

  /// Required keys that are still empty.
  static List<String> missingKeys(
    List<ProviderConfigField> fields,
    Map<String, String> values,
  ) {
    return <String>[
      for (final ProviderConfigField field in fields)
        if (field.required &&
            (values[field.key] == null || values[field.key]!.trim().isEmpty))
          field.key,
    ];
  }
}

/// A timestamped observation of a provider's availability.
class ProviderStatusSnapshot {
  const ProviderStatusSnapshot({
    required this.availability,
    required this.message,
    required this.observedAt,
    this.actionHint,
  });

  /// The state before the first probe.
  factory ProviderStatusSnapshot.unprobed() => ProviderStatusSnapshot(
    availability: ProviderAvailability.unavailable,
    message: 'Not checked yet.',
    observedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  final ProviderAvailability availability;

  /// One-line explanation shown in Settings → Sources.
  final String message;

  /// When this snapshot was taken — availability is not stored as truth.
  final DateTime observedAt;

  /// Optional next step for the user (e.g. "Add an API key").
  final String? actionHint;

  bool get canServe => availability.canServe;

  @override
  String toString() => '${availability.name}: $message';
}

/// The single state Settings → Sources presents, derived from the three axes.
enum ProviderPresentationState {
  usable('Ready'),
  needsSetup('Setup required'),
  rejectedConfiguration('Sign-in rejected'),
  incompatible('Incompatible'),
  unavailable('Temporarily unavailable'),
  disabled('Off');

  const ProviderPresentationState(this.label);

  final String label;
}

/// The three axes plus the derived presentation state for one provider.
class ProviderState {
  const ProviderState({
    required this.providerId,
    required this.kind,
    required this.compatibility,
    required this.configuration,
    required this.availability,
    required this.enabled,
    this.missingConfigurationKeys = const <String>[],
  });

  /// Builds a state from a descriptor and its observations.
  factory ProviderState.from({
    required ProviderDescriptor descriptor,
    required ProviderCompatibility compatibility,
    required Map<String, String> configurationValues,
    required ProviderStatusSnapshot availability,
    required bool enabled,
  }) {
    return ProviderState(
      providerId: descriptor.id,
      kind: descriptor.kind,
      compatibility: compatibility,
      configuration: ProviderConfigurationState.evaluate(
        descriptor.configuration,
        configurationValues,
      ),
      availability: availability,
      enabled: enabled,
      missingConfigurationKeys: ProviderConfigurationState.missingKeys(
        descriptor.configuration,
        configurationValues,
      ),
    );
  }

  final String providerId;
  final ProviderKind kind;
  final ProviderCompatibility compatibility;
  final ProviderConfigurationState configuration;
  final ProviderStatusSnapshot availability;
  final bool enabled;
  final List<String> missingConfigurationKeys;

  /// Precedence: what the app cannot fix comes first, then what the user must
  /// fix, then whether it is switched on, then transient availability.
  ProviderPresentationState get presentation {
    if (!compatibility.isCompatible) {
      return ProviderPresentationState.incompatible;
    }
    if (configuration == ProviderConfigurationState.incomplete) {
      return ProviderPresentationState.needsSetup;
    }
    if (configuration == ProviderConfigurationState.rejected) {
      return ProviderPresentationState.rejectedConfiguration;
    }
    if (!enabled) return ProviderPresentationState.disabled;
    if (!availability.canServe) return ProviderPresentationState.unavailable;
    return ProviderPresentationState.usable;
  }

  /// Shortcut for the observed availability value.
  ProviderAvailability get observedAvailability => availability.availability;

  bool get isUsable => presentation == ProviderPresentationState.usable;

  /// Retrying only helps a transient failure. Setup, compatibility and removal
  /// are not retryable.
  bool get offersRetry => presentation == ProviderPresentationState.unavailable;

  String get message {
    switch (presentation) {
      case ProviderPresentationState.usable:
        return availability.message;
      case ProviderPresentationState.needsSetup:
        final String fields = missingConfigurationKeys.isEmpty
            ? 'required details'
            : missingConfigurationKeys.join(', ');
        return 'Setup required — add $fields.';
      case ProviderPresentationState.rejectedConfiguration:
        return 'The source rejected your credentials. Replace them and try '
            'again.';
      case ProviderPresentationState.incompatible:
        return switch (compatibility) {
          ProviderCompatibility.requiresNewerApp =>
            'Needs a newer NEXUS to run this source.',
          ProviderCompatibility.unsupportedContract =>
            'This source uses an older provider contract this build no longer '
                'supports.',
          ProviderCompatibility.unsupportedPlatform =>
            'Not available on this platform.',
          ProviderCompatibility.compatible => 'Compatible.',
        };
      case ProviderPresentationState.unavailable:
        return availability.message;
      case ProviderPresentationState.disabled:
        return 'Off — configuration is kept.';
    }
  }

  String? get actionHint {
    switch (presentation) {
      case ProviderPresentationState.usable:
        return availability.actionHint;
      case ProviderPresentationState.needsSetup:
        return 'Open the source\'s settings to finish setup.';
      case ProviderPresentationState.rejectedConfiguration:
        return 'Replace the credentials for this source.';
      case ProviderPresentationState.unavailable:
        return availability.actionHint ?? 'Retry when the source recovers.';
      case ProviderPresentationState.incompatible:
      case ProviderPresentationState.disabled:
        return null;
    }
  }

  @override
  String toString() =>
      'ProviderState($providerId, ${presentation.name}, '
      '${compatibility.name}/${configuration.name}/${availability.availability.name})';
}
