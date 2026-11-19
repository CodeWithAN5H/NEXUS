import '../streaming/streaming_provider.dart';
import 'metadata_provider.dart';
import 'provider_descriptor.dart';

/// One registered provider plus the compatibility evaluated at registration.
class ProviderRegistration<T extends ProviderDescriptor> {
  const ProviderRegistration({
    required this.provider,
    required this.compatibility,
  });

  final T provider;
  final ProviderCompatibility compatibility;

  String get id => provider.id;

  bool get isCompatible => compatibility.isCompatible;
}

/// Registry of every *streaming* provider compiled into the app.
///
/// Compatibility is evaluated once, here, from the provider's declared contract
/// range and platforms — never re-derived from a live request. Adding a provider
/// is one entry in `provider_registry_bootstrap.dart`.
class StreamingProviderRegistry {
  StreamingProviderRegistry(
    Iterable<StreamingProvider> providers, {
    int contractVersion = ProviderContract.current,
    ProviderPlatform? platform,
  }) : _registrations = _build(
         providers,
         contractVersion: contractVersion,
         platform: platform ?? currentProviderPlatform,
       );

  final List<ProviderRegistration<StreamingProvider>> _registrations;

  List<StreamingProvider> get all => <StreamingProvider>[
    for (final ProviderRegistration<StreamingProvider> registration
        in _registrations)
      registration.provider,
  ];

  List<ProviderRegistration<StreamingProvider>> get registrations =>
      List<ProviderRegistration<StreamingProvider>>.unmodifiable(
        _registrations,
      );

  StreamingProvider? byId(String id) {
    for (final ProviderRegistration<StreamingProvider> registration
        in _registrations) {
      if (registration.id == id) return registration.provider;
    }
    return null;
  }

  ProviderRegistration<StreamingProvider>? registrationFor(String id) {
    for (final ProviderRegistration<StreamingProvider> registration
        in _registrations) {
      if (registration.id == id) return registration;
    }
    return null;
  }

  ProviderCompatibility compatibilityOf(String id) =>
      registrationFor(id)?.compatibility ??
      ProviderCompatibility.unsupportedContract;

  /// Providers the user has enabled, in registration order.
  List<StreamingProvider> enabled(Set<String> enabledIds) =>
      <StreamingProvider>[
        for (final ProviderRegistration<StreamingProvider> registration
            in _registrations)
          if (enabledIds.contains(registration.id)) registration.provider,
      ];
}

/// Registry of every *metadata* provider compiled into the app.
///
/// Separate from [StreamingProviderRegistry]: a metadata provider is never
/// offered as a video source, and a streaming provider never becomes the source
/// of truth for titles.
class MetadataProviderRegistry {
  MetadataProviderRegistry(
    Iterable<MetadataProvider> providers, {
    int contractVersion = ProviderContract.current,
    ProviderPlatform? platform,
  }) : _registrations = _build(
         providers,
         contractVersion: contractVersion,
         platform: platform ?? currentProviderPlatform,
       );

  final List<ProviderRegistration<MetadataProvider>> _registrations;

  List<MetadataProvider> get all => <MetadataProvider>[
    for (final ProviderRegistration<MetadataProvider> registration
        in _registrations)
      registration.provider,
  ];

  List<ProviderRegistration<MetadataProvider>> get registrations =>
      List<ProviderRegistration<MetadataProvider>>.unmodifiable(_registrations);

  MetadataProvider? byId(String id) {
    for (final ProviderRegistration<MetadataProvider> registration
        in _registrations) {
      if (registration.id == id) return registration.provider;
    }
    return null;
  }

  /// The catalogue the repository uses: the first compatible registration.
  ///
  /// Returns `null` only if every registered catalogue is incompatible, which
  /// the app treats as "no metadata available" rather than a crash.
  MetadataProvider? get primary {
    for (final ProviderRegistration<MetadataProvider> registration
        in _registrations) {
      if (registration.isCompatible) return registration.provider;
    }
    return null;
  }

  ProviderCompatibility compatibilityOf(String id) {
    for (final ProviderRegistration<MetadataProvider> registration
        in _registrations) {
      if (registration.id == id) return registration.compatibility;
    }
    return ProviderCompatibility.unsupportedContract;
  }
}

List<ProviderRegistration<T>> _build<T extends ProviderDescriptor>(
  Iterable<T> providers, {
  required int contractVersion,
  required ProviderPlatform platform,
}) {
  final List<ProviderRegistration<T>> registrations =
      <ProviderRegistration<T>>[];
  final Set<String> seen = <String>{};
  for (final T provider in providers) {
    if (provider.id.trim().isEmpty) {
      throw ArgumentError.value(provider.id, 'id', 'Provider id is empty');
    }
    if (!seen.add(provider.id)) {
      throw ArgumentError(
        'Duplicate provider id "${provider.id}" — ids are permanent keys for '
        'preferences, progress hints and stored configuration.',
      );
    }
    registrations.add(
      ProviderRegistration<T>(
        provider: provider,
        compatibility: evaluateCompatibility(
          contract: provider.contract,
          platforms: provider.platforms,
          platform: platform,
          contractVersion: contractVersion,
        ),
      ),
    );
  }
  return List<ProviderRegistration<T>>.unmodifiable(registrations);
}
