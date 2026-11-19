import 'provider_descriptor.dart';

/// One installed provider, as persisted in schema v2 `provider_entries`.
///
/// Only non-secret configuration lives here. Credentials belong to the platform
/// keystore, never to this record, a log or an export.
class ProviderRecord {
  const ProviderRecord({
    required this.providerId,
    required this.origin,
    required this.enabled,
    required this.priority,
    required this.installedAt,
    this.manifestVersion,
    this.contractVersion,
    this.config = const <String, String>{},
  });

  /// Convenience constructor for a compiled-in provider.
  factory ProviderRecord.builtIn(
    String providerId, {
    required bool enabled,
    required int priority,
    DateTime? installedAt,
    int? contractVersion,
  }) {
    return ProviderRecord(
      providerId: providerId,
      origin: ProviderOrigin.builtIn,
      enabled: enabled,
      priority: priority,
      installedAt: installedAt ?? DateTime.now(),
      contractVersion: contractVersion,
    );
  }

  final String providerId;
  final ProviderOrigin origin;
  final bool enabled;

  /// Lower runs first. The default order is install order.
  final int priority;

  final DateTime installedAt;

  /// Manifest format version, for user-added providers only.
  final String? manifestVersion;

  /// Contract version the provider declared when it was installed.
  final int? contractVersion;

  /// Non-secret declared configuration values (`{}` when there are none).
  final Map<String, String> config;

  ProviderRecord copyWith({
    ProviderOrigin? origin,
    bool? enabled,
    int? priority,
    DateTime? installedAt,
    String? manifestVersion,
    int? contractVersion,
    Map<String, String>? config,
  }) {
    return ProviderRecord(
      providerId: providerId,
      origin: origin ?? this.origin,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      installedAt: installedAt ?? this.installedAt,
      manifestVersion: manifestVersion ?? this.manifestVersion,
      contractVersion: contractVersion ?? this.contractVersion,
      config: config ?? this.config,
    );
  }

  @override
  String toString() =>
      'ProviderRecord($providerId, ${origin.name}, enabled: $enabled, '
      'priority: $priority)';
}
