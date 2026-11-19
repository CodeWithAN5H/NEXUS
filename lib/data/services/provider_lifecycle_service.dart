import '../../integrations/providers/provider_descriptor.dart';
import '../../integrations/providers/provider_failure.dart';
import '../../integrations/providers/provider_record.dart';
import '../../integrations/providers/provider_state.dart';
import '../../integrations/streaming/manifest/manifest_config_validator.dart';
import '../../integrations/streaming/manifest/manifest_error.dart';
import '../../integrations/streaming/manifest/manifest_http.dart';
import '../../integrations/streaming/manifest/manifest_streaming_provider.dart';
import '../../integrations/streaming/manifest/manifest_validator.dart';
import '../../integrations/streaming/manifest/provider_manifest.dart';
import '../repositories/provider_secret_store.dart';
import '../repositories/provider_store.dart';

/// Installing, configuring and removing declarative providers.
///
/// The only place that writes a user provider, so the invariants live in one
/// class: a row and its manifest are written in one transaction, secrets are
/// written to the keystore only, and a failed step is rolled back. It never
/// constructs a long-lived provider — the registry controller owns instances and
/// their `dispose()`.
class ProviderLifecycleService {
  ProviderLifecycleService(
    this._store,
    this._secrets, {
    Set<String> builtInIds = const <String>{},
    this.transportFactory,
    this.gate,
    DateTime Function()? clock,
  }) : _builtInIds = Set<String>.unmodifiable(builtInIds),
       _clock = clock ?? DateTime.now;

  final ProviderStore _store;
  final ProviderSecretStore _secrets;
  final Set<String> _builtInIds;
  final ManifestTransport? Function(String providerId)? transportFactory;
  final ManifestRequestGate? gate;
  final DateTime Function() _clock;

  int _revision = 0;

  /// Bumped by every successful write. The registry controller includes it in
  /// its cache signature, so a changed secret also rebuilds the provider even
  /// though the secret value is never read here.
  int get revision => _revision;

  // ── Reading ───────────────────────────────────────────────────────────────

  /// Every installed **user-added** provider, revalidated from its stored copy.
  ///
  /// A corrupt or incompatible manifest yields an entry with a typed failure; it
  /// never throws, so one bad row cannot stop app start or hide the others.
  Future<List<InstalledProvider>> loadInstalled() async {
    final List<ProviderRecord> records = await _store.loadAll();
    final List<InstalledProvider> installed = <InstalledProvider>[];
    for (final ProviderRecord record in records) {
      if (record.origin != ProviderOrigin.userAdded) continue;
      installed.add(await _loadOne(record));
    }
    return installed;
  }

  Future<InstalledProvider> _loadOne(ProviderRecord record) async {
    String? json;
    try {
      json = await _store.manifestJsonFor(record.providerId);
    } catch (_) {
      json = null;
    }
    if (json == null) {
      return InstalledProvider(
        record: record,
        manifestJson: null,
        failure: const ProviderManifestInvalid(
          providerId: '',
          message:
              'This source has no stored manifest, so it cannot be used. '
              'Remove it and install it again.',
        ),
        status: ManifestStatus.invalid,
        compatibility: ProviderCompatibility.compatible,
      );
    }

    final ManifestValidationResult validation = ManifestValidator(
      builtInIds: _builtInIds,
    ).validate(json);
    final ProviderManifest? manifest = validation.manifest;
    if (manifest == null) {
      return InstalledProvider(
        record: record,
        manifestJson: json,
        status: validation.status,
        compatibility: validation.compatibility,
        errors: validation.errors,
        failure: ProviderManifestInvalid(
          providerId: record.providerId,
          message: validation.status == ManifestStatus.requiresNewerApp
              ? 'This source uses a newer manifest format than this build of '
                    'NEXUS.'
              : 'This source\'s manifest is invalid, so it was disabled.',
        ),
      );
    }

    final Set<String> present = await _secrets.presentKeys(
      manifest.id,
      _secretKeys(manifest),
    );
    return InstalledProvider(
      record: record,
      manifestJson: json,
      manifest: manifest,
      status: validation.status,
      compatibility: validation.compatibility,
      errors: validation.errors,
      config: record.config,
      presentSecrets: present,
    );
  }

