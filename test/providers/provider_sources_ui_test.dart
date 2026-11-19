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
import 'package:nexus/integrations/streaming/manifest/manifest_http.dart';

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

  Widget app({String initialLocation = '/sources'}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        providerSecretStoreProvider.overrideWithValue(secrets),
        providerLifecycleServiceProvider.overrideWithValue(service),
        appSettingsProvider.overrideWithValue(const AppSettings()),
        providerRecordsProvider.overrideWith((Ref ref) => store.loadAll()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: _router(initialLocation: initialLocation),
      ),
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
    expect(
      find.text(
        'No user-added sources yet. Installed manifests appear '
        'here with their configuration and status.',
      ),
      findsOneWidget,
    );
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
    expect(await store.loadAll(), isEmpty);
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

    final List<dynamic> records = await store.loadAll();
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
    expect(await store.loadAll(), hasLength(1));

    await tester.ensureVisible(removeButton);
    await tester.pump();
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(await store.loadAll(), isEmpty);
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

    final List<dynamic> saved = await store.loadAll();
    expect(saved, hasLength(1));
    expect(saved.single.config['region'], 'us');
    expect(secrets.data['dev.example.full']?['apiKey'], _secret);
    await tester.pump(const Duration(seconds: 5));
  });
}
