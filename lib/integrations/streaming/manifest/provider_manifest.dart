/// Immutable model of a validated provider manifest v1.
///
/// Normative specification: `docs/PROVIDER_MANIFEST.md`. Construction is
/// deliberately boring: the validator has already checked every field, so the
/// model only maps names to typed values. Any code that needs to know whether a
/// document is acceptable must go through `ManifestValidator`, never through
/// this constructor — there is no second, weaker validation path.
library;

import '../../providers/provider_descriptor.dart';

/// Capabilities a manifest v1 may declare.
///
/// `continueWatching` is absent: provider-side resume is not expressible in v1
/// (PROVIDER_MANIFEST.md §3.1, §12), and the validator rejects it by name.
enum ManifestCapability {
  search,
  seriesMatching,
  seasons,
  episodes,
  streams,
  qualities,
  subtitles,
  audioTracks;

  ProviderCapability toProviderCapability() => switch (this) {
    ManifestCapability.search => ProviderCapability.search,
    ManifestCapability.seriesMatching => ProviderCapability.seriesMatching,
    ManifestCapability.seasons => ProviderCapability.seasons,
    ManifestCapability.episodes => ProviderCapability.episodes,
    ManifestCapability.streams => ProviderCapability.streams,
    ManifestCapability.qualities => ProviderCapability.qualities,
    ManifestCapability.subtitles => ProviderCapability.subtitles,
    ManifestCapability.audioTracks => ProviderCapability.audioTracks,
  };