  /// Builds a fresh provider instance for [entry], or `null` when it cannot be
  /// used right now (invalid, incompatible, or not configured).
  ///
  /// Revalidates through [ManifestProviderFactory] every time — a stored copy is
  /// never trusted because it was valid when installed.
  Future<ManifestStreamingProvider?> buildProvider(
    InstalledProvider entry,
  ) async {
    final ProviderManifest? manifest = entry.manifest;
    final String? json = entry.manifestJson;
    if (manifest == null || json == null) return null;
    if (!entry.isCompatible) return null;

    final Map<String, String> secretValues = await _readSecretValues(manifest);
    final Map<String, String> config = <String, String>{
      ...entry.config,
      ...secretValues,
    };
    final ManifestConfigResult validation = ManifestConfigValidator.validate(
      manifest,
      config,
      presentSecrets: secretValues.keys.toSet(),
    );
    if (!validation.isValid) return null;

    final ManifestProviderLoad load = ManifestProviderFactory().create(
      json,
      config: config,
      builtInIds: _builtInIds,
      transport: transportFactory?.call(manifest.id),
      gate: gate,
    );
    return load.provider;
  }

  // ── Installation ──────────────────────────────────────────────────────────

  /// Validates a pasted manifest and reports whether it can be installed.
  ///
  /// Nothing is written: cancelling after this step leaves the database exactly
  /// as it was.
  Future<ProviderInstallPreview> preview(
    String json, {
    String? sourceUrl,
  }) async {
    final ManifestValidationResult validation = ManifestValidator(
      builtInIds: _builtInIds,
    ).validate(json);

    bool duplicate = false;
    if (validation.manifest != null) {
      final String id = validation.manifest!.id;
      final List<ProviderRecord> existing = await _store.loadAll();
      duplicate =
          existing.any((ProviderRecord record) => record.providerId == id) ||
          _builtInIds.contains(id);
    }

    return ProviderInstallPreview(
      json: json,
      sourceUrl: sourceUrl,
      validation: validation,
      duplicate: duplicate,
    );
  }

