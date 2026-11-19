import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/errors/app_failure.dart';
import 'package:nexus/data/database/nexus_database.dart';
import 'package:nexus/data/models/app_settings.dart';
import 'package:nexus/data/providers/app_providers.dart';
import 'package:nexus/data/repositories/provider_store.dart';
import 'package:nexus/data/services/provider_lifecycle_service.dart';
import 'package:nexus/integrations/providers/provider_record.dart';
import 'package:nexus/integrations/providers/provider_registries.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_config_validator.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_error.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_http.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_streaming_provider.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_validator.dart';
import 'package:nexus/integrations/streaming/manifest/provider_manifest.dart';
import 'package:nexus/integrations/streaming/streaming_provider.dart';

import 'support/fake_secret_store.dart';
import 'support/manifest_fixtures.dart';

/// A store whose install fails, to prove the keystore rollback.
class FailingInstallStore extends ProviderStore {
  FailingInstallStore(super.db);

  @override
  Future<void> installUserProvider({
    required ProviderRecord record,
    required String manifestJson,
    String? sourceUrl,
  }) async {
    throw const StorageFailure('simulated write failure');
  }
}

const Map<String, String> _fullConfig = <String, String>{
  'baseUrl': 'https://api.example.com',
  'apiKey': 'unit-test-secret-value',
  'region': 'eu',
  'includeSpecials': 'true',
};