  static ManifestCapability? fromName(String name) {
    for (final ManifestCapability value in ManifestCapability.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// The fixed comparison strategies of PROVIDER_MANIFEST.md §7.
enum ManifestMatchStrategy {
  exactTitle,
  normalisedTitle,
  normalisedTitleAndYear,
}

/// How episode numbers are made absolute.
enum ManifestNumbering { absolute, seasonRelative }

/// Container/protocol declared by a manifest.
enum ManifestProtocol { hls, dash, progressive }

/// One declared configuration field.
class ManifestConfigField {
  const ManifestConfigField({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    this.hint,
    this.defaultValue,
    this.placeholder,
    this.choices = const <String>[],
    this.pattern,
    this.maxLength = 256,
  });

  final String key;
  final String label;
  final ProviderConfigType type;
  final bool required;
  final String? hint;
  final String? defaultValue;
  final String? placeholder;
  final List<String> choices;
  final String? pattern;
  final int maxLength;

  /// Maps to the platform declaration used by the settings form.
  ProviderConfigField toProviderConfigField() => ProviderConfigField(
    key: key,
    label: label,
    type: type,
    required: required,
    hint: hint,
    defaultValue: defaultValue,
    placeholder: placeholder,
    choices: choices,
    pattern: pattern,
    maxLength: maxLength,
  );
}

/// The network envelope (PROVIDER_MANIFEST.md §5).
class ManifestNet {
  const ManifestNet({
    required this.origins,
    required this.mediaHosts,
    required this.maxRedirects,
    required this.minRequestIntervalMs,
    required this.timeoutMs,
    required this.maxResponseBytes,
  });

  /// Declared API origins, already validated as `https://host[:port]`.
  final List<Uri> origins;

  /// `example.com` or `*.example.com`, lowercase.
  final List<String> mediaHosts;
  final int maxRedirects;
  final int minRequestIntervalMs;
  final int timeoutMs;
  final int maxResponseBytes;
}

/// Fields every request definition shares.
class ManifestRequestSpec {
  const ManifestRequestSpec({
    required this.method,
    required this.url,
    required this.query,
    required this.headers,
    required this.body,
    required this.timeoutMs,
    required this.maxBytes,
    required this.notFoundStatus,
  });

  /// `GET`, `POST` or (probe only) `HEAD`.
  final String method;

  /// Template, not a URI: placeholders are still unbound.
  final String url;
  final Map<String, String> query;
  final Map<String, String> headers;
  final Map<String, Object?> body;
  final int? timeoutMs;
  final int? maxBytes;
  final List<int> notFoundStatus;
}

/// A `list` path plus the fixed field mapping for its items.
class ManifestListMapping {
  const ManifestListMapping({required this.list, required this.fields});

  final String list;

  /// Field name → JSON path, e.g. `seriesId` → `$.id`.
  final Map<String, String> fields;

  String? path(String field) => fields[field];
}

/// `probe` request.
class ManifestProbeRequest {
  const ManifestProbeRequest({required this.spec, required this.expectStatus});

  final ManifestRequestSpec spec;
  final List<int> expectStatus;
}

/// `search` request.
class ManifestSearchRequest {
  const ManifestSearchRequest({
    required this.spec,
    required this.mapping,
    required this.maxResults,
  });

  final ManifestRequestSpec spec;
  final ManifestListMapping mapping;
  final int maxResults;
}

/// `match` request.
class ManifestMatchRequest {
  const ManifestMatchRequest({
    required this.spec,
    required this.mapping,
    required this.maxResults,
    required this.strategy,
    required this.minConfidence,
  });

  final ManifestRequestSpec spec;
  final ManifestListMapping mapping;
  final int maxResults;
  final ManifestMatchStrategy strategy;
  final double minConfidence;
}

/// `seasons` request.
class ManifestSeasonsRequest {
  const ManifestSeasonsRequest({required this.spec, required this.mapping});

  final ManifestRequestSpec spec;
  final ManifestListMapping mapping;
}

/// `episodes` request.
class ManifestEpisodesRequest {
  const ManifestEpisodesRequest({
    required this.spec,
    required this.mapping,
    required this.numbering,
  });

  final ManifestRequestSpec spec;
  final ManifestListMapping mapping;
  final ManifestNumbering numbering;
}

/// `resolve` request, including its optional subtitle and audio sections.
class ManifestResolveRequest {
  const ManifestResolveRequest({
    required this.spec,
    required this.variants,
    required this.streamHeaders,
    required this.defaultProtocol,
    this.subtitles,
    this.audio,
  });

  final ManifestRequestSpec spec;
  final ManifestListMapping variants;
  final ManifestListMapping? subtitles;
  final ManifestListMapping? audio;
  final Map<String, String> streamHeaders;
  final ManifestProtocol defaultProtocol;
}

/// Every request definition of a manifest.
class ManifestRequests {
  const ManifestRequests({
    this.probe,
    this.search,
    this.match,
    this.seasons,
    this.episodes,
    this.resolve,
  });

  final ManifestProbeRequest? probe;
  final ManifestSearchRequest? search;
  final ManifestMatchRequest? match;
  final ManifestSeasonsRequest? seasons;
  final ManifestEpisodesRequest? episodes;
  final ManifestResolveRequest? resolve;
}

/// Status and message policy.
class ManifestErrorPolicy {
  const ManifestErrorPolicy({
    required this.unauthorisedStatus,
    required this.rateLimitedStatus,
    required this.retryAfterHeader,
    required this.messagePath,
    required this.maxRetryAfterSeconds,
  });

  final List<int> unauthorisedStatus;
  final List<int> rateLimitedStatus;
  final String retryAfterHeader;
  final String? messagePath;
  final int maxRetryAfterSeconds;
}

/// A validated manifest.
class ProviderManifest {
  const ProviderManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.attribution,
    required this.capabilities,
    required this.config,
    required this.net,
    required this.requests,
    required this.errors,
    this.description,
    this.homepage,
    this.notice,
    this.contractMin = ProviderContract.current,
    this.contractMax = ProviderContract.current,
  });

  /// Version of the manifest format this document uses. Always 1 here: a newer
  /// document is refused with `requiresNewerApp` before a model is built.
  static const int supportedVersion = 1;

  final String id;
  final String name;
  final String version;
  final String? description;
  final String? homepage;
  final String attribution;
  final String? notice;
  final int contractMin;
  final int contractMax;
  final List<ManifestCapability> capabilities;
  final List<ManifestConfigField> config;
  final ManifestNet net;
  final ManifestRequests requests;
  final ManifestErrorPolicy errors;

  ProviderContractRange get contractRange =>
      ProviderContractRange(min: contractMin, max: contractMax);

  Set<ProviderCapability> get providerCapabilities => <ProviderCapability>{
    for (final ManifestCapability capability in capabilities)
      capability.toProviderCapability(),
  };

  bool has(ManifestCapability capability) => capabilities.contains(capability);

  /// Declared origins plus the origin of every `url` field's default value.
  ///
  /// Configured values extend this at runtime (a self-hosted base URL); this
  /// getter only covers what is knowable before the user configures anything.
  Set<Uri> get declaredOrigins {
    final Set<Uri> result = <Uri>{
      for (final Uri origin in net.origins) _originOf(origin),
    };
    for (final ManifestConfigField field in config) {
      if (field.type != ProviderConfigType.url) continue;
      final String? value = field.defaultValue;
      if (value == null) continue;
      final Uri? uri = Uri.tryParse(value);
      if (uri != null) result.add(_originOf(uri));
    }
    return result;
  }

  static Uri _originOf(Uri uri) => Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );
}

/// [ProviderDescriptor] view of a manifest, without constructing a provider.
///
/// Sources needs the identity, capabilities and declared fields of a disabled or
/// unconfigured provider, and building a real adapter just to read them would
/// open an HTTP client that then has to be disposed. This view is inert.
class ManifestDescriptor implements ProviderDescriptor {
  ManifestDescriptor(this.manifest);

  final ProviderManifest manifest;

  @override
  String get id => manifest.id;

  @override
  String get name => manifest.name;

  @override
  String get description => manifest.description ?? 'Installed source.';

  @override
  String get version => manifest.version;

  @override
  String get attribution => manifest.attribution;

  @override
  ProviderKind get kind => ProviderKind.streaming;

  @override
  ProviderOrigin get origin => ProviderOrigin.userAdded;

  @override
  ProviderContractRange get contract => manifest.contractRange;

  @override
  Set<ProviderPlatform> get platforms => const <ProviderPlatform>{
    ProviderPlatform.android,
    ProviderPlatform.windows,
    ProviderPlatform.linux,
  };

  Set<ProviderCapability> get capabilities => manifest.providerCapabilities;

  @override
  List<ProviderConfigField> get configuration => <ProviderConfigField>[
    for (final ManifestConfigField field in manifest.config)
      field.toProviderConfigField(),
  ];
}