  /// Persists [preview]'s provider. Throws [ProviderLifecycleFailure] on every
  /// refusal; the database and keystore are unchanged when it does.
  Future<ProviderRecord> install(
    ProviderInstallPreview preview, {
    Map<String, String> values = const <String, String>{},
    bool enabled = true,
  }) async {
    if (!preview.canInstall) {
      throw ProviderLifecycleFailure(
        preview.blockingMessage,
        code: preview.duplicate
            ? 'provider.alreadyInstalled'
            : 'provider.manifestInvalid',
      );
    }

    // Revalidate the exact text that will be stored: a manifest is never
    // trusted because an earlier preview accepted it.
    final ManifestValidationResult recheck = ManifestValidator(
      builtInIds: _builtInIds,
    ).validate(preview.json);
    final ProviderManifest? manifest = recheck.manifest;
    if (manifest == null || recheck.status != ManifestStatus.valid) {
      throw ProviderLifecycleFailure(
        'That manifest is no longer valid and was not installed.',
        code: 'provider.manifestInvalid',
      );
    }

    final List<ProviderRecord> existing = await _store.loadAll();
    if (existing.any((ProviderRecord row) => row.providerId == manifest.id)) {
      throw const ProviderLifecycleFailure(
        'That source is already installed.',
        code: 'provider.alreadyInstalled',
      );
    }

    final ManifestConfigResult config = ManifestConfigValidator.validate(
      manifest,
      values,
    );
    if (!config.isValid) {
      throw ProviderLifecycleFailure(
        'Check the highlighted fields and try again.',
        code: 'provider.configInvalid',
        fieldErrors: config.errors,
      );
    }

    final Map<String, String> nonSecret = <String, String>{};
    final Map<String, String> secretValues = <String, String>{};
    for (final ManifestConfigField field in manifest.config) {
      final String? value = config.values[field.key];
      if (value == null) continue;
      if (field.type == ProviderConfigType.secret) {
        secretValues[field.key] = value;
      } else {
        nonSecret[field.key] = value;
      }
    }

    final Set<String> written = <String>{};
    try {
      for (final MapEntry<String, String> entry in secretValues.entries) {
        await _secrets.write(manifest.id, entry.key, entry.value);
        written.add(entry.key);
      }
    } on Object {
      for (final String key in written) {
        await _secrets.delete(manifest.id, key);
      }
      throw const ProviderLifecycleFailure(
        'NEXUS could not save the credential to secure storage, so nothing was '
        'installed.',
        code: 'provider.secureStorage',
      );
    }

    final ProviderRecord record = ProviderRecord(
      providerId: manifest.id,
      origin: ProviderOrigin.userAdded,
      enabled: enabled,
      priority: await _store.nextPriority(),
      installedAt: _clock(),
      manifestVersion: '${ProviderManifest.supportedVersion}',
      contractVersion: manifest.contractMax,
      config: nonSecret,
    );

    try {
      await _store.installUserProvider(
        record: record,
        manifestJson: preview.json,
        sourceUrl: preview.sourceUrl,
      );
    } on Object {
      // The keystore write must not outlive a failed install.
      for (final String key in written) {
        await _secrets.delete(manifest.id, key);
      }
      throw const ProviderLifecycleFailure(
        'That source could not be saved, so it was not installed.',
        code: 'provider.storage',
      );
    }

    _revision++;
    return record;
  }

  // ── Configuration ─────────────────────────────────────────────────────────

  /// Updates configuration after installation.
  ///
  /// A secret included in [secrets] replaces the stored one; a key in
  /// [clearSecrets] removes it; a secret absent from both is left untouched.
  /// Existing non-secret values not present in [values] are dropped, because the
  /// form always submits the complete set.
  Future<void> updateConfiguration(
    String providerId, {
    required Map<String, String> values,
    Map<String, String> secrets = const <String, String>{},
    Set<String> clearSecrets = const <String>{},
  }) async {
    final List<ProviderRecord> records = await _store.loadAll();
    ProviderRecord? record;
    for (final ProviderRecord candidate in records) {
      if (candidate.providerId == providerId) {
        record = candidate;
        break;
      }
    }
    if (record == null || record.origin != ProviderOrigin.userAdded) {
      throw const ProviderLifecycleFailure(
        'That source is not installed.',
        code: 'provider.notInstalled',
      );
    }
    final String? json = await _store.manifestJsonFor(providerId);
    if (json == null) {
      throw const ProviderLifecycleFailure(
        'That source has no stored manifest.',
        code: 'provider.manifestInvalid',
      );
    }
    final ManifestValidationResult validation = ManifestValidator(
      builtInIds: _builtInIds,
    ).validate(json);
    final ProviderManifest? manifest = validation.manifest;
    if (manifest == null) {
      throw const ProviderLifecycleFailure(
        'That source\'s manifest is invalid, so its configuration cannot be '
        'edited. Remove and reinstall it.',
        code: 'provider.manifestInvalid',
      );
    }

    final Set<String> present = await _secrets.presentKeys(
      manifest.id,
      _secretKeys(manifest),
    );
    final Set<String> satisfiedSecrets = <String>{
      ...present,
      for (final MapEntry<String, String> entry in secrets.entries)
        if (entry.value.trim().isNotEmpty) entry.key,
    };
    final ManifestConfigResult config = ManifestConfigValidator.validate(
      manifest,
      values,
      presentSecrets: satisfiedSecrets,
    );
    if (!config.isValid) {
      throw ProviderLifecycleFailure(
        'Check the highlighted fields and try again.',
        code: 'provider.configInvalid',
        fieldErrors: config.errors,
      );
    }

    final Map<String, String> nonSecret = <String, String>{};
    for (final ManifestConfigField field in manifest.config) {
      if (field.type.isSecret) continue;
      final String? value = config.values[field.key];
      if (value != null) nonSecret[field.key] = value;
    }

    // Snapshot the secrets about to change so a later failure can restore them.
    final Map<String, String?> previous = <String, String?>{};
    for (final String key in <String>{...secrets.keys, ...clearSecrets}) {
      previous[key] = await _secrets.read(providerId, key);
    }

    Future<void> restoreSecrets() async {
      for (final MapEntry<String, String?> entry in previous.entries) {
        final String? value = entry.value;
        try {
          if (value == null || value.isEmpty) {
            await _secrets.delete(providerId, entry.key);
          } else {
            await _secrets.write(providerId, entry.key, value);
          }
        } on Object {
          // The keystore is already failing; the caller still gets the typed
          // refusal, and the config row was never written.
        }
      }
    }

    try {
      for (final MapEntry<String, String> entry in secrets.entries) {
        final String value = entry.value.trim();
        if (value.isEmpty) continue;
        await _secrets.write(providerId, entry.key, value);
      }
      for (final String key in clearSecrets) {
        await _secrets.delete(providerId, key);
      }
    } on Object {
      await restoreSecrets();
      throw const ProviderLifecycleFailure(
        'NEXUS could not update secure storage, so nothing was changed.',
        code: 'provider.secureStorage',
      );
    }

    try {
      await _store.setConfig(providerId, nonSecret);
    } on Object {
      await restoreSecrets();
      throw const ProviderLifecycleFailure(
        'That configuration could not be saved, so nothing was changed.',
        code: 'provider.storage',
      );
    }
    _revision++;
  }

