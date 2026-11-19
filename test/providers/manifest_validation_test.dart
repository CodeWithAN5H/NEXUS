import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/integrations/providers/provider_descriptor.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_error.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_validator.dart';
import 'package:nexus/integrations/streaming/manifest/provider_manifest.dart';

import 'support/manifest_fixtures.dart';

void main() {
  group('Manifest schema (T-M01–T-M03)', () {
    test('T-M01 minimal valid manifest parses', () {
      final ManifestValidationResult result = ManifestValidator().validate(
        manifestExample('valid-minimal.json'),
      );

      expect(result.status, ManifestStatus.valid);
      expect(result.errors, isEmpty);
      final ProviderManifest manifest = result.manifest!;
      expect(manifest.id, 'dev.example.minimal');
      expect(manifest.capabilities, hasLength(4));
      expect(manifest.config, hasLength(1));
      expect(manifest.config.single.type, ProviderConfigType.url);
      expect(manifest.contractRange.min, 1);
    });

    test('T-M02 full valid manifest parses every section', () {
      final ManifestValidationResult result = ManifestValidator().validate(
        manifestExample('valid-full.json'),
      );

      expect(result.status, ManifestStatus.valid, reason: '${result.errors}');
      final ProviderManifest manifest = result.manifest!;
      expect(manifest.capabilities, hasLength(8));
      expect(manifest.config, hasLength(4));
      expect(manifest.requests.probe, isNotNull);
      expect(manifest.requests.search, isNotNull);
      expect(manifest.requests.match, isNotNull);
      expect(manifest.requests.seasons, isNotNull);
      expect(manifest.requests.episodes, isNotNull);
      expect(manifest.requests.resolve, isNotNull);
      expect(
        manifest.requests.episodes!.numbering,
        ManifestNumbering.seasonRelative,
      );
      expect(
        manifest.requests.match!.strategy,
        ManifestMatchStrategy.normalisedTitleAndYear,
      );
      expect(manifest.requests.match!.minConfidence, closeTo(0.92, 0.001));
      expect(manifest.net.maxRedirects, 2);
      expect(manifest.net.maxResponseBytes, 524288);
      expect(manifest.errors.rateLimitedStatus, <int>[429]);
      expect(manifest.errors.maxRetryAfterSeconds, 600);
      expect(manifest.notice, isNotNull);
    });

    test(
      'T-M03 committed valid examples validate, invalid ones are refused',
      () {
        for (final String name in <String>[
          'valid-minimal.json',
          'valid-full.json',
        ]) {
          expect(
            ManifestValidator().validate(manifestExample(name)).status,
            ManifestStatus.valid,
            reason: name,
          );
        }

        final Map<String, (String code, String path)> expected =
            <String, (String, String)>{
              'invalid-http-origin.json': ('manifest.schema', '/net/origins/0'),
              'invalid-unbacked-capability.json': (
                'manifest.schema',
                '/requests/seasons',
              ),
              'invalid-executable-field.json': (
                'manifest.schema',
                '/requests/search/script',
              ),
              'invalid-jsonpath-filter.json': (
                'manifest.path',
                '/requests/search/list',
              ),
            };
        for (final MapEntry<String, (String, String)> entry
            in expected.entries) {
          final ManifestValidationResult result = ManifestValidator().validate(
            manifestExample(entry.key),
          );
          expect(result.status, ManifestStatus.invalid, reason: entry.key);
          expect(
            result.errors.any(
              (ManifestError error) =>
                  error.code == entry.value.$1 && error.path == entry.value.$2,
            ),
            isTrue,
            reason: '${entry.key}: ${result.errors}',
          );
        }
      },
    );
  });

  group('Manifest schema refusals (T-M04–T-M12)', () {
    test('T-M08 unknown top-level key is refused, not ignored', () {
      final Map<String, dynamic> manifest = minimalManifest()
        ..['eval'] = 'code';
      final ManifestValidationResult result = validate(manifest);

      expect(result.status, ManifestStatus.invalid);
      expect(result.errors.first.code, 'manifest.schema');
      expect(result.errors.first.path, '/eval');
    });

    test('T-M09 duplicate configuration keys are refused', () {
      final Map<String, dynamic> manifest = minimalManifest();
      (manifest['config'] as List<dynamic>).add(
        copyOf(
          (manifest['config'] as List<dynamic>).first as Map<String, dynamic>,
        ),
      );
      final ManifestValidationResult result = validate(manifest);

      expect(result.status, ManifestStatus.invalid);
      expect(
        result.errors.any(
          (ManifestError error) =>
              error.code == 'manifest.semantic' &&
              error.path == '/config/1/key',
        ),
        isTrue,
        reason: '${result.errors}',
      );
    });

    test('T-M10 subtitles mapping without the capability is refused', () {
      final Map<String, dynamic> manifest = minimalManifest();
      final Map<String, dynamic> resolve =
          (manifest['requests'] as Map<String, dynamic>)['resolve']
              as Map<String, dynamic>;
      resolve['subtitles'] = <String, dynamic>{
        'list': r'$.tracks',
        'map': <String, dynamic>{'label': r'$.name', 'uri': r'$.file'},
      };
      final ManifestValidationResult result = validate(manifest);

      expect(
        result.errors.any(
          (ManifestError error) =>
              error.path == '/requests/resolve/subtitles' &&
              error.code == 'manifest.semantic',
        ),
        isTrue,
        reason: '${result.errors}',
      );
    });

    test('T-M11 a secret field cannot declare a default value', () {
      final Map<String, dynamic> manifest = minimalManifest();
      (manifest['config'] as List<dynamic>).add(<String, dynamic>{
        'key': 'apiKey',
        'label': 'API key',
        'type': 'secret',
        'defaultValue': 'hard-coded-secret',
      });
      final ManifestValidationResult result = validate(manifest);

      expect(
        result.errors.any(
          (ManifestError error) =>
              error.code == 'manifest.semantic' &&
              error.path == '/config/1/defaultValue',
        ),
        isTrue,
        reason: '${result.errors}',
      );
    });

    test('T-M12 seasonRelative numbering needs map.seasonId', () {
      final Map<String, dynamic> manifest = fullManifest();
      final Map<String, dynamic> episodes =
          (manifest['requests'] as Map<String, dynamic>)['episodes']
              as Map<String, dynamic>;
      ((episodes['map'] as Map<String, dynamic>)).remove('seasonId');
      final ManifestValidationResult result = validate(manifest);

      expect(
        result.errors.any(
          (ManifestError error) =>
              error.path == '/requests/episodes/map' &&
              error.code == 'manifest.schema',
        ),
        isTrue,
        reason: '${result.errors}',
      );
    });

    test('plain-HTTP request URL is refused', () {
      final Map<String, dynamic> manifest = minimalManifest();
      final Map<String, dynamic> search =
          (manifest['requests'] as Map<String, dynamic>)['search']
              as Map<String, dynamic>;
      search['url'] = 'http://api.example.com/search';
      final ManifestValidationResult result = validate(manifest);

      expect(
        result.errors.any(
          (ManifestError error) =>
              error.path == '/requests/search/url' &&
              error.code == 'manifest.schema',
        ),
        isTrue,
        reason: '${result.errors}',
      );
    });

    test('an absolute URL outside net.origins is refused at validation', () {
      final Map<String, dynamic> manifest = minimalManifest();
      final Map<String, dynamic> search =
          (manifest['requests'] as Map<String, dynamic>)['search']
              as Map<String, dynamic>;
      search['url'] = 'https://evil.test/search';
      final ManifestValidationResult result = validate(manifest);

      expect(
        result.errors.any(
          (ManifestError error) =>
              error.path == '/requests/search/url' &&
              error.message.contains('not declared'),
        ),
        isTrue,
        reason: '${result.errors}',
      );
    });
  });

  group('Templates, paths and semantics (T-M13–T-M14, T-M18–T-M19)', () {
    test('T-M13 {page} outside a search request is refused', () {
      final Map<String, dynamic> manifest = minimalManifest();
      final Map<String, dynamic> resolve =
          (manifest['requests'] as Map<String, dynamic>)['resolve']
              as Map<String, dynamic>;
      resolve['url'] = '{baseUrl}/episodes/{episodeId}?page={page}';
      final ManifestValidationResult result = validate(manifest);

      expect(
        result.errors.any(
          (ManifestError error) =>
              error.code == 'manifest.template' &&
              error.path == '/requests/resolve/url' &&
              error.message.contains('page'),
        ),
        isTrue,
        reason: '${result.errors}',
      );
    });

    test('T-M14 a path deeper than 8 segments is refused', () {
      final Map<String, dynamic> manifest = minimalManifest();
      final Map<String, dynamic> search =
          (manifest['requests'] as Map<String, dynamic>)['search']
              as Map<String, dynamic>;
      search['list'] = r'$.a.b.c.d.e.f.g.h.i';
      final ManifestValidationResult result = validate(manifest);

      expect(
        result.errors.any(
          (ManifestError error) =>
              error.code == 'manifest.path' &&
              error.path == '/requests/search/list',
        ),
        isTrue,
        reason: '${result.errors}',
      );
    });

    test('T-M18 reserved id prefixes are refused', () {
      for (final String id in <String>['nexus.demo', 'app.demo']) {
        final Map<String, dynamic> manifest = minimalManifest()..['id'] = id;
        final ManifestValidationResult result = validate(manifest);
        expect(
          result.errors.any(
            (ManifestError error) =>
                error.code == 'manifest.semantic' && error.path == '/id',
          ),
          isTrue,
          reason: '$id: ${result.errors}',
        );
      }
    });

    test('T-M19 a built-in id cannot be claimed', () {
      final Map<String, dynamic> notReverseDns = minimalManifest()
        ..['id'] = 'sample';
      expect(validate(notReverseDns).status, ManifestStatus.invalid);

      final Map<String, dynamic> collides = minimalManifest()
        ..['id'] = 'dev.anilist';
      final ManifestValidationResult result = validate(
        collides,
        builtInIds: <String>{'dev.anilist'},
      );
      expect(
        result.errors.any(
          (ManifestError error) =>
              error.code == 'manifest.semantic' &&
              error.message.contains('built into NEXUS'),
        ),
        isTrue,
        reason: '${result.errors}',
      );
    });

    test(
      'an unknown placeholder is a validation error, not an empty string',
      () {
        final Map<String, dynamic> manifest = minimalManifest();
        final Map<String, dynamic> resolve =
            (manifest['requests'] as Map<String, dynamic>)['resolve']
                as Map<String, dynamic>;
        resolve['url'] = '{baseUrl}/episodes/{seriesId}/{episodeId}/{seasonId}';
        final ManifestValidationResult result = validate(manifest);

        expect(
          result.errors.any(
            (ManifestError error) =>
                error.code == 'manifest.template' &&
                error.message.contains('seasonId'),
          ),
          isTrue,
          reason: '${result.errors}',
        );
      },
    );

    test('a {config.*} placeholder must be declared', () {
      final Map<String, dynamic> manifest = minimalManifest();
      final Map<String, dynamic> search =
          (manifest['requests'] as Map<String, dynamic>)['search']
              as Map<String, dynamic>;
      search['headers'] = <String, String>{'X-Api-Key': '{config.apiKey}'};
      final ManifestValidationResult result = validate(manifest);

      expect(
        result.errors.any(
          (ManifestError error) =>
              error.code == 'manifest.template' &&
              error.message.contains('config.apiKey'),
        ),
        isTrue,
        reason: '${result.errors}',
      );
    });

    test('an empty request map is refused', () {
      final Map<String, dynamic> manifest = minimalManifest();
      manifest['requests'] = <String, dynamic>{};
      manifest['capabilities'] = <String>['search'];
      final ManifestValidationResult result = validate(manifest);

      expect(result.status, ManifestStatus.invalid);
    });
  });

  group('Parse limits (T-M20–T-M22)', () {
    test('T-M20 a document over 512 KiB is refused before parsing', () {
      final Map<String, dynamic> manifest = minimalManifest()
        ..['description'] = 'x' * (513 * 1024);
      final ManifestValidationResult result = ManifestValidator().validate(
        jsonEncode(manifest),
      );

      expect(result.status, ManifestStatus.invalid);
      expect(result.errors.single.code, 'manifest.parse');
      expect(result.errors.single.message, contains('512 KiB'));
    });

    test('T-M21 nesting deeper than 12 is refused', () {
      String nested = '{}';
      for (int i = 0; i < 14; i++) {
        nested = '{"a":$nested}';
      }
      final ManifestValidationResult result = ManifestValidator().validate(
        nested,
      );

      expect(result.status, ManifestStatus.invalid);
      expect(result.errors.single.code, 'manifest.parse');
      expect(result.errors.single.message, contains('deeper than 12'));
    });

    test('T-M22 malformed JSON reports a byte offset', () {
      final String source = manifestExample('valid-minimal.json');
      final ManifestValidationResult result = ManifestValidator().validate(
        source.substring(0, source.length ~/ 2),
      );

      expect(result.status, ManifestStatus.invalid);
      expect(result.errors.single.code, 'manifest.parse');
      expect(result.errors.single.message, contains('byte'));
    });
  });

  group('Error reporting and compatibility (T-M16–T-M17, T-M23–T-M24)', () {
    test('T-M16 a contract above this build is a compatibility outcome', () {
      final Map<String, dynamic> manifest = minimalManifest();
      manifest['contract'] = <String, int>{'min': 9, 'max': 9};
      final ManifestValidationResult result = validate(manifest);

      expect(result.status, ManifestStatus.unsupportedContract);
      expect(result.compatibility, ProviderCompatibility.requiresNewerApp);
      expect(result.errors, isEmpty);
      expect(result.manifest, isNotNull);
    });

    test('T-M16b a retired contract is unsupported, never invoked', () {
      final Map<String, dynamic> manifest = minimalManifest();
      manifest['contract'] = <String, int>{'min': 1, 'max': 1};
      final ManifestValidationResult result = const ManifestValidator(
        contractVersion: 2,
      ).validate(jsonEncode(manifest));

      expect(result.status, ManifestStatus.unsupportedContract);
      expect(result.compatibility, ProviderCompatibility.unsupportedContract);
    });

    test('T-M17 a newer manifest version is retained, not deleted', () {
      final Map<String, dynamic> manifest = minimalManifest()
        ..['manifestVersion'] = 2;
      final ManifestValidationResult result = validate(manifest);

      expect(result.status, ManifestStatus.requiresNewerApp);
      expect(result.compatibility, ProviderCompatibility.requiresNewerApp);
      expect(result.errors, isEmpty);
      expect(result.manifest, isNull);
    });

    test('T-M23 every independent defect is reported, ordered by path', () {
      final Map<String, dynamic> manifest = minimalManifest();
      manifest['attribution'] = 'x';
      manifest['eval'] = 'code';
      (manifest['capabilities'] as List<dynamic>).add('seasons');

      final ManifestValidationResult result = validate(manifest);

      expect(result.errors.length, greaterThanOrEqualTo(3));
      final List<String> paths = <String>[
        for (final ManifestError error in result.errors) error.path,
      ];
      expect(paths, orderedEquals(<String>[...paths]..sort()));
    });

    test('T-M24 no error message echoes a configured value', () {
      final Map<String, dynamic> manifest = minimalManifest();
      (manifest['config'] as List<dynamic>).add(<String, dynamic>{
        'key': 'apiKey',
        'label': 'API key',
        'type': 'secret',
        'defaultValue': 'unit-test-secret-value',
      });
      final ManifestValidationResult result = validate(manifest);

      expect(result.errors, isNotEmpty);
      for (final ManifestError error in result.errors) {
        expect(error.message, isNot(contains('unit-test-secret-value')));
      }
    });

    test('capabilities must be backed in both directions', () {
      final Map<String, dynamic> declared = minimalManifest();
      (declared['capabilities'] as List<dynamic>).add('subtitles');
      final ManifestValidationResult missingMapping = validate(declared);
      expect(
        missingMapping.errors.any(
          (ManifestError error) =>
              error.path == '/capabilities' &&
              error.code == 'manifest.semantic',
        ),
        isTrue,
      );

      final Map<String, dynamic> undeclared = minimalManifest();
      ((undeclared['capabilities'] as List<dynamic>)).remove('episodes');
      final ManifestValidationResult missingCapability = validate(undeclared);
      expect(
        missingCapability.errors.any(
          (ManifestError error) =>
              error.path == '/requests/episodes' &&
              error.code == 'manifest.semantic',
        ),
        isTrue,
        reason: '${missingCapability.errors}',
      );
    });

    test('continueWatching is refused by name', () {
      final Map<String, dynamic> manifest = minimalManifest();
      (manifest['capabilities'] as List<dynamic>).add('continueWatching');
      final ManifestValidationResult result = validate(manifest);
      expect(
        result.errors.any(
          (ManifestError error) =>
              error.message.contains('not part of manifest v1'),
        ),
        isTrue,
      );
    });

    test('a metadata kind is refused: v1 is streaming only', () {
      final Map<String, dynamic> manifest = minimalManifest()
        ..['kind'] = 'metadata';
      final ManifestValidationResult result = validate(manifest);
      expect(
        result.errors.any((ManifestError error) => error.path == '/kind'),
        isTrue,
      );
    });

    test('the validator is deterministic', () {
      final Map<String, dynamic> manifest = minimalManifest()
        ..['attribution'] = 'x';
      final List<String> first = <String>[
        for (final ManifestError error in validate(manifest).errors)
          '${error.code}@${error.path}',
      ];
      final List<String> second = <String>[
        for (final ManifestError error in validate(manifest).errors)
          '${error.code}@${error.path}',
      ];
      expect(second, first);
    });
  });
}
