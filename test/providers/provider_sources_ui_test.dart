import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus/core/theme/app_theme.dart';
import 'package:nexus/core/widgets/buttons.dart';
import 'package:nexus/data/database/nexus_database.dart';
import 'package:nexus/data/models/app_settings.dart';
import 'package:nexus/data/providers/app_providers.dart';
import 'package:nexus/data/repositories/provider_store.dart';
import 'package:nexus/data/services/provider_lifecycle_service.dart';
import 'package:nexus/features/settings/provider_config_screen.dart';
import 'package:nexus/features/settings/provider_import_screen.dart';
import 'package:nexus/features/settings/sources_screen.dart';
import 'package:nexus/integrations/providers/provider_descriptor.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_http.dart';
import 'package:nexus/integrations/streaming/sample_provider.dart';

import 'support/fake_secret_store.dart';
import 'support/manifest_fixtures.dart';

const String _secret = 'unit-test-secret-value';

GoRouter _router({String initialLocation = '/sources'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/sources',
        builder: (BuildContext context, GoRouterState state) =>
            const SourcesScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'import',
            builder: (BuildContext context, GoRouterState state) =>
                const ProviderImportScreen(),
          ),
          GoRoute(
            path: ':providerId/configure',
            builder: (BuildContext context, GoRouterState state) =>
                ProviderConfigScreen(
                  providerId: state.pathParameters['providerId'] ?? '',
                ),
          ),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late NexusDatabase db;
  late ProviderStore store;
  late FakeSecretStore secrets;
  late ProviderLifecycleService service;

  setUp(() async {
    db = NexusDatabase(NativeDatabase.memory());
    store = ProviderStore(db);
    // The real app seeds built-in rows at start-up; the screen derives their
    // state from those rows, so tests do the same.
    await store.syncBuiltIns(
      const <ProviderDescriptor>[SamplePlaybackProvider()],
      enabledIds: const <String>{'sample'},
    );
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

  Widget app({
    String initialLocation = '/sources',
    ProviderLifecycleService? lifecycle,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        providerSecretStoreProvider.overrideWithValue(secrets),
        providerLifecycleServiceProvider.overrideWithValue(
          lifecycle ?? service,
        ),
        appSettingsProvider.overrideWithValue(const AppSettings()),
        providerRecordsProvider.overrideWith((Ref ref) => store.loadAll()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: _router(initialLocation: initialLocation),
      ),
    );
  }

  Future<void> installMinimal({bool enabled = false}) async {
    final ProviderInstallPreview preview = await service.preview(
      jsonEncode(minimalManifest()),
    );
    await service.install(
      preview,
      values: const <String, String>{'baseUrl': 'https://api.example.com'},
      enabled: enabled,
    );
  }

  Future<void> installFull({bool enabled = true}) async {
    final ProviderInstallPreview preview = await service.preview(
      jsonEncode(fullManifest()),
    );
    await service.install(
      preview,
      values: const <String, String>{
        'baseUrl': 'https://api.example.com',
        'apiKey': _secret,
        'region': 'eu',
        'includeSpecials': 'true',
      },
      enabled: enabled,
    );
  }

  testWidgets('Sources lists the built-in test source and no user sources', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Built-in'), findsWidgets);
    expect(find.text('Test only'), findsOneWidget);
    expect(find.text('Add source'), findsOneWidget);
    expect(find.textContaining('No user-added sources yet'), findsOneWidget);
  });

  testWidgets('an invalid manifest is rejected with its problems', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add source'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      '{"manifestVersion": 1}',
    );
    await tester.tap(find.text('Review manifest'));
    await tester.pumpAndSettle();

    expect(find.text('Unreadable manifest'), findsOneWidget);
    expect(find.textContaining('This manifest has'), findsOneWidget);
    final PrimaryButton install = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, 'Install source'),
    );
    expect(install.onPressed, isNull);
    expect(await service.loadInstalled(), isEmpty);
    expect(secrets.data, isEmpty);
  });

  testWidgets('a valid manifest is reviewed, configured and installed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add source'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      jsonEncode(fullManifest()),
    );
    await tester.tap(find.text('Review manifest'));
    // Bounded pumps: a focused text field blinks its caret forever, so
    // pumpAndSettle never settles once the form appears.
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Example Full'), findsOneWidget);
    expect(find.text('v2.1.0'), findsOneWidget);
    expect(find.text('Provider contract 1'), findsOneWidget);
    expect(
      find.text('This manifest is valid and compatible with this build.'),
      findsOneWidget,
    );
    expect(find.text('API base URL'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('Region'), findsOneWidget);
    expect(find.text('Include specials'), findsOneWidget);

    final List<TextField> fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    // 0 is the manifest editor, then baseUrl and the secret.
    await tester.enterText(find.byWidget(fields[1]), 'https://api.example.com');
    await tester.enterText(find.byWidget(fields[2]), _secret);
    final Finder eu = find.text('eu');
    await tester.ensureVisible(eu);
    await tester.pump();
    await tester.tap(eu);
    await tester.pump();

    final Finder install = find.text('Install source');
    await tester.ensureVisible(install);
    await tester.pump();
    await tester.tap(install);
    // Bounded pumps: the confirmation SnackBar keeps a timer alive, and the
    // install triggers a reload, so waiting for "all animations" can wait
    // forever on the skeleton.
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final List<dynamic> records = (await store.loadAll())
        .where((dynamic record) => record.origin == ProviderOrigin.userAdded)
        .toList();
    expect(records, hasLength(1));
    expect(await service.loadInstalled(), hasLength(1));
    expect(secrets.data['dev.example.full']?['apiKey'], _secret);
    expect(find.text('Example Full'), findsOneWidget);
    expect(find.text('User-added'), findsOneWidget);

    // Let the confirmation SnackBar's timer finish before the test ends.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('removal asks for confirmation and deletes credentials', (
    WidgetTester tester,
  ) async {
    await installFull(enabled: false);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Example Full'), findsOneWidget);
    expect(find.text('Off'), findsWidgets);

    final Finder removeButton = find.widgetWithText(SecondaryButton, 'Remove');
    await tester.ensureVisible(removeButton);
    await tester.pump();
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    expect(find.text('Remove Example Full?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(await service.loadInstalled(), hasLength(1));

    await tester.ensureVisible(removeButton);
    await tester.pump();
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(await service.loadInstalled(), isEmpty);
    expect(secrets.data, isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('an invalid stored manifest shows diagnostics, not a crash', (
    WidgetTester tester,
  ) async {
    await installFull(enabled: false);
    await store.saveManifest(
      providerId: 'dev.example.full',
      manifestJson: 'not json',
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Invalid source'), findsOneWidget);
    expect(find.textContaining('manifest'), findsWidgets);
    expect(find.widgetWithText(SecondaryButton, 'Remove'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a disabled source offers Enable, not playback or retry', (
    WidgetTester tester,
  ) async {
    await installFull(enabled: false);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Off'), findsWidgets);
    expect(find.widgetWithText(SecondaryButton, 'Enable'), findsOneWidget);
    expect(find.widgetWithText(SecondaryButton, 'Configure'), findsOneWidget);
    expect(find.widgetWithText(SecondaryButton, 'Details'), findsWidgets);
    // Only the built-in test source can play; the disabled user source cannot.
    expect(
      find.widgetWithText(SecondaryButton, 'Test playback'),
      findsOneWidget,
    );
    expect(find.widgetWithText(SecondaryButton, 'Retry'), findsNothing);
  });

  testWidgets('a missing credential shows Setup required and Configure', (
    WidgetTester tester,
  ) async {
    await installFull();
    await secrets.delete('dev.example.full', 'apiKey');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Setup required'), findsOneWidget);
    expect(find.widgetWithText(SecondaryButton, 'Configure'), findsOneWidget);
    // Only the built-in test source can play; the unconfigured source cannot.
    expect(
      find.widgetWithText(SecondaryButton, 'Test playback'),
      findsOneWidget,
    );
    expect(find.widgetWithText(SecondaryButton, 'Retry'), findsNothing);
  });

  testWidgets('an unavailable source offers Retry', (
    WidgetTester tester,
  ) async {
    await installFull();
    final ProviderLifecycleService failing = ProviderLifecycleService(
      store,
      secrets,
      builtInIds: const <String>{'sample', 'anilist'},
      transportFactory: (String id) => FakeManifestTransport(
        (ManifestTransportRequest request) async =>
            FakeManifestResponse.raw('upstream down', status: 500),
      ),
    );
    await tester.pumpWidget(app(lifecycle: failing));
    await tester.pumpAndSettle();

    expect(find.text('Temporarily unavailable'), findsOneWidget);
    expect(find.widgetWithText(SecondaryButton, 'Retry'), findsOneWidget);
    // Only the built-in test source can play; the failing source cannot.
    expect(
      find.widgetWithText(SecondaryButton, 'Test playback'),
      findsOneWidget,
    );

    final Finder retry = find.widgetWithText(SecondaryButton, 'Retry');
    await tester.ensureVisible(retry);
    await tester.pump();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('Temporarily unavailable'), findsOneWidget);

    // Let the adapter's request timeout timers expire before disposal.
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('two sources can be reordered and the order persists', (
    WidgetTester tester,
  ) async {
    await installMinimal();
    await installFull(enabled: false);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Priority 1'), findsOneWidget);
    expect(find.text('Priority 2'), findsOneWidget);

    final Finder moveDown = find.byTooltip('Move down').first;
    await tester.ensureVisible(moveDown);
    await tester.pump();
    await tester.tap(moveDown);
    await tester.pumpAndSettle();

    final List<dynamic> records = await store.loadAll();
    expect(
      records.map((dynamic record) => record.providerId).toList(),
      <String>['sample', 'dev.example.full', 'dev.example.minimal'],
    );
    expect(find.text('Priority 1'), findsOneWidget);
  });

  testWidgets(
    'diagnostics stay off until opted in, then record redacted entries',
    (WidgetTester tester) async {
      await installFull(enabled: false);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final Finder details = find
          .widgetWithText(SecondaryButton, 'Details')
          .last;
      await tester.ensureVisible(details);
      await tester.pump();
      await tester.tap(details);
      await tester.pumpAndSettle();

      expect(find.text('Diagnostics'), findsOneWidget);
      expect(find.textContaining('Diagnostics are off.'), findsOneWidget);
      expect(find.text(_secret), findsNothing);

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Recording is on for this source only'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Diagnostics enabled for this source.'),
        findsOneWidget,
      );
      expect(find.text(_secret), findsNothing);

      await tester.tap(find.text('Run check'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not registered'), findsOneWidget);
      expect(find.text(_secret), findsNothing);
    },
  );

  testWidgets('the configuration screen never shows a saved secret', (
    WidgetTester tester,
  ) async {
    await installFull();
    await tester.pumpWidget(
      app(initialLocation: '/sources/dev.example.full/configure'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Saved securely. Its value is never shown again.'),
      findsOneWidget,
    );
    expect(find.text(_secret), findsNothing);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    // All declared controls are generated from the manifest.
    expect(find.text('API base URL'), findsOneWidget);
    expect(find.text('Region'), findsOneWidget);
    expect(find.text('eu'), findsOneWidget);
    expect(find.text('us'), findsOneWidget);
    expect(find.text('True'), findsOneWidget);
    expect(find.text('False'), findsOneWidget);

    await tester.tap(find.text('us'));
    await tester.pump();
    final Finder save = find.text('Save configuration');
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final List<dynamic> saved = (await store.loadAll())
        .where((dynamic record) => record.origin == ProviderOrigin.userAdded)
        .toList();
    expect(saved, hasLength(1));
    expect(saved.single.config['region'], 'us');
    expect(secrets.data['dev.example.full']?['apiKey'], _secret);
    await tester.pump(const Duration(seconds: 5));
  });
}