  // ── Removal and enablement ────────────────────────────────────────────────

  /// Removes a user-added provider, its manifest, its per-title choices and its
  /// credentials. Library entries, history and playback positions are untouched.
  Future<void> remove(String providerId) async {
    final List<ProviderRecord> records = await _store.loadAll();
    ProviderRecord? record;
    for (final ProviderRecord candidate in records) {
      if (candidate.providerId == providerId) {
        record = candidate;
        break;
      }
    }
    if (record == null) {
      throw const ProviderLifecycleFailure(
        'That source is not installed.',
        code: 'provider.notInstalled',
      );
    }
    if (record.origin != ProviderOrigin.userAdded) {
      throw const ProviderLifecycleFailure(
        'Built-in sources cannot be removed.',
        code: 'provider.builtIn',
      );
    }

    final Set<String> secretKeys = <String>{};
    final String? json = await _store.manifestJsonFor(providerId);
    if (json != null) {
      final ManifestValidationResult validation = ManifestValidator(
        builtInIds: _builtInIds,
      ).validate(json);
      final ProviderManifest? manifest = validation.manifest;
      if (manifest != null) secretKeys.addAll(_secretKeys(manifest));
    }

    await _store.remove(providerId);
    // Best effort: the provider row is already gone, so a stale credential can
    // never be used; failing here must not make removal look unsuccessful.
    await _secrets.deleteProvider(providerId, secretKeys);
    _revision++;
  }

  Future<void> setEnabled(String providerId, bool enabled) async {
    await _store.setEnabled(providerId, enabled);
    _revision++;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Set<String> _secretKeys(ProviderManifest manifest) => <String>{
    for (final ManifestConfigField field in manifest.config)
      if (field.type.isSecret) field.key,
  };

  Future<Map<String, String>> _readSecretValues(
    ProviderManifest manifest,
  ) async {
    final Map<String, String> values = <String, String>{};
    for (final String key in _secretKeys(manifest)) {
      final String? value = await _secrets.read(manifest.id, key);
      if (value != null && value.isNotEmpty) values[key] = value;
    }
    return values;
  }
}

/// A manifest the user is about to install, already validated.
class ProviderInstallPreview {
  const ProviderInstallPreview({
    required this.json,
    required this.validation,
    required this.duplicate,
    this.sourceUrl,
  });

