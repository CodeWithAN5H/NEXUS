import 'dart:convert';

import '../../providers/provider_descriptor.dart';
import 'json_path_reader.dart';
import 'manifest_error.dart';
import 'provider_manifest.dart';

/// Offline validator for declarative provider manifests.
///
/// Implements stages 1–4 of `docs/PROVIDER_MANIFEST.md` §2/§9: parse, schema,
/// templates and paths, semantics, then compatibility. It is deterministic and
/// side-effect free: validating a manifest never opens a socket, never writes a
/// row and never constructs a provider.
///
/// It collects **every** problem it can rather than stopping at the first, so a
/// review screen can show a complete list. It is the only way to obtain a
/// [ProviderManifest]; there is no lenient constructor.
class ManifestValidator {
  const ManifestValidator({
    this.contractVersion = ProviderContract.current,
    this.builtInIds = const <String>{},
  });

  /// Maximum document size before parsing (PROVIDER_MANIFEST.md §9).
  static const int maxBytes = 512 * 1024;

  /// Maximum container nesting depth.
  static const int maxDepth = 12;

  /// Increment only when the provider contract changes breakingly.
  final int contractVersion;

  /// Ids compiled into the app; a manifest may not claim one.
  final Set<String> builtInIds;

  static final RegExp _idPattern = RegExp(
    r'^[a-z][a-z0-9]*(?:\.[a-z0-9][a-z0-9-]*)+$',
  );
  static final RegExp _semver = RegExp(
    r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]{1,32})?$',
  );
  static final RegExp _origin = RegExp(
    r'^https://(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,24}(?::[0-9]{1,5})?$',
  );
  static final RegExp _hostPattern = RegExp(
    r'^(?:\*\.)?(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,24}$',
  );
  static final RegExp _template = RegExp(r'''^[^\s<>"'\u0060]{1,512}$''');
  static final RegExp _homepage = RegExp(
    r'^https://[A-Za-z0-9.-]+(?::[0-9]{1,5})?(?:/[^\s]*)?$',
  );
  static final RegExp _configKey = RegExp(r'^[a-z][a-zA-Z0-9_]{0,31}$');
  static final RegExp _queryName = RegExp(r'^[A-Za-z][A-Za-z0-9-]{0,31}$');
  static final RegExp _headerName = RegExp(r'^[A-Za-z][A-Za-z0-9-]{0,31}$');

  static const Set<String> _forbiddenHeaders = <String>{
    'host',
    'content-length',
    'connection',
    'transfer-encoding',
    'upgrade',
    'expect',
    'cookie',
    'set-cookie',
  };

  /// Validates a JSON document.
  ManifestValidationResult validate(String source, {int? manifestVersion}) {
    final _Collector c = _Collector();

    final int byteLength = utf8.encode(source).length;
    if (byteLength > maxBytes) {
      c.add(
        'manifest.parse',
        '/',
        'The manifest is ${_kib(byteLength)} KiB; the limit is 512 KiB.',
      );
      return _invalid(c);
    }
    if (_exceedsDepth(source, maxDepth)) {
      c.add(
        'manifest.parse',
        '/',
        'The document nests deeper than $maxDepth levels.',
      );
      return _invalid(c);
    }

    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      final String at = error.offset == null ? '' : ' at byte ${error.offset}';
      c.add('manifest.parse', '/', 'The document is not valid JSON$at.');
      return _invalid(c);
    }
    return validateDecoded(decoded, manifestVersion: manifestVersion);
  }

  /// Validates an already-decoded document (used by tests and by stored copies).
  ManifestValidationResult validateDecoded(
    Object? decoded, {
    int? manifestVersion,
  }) {
    final _Collector c = _Collector();

    if (decoded is! Map<String, dynamic>) {
      c.add('manifest.schema', '/', 'A manifest must be a JSON object.');
      return _invalid(c);
    }

    final Object? declaredVersion = decoded['manifestVersion'];
    if (declaredVersion is! int) {
      c.add(
        'manifest.schema',
        '/manifestVersion',
        declaredVersion == null
            ? 'This property is required.'
            : 'The manifest format version must be an integer.',
      );
      return _invalid(c);
    }
    if (declaredVersion != ProviderManifest.supportedVersion) {
      // A newer format is a compatibility outcome, not a defect: the copy is
      // retained so an app update can revive it (PROVIDER_MANIFEST.md §10).
      return ManifestValidationResult(
        status: ManifestStatus.requiresNewerApp,
        compatibility: ProviderCompatibility.requiresNewerApp,
      );
    }

    _checkSchema(decoded, c);
    _checkTemplates(decoded, c);
    _checkPaths(decoded, c);
    _checkSemantics(decoded, c);

    if (!c.isEmpty) return _invalid(c);

    final ProviderManifest manifest = _buildManifest(decoded);
    final ProviderCompatibility compatibility = _compatibility(manifest);
    return ManifestValidationResult(
      status: compatibility.isCompatible
          ? ManifestStatus.valid
          : ManifestStatus.unsupportedContract,
      compatibility: compatibility,
      manifest: manifest,
    );
  }

  // ── Stage 2: schema ───────────────────────────────────────────────────────

  void _checkSchema(Map<String, dynamic> doc, _Collector c) {
    _unknownKeys(doc, '', _topLevelKeys, c);

    _string(
      doc,
      'id',
      '',
      c,
      min: 1,
      max: 80,
      pattern: _idPattern,
      patternHint: 'lowercase reverse-dns, e.g. "dev.example.catalogue"',
    );
    _string(doc, 'name', '', c, min: 1, max: 60);
    _string(
      doc,
      'version',
      '',
      c,
      pattern: _semver,
      patternHint: 'semantic version, e.g. "1.0.0"',
    );
    _string(doc, 'description', '', c, required: false, max: 280);
    _string(doc, 'attribution', '', c, min: 3, max: 280);
    _string(doc, 'notice', '', c, required: false, max: 200);

    final String? homepage = _string(
      doc,
      'homepage',
      '',
      c,
      required: false,
      max: 512,
      pattern: _homepage,
      patternHint: 'an https URL',
    );
    if (homepage != null) {
      final Uri? uri = Uri.tryParse(homepage);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        c.add(
          'manifest.schema',
          '/homepage',
          'The homepage must be an absolute https URL.',
        );
      }
    }

    final Object? kind = doc['kind'];
    if (kind == null) {
      c.add('manifest.schema', '/kind', 'This property is required.');
    } else if (kind != 'streaming') {
      c.add(
        'manifest.schema',
        '/kind',
        'v1 defines streaming manifests only ("streaming"); metadata manifests '
            'are not supported.',
      );
    }

    _checkContract(doc, c);
    _checkCapabilities(doc, c);
    _checkConfig(doc, c);
    final List<Uri>? origins = _checkNet(doc, c);
    _checkRequests(doc, origins ?? const <Uri>[], c);

    final Object? errors = doc['errors'];
    if (errors != null) {
      if (errors is! Map<String, dynamic>) {
        c.add('manifest.schema', '/errors', 'This value must be an object.');
      } else {
        _checkErrorPolicy(errors, c);
      }
    }
  }

  static const Set<String> _topLevelKeys = <String>{
    'manifestVersion',
    'id',
    'name',
    'version',
    'description',
    'kind',
    'contract',
    'attribution',
    'homepage',
    'capabilities',
    'config',
    'net',
    'requests',
    'errors',
    'notice',
  };

  void _checkContract(Map<String, dynamic> doc, _Collector c) {
    final Object? contract = doc['contract'];
    if (contract == null) {
      c.add('manifest.schema', '/contract', 'This property is required.');
      return;
    }
    if (contract is! Map<String, dynamic>) {
      c.add('manifest.schema', '/contract', 'This value must be an object.');
      return;
    }
    _unknownKeys(contract, '/contract', const <String>{'min', 'max'}, c);
    final int? min = _int(contract, 'min', '/contract', c, min: 1, max: 1000);
    final int? max = _int(contract, 'max', '/contract', c, min: 1, max: 1000);
    if (min != null && max != null && min > max) {
      c.add(
        'manifest.schema',
        '/contract',
        'The minimum contract version cannot be above the maximum.',
      );
    }
  }

  void _checkCapabilities(Map<String, dynamic> doc, _Collector c) {
    final Object? raw = doc['capabilities'];
    if (raw == null) {
      c.add('manifest.schema', '/capabilities', 'This property is required.');
      return;
    }
    if (raw is! List) {
      c.add('manifest.schema', '/capabilities', 'This value must be an array.');
      return;
    }
    if (raw.isEmpty) {
      c.add(
        'manifest.schema',
        '/capabilities',
        'A provider must declare at least one capability.',
      );
    }
    if (raw.length > 9) {
      c.add(
        'manifest.schema',
        '/capabilities',
        'At most 9 capabilities may be declared.',
      );
    }
    final Set<String> seen = <String>{};
    for (int i = 0; i < raw.length; i++) {
      final String path = '/capabilities/$i';
      final Object? value = raw[i];
      if (value is! String) {
        c.add('manifest.schema', path, 'A capability must be a string.');
        continue;
      }
      if (value == 'continueWatching') {
        c.add(
          'manifest.schema',
          path,
          'Provider-side resume is not part of manifest v1.',
        );
        continue;
      }
      if (ManifestCapability.fromName(value) == null) {
        c.add('manifest.schema', path, '"$value" is not a known capability.');
      }
      if (!seen.add(value)) {
        c.add('manifest.schema', path, 'This capability is declared twice.');
      }
    }
  }

  void _checkConfig(Map<String, dynamic> doc, _Collector c) {
    final Object? raw = doc['config'];
    if (raw == null) return;
    if (raw is! List) {
      c.add('manifest.schema', '/config', 'This value must be an array.');
      return;
    }
    if (raw.length > 12) {
      c.add(
        'manifest.schema',
        '/config',
        'At most 12 configuration fields may be declared.',
      );
    }
    for (int i = 0; i < raw.length; i++) {
      final String path = '/config/$i';
      final Object? entry = raw[i];
      if (entry is! Map<String, dynamic>) {
        c.add('manifest.schema', path, 'Each field must be an object.');
        continue;
      }
      _unknownKeys(entry, path, _configFieldKeys, c);
      _string(
        entry,
        'key',
        path,
        c,
        pattern: _configKey,
        patternHint: 'lowercase first letter, letters/digits/underscore only',
      );
      _string(entry, 'label', path, c, min: 1, max: 60);
      final String? type = _string(entry, 'type', path, c);
      _string(entry, 'hint', path, c, required: false, max: 160);
      _string(entry, 'placeholder', path, c, required: false, max: 120);
      _string(entry, 'defaultValue', path, c, required: false, max: 512);
      _int(entry, 'maxLength', path, c, required: false, min: 1, max: 512);
      _bool(entry, 'required', path, c, required: false);

      final String? pattern = _string(
        entry,
        'pattern',
        path,
        c,
        required: false,
        max: 200,
      );
      if (pattern != null) {
        try {
          RegExp(pattern);
        } on FormatException {
          c.add(
            'manifest.schema',
            '$path/pattern',
            'This is not a valid regular expression.',
          );
        }
      }

      final List<String>? choices = _stringList(
        entry,
        'choices',
        path,
        c,
        required: false,
        maxItems: 16,
        maxLength: 40,
      );
      if (type == 'choice') {
        if (choices == null || choices.length < 2) {
          c.add(
            'manifest.schema',
            '$path/choices',
            'A choice field needs at least two choices.',
          );
        }
      } else if (choices != null) {
        c.add(
          'manifest.schema',
          '$path/choices',
          'Only a choice field may declare choices.',
        );
      }

      final Object? defaultValue = entry['defaultValue'];
      if (defaultValue != null) {
        if (defaultValue is! String) {
          c.add(
            'manifest.schema',
            '$path/defaultValue',
            'A default value must be a string.',
          );
        } else {
          switch (type) {
            case 'url':
              final Uri? uri = Uri.tryParse(defaultValue);
              if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
                c.add(
                  'manifest.schema',
                  '$path/defaultValue',
                  'A url field default must be an absolute https URL.',
                );
              }
            case 'bool':
              if (defaultValue != 'true' && defaultValue != 'false') {
                c.add(
                  'manifest.schema',
                  '$path/defaultValue',
                  'A bool default must be "true" or "false".',
                );
              }
            case 'secret':
              c.add(
                'manifest.semantic',
                '$path/defaultValue',
                'A secret field cannot declare a default value: secrets are '
                    'entered by the user and stored in the keystore.',
              );
            case 'choice':
              if (choices != null && !choices.contains(defaultValue)) {
                c.add(
                  'manifest.schema',
                  '$path/defaultValue',
                  'The default must be one of the declared choices.',
                );
              }
            case 'text':
            case null:
              break;
          }
        }
      }
    }
  }

  static const Set<String> _configFieldKeys = <String>{
    'key',
    'label',
    'type',
    'required',
    'hint',
    'defaultValue',
    'placeholder',
    'choices',
    'pattern',
    'maxLength',
  };

  List<Uri>? _checkNet(Map<String, dynamic> doc, _Collector c) {
    final Object? raw = doc['net'];
    if (raw == null) {
      c.add('manifest.schema', '/net', 'This property is required.');
      return null;
    }
    if (raw is! Map<String, dynamic>) {
      c.add('manifest.schema', '/net', 'This value must be an object.');
      return null;
    }
    _unknownKeys(raw, '/net', _netKeys, c);

    final List<String>? origins = _stringList(
      raw,
      'origins',
      '/net',
      c,
      minItems: 1,
      maxItems: 8,
      maxLength: 128,
      pattern: _origin,
      patternHint: 'an https origin with a DNS host, no path',
    );
    final List<Uri> parsed = <Uri>[];
    if (origins != null) {
      for (int i = 0; i < origins.length; i++) {
        final Uri? uri = Uri.tryParse(origins[i]);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.path.length > 1 ||
            uri.hasQuery ||
            uri.hasFragment) {
          c.add(
            'manifest.schema',
            '/net/origins/$i',
            'An origin must be https://host[:port] with no path or '
                'credentials.',
          );
          continue;
        }
        if (uri.hasPort && uri.port > 65535) {
          c.add('manifest.schema', '/net/origins/$i', 'The port is invalid.');
          continue;
        }
        parsed.add(
          Uri(
            scheme: 'https',
            host: uri.host,
            port: uri.hasPort ? uri.port : null,
          ),
        );
      }
    }

    _stringList(
      raw,
      'mediaHosts',
      '/net',
      c,
      required: false,
      maxItems: 16,
      maxLength: 128,
      pattern: _hostPattern,
      patternHint: 'lowercase DNS host or "*.example.com"',
    );
    _int(raw, 'maxRedirects', '/net', c, required: false, min: 0, max: 5);
    _int(
      raw,
      'minRequestIntervalMs',
      '/net',
      c,
      required: false,
      min: 0,
      max: 10000,
    );
    _int(raw, 'timeoutMs', '/net', c, required: false, min: 1000, max: 20000);
    _int(
      raw,
      'maxResponseBytes',
      '/net',
      c,
      required: false,
      min: 16384,
      max: 2097152,
    );
    return parsed;
  }

  static const Set<String> _netKeys = <String>{
    'origins',
    'mediaHosts',
    'maxRedirects',
    'minRequestIntervalMs',
    'timeoutMs',
    'maxResponseBytes',
  };

  void _checkRequests(
    Map<String, dynamic> doc,
    List<Uri> origins,
    _Collector c,
  ) {
    final Object? raw = doc['requests'];
    if (raw == null) {
      c.add('manifest.schema', '/requests', 'This property is required.');
      return;
    }
    if (raw is! Map<String, dynamic>) {
      c.add('manifest.schema', '/requests', 'This value must be an object.');
      return;
    }
    _unknownKeys(raw, '/requests', _requestKinds, c);
    if (raw.isEmpty) {
      c.add(
        'manifest.schema',
        '/requests',
        'A manifest must define at least one request.',
      );
    }

    if (raw['probe'] != null) _probe(raw, origins, c);
    if (raw['search'] != null) _search(raw, origins, c);
    if (raw['match'] != null) _match(raw, origins, c);
    if (raw['seasons'] != null) _seasons(raw, origins, c);
    if (raw['episodes'] != null) _episodes(raw, origins, c);
    if (raw['resolve'] != null) _resolve(raw, origins, c);
  }

  static const Set<String> _requestKinds = <String>{
    'probe',
    'search',
    'match',
    'seasons',
    'episodes',
    'resolve',
  };

  void _probe(Map<String, dynamic> requests, List<Uri> origins, _Collector c) {
    const String path = '/requests/probe';
    final Map<String, dynamic>? m = _requestObject(requests, 'probe', c);
    if (m == null) return;
    _unknownKeys(m, path, const <String>{
      'method',
      'url',
      'headers',
      'timeoutMs',
      'expectStatus',
    }, c);
    _requestSpec(
      m,
      path,
      c,
      origins: origins,
      methods: const <String>{'GET', 'HEAD'},
      allowQuery: false,
      allowBody: false,
      allowBytes: false,
      allowNotFound: false,
    );
    _statusList(m, 'expectStatus', path, c, required: false);
  }

  void _search(Map<String, dynamic> requests, List<Uri> origins, _Collector c) {
    const String path = '/requests/search';
    final Map<String, dynamic>? m = _requestObject(requests, 'search', c);
    if (m == null) return;
    _unknownKeys(m, path, _listRequestKeys, c);
    _requestSpec(m, path, c, origins: origins);
    _int(m, 'maxResults', path, c, required: false, min: 1, max: 100);
    _listMapping(m, path, c, _seriesRequired, _seriesOptional);
  }

  void _match(Map<String, dynamic> requests, List<Uri> origins, _Collector c) {
    const String path = '/requests/match';
    final Map<String, dynamic>? m = _requestObject(requests, 'match', c);
    if (m == null) return;
    _unknownKeys(m, path, <String>{
      ..._listRequestKeys,
      'strategy',
      'minConfidence',
    }, c);
    _requestSpec(m, path, c, origins: origins);
    _int(m, 'maxResults', path, c, required: false, min: 1, max: 50);
    final String? strategy = _string(m, 'strategy', path, c);
    if (strategy != null) {
      const Set<String> strategies = <String>{
        'exactTitle',
        'normalisedTitle',
        'normalisedTitleAndYear',
      };
      if (!strategies.contains(strategy)) {
        c.add(
          'manifest.schema',
          '$path/strategy',
          '"$strategy" is not a supported match strategy.',
        );
      }
    }
    _number(m, 'minConfidence', path, c, required: false, min: 0, max: 1);
    _listMapping(m, path, c, _seriesRequired, _seriesOptional);
  }

  void _seasons(
    Map<String, dynamic> requests,
    List<Uri> origins,
    _Collector c,
  ) {
    const String path = '/requests/seasons';
    final Map<String, dynamic>? m = _requestObject(requests, 'seasons', c);
    if (m == null) return;
    _unknownKeys(m, path, _listRequestKeys, c);
    _requestSpec(m, path, c, origins: origins);
    _listMapping(
      m,
      path,
      c,
      const <String>{'seasonId', 'label', 'index'},
      const <String>{'episodeCount', 'year'},
    );
  }

  void _episodes(
    Map<String, dynamic> requests,
    List<Uri> origins,
    _Collector c,
  ) {
    const String path = '/requests/episodes';
    final Map<String, dynamic>? m = _requestObject(requests, 'episodes', c);
    if (m == null) return;
    _unknownKeys(m, path, <String>{..._listRequestKeys, 'numbering'}, c);
    _requestSpec(m, path, c, origins: origins);
    final String numbering =
        _string(m, 'numbering', path, c, required: false) ?? 'absolute';
    if (numbering != 'absolute' && numbering != 'seasonRelative') {
      c.add(
        'manifest.schema',
        '$path/numbering',
        '"$numbering" is not a supported numbering mode.',
      );
    }
    final ManifestListMapping? mapping = _listMapping(
      m,
      path,
      c,
      const <String>{'episodeId', 'number', 'title'},
      const <String>{'seasonId', 'durationSeconds', 'thumbnail', 'description'},
    );
    if (numbering == 'seasonRelative' && mapping != null) {
      if (mapping.path('seasonId') == null) {
        c.add(
          'manifest.schema',
          '$path/map',
          'Season-relative numbering needs "seasonId" in the map so absolute '
              'numbers can be computed.',
        );
      }
    }
  }

  void _resolve(
    Map<String, dynamic> requests,
    List<Uri> origins,
    _Collector c,
  ) {
    const String path = '/requests/resolve';
    final Map<String, dynamic>? m = _requestObject(requests, 'resolve', c);
    if (m == null) return;
    _unknownKeys(m, path, <String>{
      'method',
      'url',
      'query',
      'headers',
      'timeoutMs',
      'maxBytes',
      'notFoundStatus',
      'variants',
      'subtitles',
      'audio',
      'streamHeaders',
      'defaultProtocol',
    }, c);
    _requestSpec(m, path, c, origins: origins, allowBody: false);

    final Object? variants = m['variants'];
    if (variants == null) {
      c.add('manifest.schema', '$path/variants', 'This property is required.');
    } else if (variants is! Map<String, dynamic>) {
      c.add(
        'manifest.schema',
        '$path/variants',
        'This value must be an object.',
      );
    } else {
      _unknownKeys(variants, '$path/variants', const <String>{
        'list',
        'map',
      }, c);
      _listMapping(
        variants,
        '$path/variants',
        c,
        const <String>{'label', 'uri'},
        const <String>{'height', 'protocol', 'isDefault'},
      );
    }

    final Object? subtitles = m['subtitles'];
    if (subtitles != null) {
      if (subtitles is! Map<String, dynamic>) {
        c.add(
          'manifest.schema',
          '$path/subtitles',
          'This value must be an object.',
        );
      } else {
        _unknownKeys(subtitles, '$path/subtitles', const <String>{
          'list',
          'map',
        }, c);
        _listMapping(
          subtitles,
          '$path/subtitles',
          c,
          const <String>{'label', 'uri'},
          const <String>{'language', 'isDefault'},
        );
      }
    }

    final Object? audio = m['audio'];
    if (audio != null) {
      if (audio is! Map<String, dynamic>) {
        c.add(
          'manifest.schema',
          '$path/audio',
          'This value must be an object.',
        );
      } else {
        _unknownKeys(audio, '$path/audio', const <String>{'list', 'map'}, c);
        _listMapping(
          audio,
          '$path/audio',
          c,
          const <String>{'label'},
          const <String>{'language', 'isDefault'},
        );
      }
    }

    final Object? streamHeaders = m['streamHeaders'];
    if (streamHeaders != null) {
      _headers(m, 'streamHeaders', path, c);
    }
    final String? protocol = _string(
      m,
      'defaultProtocol',
      path,
      c,
      required: false,
    );
    if (protocol != null &&
        !const <String>{'hls', 'dash', 'progressive'}.contains(protocol)) {
      c.add(
        'manifest.schema',
        '$path/defaultProtocol',
        '"$protocol" is not a supported protocol.',
      );
    }
  }

  Map<String, dynamic>? _requestObject(
    Map<String, dynamic> requests,
    String kind,
    _Collector c,
  ) {
    final Object? value = requests[kind];
    if (value is! Map<String, dynamic>) {
      c.add(
        'manifest.schema',
        '/requests/$kind',
        'This value must be an object.',
      );
      return null;
    }
    return value;
  }

  static const Set<String> _listRequestKeys = <String>{
    'method',
    'url',
    'query',
    'headers',
    'body',
    'timeoutMs',
    'maxBytes',
    'notFoundStatus',
    'list',
    'maxResults',
    'map',
  };

  static const Set<String> _seriesRequired = <String>{'seriesId', 'title'};
  static const Set<String> _seriesOptional = <String>{
    'coverImage',
    'synopsis',
    'year',
    'episodeCount',
  };

  void _requestSpec(
    Map<String, dynamic> m,
    String path,
    _Collector c, {
    required List<Uri> origins,
    Set<String> methods = const <String>{'GET', 'POST'},
    bool allowQuery = true,
    bool allowBody = true,
    bool allowBytes = true,
    bool allowNotFound = true,
  }) {
    final String? url = _string(
      m,
      'url',
      path,
      c,
      min: 1,
      max: 512,
      pattern: _template,
      patternHint:
          'a URL template with no whitespace, quotes or angle brackets',
    );

    final String method =
        _string(m, 'method', path, c, required: false) ?? 'GET';
    if (!methods.contains(method)) {
      c.add(
        'manifest.schema',
        '$path/method',
        'The method must be one of ${methods.join(', ')}.',
      );
    }

    if (url != null) _checkUrlShape(url, '$path/url', origins, c);

    if (allowQuery) {
      _templateMap(m, 'query', path, c);
      _headers(m, 'headers', path, c);
    } else if (m['query'] != null || m['headers'] != null) {
      // Probe accepts headers but not query parameters.
      if (m['headers'] != null) _headers(m, 'headers', path, c);
      if (m['query'] != null) {
        c.add(
          'manifest.schema',
          '$path/query',
          'A probe request cannot declare query parameters.',
        );
      }
    }

    if (allowBody && m['body'] != null) {
      _body(m, 'body', path, c);
    } else if (!allowBody && m['body'] != null) {
      c.add(
        'manifest.schema',
        '$path/body',
        'This request cannot declare a body.',
      );
    }

    _int(m, 'timeoutMs', path, c, required: false, min: 1000, max: 20000);
    if (allowBytes) {
      _int(m, 'maxBytes', path, c, required: false, min: 16384, max: 2097152);
    }
    if (allowNotFound) {
      _statusList(m, 'notFoundStatus', path, c, required: false);
    }
  }

  void _checkUrlShape(
    String url,
    String path,
    List<Uri> origins,
    _Collector c,
  ) {
    if (url.contains(RegExp(r'\s'))) {
      c.add(
        'manifest.schema',
        path,
        'A URL template cannot contain whitespace.',
      );
      return;
    }
    if (url.startsWith('{')) {
      final List<String> placeholders = _placeholders(url);
      if (placeholders.isEmpty) {
        c.add('manifest.schema', path, 'This is not a usable URL template.');
        return;
      }
      final String first = placeholders.first;
      if (first != 'baseUrl' && !first.startsWith('config.')) {
        c.add(
          'manifest.schema',
          path,
          'A URL template must start with https://, {baseUrl} or '
              '{config.<key>}.',
        );
      }
      return;
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      c.add(
        'manifest.schema',
        path,
        'A request URL must be an absolute https URL or begin with a '
            'placeholder.',
      );
      return;
    }
    if (uri.userInfo.isNotEmpty) {
      c.add(
        'manifest.schema',
        path,
        'A request URL cannot contain credentials.',
      );
      return;
    }
    if (!_originContains(origins, uri)) {
      c.add(
        'manifest.schema',
        path,
        'The URL host "${uri.host}" is not declared in net.origins.',
      );
    }
  }

  Map<String, String>? _templateMap(
    Map<String, dynamic> m,
    String key,
    String path,
    _Collector c,
  ) {
    final Object? raw = m[key];
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) {
      c.add('manifest.schema', '$path/$key', 'This value must be an object.');
      return null;
    }
    if (raw.length > 12) {
      c.add('manifest.schema', '$path/$key', 'At most 12 entries are allowed.');
    }
    final Map<String, String> result = <String, String>{};
    for (final MapEntry<String, dynamic> entry in raw.entries) {
      final String entryPath = '$path/$key/${entry.key}';
      if (!_queryName.hasMatch(entry.key)) {
        c.add(
          'manifest.schema',
          entryPath,
          'A name must start with a letter and use letters, digits or hyphens.',
        );
        continue;
      }
      final Object? value = entry.value;
      if (value is! String) {
        c.add('manifest.schema', entryPath, 'This value must be a string.');
        continue;
      }
      if (value.length > 512 || !_template.hasMatch(value)) {
        c.add(
          'manifest.schema',
          entryPath,
          'A template must be 1–512 characters with no whitespace or quotes.',
        );
        continue;
      }
      result[entry.key] = value;
    }
    return result;
  }

  Map<String, String>? _headers(
    Map<String, dynamic> m,
    String key,
    String path,
    _Collector c,
  ) {
    final Object? raw = m[key];
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) {
      c.add('manifest.schema', '$path/$key', 'This value must be an object.');
      return null;
    }
    if (raw.length > 10) {
      c.add('manifest.schema', '$path/$key', 'At most 10 headers are allowed.');
    }
    final Map<String, String> result = <String, String>{};
    for (final MapEntry<String, dynamic> entry in raw.entries) {
      final String entryPath = '$path/$key/${entry.key}';
      if (!_headerName.hasMatch(entry.key)) {
        c.add('manifest.schema', entryPath, 'This is not a valid header name.');
        continue;
      }
      if (_forbiddenHeaders.contains(entry.key.toLowerCase())) {
        c.add(
          'manifest.schema',
          entryPath,
          'The "${entry.key}" header cannot be set by a manifest.',
        );
        continue;
      }
      final Object? value = entry.value;
      if (value is! String) {
        c.add('manifest.schema', entryPath, 'This value must be a string.');
        continue;
      }
      if (value.length > 1024 || !_template.hasMatch(value)) {
        c.add(
          'manifest.schema',
          entryPath,
          'A header template must be 1–1024 characters with no whitespace or '
              'quotes.',
        );
        continue;
      }
      result[entry.key] = value;
    }
    return result;
  }

  Map<String, Object?>? _body(
    Map<String, dynamic> m,
    String key,
    String path,
    _Collector c,
  ) {
    final Object? raw = m[key];
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) {
      c.add('manifest.schema', '$path/$key', 'This value must be an object.');
      return null;
    }
    if (raw.length > 12) {
      c.add(
        'manifest.schema',
        '$path/$key',
        'At most 12 body fields are allowed.',
      );
    }
    final Map<String, Object?> result = <String, Object?>{};
    for (final MapEntry<String, dynamic> entry in raw.entries) {
      final String entryPath = '$path/$key/${entry.key}';
      final Object? value = entry.value;
      if (value is Map || value is List) {
        c.add(
          'manifest.schema',
          entryPath,
          'A request body is flat: nested objects and arrays are not allowed.',
        );
        continue;
      }
      if (value is! String && value is! num && value is! bool) {
        c.add(
          'manifest.schema',
          entryPath,
          'A body value must be a string, number or boolean.',
        );
        continue;
      }
      if (value is String &&
          (value.length > 512 || !_template.hasMatch(value))) {
        c.add(
          'manifest.schema',
          entryPath,
          'A body template must be 1–512 characters with no whitespace or '
              'quotes.',
        );
        continue;
      }
      result[entry.key] = value;
    }
    return result;
  }

  void _statusList(
    Map<String, dynamic> m,
    String key,
    String path,
    _Collector c, {
    required bool required,
  }) {
    final Object? raw = m[key];
    if (raw == null) {
      if (required) c.add('manifest.schema', '$path/$key', 'Required.');
      return;
    }
    if (raw is! List) {
      c.add('manifest.schema', '$path/$key', 'This value must be an array.');
      return;
    }
    if (raw.length > 8) {
      c.add(
        'manifest.schema',
        '$path/$key',
        'At most 8 status codes are allowed.',
      );
    }
    final Set<int> seen = <int>{};
    for (int i = 0; i < raw.length; i++) {
      final Object? value = raw[i];
      if (value is! int || value < 100 || value > 599) {
        c.add(
          'manifest.schema',
          '$path/$key/$i',
          'A status code must be an integer from 100 to 599.',
        );
        continue;
      }
      if (!seen.add(value)) {
        c.add('manifest.schema', '$path/$key/$i', 'This code is listed twice.');
      }
    }
  }

  ManifestListMapping? _listMapping(
    Map<String, dynamic> m,
    String path,
    _Collector c,
    Set<String> requiredFields,
    Set<String> optionalFields,
  ) {
    final Object? raw = m['map'];
    if (raw == null) {
      c.add('manifest.schema', '$path/map', 'This property is required.');
      return null;
    }
    if (raw is! Map<String, dynamic>) {
      c.add('manifest.schema', '$path/map', 'This value must be an object.');
      return null;
    }
    _unknownKeys(raw, '$path/map', <String>{
      ...requiredFields,
      ...optionalFields,
    }, c);
    final Map<String, String> fields = <String, String>{};
    for (final String field in requiredFields) {
      final String? value = _string(raw, field, '$path/map', c, max: 256);
      if (value != null) fields[field] = value;
    }
    for (final String field in optionalFields) {
      final String? value = _string(
        raw,
        field,
        '$path/map',
        c,
        required: false,
        max: 256,
      );
      if (value != null) fields[field] = value;
    }

    final Object? list = m['list'];
    if (list == null) {
      c.add('manifest.schema', '$path/list', 'This property is required.');
      return null;
    }
    if (list is! String) {
      c.add('manifest.schema', '$path/list', 'This value must be a string.');
      return null;
    }
    return ManifestListMapping(list: list, fields: fields);
  }

  void _checkErrorPolicy(Map<String, dynamic> errors, _Collector c) {
    const String path = '/errors';
    _unknownKeys(errors, path, const <String>{
      'unauthorisedStatus',
      'rateLimitedStatus',
      'retryAfterHeader',
      'messagePath',
      'maxRetryAfterSeconds',
    }, c);
    _statusList(errors, 'unauthorisedStatus', path, c, required: false);
    _statusList(errors, 'rateLimitedStatus', path, c, required: false);
    _string(
      errors,
      'retryAfterHeader',
      path,
      c,
      required: false,
      max: 40,
      pattern: _headerName,
      patternHint: 'a valid header name',
    );
    _string(errors, 'messagePath', path, c, required: false, max: 256);
    _int(
      errors,
      'maxRetryAfterSeconds',
      path,
      c,
      required: false,
      min: 1,
      max: 3600,
    );
  }

  // ── Stage 3: templates ────────────────────────────────────────────────────

  void _checkTemplates(Map<String, dynamic> doc, _Collector c) {
    final Set<String> configKeys = _declaredConfigKeys(doc);
    final bool hasBaseUrl = _hasBaseUrlField(doc);
    final Map<String, dynamic>? requests =
        doc['requests'] is Map<String, dynamic>
        ? doc['requests'] as Map<String, dynamic>
        : null;
    if (requests == null) return;

    for (final String kind in _requestKinds) {
      final Object? raw = requests[kind];
      if (raw is! Map<String, dynamic>) continue;
      final String path = '/requests/$kind';
      final Set<String> allowed = _allowedPlaceholders(kind);
      for (final MapEntry<String, dynamic> entry in raw.entries) {
        if (entry.key == 'url' ||
            entry.key == 'query' ||
            entry.key == 'headers' ||
            entry.key == 'streamHeaders') {
          _checkTemplateValue(
            entry.value,
            '$path/${entry.key}',
            kind,
            allowed,
            configKeys,
            hasBaseUrl,
            c,
          );
        }
        if (entry.key == 'map' && entry.value is Map<String, dynamic>) {
          // Paths, not templates: handled by the path stage.
          continue;
        }
        if (entry.key == 'body' && entry.value is Map<String, dynamic>) {
          for (final MapEntry<String, dynamic> body
              in (entry.value as Map<String, dynamic>).entries) {
            final Object? value = body.value;
            if (value is String) {
              _checkTemplateString(
                value,
                '$path/body/${body.key}',
                kind,
                allowed,
                configKeys,
                hasBaseUrl,
                c,
              );
            }
          }
        }
        if ((entry.key == 'variants' ||
                entry.key == 'subtitles' ||
                entry.key == 'audio') &&
            entry.value is Map<String, dynamic>) {
          continue;
        }
      }
    }
  }

  void _checkTemplateValue(
    Object? value,
    String path,
    String kind,
    Set<String> allowed,
    Set<String> configKeys,
    bool hasBaseUrl,
    _Collector c,
  ) {
    if (value is String) {
      _checkTemplateString(
        value,
        path,
        kind,
        allowed,
        configKeys,
        hasBaseUrl,
        c,
      );
      return;
    }
    if (value is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in value.entries) {
        if (entry.value is String) {
          _checkTemplateString(
            entry.value as String,
            '$path/${entry.key}',
            kind,
            allowed,
            configKeys,
            hasBaseUrl,
            c,
          );
        }
      }
    }
  }

  void _checkTemplateString(
    String template,
    String path,
    String kind,
    Set<String> allowed,
    Set<String> configKeys,
    bool hasBaseUrl,
    _Collector c,
  ) {
    for (final String name in _placeholders(template)) {
      if (name == 'baseUrl') {
        if (!hasBaseUrl) {
          c.add(
            'manifest.template',
            path,
            '{baseUrl} is used but no "baseUrl" url configuration field is '
                'declared.',
          );
        }
        continue;
      }
      if (name.startsWith('config.')) {
        final String key = name.substring('config.'.length);
        if (!configKeys.contains(key)) {
          c.add(
            'manifest.template',
            path,
            '{$name} refers to a configuration field this manifest does not '
                'declare.',
          );
        }
        continue;
      }
      if (!allowed.contains(name)) {
        c.add(
          'manifest.template',
          path,
          '{$name} is not available in a $kind request.',
        );
      }
    }
  }

  Set<String> _allowedPlaceholders(String kind) => switch (kind) {
    'probe' => const <String>{},
    'search' => const <String>{'query', 'page'},
    'match' => const <String>{
      'query',
      'title',
      'titleRomaji',
      'titleEnglish',
      'year',
    },
    'seasons' => const <String>{'seriesId'},
    'episodes' => const <String>{'seriesId', 'seasonId', 'seasonIndex'},
    'resolve' => const <String>{'seriesId', 'episodeId'},
    _ => const <String>{},
  };

  // ── Stage 3: JSON paths ───────────────────────────────────────────────────

  void _checkPaths(Map<String, dynamic> doc, _Collector c) {
    final Object? requests = doc['requests'];
    if (requests is! Map<String, dynamic>) return;
    for (final String kind in _requestKinds) {
      final Object? raw = requests[kind];
      if (raw is! Map<String, dynamic>) continue;
      final String path = '/requests/$kind';
      if (raw['list'] is String) {
        _checkPath(raw['list'] as String, '$path/list', c);
      }
      if (raw['map'] is Map<String, dynamic>) {
        final Map<String, dynamic> map = raw['map'] as Map<String, dynamic>;
        for (final MapEntry<String, dynamic> entry in map.entries) {
          if (entry.value is String) {
            _checkPath(entry.value as String, '$path/map/${entry.key}', c);
          }
        }
      }
      for (final String section in const <String>[
        'variants',
        'subtitles',
        'audio',
      ]) {
        final Object? group = raw[section];
        if (group is! Map<String, dynamic>) continue;
        if (group['list'] is String) {
          _checkPath(group['list'] as String, '$path/$section/list', c);
        }
        if (group['map'] is Map<String, dynamic>) {
          final Map<String, dynamic> map = group['map'] as Map<String, dynamic>;
          for (final MapEntry<String, dynamic> entry in map.entries) {
            if (entry.value is String) {
              _checkPath(
                entry.value as String,
                '$path/$section/map/${entry.key}',
                c,
              );
            }
          }
        }
      }
    }
    final Object? errors = doc['errors'];
    if (errors is Map<String, dynamic> && errors['messagePath'] is String) {
      _checkPath(errors['messagePath'] as String, '/errors/messagePath', c);
    }
  }

  void _checkPath(String source, String path, _Collector c) {
    if (JsonPath.tryParse(source) == null) {
      c.add(
        'manifest.path',
        path,
        'Only \$, .key, ["key"], [n] and one trailing [*] are supported, up to '
            '8 segments and 256 characters. Filters, slices, functions and '
            'recursion are refused.',
      );
    }
  }

  // ── Stage 3: semantics ────────────────────────────────────────────────────

  void _checkSemantics(Map<String, dynamic> doc, _Collector c) {
    final String? id = doc['id'] is String ? doc['id'] as String : null;
    if (id != null) {
      if (RegExp(r'^(?:nexus|app|com\.nexus)(?:\.|$)').hasMatch(id)) {
        c.add(
          'manifest.semantic',
          '/id',
          'Ids beginning with nexus., app. or com.nexus are reserved.',
        );
      }
      if (builtInIds.contains(id)) {
        c.add(
          'manifest.semantic',
          '/id',
          'The id "$id" is already used by a provider built into NEXUS.',
        );
      }
    }

    // Duplicate config keys and the baseUrl contract.
    final Object? config = doc['config'];
    if (config is List) {
      final Set<String> keys = <String>{};
      for (int i = 0; i < config.length; i++) {
        final Object? entry = config[i];
        if (entry is! Map<String, dynamic>) continue;
        final Object? key = entry['key'];
        if (key is! String) continue;
        if (!keys.add(key)) {
          c.add(
            'manifest.semantic',
            '/config/$i/key',
            'The key "$key" is declared more than once.',
          );
        }
        if (key == 'baseUrl' && entry['type'] != 'url') {
          c.add(
            'manifest.semantic',
            '/config/$i/type',
            'The "baseUrl" field must have type "url".',
          );
        }
      }
    }

    final Object? capabilities = doc['capabilities'];
    final Set<String> declared = capabilities is List
        ? capabilities.whereType<String>().toSet()
        : <String>{};
    final Object? requests = doc['requests'];
    final Set<String> defined = requests is Map<String, dynamic>
        ? requests.keys.toSet()
        : <String>{};

    void requireBacking(String capability, String request) {
      if (declared.contains(capability) && !defined.contains(request)) {
        c.add(
          'manifest.schema',
          '/requests/$request',
          '"$request" is a required property: the "$capability" capability '
              'declares behaviour no request would provide.',
        );
      }
    }

    requireBacking('search', 'search');
    requireBacking('seriesMatching', 'match');
    requireBacking('seasons', 'seasons');
    requireBacking('episodes', 'episodes');
    requireBacking('streams', 'resolve');
    requireBacking('subtitles', 'resolve');
    requireBacking('audioTracks', 'resolve');

    void requireCapability(String request, String capability) {
      if (defined.contains(request) && !declared.contains(capability)) {
        c.add(
          'manifest.semantic',
          '/requests/$request',
          'A "$request" request needs the "$capability" capability, otherwise '
              'the app would never call it.',
        );
      }
    }

    requireCapability('search', 'search');
    requireCapability('match', 'seriesMatching');
    requireCapability('seasons', 'seasons');
    requireCapability('episodes', 'episodes');
    requireCapability('resolve', 'streams');

    if (requests is Map<String, dynamic> &&
        requests['resolve'] is Map<String, dynamic>) {
      final Map<String, dynamic> resolve =
          requests['resolve'] as Map<String, dynamic>;
      if (resolve['subtitles'] != null && !declared.contains('subtitles')) {
        c.add(
          'manifest.semantic',
          '/requests/resolve/subtitles',
          'A subtitles mapping needs the "subtitles" capability.',
        );
      }
      if (resolve['audio'] != null && !declared.contains('audioTracks')) {
        c.add(
          'manifest.semantic',
          '/requests/resolve/audio',
          'An audio mapping needs the "audioTracks" capability.',
        );
      }
    }
    if (declared.contains('subtitles') &&
        !(requests is Map<String, dynamic> &&
            requests['resolve'] is Map<String, dynamic> &&
            (requests['resolve'] as Map<String, dynamic>)['subtitles'] !=
                null)) {
      c.add(
        'manifest.semantic',
        '/capabilities',
        'The "subtitles" capability requires resolve.subtitles, otherwise no '
            'track could ever be offered.',
      );
    }
    if (declared.contains('audioTracks') &&
        !(requests is Map<String, dynamic> &&
            requests['resolve'] is Map<String, dynamic> &&
            (requests['resolve'] as Map<String, dynamic>)['audio'] != null)) {
      c.add(
        'manifest.semantic',
        '/capabilities',
        'The "audioTracks" capability requires resolve.audio, otherwise no '
            'track could ever be offered.',
      );
    }
  }

  // ── Model construction ────────────────────────────────────────────────────

  ProviderManifest _buildManifest(Map<String, dynamic> doc) {
    final Map<String, dynamic> net = doc['net'] as Map<String, dynamic>;
    final Map<String, dynamic> requests =
        doc['requests'] as Map<String, dynamic>;
    final List<String> origins = <String>{
      for (final Object? value in net['origins'] as List) value as String,
    }.toList(growable: false);

    return ProviderManifest(
      id: doc['id'] as String,
      name: doc['name'] as String,
      version: doc['version'] as String,
      description: doc['description'] as String?,
      homepage: doc['homepage'] as String?,
      attribution: doc['attribution'] as String,
      notice: doc['notice'] as String?,
      contractMin: (doc['contract'] as Map<String, dynamic>)['min'] as int,
      contractMax: (doc['contract'] as Map<String, dynamic>)['max'] as int,
      capabilities: <ManifestCapability>[
        for (final Object? value in doc['capabilities'] as List)
          ManifestCapability.fromName(value as String)!,
      ],
      config: _buildConfig(doc['config']),
      net: ManifestNet(
        origins: <Uri>[for (final String origin in origins) Uri.parse(origin)],
        mediaHosts: <String>[
          for (final Object? value
              in (net['mediaHosts'] as List?) ?? const <Object?>[])
            value as String,
        ],
        maxRedirects: (net['maxRedirects'] as int?) ?? 3,
        minRequestIntervalMs: (net['minRequestIntervalMs'] as int?) ?? 250,
        timeoutMs: (net['timeoutMs'] as int?) ?? 15000,
        maxResponseBytes: (net['maxResponseBytes'] as int?) ?? 1048576,
      ),
      requests: ManifestRequests(
        probe: requests['probe'] == null
            ? null
            : _buildProbe(requests['probe'] as Map<String, dynamic>),
        search: requests['search'] == null
            ? null
            : _buildSearch(requests['search'] as Map<String, dynamic>),
        match: requests['match'] == null
            ? null
            : _buildMatch(requests['match'] as Map<String, dynamic>),
        seasons: requests['seasons'] == null
            ? null
            : _buildSeasons(requests['seasons'] as Map<String, dynamic>),
        episodes: requests['episodes'] == null
            ? null
            : _buildEpisodes(requests['episodes'] as Map<String, dynamic>),
        resolve: requests['resolve'] == null
            ? null
            : _buildResolve(requests['resolve'] as Map<String, dynamic>),
      ),
      errors: _buildErrorPolicy(doc['errors']),
    );
  }

  List<ManifestConfigField> _buildConfig(Object? raw) {
    if (raw is! List) return const <ManifestConfigField>[];
    return <ManifestConfigField>[
      for (final Object? entry in raw)
        if (entry is Map<String, dynamic>)
          ManifestConfigField(
            key: entry['key'] as String,
            label: entry['label'] as String,
            type: switch (entry['type']) {
              'url' => ProviderConfigType.url,
              'secret' => ProviderConfigType.secret,
              'choice' => ProviderConfigType.choice,
              'bool' => ProviderConfigType.boolean,
              _ => ProviderConfigType.text,
            },
            required: (entry['required'] as bool?) ?? false,
            hint: entry['hint'] as String?,
            defaultValue: entry['defaultValue'] as String?,
            placeholder: entry['placeholder'] as String?,
            choices: <String>[
              for (final Object? choice
                  in (entry['choices'] as List?) ?? const <Object?>[])
                choice as String,
            ],
            pattern: entry['pattern'] as String?,
            maxLength: (entry['maxLength'] as int?) ?? 256,
          ),
    ];
  }

  ManifestRequestSpec _buildSpec(Map<String, dynamic> m) {
    return ManifestRequestSpec(
      method: ((m['method'] as String?) ?? 'GET').toUpperCase(),
      url: m['url'] as String,
      query: <String, String>{
        for (final MapEntry<String, dynamic> entry
            in (m['query'] as Map<String, dynamic>? ??
                    const <String, dynamic>{})
                .entries)
          entry.key: entry.value as String,
      },
      headers: <String, String>{
        for (final MapEntry<String, dynamic> entry
            in (m['headers'] as Map<String, dynamic>? ??
                    const <String, dynamic>{})
                .entries)
          entry.key: entry.value as String,
      },
      body: <String, Object?>{
        for (final MapEntry<String, dynamic> entry
            in (m['body'] as Map<String, dynamic>? ?? const <String, dynamic>{})
                .entries)
          entry.key: entry.value,
      },
      timeoutMs: m['timeoutMs'] as int?,
      maxBytes: m['maxBytes'] as int?,
      notFoundStatus: <int>[
        for (final Object? value
            in (m['notFoundStatus'] as List?) ?? const <Object?>[])
          value as int,
      ],
    );
  }

  ManifestListMapping _buildMapping(Map<String, dynamic> map) {
    return ManifestListMapping(
      list: map['list'] as String,
      fields: <String, String>{
        for (final MapEntry<String, dynamic> entry
            in (map['map'] as Map<String, dynamic>).entries)
          entry.key: entry.value as String,
      },
    );
  }

  ManifestProbeRequest _buildProbe(Map<String, dynamic> m) {
    return ManifestProbeRequest(
      spec: _buildSpec(m),
      expectStatus: <int>[
        for (final Object? value
            in (m['expectStatus'] as List?) ?? const <Object?>[])
          value as int,
      ],
    );
  }

  ManifestSearchRequest _buildSearch(Map<String, dynamic> m) {
    return ManifestSearchRequest(
      spec: _buildSpec(m),
      mapping: _buildMapping(m),
      maxResults: (m['maxResults'] as int?) ?? 30,
    );
  }

  ManifestMatchRequest _buildMatch(Map<String, dynamic> m) {
    return ManifestMatchRequest(
      spec: _buildSpec(m),
      mapping: _buildMapping(m),
      maxResults: (m['maxResults'] as int?) ?? 10,
      strategy: switch (m['strategy']) {
        'exactTitle' => ManifestMatchStrategy.exactTitle,
        'normalisedTitleAndYear' =>
          ManifestMatchStrategy.normalisedTitleAndYear,
        _ => ManifestMatchStrategy.normalisedTitle,
      },
      minConfidence: (m['minConfidence'] as num?)?.toDouble() ?? 0.9,
    );
  }

  ManifestSeasonsRequest _buildSeasons(Map<String, dynamic> m) {
    return ManifestSeasonsRequest(
      spec: _buildSpec(m),
      mapping: _buildMapping(m),
    );
  }

  ManifestEpisodesRequest _buildEpisodes(Map<String, dynamic> m) {
    return ManifestEpisodesRequest(
      spec: _buildSpec(m),
      mapping: _buildMapping(m),
      numbering: m['numbering'] == 'seasonRelative'
          ? ManifestNumbering.seasonRelative
          : ManifestNumbering.absolute,
    );
  }

  ManifestResolveRequest _buildResolve(Map<String, dynamic> m) {
    ManifestListMapping? nested(String key) {
      final Object? value = m[key];
      if (value is! Map<String, dynamic>) return null;
      final Object? map = value['map'];
      if (map is! Map<String, dynamic>) return null;
      return _buildMapping(<String, dynamic>{
        'list': value['list'],
        'map': map,
      });
    }

    return ManifestResolveRequest(
      spec: _buildSpec(m),
      variants: _buildMapping(m['variants'] as Map<String, dynamic>),
      subtitles: nested('subtitles'),
      audio: nested('audio'),
      streamHeaders: <String, String>{
        for (final MapEntry<String, dynamic> entry
            in (m['streamHeaders'] as Map<String, dynamic>? ??
                    const <String, dynamic>{})
                .entries)
          entry.key: entry.value as String,
      },
      defaultProtocol: switch (m['defaultProtocol']) {
        'dash' => ManifestProtocol.dash,
        'progressive' => ManifestProtocol.progressive,
        _ => ManifestProtocol.hls,
      },
    );
  }

  ManifestErrorPolicy _buildErrorPolicy(Object? raw) {
    final Map<String, dynamic> m = raw is Map<String, dynamic>
        ? raw
        : const <String, dynamic>{};
    List<int> statuses(String key, List<int> defaults) {
      final Object? value = m[key];
      if (value is! List) return defaults;
      return <int>[for (final Object? item in value) item as int];
    }

    return ManifestErrorPolicy(
      unauthorisedStatus: statuses('unauthorisedStatus', const <int>[401, 403]),
      rateLimitedStatus: statuses('rateLimitedStatus', const <int>[429]),
      retryAfterHeader: (m['retryAfterHeader'] as String?) ?? 'Retry-After',
      messagePath: m['messagePath'] as String?,
      maxRetryAfterSeconds: (m['maxRetryAfterSeconds'] as int?) ?? 300,
    );
  }

  // ── Compatibility ─────────────────────────────────────────────────────────

  ProviderCompatibility _compatibility(ProviderManifest manifest) {
    if (manifest.contractMin > contractVersion) {
      return ProviderCompatibility.requiresNewerApp;
    }
    if (manifest.contractMax < contractVersion) {
      return ProviderCompatibility.unsupportedContract;
    }
    return ProviderCompatibility.compatible;
  }

  // ── Small helpers ─────────────────────────────────────────────────────────

  ManifestValidationResult _invalid(_Collector c) => ManifestValidationResult(
    status: ManifestStatus.invalid,
    compatibility: ProviderCompatibility.compatible,
    errors: ManifestValidationResult.sorted(c.errors),
  );

  void _unknownKeys(
    Map<String, dynamic> map,
    String path,
    Set<String> allowed,
    _Collector c,
  ) {
    for (final String key in map.keys) {
      if (!allowed.contains(key)) {
        c.add(
          'manifest.schema',
          '$path/$key',
          'Unexpected property "$key". Unknown keys are refused rather than '
              'ignored.',
        );
      }
    }
  }

  String? _string(
    Map<String, dynamic> map,
    String key,
    String path,
    _Collector c, {
    bool required = true,
    int min = 0,
    int? max,
    RegExp? pattern,
    String? patternHint,
  }) {
    final Object? value = map[key];
    final String at = '$path/$key';
    if (value == null) {
      if (required) c.add('manifest.schema', at, 'This property is required.');
      return null;
    }
    if (value is! String) {
      c.add('manifest.schema', at, 'This value must be a string.');
      return null;
    }
    if (value.length < min) {
      c.add(
        'manifest.schema',
        at,
        'This value must be at least $min characters.',
      );
      return null;
    }
    if (max != null && value.length > max) {
      c.add(
        'manifest.schema',
        at,
        'This value must be at most $max characters.',
      );
      return null;
    }
    if (pattern != null && !pattern.hasMatch(value)) {
      c.add(
        'manifest.schema',
        at,
        'This value must be ${patternHint ?? 'in the expected format'}.',
      );
      return null;
    }
    return value;
  }

  int? _int(
    Map<String, dynamic> map,
    String key,
    String path,
    _Collector c, {
    bool required = true,
    int? min,
    int? max,
  }) {
    final Object? value = map[key];
    final String at = '$path/$key';
    if (value == null) {
      if (required) c.add('manifest.schema', at, 'This property is required.');
      return null;
    }
    if (value is! int) {
      c.add('manifest.schema', at, 'This value must be an integer.');
      return null;
    }
    if ((min != null && value < min) || (max != null && value > max)) {
      c.add('manifest.schema', at, 'This value must be between $min and $max.');
      return null;
    }
    return value;
  }

  double? _number(
    Map<String, dynamic> map,
    String key,
    String path,
    _Collector c, {
    bool required = true,
    double? min,
    double? max,
  }) {
    final Object? value = map[key];
    final String at = '$path/$key';
    if (value == null) {
      if (required) c.add('manifest.schema', at, 'This property is required.');
      return null;
    }
    if (value is! num) {
      c.add('manifest.schema', at, 'This value must be a number.');
      return null;
    }
    final double result = value.toDouble();
    if ((min != null && result < min) || (max != null && result > max)) {
      c.add('manifest.schema', at, 'This value must be between $min and $max.');
      return null;
    }
    return result;
  }

  bool? _bool(
    Map<String, dynamic> map,
    String key,
    String path,
    _Collector c, {
    bool required = true,
  }) {
    final Object? value = map[key];
    final String at = '$path/$key';
    if (value == null) {
      if (required) c.add('manifest.schema', at, 'This property is required.');
      return null;
    }
    if (value is! bool) {
      c.add('manifest.schema', at, 'This value must be true or false.');
      return null;
    }
    return value;
  }

  List<String>? _stringList(
    Map<String, dynamic> map,
    String key,
    String path,
    _Collector c, {
    bool required = true,
    int minItems = 0,
    int? maxItems,
    int? maxLength,
    RegExp? pattern,
    String? patternHint,
  }) {
    final Object? value = map[key];
    final String at = '$path/$key';
    if (value == null) {
      if (required) c.add('manifest.schema', at, 'This property is required.');
      return null;
    }
    if (value is! List) {
      c.add('manifest.schema', at, 'This value must be an array.');
      return null;
    }
    if (value.length < minItems) {
      c.add(
        'manifest.schema',
        at,
        'At least $minItems ${minItems == 1 ? 'entry is' : 'entries are'} '
            'required.',
      );
    }
    if (maxItems != null && value.length > maxItems) {
      c.add('manifest.schema', at, 'At most $maxItems entries are allowed.');
    }
    final List<String> result = <String>[];
    final Set<String> seen = <String>{};
    for (int i = 0; i < value.length; i++) {
      final Object? item = value[i];
      final String itemPath = '$at/$i';
      if (item is! String) {
        c.add('manifest.schema', itemPath, 'This value must be a string.');
        continue;
      }
      if (maxLength != null && item.length > maxLength) {
        c.add(
          'manifest.schema',
          itemPath,
          'This value must be at most $maxLength characters.',
        );
        continue;
      }
      if (pattern != null && !pattern.hasMatch(item)) {
        c.add(
          'manifest.schema',
          itemPath,
          'This value must be ${patternHint ?? 'in the expected format'}.',
        );
        continue;
      }
      if (!seen.add(item)) {
        c.add('manifest.schema', itemPath, 'This value is listed twice.');
        continue;
      }
      result.add(item);
    }
    return result;
  }

  Set<String> _declaredConfigKeys(Map<String, dynamic> doc) {
    final Object? config = doc['config'];
    if (config is! List) return const <String>{};
    return <String>{
      for (final Object? entry in config)
        if (entry is Map<String, dynamic> && entry['key'] is String)
          entry['key'] as String,
    };
  }

  bool _hasBaseUrlField(Map<String, dynamic> doc) {
    final Object? config = doc['config'];
    if (config is! List) return false;
    for (final Object? entry in config) {
      if (entry is Map<String, dynamic> &&
          entry['key'] == 'baseUrl' &&
          entry['type'] == 'url') {
        return true;
      }
    }
    return false;
  }

  static bool _originContains(List<Uri> origins, Uri uri) {
    for (final Uri origin in origins) {
      if (origin.scheme == uri.scheme &&
          origin.host == uri.host &&
          (origin.hasPort ? origin.port : 443) ==
              (uri.hasPort ? uri.port : 443)) {
        return true;
      }
    }
    return false;
  }

  static List<String> _placeholders(String template) {
    return <String>[
      for (final RegExpMatch match in RegExp(
        r'\{([A-Za-z][A-Za-z0-9_.]*)\}',
      ).allMatches(template))
        match.group(1)!,
    ];
  }

  /// Counts container nesting outside strings, so an absurd document is refused
  /// before the decoder can exhaust the stack.
  static bool _exceedsDepth(String source, int limit) {
    int depth = 0;
    bool inString = false;
    bool escaped = false;
    for (int i = 0; i < source.length; i++) {
      final String ch = source[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
        continue;
      }
      if (ch == '{' || ch == '[') {
        depth++;
        if (depth > limit) return true;
      } else if (ch == '}' || ch == ']') {
        depth--;
      }
    }
    return false;
  }

  static String _kib(int bytes) => (bytes / 1024).ceil().toString();
}

class _Collector {
  final List<ManifestError> errors = <ManifestError>[];

  bool get isEmpty => errors.isEmpty;

  void add(String code, String path, String message) {
    errors.add(ManifestError(code: code, path: path, message: message));
  }
}
