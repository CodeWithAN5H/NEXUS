import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/database/nexus_database.dart';
import 'package:nexus/data/models/anime.dart';
import 'package:nexus/data/repositories/provider_store.dart';
import 'package:nexus/data/services/provider_lifecycle_service.dart';
import 'package:nexus/data/services/provider_management_service.dart';
import 'package:nexus/integrations/providers/provider_descriptor.dart';
import 'package:nexus/integrations/providers/provider_record.dart';
import 'package:nexus/integrations/providers/provider_registries.dart';
import 'package:nexus/integrations/providers/provider_resolver.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_http.dart';
import 'package:nexus/integrations/streaming/sample_provider.dart';
import 'package:nexus/integrations/streaming/streaming_provider.dart';

import 'support/fake_providers.dart';
import 'support/fake_secret_store.dart';
import 'support/manifest_fixtures.dart';

const Anime _anime = Anime(id: 154587, title: 'Frieren');
const String _minimalId = 'dev.example.minimal';
const String _fullId = 'dev.example.full';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late NexusDatabase db;
  late ProviderStore store;
  late FakeSecretStore secrets;
  late ProviderLifecycleService lifecycle;
  late ProviderManagementService management;

  setUp(() async {
    db = NexusDatabase(NativeDatabase.memory());
    store = ProviderStore(db);
    secrets = FakeSecretStore();
    lifecycle = ProviderLifecycleService(
      store,
      secrets,
      builtInIds: const <String>{'sample'},
      transportFactory: (String id) => FakeManifestTransport(
        (ManifestTransportRequest request) async =>
            FakeManifestResponse.json(<String, dynamic>{
              'results': <Object>[],
              'episodes': <Object>[],
              'sources': <Object>[],
            }),
      ),
    );
    management = ProviderManagementService(store, lifecycle);
    await store.syncBuiltIns(
      const <ProviderDescriptor>[SamplePlaybackProvider()],
      enabledIds: const <String>{'sample'},
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> install(
    String id, {
    Map<String, String> config = const {},
  }) async {
    final String json = id == _minimalId
        ? jsonEncode(minimalManifest())
        : jsonEncode(fullManifest());
    final ProviderInstallPreview preview = await lifecycle.preview(json);
    await lifecycle.install(
      preview,
      values: config.isNotEmpty
          ? config
          : id == _minimalId
          ? <String, String>{'baseUrl': 'https://api.example.com'}
          : <String, String>{
              'baseUrl': 'https://api.example.com',
              'apiKey': 'unit-test-secret-value',
            },
    );
  }

  List<String> ids(List<ProviderRecord> records) => <String>[
    for (final ProviderRecord record in records) record.providerId,
  ];

  group('reordering user-added providers', () {
    test('moves one source and rewrites a complete, unique order', () async {
      await install(_minimalId);
      await install(_fullId);

      expect(ids(await store.loadAll()), <String>[
        'sample',
        _minimalId,
        _fullId,
      ]);

      final List<String> order = await management.moveUserProvider(
        _fullId,
        delta: -1,
      );
      expect(order, <String>[_fullId, _minimalId]);

      final List<ProviderRecord> records = await store.loadAll();
      expect(ids(records), <String>['sample', _fullId, _minimalId]);
      expect(
        records.map((ProviderRecord record) => record.priority).toSet(),
        hasLength(records.length),
        reason: 'no two sources may share a priority',
      );
      expect(
        records.first.origin,
        ProviderOrigin.builtIn,
        reason: 'the built-in row stays first and stays built-in',
      );
      expect(records.first.enabled, isTrue);
    });

    test('the new order survives a restart', () async {
      await install(_minimalId);
      await install(_fullId);
      await management.moveUserProvider(_fullId, delta: -1);

      final ProviderStore reopened = ProviderStore(db);
      expect(ids(await reopened.loadAll()), <String>[
        'sample',
        _fullId,
        _minimalId,
      ]);
    });

    test('moving past either end is a no-op', () async {
      await install(_minimalId);
      await install(_fullId);
      final List<int> before = <int>[
        for (final ProviderRecord record in await store.loadAll())
          record.priority,
      ];

      await management.moveUserProvider(_minimalId, delta: -1);
      await management.moveUserProvider(_fullId, delta: 1);

      expect(<int>[
        for (final ProviderRecord record in await store.loadAll())
          record.priority,
      ], before);
    });

    test('an unknown or built-in id cannot be reordered', () async {
      await install(_minimalId);
      await expectLater(
        management.moveUserProvider('not.installed', delta: 1),
        throwsA(
          isA<ProviderLifecycleFailure>().having(
            (ProviderLifecycleFailure failure) => failure.code,
            'code',
            'provider.notInstalled',
          ),
        ),
      );
      await expectLater(
        management.moveUserProvider('sample', delta: 1),
        throwsA(isA<ProviderLifecycleFailure>()),
      );
    });

    test('two quick moves are serialised into one consistent order', () async {
      await install(_minimalId);
      await install(_fullId);

      await Future.wait(<Future<List<String>>>[
        management.moveUserProvider(_fullId, delta: -1),
        management.moveUserProvider(_fullId, delta: -1),
      ]);

      final List<ProviderRecord> records = await store.loadAll();
      expect(ids(records), <String>['sample', _fullId, _minimalId]);
      expect(
        records.map((ProviderRecord record) => record.priority).toSet(),
        hasLength(records.length),
      );
    });

    test('per-title preference survives a reorder and still wins', () async {
      await install(_minimalId);
      await install(_fullId);
      await store.setPreference(_anime.id, _fullId);
      await management.moveUserProvider(_fullId, delta: -1);

      expect(await store.preferenceFor(_anime.id), _fullId);
    });
  });

  group('resolver ordering', () {
    late StreamingProviderRegistry registry;

    setUp(() {
      registry = StreamingProviderRegistry(<StreamingProvider>[
        FakeStreamingProvider(
          id: _minimalId,
          series: const ProviderSeries(
            providerId: _minimalId,
            seriesId: 'a',
            title: 'Frieren',
          ),
        ),
        FakeStreamingProvider(
          id: _fullId,
          series: const ProviderSeries(
            providerId: _fullId,
            seriesId: 'b',
            title: 'Frieren',
          ),
        ),
      ]);
    });

    test('follows the stored priority order', () async {
      await install(_minimalId);
      await install(_fullId);

      Future<List<String>> lookupOrder() async {
        final ProviderResolver resolver = ProviderResolver(
          registry: registry,
          records: await store.loadAll(),
        );
        final SourceLookup lookup = await resolver.lookup(_anime);
        return <String>[
          for (final SourceResolution match in lookup.matches)
            match.provider.id,
        ];
      }

      expect(await lookupOrder(), <String>[_minimalId, _fullId]);

      await management.moveUserProvider(_fullId, delta: -1);
      expect(await lookupOrder(), <String>[_fullId, _minimalId]);
    });

    test('a per-title preference outranks priority', () async {
      await install(_minimalId);
      await install(_fullId);

      final ProviderResolver resolver = ProviderResolver(
        registry: registry,
        records: await store.loadAll(),
        titlePreferences: <int, String>{_anime.id: _fullId},
      );
      final SourceLookup lookup = await resolver.lookup(_anime);

      expect(lookup.matches.first.provider.id, _fullId);
      expect(lookup.preferredProviderId, _fullId);
      expect(
        lookup.matches.map((SourceResolution match) => match.provider.id),
        containsAll(<String>[_fullId, _minimalId]),
      );
    });

    test('a disabled source drops out without disturbing the rest', () async {
      await install(_minimalId);
      await install(_fullId);
      await management.setEnabled(_minimalId, false);

      final ProviderResolver resolver = ProviderResolver(
        registry: registry,
        records: await store.loadAll(),
      );
      final SourceLookup lookup = await resolver.lookup(_anime);

      expect(
        lookup.matches.map((SourceResolution match) => match.provider.id),
        <String>[_fullId],
      );
    });
  });
}
