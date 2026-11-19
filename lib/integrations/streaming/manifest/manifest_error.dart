import '../../providers/provider_descriptor.dart';
import 'provider_manifest.dart';

/// One problem found in a manifest, in the shape the UI renders:
/// `path → message`, with a stable machine [code].
///
/// Codes follow `docs/PROVIDER_MANIFEST.md` §9 and never carry wildcard or
/// untrusted detail: [message] is composed by the validator, and never includes
/// a configured value.
class ManifestError {
  const ManifestError({
    required this.code,
    required this.path,
    required this.message,
  });

  /// `manifest.parse`, `manifest.schema`, `manifest.template`, `manifest.path`,
  /// `manifest.semantic` or `manifest.compat`.
  final String code;

  /// JSON-pointer-like location, e.g. `/net/origins/0`.
  final String path;

  /// Human explanation, safe to display.
  final String message;

  @override
  String toString() => '$code at $path: $message';
}

/// The outcome of validating one manifest `manifestVersion`.
///
/// A manifest can be structurally well formed and still unusable by this build
/// (newer format, retired contract). Those are compatibility outcomes, not
/// parse errors, so they get their own status rather than appearing as a list of
/// red validation rows.
enum ManifestStatus {
  /// Every stage passed and the provider can be installed.
  valid,

  /// At least one stage failed; [ManifestValidationResult.errors] explains why.
  invalid,

  /// `manifestVersion` is newer than this build understands. The manifest is
  /// retained so an app update can revive it (PROVIDER_MANIFEST.md §10).
  requiresNewerApp,

  /// The manifest's contract range does not include this build's contract.
  unsupportedContract,
}

/// Result of validating a manifest document.
class ManifestValidationResult {
  const ManifestValidationResult({
    required this.status,
    required this.compatibility,
    this.errors = const <ManifestError>[],
    this.manifest,
  });

  final ManifestStatus status;
  final ProviderCompatibility compatibility;
  final List<ManifestError> errors;

  /// The parsed model, present for [ManifestStatus.valid] and
  /// [ManifestStatus.unsupportedContract] — the latter is still listed in
  /// Settings → Sources, it simply is never invoked.
  final ProviderManifest? manifest;

  /// True only when a provider can actually be constructed.
  bool get isValid => status == ManifestStatus.valid;

  /// Compatibility value for the provider record. `requiresNewerApp` and
  /// `unsupportedContract` are surfaced through the existing state axis.
  bool get isCompatibilityFailure =>
      status == ManifestStatus.requiresNewerApp ||
      status == ManifestStatus.unsupportedContract;

  /// All errors, ordered by path then code, so the review screen is stable.
  static List<ManifestError> sorted(List<ManifestError> errors) {
    final List<ManifestError> ordered = List<ManifestError>.of(errors);
    ordered.sort((ManifestError a, ManifestError b) {
      final int byPath = a.path.compareTo(b.path);
      return byPath != 0 ? byPath : a.code.compareTo(b.code);
    });
    return List<ManifestError>.unmodifiable(ordered);
  }
}