  final String json;
  final String? sourceUrl;
  final ManifestValidationResult validation;
  final bool duplicate;

  ProviderManifest? get manifest => validation.manifest;

  List<ManifestError> get errors => validation.errors;

  ProviderCompatibility get compatibility => validation.compatibility;

  ManifestStatus get status => validation.status;

  bool get canInstall =>
      validation.status == ManifestStatus.valid && !duplicate;

  String get blockingMessage {
    if (duplicate) return 'That source is already installed.';
    return switch (validation.status) {
      ManifestStatus.requiresNewerApp =>
        'This manifest needs a newer version of NEXUS.',
      ManifestStatus.unsupportedContract =>
        'This source targets a provider contract this build does not support.',
      ManifestStatus.invalid =>
        validation.errors.isEmpty
            ? 'This manifest is not valid.'
            : 'This manifest has ${validation.errors.length} '
                  '${validation.errors.length == 1 ? 'problem' : 'problems'}.',
      ManifestStatus.valid => '',
    };
  }
}

/// One installed user provider as read from disk, with its revalidated manifest.
///
/// Holds no provider instance: constructing one would open an HTTP client that
/// has to be disposed, and this object outlives a screen.
class InstalledProvider {
  const InstalledProvider({
    required this.record,
    required this.status,
    required this.compatibility,
    this.manifestJson,
    this.manifest,
    this.config = const <String, String>{},
    this.presentSecrets = const <String>{},
    this.errors = const <ManifestError>[],
    this.failure,
  });

  final ProviderRecord record;
  final String? manifestJson;
  final ProviderManifest? manifest;
  final ManifestStatus status;
  final ProviderCompatibility compatibility;
  final List<ManifestError> errors;
  final ProviderFailure? failure;

  /// Non-secret configuration only.
  final Map<String, String> config;

  /// Which declared secret fields hold a value. Never the values themselves.
  final Set<String> presentSecrets;

  String get id => record.providerId;

  bool get isCompatible => compatibility.isCompatible;

  bool get isValid => manifest != null && status == ManifestStatus.valid;

  ProviderDescriptor? get descriptor =>
      manifest == null ? null : ManifestDescriptor(manifest!);

  /// Configuration values plus presence markers, which is what the state axes
  /// evaluate. A secret is signalled as configured without its value.
  Map<String, String> get presenceConfig => <String, String>{
    ...config,
    for (final String key in presentSecrets) key: '***',
  };

  bool get isConfigured {
    final ProviderDescriptor? view = descriptor;
    if (view == null) return false;
    return ProviderConfigurationState.evaluate(
      view.configuration,
      presenceConfig,
    ).isSatisfied;
  }

  ProviderState stateFor({
    required ProviderAvailability availability,
    String message = 'Not checked yet.',
  }) {
    final ProviderDescriptor? view = descriptor;
    if (view == null) {
      throw StateError('No manifest for $id');
    }
    return ProviderState.from(
      descriptor: view,
      compatibility: compatibility,
      configurationValues: presenceConfig,
      availability: ProviderStatusSnapshot(
        availability: availability,
        message: message,
        observedAt: DateTime.now(),
      ),
      enabled: record.enabled,
    );
  }
}

/// A lifecycle refusal, safe to show.
class ProviderLifecycleFailure implements Exception {
  const ProviderLifecycleFailure(
    this.message, {
    this.code = 'provider.lifecycle',
    this.fieldErrors = const <String, String>{},
  });

  final String message;
  final String code;

  /// Field key → message, for a configuration form.
  final Map<String, String> fieldErrors;

  @override
  String toString() => 'ProviderLifecycleFailure($code): $message';
}
