# Contributing to NEXUS

## 1. Before you start

- Read [ARCHITECTURE.md](ARCHITECTURE.md) and [UI_SPEC.md](UI_SPEC.md). The visual direction is approved; changes to it need a documented reason in `UI_SPEC.md` §6.
- Check [PROJECT_STATUS.md](PROJECT_STATUS.md) for the current milestone and known issues.

## 2. Environment

| Tool | Version |
|---|---|
| Flutter | 3.50.0 (stable) |
| Dart | 3.14.0 (bundled) |
| JDK | 17 |
| Android SDK | platform 36, build-tools 36.0.0 |
| Windows builds | Visual Studio 2022 with Desktop C++ workload |

```bash
flutter pub get
dart run build_runner build      # required after changing the Drift schema
```

## 3. Workflow

1. Branch from the current working branch.
2. Keep one logical change per branch: a feature, a fix, or a refactor — not all three.
3. Implement against the architecture (screens → providers → repositories → integrations).
4. Run the full verification below.
5. Update the documentation the change affects (`PROJECT_STATUS.md`, `CHANGELOG.md`, and `UI_SPEC.md`/`ARCHITECTURE.md`/`DATABASE.md` when behaviour changes).
6. Commit with a message that explains *why*.

## 4. Verification checklist

Every change must pass, in this order:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze                 # must be: No issues found!
flutter test                    # all tests must pass
flutter build apk --release     # for anything touching Android config or plugins
```

Never report a build or test as passing unless it was actually executed. If something could not run (no Windows host, no device), say so explicitly.

## 5. Code conventions

- **Formatting:** `dart format`; 80-column friendly.
- **Imports:** package imports for Flutter/packages, relative for project files. Material comes from `package:material_ui/material_ui.dart` (Flutter 3.50).
- **Types:** explicit types on public APIs and collection literals (`<Widget>[...]`); the analyzer runs with `strict-casts`, `strict-inference` and `strict-raw-types`.
- **Colours and spacing:** tokens only (`AppColors`, `AppSpacing`, `AppRadius`, `AppDurations`).
- **Strings:** single quotes.
- **State:** screens read providers; they never construct repositories. High-frequency values (playback position) go in `ValueNotifier`s, not `setState`.
- **Errors:** translate at the repository boundary into `AppFailure`; never leak `DioException`/`SqliteException` to the UI.
- **No placeholders presented as features.** If it is not wired up, the UI must say so.

### Documentation comments

Explain *why*, not *what*. A comment that restates the code should be deleted.

## 6. Adding a content provider

Read [docs/PROVIDERS.md](docs/PROVIDERS.md) first — it is normative, and §12 lists
what the current code does not yet support (descriptors, configuration,
compatibility, install/remove). Until that lands, adding a provider means the
built-in adapter path:

1. Implement `StreamingProvider` in `lib/integrations/streaming/`.
2. Declare honest `capabilities` and `ProviderStatus`; return `null` from `match()` when there is no entry rather than a best guess.
3. Mark test/public-domain media with `isSample: true` on `EpisodeStream` so the player shows the `SAMPLE` badge.
4. Register it in `provider_registry_bootstrap.dart` — the only composition point.
5. Add tests: capabilities, episodes, resolution, that real titles are not falsely matched, and that failures map to a typed provider error.

Rules that a new provider must not break:

- No screen may reference a concrete provider type or branch on provider id; capabilities are the only switch.
- No provider-specific field may enter a domain model — provider identity is a hint, not a model property.
- Metadata must keep working with every streaming provider removed.
- Provider code must not need a schema migration, a route change or a screen change to be added.
- Disabling or removing a provider must leave library, history, positions and settings intact.

Only integrate sources you are authorised to use. Do not add scrapers for protected services, DRM circumvention, or hardcoded third-party stream URLs. User-added sources use the sandboxed declarative format (HTTPS only, origin-pinned, JSON mapping, no scripting) described in `docs/PROVIDERS.md` §7.

## 7. Database changes

- Update the table in `lib/data/database/nexus_database.dart`.
- Bump `AppConstants.databaseSchemaVersion` **and** add the matching `onUpgrade` step in the same change.
- Regenerate: `dart run build_runner build`.
- Add a test proving existing rows survive the migration. See [DATABASE.md](DATABASE.md) §3.

## 8. Secrets and signing

- Never commit keystores, `android/key.properties`, tokens or API keys.
- `android/key.properties` is git-ignored and read by `android/app/build.gradle.kts` when present.
- Tokens (future AniList auth, provider credentials) belong in secure storage at runtime, never in source, SQLite, preferences, logs or crash reports.

## 9. Commit messages

```
<area>: <what changed and why>

<optional body: trade-offs, migration notes, verification performed>
```

Examples: `player: resume position when duration arrives late`, `db: keep progress when re-saving a title`.

## 10. Review checklist

- [ ] Behaviour matches the request; nothing unrelated changed.
- [ ] Loading, error, empty and data states all handled.
- [ ] No hardcoded colours, spacing or URLs; no secrets.
- [ ] Provider/capability claims are honest.
- [ ] Tests added or updated for the changed logic.
- [ ] `flutter analyze` and `flutter test` pass; output included in the report.
- [ ] Docs updated; `PROJECT_STATUS.md` reflects verified vs unverified work.