const String _secret = 'unit-test-secret-value';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late NexusDatabase db;
  late ProviderStore store;
  late FakeSecretStore secrets;
  late ProviderLifecycleService service;

  setUp(() {
    db = NexusDatabase(NativeDatabase.memory());
    store = ProviderStore(db);
    secrets = FakeSecretStore();
    service = ProviderLifecycleService(
      store,
      secrets,
      builtInIds: const <String>{'sample', 'anilist'},
      transportFactory: (String id) => FakeManifestTransport(
        (ManifestTransportRequest request) async =>
            FakeManifestResponse.json(<String, dynamic>{
              'results': <Object>[],
              'episodes': <Object>[],
              'sources': <Object>[],
            }),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<ProviderInstallPreview> previewFull() =>
      service.preview(jsonEncode(fullManifest()));

  Future<void> installFull({bool enabled = true}) async {
    final ProviderInstallPreview preview = await previewFull();
    await service.install(preview, values: _fullConfig, enabled: enabled);
  }

  group('installation', () {
    test('a valid manifest previews with identity and capabilities', () async {
      final ProviderInstallPreview preview = await previewFull();
      expect(preview.canInstall, isTrue);
      expect(preview.manifest!.name, 'Example Full');
      expect(preview.manifest!.version, '2.1.0');
      expect(preview.manifest!.providerCapabilities, isNotEmpty);
      expect(preview.errors, isEmpty);
    });

    test(
      'installing persists the row, manifest and non-secret config',
      () async {
        await installFull();

        final List<ProviderRecord> records = await store.loadAll();
        expect(records, hasLength(1));
        final ProviderRecord record = records.single;
        expect(record.providerId, 'dev.example.full');
        expect(record.origin, ProviderOrigin.userAdded);
        expect(record.enabled, isTrue);
        expect(record.config, <String, String>{
          'baseUrl': 'https://api.example.com',
          'region': 'eu',
          'includeSpecials': 'true',
        });
        expect(await store.manifestJsonFor('dev.example.full'), isNotNull);
      },
    );

    test('a secret goes to the keystore and never to SQLite', () async {
      await installFull();

      expect(secrets.data['dev.example.full']?['apiKey'], _secret);
      final List<ProviderRecord> records = await store.loadAll();
      expect(jsonEncode(records.single.config), isNot(contains(_secret)));
      final String? manifest = await store.manifestJsonFor('dev.example.full');
      expect(manifest, isNot(contains(_secret)));
      // The manifest itself is a template; only config can carry a value.
      expect(manifest, contains('apiKey'));
    });

    test('an invalid manifest is never installed', () async {
      final String broken = jsonEncode(<String, dynamic>{'manifestVersion': 1});
      final ProviderInstallPreview preview = await service.preview(broken);
      expect(preview.canInstall, isFalse);
      expect(
        () => service.install(preview, values: const <String, String>{}),
        throwsA(
          isA<ProviderLifecycleFailure>().having(
            (ProviderLifecycleFailure failure) => failure.code,
            'code',
            'provider.manifestInvalid',
          ),
        ),
      );
      expect(await store.loadAll(), isEmpty);
      expect(secrets.data, isEmpty);
    });

    test(
      'a duplicate id is refused and leaves the first install intact',
      () async {
        await installFull();
        final ProviderInstallPreview second = await previewFull();
        expect(second.duplicate, isTrue);
        expect(second.canInstall, isFalse);

        await expectLater(
          service.install(second, values: _fullConfig),
          throwsA(
            isA<ProviderLifecycleFailure>().having(
              (ProviderLifecycleFailure failure) => failure.code,
              'code',
              'provider.alreadyInstalled',
            ),
          ),
        );
        expect(await store.loadAll(), hasLength(1));
      },
    );

    test('a reserved built-in id is refused', () async {
      final Map<String, dynamic> document = fullManifest();
      document['id'] = 'sample';
      final ProviderInstallPreview preview = await service.preview(
        jsonEncode(document),
      );
      expect(preview.canInstall, isFalse);
      expect(
        preview.errors.map((ManifestError error) => error.code),
        contains('manifest.semantic'),
      );
      await expectLater(
        service.install(preview, values: _fullConfig),
        throwsA(isA<ProviderLifecycleFailure>()),
      );
      expect(await store.loadAll(), isEmpty);
    });

    test('cancelling after preview writes nothing', () async {
      await previewFull();
      expect(await store.loadAll(), isEmpty);
      expect(await store.manifestJsonFor('dev.example.full'), isNull);
      expect(secrets.data, isEmpty);
    });

    test('a failed database write rolls the keystore back', () async {
      final ProviderLifecycleService failing = ProviderLifecycleService(
        FailingInstallStore(db),
        secrets,
        builtInIds: const <String>{'sample'},
      );
      final ProviderInstallPreview preview = await failing.preview(
        jsonEncode(fullManifest()),
      );

      await expectLater(
        failing.install(preview, values: _fullConfig),
        throwsA(
          isA<ProviderLifecycleFailure>().having(
            (ProviderLifecycleFailure failure) => failure.code,
            'code',
            'provider.storage',
          ),
        ),
      );
      expect(secrets.data, isEmpty, reason: 'the secret must not outlive it');
      expect(await store.loadAll(), isEmpty);
    });

    test('an unreachable keystore aborts the install', () async {
      secrets.failWrites = true;
      final ProviderInstallPreview preview = await previewFull();
      await expectLater(
        service.install(preview, values: _fullConfig),
        throwsA(
          isA<ProviderLifecycleFailure>().having(
            (ProviderLifecycleFailure failure) => failure.code,
            'code',
            'provider.secureStorage',
          ),
        ),
      );
      expect(await store.loadAll(), isEmpty);
    });

    test('installation revalidates instead of trusting the preview', () async {
      final ManifestValidationResult valid = ManifestValidator(
        builtInIds: const <String>{'sample'},
      ).validate(jsonEncode(fullManifest()));
      final ProviderInstallPreview tampered = ProviderInstallPreview(
        json: '{"manifestVersion": 1}',
        validation: valid,
        duplicate: false,
      );

      await expectLater(
        service.install(tampered, values: _fullConfig),
        throwsA(
          isA<ProviderLifecycleFailure>().having(
            (ProviderLifecycleFailure failure) => failure.code,
            'code',
            'provider.manifestInvalid',
          ),
        ),
      );
      expect(await store.loadAll(), isEmpty);
    });
  });

  group('configuration', () {
    test('a missing required field is reported per field', () async {
      final ProviderInstallPreview preview = await previewFull();
      await expectLater(
        service.install(preview),
        throwsA(
          isA<ProviderLifecycleFailure>()
              .having(
                (ProviderLifecycleFailure failure) => failure.code,
                'code',
                'provider.configInvalid',
              )
              .having(
                (ProviderLifecycleFailure failure) => failure.fieldErrors.keys,
                'fields',
                containsAll(<String>['baseUrl', 'apiKey']),
              ),
        ),
      );
      expect(await store.loadAll(), isEmpty);
    });

    test('each documented type is validated', () async {
      final ProviderManifest manifest = parseManifest(fullManifest());

      final ManifestConfigResult badUrl = ManifestConfigValidator.validate(
        manifest,
        <String, String>{..._fullConfig, 'baseUrl': 'http://insecure.example'},
      );
      expect(badUrl.errors['baseUrl'], isNotNull);

      final ManifestConfigResult badChoice = ManifestConfigValidator.validate(
        manifest,
        <String, String>{..._fullConfig, 'region': 'mars'},
      );
      expect(badChoice.errors['region'], isNotNull);

      final ManifestConfigResult badBool = ManifestConfigValidator.validate(
        manifest,
        <String, String>{..._fullConfig, 'includeSpecials': 'yes'},
      );
      expect(badBool.errors['includeSpecials'], isNotNull);

      final ManifestConfigResult good = ManifestConfigValidator.validate(
        manifest,
        _fullConfig,
      );
      expect(good.isValid, isTrue);
      expect(good.values['region'], 'eu');
    });

    test('pattern and maxLength rules are enforced', () {
      final Map<String, dynamic> document = fullManifest();
      (document['config'] as List<dynamic>).add(<String, dynamic>{
        'key': 'tag',
        'label': 'Tag',
        'type': 'text',
        'pattern': r'^[a-z]{2,4}$',
        'maxLength': 4,
      });
      final ProviderManifest manifest = parseManifest(document);

      final ManifestConfigResult tooLong = ManifestConfigValidator.validate(
        manifest,
        <String, String>{..._fullConfig, 'tag': 'abcde'},
      );
      expect(tooLong.errors['tag'], contains('4'));

      final ManifestConfigResult wrongShape = ManifestConfigValidator.validate(
        manifest,
        <String, String>{..._fullConfig, 'tag': 'AB'},
      );
      expect(wrongShape.errors['tag'], isNotNull);

      final ManifestConfigResult ok = ManifestConfigValidator.validate(
        manifest,
        <String, String>{..._fullConfig, 'tag': 'abc'},
      );
      expect(ok.errors, isEmpty);
    });

    test(
      'editing keeps an untouched secret and can replace or clear it',
      () async {
        await installFull();

        await service.updateConfiguration(
          'dev.example.full',
          values: <String, String>{
            'baseUrl': 'https://new.example.com',
            'region': 'us',
          },
        );
        expect(
          secrets.data['dev.example.full']?['apiKey'],
          _secret,
          reason: 'a secret absent from the form is left untouched',
        );
        final ProviderRecord record = (await store.loadAll()).single;
        expect(record.config['baseUrl'], 'https://new.example.com');

        await service.updateConfiguration(
          'dev.example.full',
          values: record.config,
          secrets: <String, String>{'apiKey': 'rotated-secret'},
        );
        expect(secrets.data['dev.example.full']?['apiKey'], 'rotated-secret');

        await service.updateConfiguration(
          'dev.example.full',
          values: record.config,
          clearSecrets: <String>{'apiKey'},
        );
        expect(secrets.data['dev.example.full']?['apiKey'], isNull);

        final InstalledProvider installed =
            (await service.loadInstalled()).single;
        expect(installed.presentSecrets, isEmpty);
        expect(installed.isConfigured, isFalse);
        expect(await service.buildProvider(installed), isNull);
      },
    );

    test('a failed secret write reverts the configuration', () async {
      await installFull();
      secrets.failWrites = true;

      await expectLater(
        service.updateConfiguration(
          'dev.example.full',
          values: <String, String>{
            'baseUrl': 'https://other.example.com',
            'region': 'us',
          },
          secrets: <String, String>{'apiKey': 'new-secret'},
        ),
        throwsA(
          isA<ProviderLifecycleFailure>().having(
            (ProviderLifecycleFailure failure) => failure.code,
            'code',
            'provider.secureStorage',
          ),
        ),
      );

      final ProviderRecord record = (await store.loadAll()).single;
      expect(record.config['baseUrl'], 'https://api.example.com');
    });

    test(
      'a missing keystore entry makes the provider unconfigured, not a crash',
      () async {
        await installFull();
        await secrets.delete('dev.example.full', 'apiKey');

        final InstalledProvider installed =
            (await service.loadInstalled()).single;
        expect(installed.presentSecrets, isEmpty);
        expect(installed.isConfigured, isFalse);
        expect(installed.presenceConfig.containsKey('apiKey'), isFalse);
        expect(await service.buildProvider(installed), isNull);
      },
    );
  });

  group('lifecycle', () {
    test('startup restoration rebuilds a configured provider', () async {
      await installFull();

      // A brand-new service, as after a restart.
      final ProviderLifecycleService restarted = ProviderLifecycleService(
        store,
        secrets,
        builtInIds: const <String>{'sample'},
      );
      final List<InstalledProvider> installed = await restarted.loadInstalled();
      expect(installed, hasLength(1));
      expect(installed.single.isValid, isTrue);
      expect(installed.single.isConfigured, isTrue);

      final ManifestStreamingProvider? provider = await restarted.buildProvider(
        installed.single,
      );
      expect(provider, isNotNull);
      expect(provider!.id, 'dev.example.full');
      await provider.dispose();
    });

    test('an invalid stored manifest is reported, not thrown', () async {
      await installFull();
      await store.saveManifest(
        providerId: 'dev.example.full',
        manifestJson: '{"manifestVersion": 1, "id": ',
      );

      final List<InstalledProvider> installed = await service.loadInstalled();
      expect(installed, hasLength(1));
      expect(installed.single.isValid, isFalse);
      expect(installed.single.failure, isNotNull);
      expect(installed.single.status, ManifestStatus.invalid);
      expect(await service.buildProvider(installed.single), isNull);
    });

    test('an incompatible stored manifest is reported, not thrown', () async {
      await installFull();
      final Map<String, dynamic> document = fullManifest();
      document['contract'] = <String, int>{'min': 2, 'max': 2};
      await store.saveManifest(
        providerId: 'dev.example.full',
        manifestJson: jsonEncode(document),
      );

      final List<InstalledProvider> installed = await service.loadInstalled();
      expect(installed.single.isValid, isFalse);
      expect(installed.single.isCompatible, isFalse);
      expect(installed.single.status, ManifestStatus.unsupportedContract);
      expect(await service.buildProvider(installed.single), isNull);
    });

    test(
      'disable keeps configuration and secrets, re-enable restores use',
      () async {
        await installFull();

        await service.setEnabled('dev.example.full', false);
        InstalledProvider installed = (await service.loadInstalled()).single;
        expect(installed.record.enabled, isFalse);
        expect(installed.isConfigured, isTrue, reason: 'config is kept');
        expect(
          secrets.data['dev.example.full']?['apiKey'],
          _secret,
          reason: 'secrets are kept',
        );

        await service.setEnabled('dev.example.full', true);
        installed = (await service.loadInstalled()).single;
        expect(installed.record.enabled, isTrue);
        expect(await service.buildProvider(installed), isNotNull);
      },
    );

    test(
      'removal deletes the source and credentials but keeps user data',
      () async {
        await installFull();
        await db
            .into(db.libraryEntries)
            .insert(
              LibraryEntriesCompanion.insert(
                animeId: const Value<int>(154587),
                title: 'Frieren',
              ),
            );
        await db
            .into(db.progressEntries)
            .insert(
              ProgressEntriesCompanion.insert(
                animeId: 154587,
                episodeNumber: 3,
                title: 'Frieren',
                providerId: const Value<String>('dev.example.full'),
                seriesId: const Value<String>('series-1'),
                positionMs: const Value<int>(42000),
              ),
            );

        await service.remove('dev.example.full');

        expect(await store.loadAll(), isEmpty);
        expect(await store.manifestJsonFor('dev.example.full'), isNull);
        expect(secrets.data, isEmpty);
        expect(await db.select(db.libraryEntries).get(), hasLength(1));
        final List<ProgressRow> progress = await db
            .select(db.progressEntries)
            .get();
        expect(progress, hasLength(1));
        expect(progress.single.positionMs, 42000);
      },
    );

    test(
      'removal still clears credentials when the manifest is corrupt',
      () async {
        await installFull();
        await store.saveManifest(
          providerId: 'dev.example.full',
          manifestJson: 'not json',
        );

        await service.remove('dev.example.full');

        expect(await store.loadAll(), isEmpty);
        expect(
          secrets.data,
          isEmpty,
          reason: 'the namespace sweep finds keys the manifest cannot name',
        );
      },
    );

    test('a built-in source cannot be removed', () async {
      await expectLater(
        service.remove('sample'),
        throwsA(
          isA<ProviderLifecycleFailure>().having(
            (ProviderLifecycleFailure failure) => failure.code,
            'code',
            'provider.notInstalled',
          ),
        ),
      );
    });
  });

  group('registry controller', () {
    Future<ProviderContainer> container({
      ProviderStore? customStore,
      FakeSecretStore? customSecrets,
    }) async {
      await installFull();
      final FakeSecretStore secretStore = customSecrets ?? secrets;
      final ProviderLifecycleService lifecycle = ProviderLifecycleService(
        customStore ?? store,
        secretStore,
        builtInIds: const <String>{'sample'},
      );
      final ProviderContainer providerContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          providerSecretStoreProvider.overrideWithValue(secretStore),
          providerLifecycleServiceProvider.overrideWithValue(lifecycle),
          appSettingsProvider.overrideWithValue(AppSettings.defaults),
        ],
      );
      addTearDown(providerContainer.dispose);
      return providerContainer;
    }

    test(
      'enabled, configured user providers join the existing registry',
      () async {
        final ProviderContainer providerContainer = await container();
        final UserStreamingProvidersController controller = providerContainer
            .read(userStreamingProvidersProvider.notifier);
        await controller.refresh();

        final List<StreamingProvider> userProviders = providerContainer.read(
          userStreamingProvidersProvider,
        );
        expect(userProviders, hasLength(1));
        expect(userProviders.single.id, 'dev.example.full');

        final StreamingProviderRegistry registry = providerContainer.read(
          streamingProviderRegistryProvider,
        );
        expect(registry.all.map((p) => p.id), contains('dev.example.full'));
        expect(
          registry.all.where((p) => p.id == 'sample'),
          hasLength(1),
          reason: 'built-ins stay exactly once',
        );
      },
    );

    test('refresh reuses an unchanged instance and never duplicates', () async {
      final ProviderContainer providerContainer = await container();
      final UserStreamingProvidersController controller = providerContainer
          .read(userStreamingProvidersProvider.notifier);
      await controller.refresh();
      final StreamingProvider first = providerContainer
          .read(userStreamingProvidersProvider)
          .single;

      await controller.refresh();
      final List<StreamingProvider> after = providerContainer.read(
        userStreamingProvidersProvider,
      );
      expect(after, hasLength(1));
      expect(identical(after.single, first), isTrue);
    });

    test(
      'disabling disposes the live instance and removes it from the registry',
      () async {
        final ProviderContainer providerContainer = await container();
        final UserStreamingProvidersController controller = providerContainer
            .read(userStreamingProvidersProvider.notifier);
        await controller.refresh();
        final ManifestStreamingProvider live =
            providerContainer.read(userStreamingProvidersProvider).single
                as ManifestStreamingProvider;

        await service.setEnabled('dev.example.full', false);
        await controller.refresh();

        expect(providerContainer.read(userStreamingProvidersProvider), isEmpty);
        expect(live.isDisposed, isTrue);
        expect(
          providerContainer
              .read(streamingProviderRegistryProvider)
              .all
              .map((p) => p.id),
          isNot(contains('dev.example.full')),
        );
      },
    );

    test(
      'an invalid stored manifest is skipped without breaking startup',
      () async {
        final ProviderContainer providerContainer = await container();
        await store.saveManifest(
          providerId: 'dev.example.full',
          manifestJson: 'not json',
        );
        final UserStreamingProvidersController controller = providerContainer
            .read(userStreamingProvidersProvider.notifier);
        await controller.refresh();

        expect(providerContainer.read(userStreamingProvidersProvider), isEmpty);
        expect(
          providerContainer.read(streamingProviderRegistryProvider).all,
          isNotEmpty,
          reason: 'built-ins still register',
        );
      },
    );

    test('removal disposes the instance', () async {
      final ProviderContainer providerContainer = await container();
      final UserStreamingProvidersController controller = providerContainer
          .read(userStreamingProvidersProvider.notifier);
      await controller.refresh();
      final ManifestStreamingProvider live =
          providerContainer.read(userStreamingProvidersProvider).single
              as ManifestStreamingProvider;

      await service.remove('dev.example.full');
      await controller.refresh();

      expect(live.isDisposed, isTrue);
      expect(providerContainer.read(userStreamingProvidersProvider), isEmpty);
    });
  });
}
