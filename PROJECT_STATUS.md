# NEXUS — Project Status

**Last updated:** 2026-11-19
**Milestone:** v0.2.0-alpha.1 shipped; **milestone 2.2d (Sources surface, states and diagnostics) implemented** on `main` and not yet released
**Latest change:** every derived provider state now leads with the action that can change it, user-added sources can be reordered, and opt-in redacted diagnostics explain failures — 41 new hermetic tests, no schema migration (§14)
**Source of truth:** https://github.com/CodeWithAN5H/NEXUS (branch `main`)
**Application id:** `app.nexus` — confirmed permanent 2026-11-17

---

## 1. Environment in this session

| Item | Value |
|---|---|
| Host | Ubuntu 24.04.5 LTS, x86-64, 2 vCPU, 3.8 GiB RAM, headless |
| Flutter | 3.50.0 stable (installed project-locally in `.toolchain/`, git-ignored) |
| Dart | 3.14.0 |
| Java | Temurin JDK 17.0.21 (project-local) |
| Android SDK | platform `android-36`, build-tools `36.0.0`, platform-tools 37 — licences accepted |
| Gradle / AGP | 9.5 / 9.3.1 (from Flutter template), Kotlin 2.4.20 |
| Windows host | **None** — `flutter build windows` cannot run here |
| Android device / emulator | **None** — no KVM, headless; the APK was built, not run |

No system-wide software was installed (no root available). Everything lives under `.toolchain/` and is referenced per command; the repository has no machine-specific paths.

---

## 2. Completed in this milestone

**Foundation**
- Flutter project for Android + Windows, application id `app.nexus` (provisional).
- 137 packages resolved; `material_ui` adopted after Flutter 3.50 deprecated `flutter/material.dart`.
- Central design system: colour/spacing/radius/motion/typography tokens, Inter bundled (4 weights).

**Application shell**
- `go_router` with a six-branch `StatefulShellRoute`; adaptive shell (bottom bar on Android, sidebar on desktop); focused routes for details, sources and player.
- Windows keyboard shortcuts in the player (Space, ←/→, ↑/↓, F, M, Esc).

**Screens**
- Home (featured carousel + five live rails + Continue Watching + pull to refresh).
- Explore (debounced search, filter sheet with genre/season/year/sort, responsive grid, recent searches).
- Anime details (backdrop, metadata, expandable synopsis, Episodes/Details/Related tabs, library status sheet).
- Library (five statuses with counts, search, four sorts, grid/list, progress).
- History (resume, delete, clear all).
- Profile (local stats, links, honest AniList `v0.4` state).
- Settings (appearance, playback, subtitles, audio, sources, AniList, about/licences) — every control is wired.
- Sources (per-provider status, capabilities, enable toggle, generic playback test).
- Player (custom chrome, quality/audio/subtitle/speed/episode menus, resume, auto-next, gestures, auto-hide, keyboard).

**Data**
- Drift schema v1 with four tables, primary keys, versioned migration strategy and `PRAGMA foreign_keys`.
- Repositories: library, history, search history, preferences, metadata (5-minute TTL cache).
- Sealed `AppFailure` hierarchy with `DioException`/HTTP mapping.

**Content providers**
- `StreamingProvider` contract + registry + source manager.
- Built-in Playback Test Library using **verified** public HLS streams (Apple BipBop, Mux BBB) with `SAMPLE` labelling; `match()` never claims a real anime.

**Android packaging**
- INTERNET / ACCESS_NETWORK_STATE / WAKE_LOCK permissions, `NEXUS` label.
- Gradle release signing scaffold via `android/key.properties` (debug-signed fallback for testers).
- Universal release APK produced and verified.

---

## 3. Verification results

> This table records the **v0.1.0-alpha** build. Verification for
> **v0.2.0-alpha.1** is in §11, including the schema migration and the 144-test
> suite.

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | ✅ clean (exit 0) |
| Static analysis | `flutter analyze` | ✅ **No issues found!** (0 errors, 0 warnings, 0 infos) |
| Unit/widget/database tests | `flutter test` | ✅ **79/79 passed** |
| Code generation | `dart run build_runner build` | ✅ 37 outputs, Drift schema generated |
| Release APK build | `flutter build apk --release` | ✅ `APK_BUILD_EXIT=0` |
| APK package identity | `aapt2 dump badging` | ✅ `app.nexus`, versionCode `1`, versionName `0.1.0`, minSdk `24`, targetSdk `36`, label `NEXUS` |
| APK permissions | `aapt2 dump badging` | ✅ INTERNET, ACCESS_NETWORK_STATE, WAKE_LOCK present |
| APK signature | `apksigner verify --print-certs` | ⚠️ Signed, but with the **Android Debug** certificate (expected — no release keystore exists yet) |
| APK artifact | `sha256sum` | `85505a9c9c69e65d5144105ec7f0e168654011c85fdcd2104e2f5d77eeabf81b` (105 MB, universal) |
| AniList schema | live GraphQL introspection | ✅ `MediaSort`, `MediaSeason`, `MediaStatus`, `MediaFormat` enums confirmed |
| Test stream reachability | `curl` HEAD/range requests | ✅ Apple BipBop master + sub-playlists, Mux 1080p + 240p all HTTP 200 |
| Data preservation | `test/database_test.dart` "survive a close/reopen cycle" | ✅ library progress, position and settings intact |

### Not verified (and why)

| Item | Status | Reason |
|---|---|---|
| App launch and runtime behaviour | ❌ Not verified | No Android device or emulator in this environment; the APK was built, never executed |
| Playback actually decoding video | ❌ Not verified | Same; stream URLs were verified reachable, the decoder path was not exercised |
| UI compared against the concept images | ❌ Not verified | Headless host, no rendering surface or screenshot capability |
| Windows build | ❌ Not verified | Requires a Windows host with MSVC |
| Migration from a real previous release | ⚠️ Partially verified | Schema v1 has no upgrade path yet; the close/reopen persistence test simulates an update |
| Android in-place update over a previous APK | ❌ Not verified | Requires a signing key and an installing device |
| Instrumented/integration tests | ❌ Not written | Need a device; unit + widget + database coverage only |

---

## 4. Artifacts and release pipeline

| File | Purpose |
|---|---|
| `artifacts/NEXUS-0.1.0-alpha-universal.apk` | Local, **debug-signed** verification build. Not published anywhere. |
| `artifacts/SHA256SUMS.txt` | Checksum for the above |

That APK is a preview: signed with the Android debug certificate, so it cannot be updated by a release-signed build. **It must never be published as a GitHub Release asset** — doing so would force everyone onto an uninstall path that destroys local data.

**Release pipeline (ready, not yet executed):** `.github/workflows/release.yml` builds, verifies and publishes on tag `v*` — it refuses to run without the four signing secrets and refuses to publish a debug-signed APK. Setup steps and update verification: [docs/RELEASE.md](docs/RELEASE.md) §3–§6. No release exists yet, because the permanent application id and the signing identity are owner decisions.

Universal APK size is 105 MB because it carries libmpv for four ABIs. `flutter build apk --split-per-abi` produces roughly 35–40 MB per architecture when a smaller download matters.

---

## 5. Known issues and limitations

**Product**
1. No anime content source. Details → Episodes shows an explicit "no source available" state; this is intentional, not a bug.
2. No AniList sign-in, list sync or score push (Profile shows a `v0.4` badge rather than a fake connection).
3. Rails are capped at 12 items and Explore at 24 per request — no pagination yet.
4. Default Flutter launcher icon; no bespoke splash.
5. Dark theme only.
6. Episode watched state is derived from the library's `watchedEpisodes` high-water mark plus per-episode progress ≥ 90 %, not from an independent per-episode table.

**Player**
7. Windows fullscreen is window-level (no true borderless mode without a window plugin); Android uses immersive mode + landscape.
8. Brightness gestures are Android-only and fail silently elsewhere.
9. No subtitle delay/styling beyond size/colour/background; no PiP; no automatic quality downgrade on poor networks.
10. `media_kit` drives mpv; behaviour differences between Android and Windows media stacks are expected but unmeasured here.

**Engineering**
11. Release signing not yet established (blocked on owner approval).
12. Application id `app.nexus` is permanent as of 2026-11-17 (confirmed by the owner).
13. Linux desktop not configured (no clang/CMake/GTK in this image) — out of scope for v0.1.
14. `dart format` and `flutter analyze` are clean, but there is no CI pipeline yet.

---

## 6. Next actions

**Immediate (v0.2.0-alpha)** — the sequence, dependencies and per-milestone completion criteria are in [docs/V0.2_PLAN.md](docs/V0.2_PLAN.md). Milestones **2.1a, 2.1b, 2.2a, 2.1c, 2.2b, 2.2c and 2.2d are complete** (§11–§14). The next code is **2.3a**, which is blocked on decision D1 (the owner's authorised provider); nothing else in v0.2 is waiting on code.

0. Install the v0.2.0-alpha.1 APK on a real Android device; verify launch, rails, search, details, library persistence, the migrated database and playback of the test streams. Record results here. (Still blocked: no device — decision D6.)
1. ~~**2.1a** contract, descriptor envelope, three axes, `probe()`/`dispose()`, sealed `ProviderFailure`.~~ ✅ §11
2. ~~**2.1b** `MetadataProvider` split; AniList stops being a special case.~~ ✅ §11
3. ~~**2.2a** provider store + additive schema v2 ([DATABASE.md](DATABASE.md) §6).~~ ✅ §11
4. ~~**2.1c** collect-all resolution, priority, per-title preference.~~ ✅ §11 — release waiting on signing
5. ~~**2.2b** manifest validator and interpreter ([docs/PROVIDER_MANIFEST.md](docs/PROVIDER_MANIFEST.md)).~~ ✅ §12
   ~~**2.2c** lifecycle and configuration.~~ ✅ §13 — install, generated configuration, keystore secrets, startup revalidation, enable/disable, removal and the Sources workflows that exercise them.
   ~~**2.2d** Sources states, priority ordering and diagnostics.~~ ✅ §14 — one action per state, serialised reordering, opt-in redacted diagnostics with a confirmed clipboard export.
6. **2.3a** register the owner's authorised provider; **2.3b** real episode lists and provider subtitles (blocked on decision D1).
7. **2.4a** Explore pagination; **2.4b** AniList `streamingEpisodes` and air dates merged into the Episodes tab.
8. **2.5a** Windows build verification (blocked on a Windows host); **2.5b** launcher icon and splash.

**Then (v0.3 → v0.4)**
6. Playback hardening: buffering reporting, per-title quality memory, PiP, error taxonomy.
7. AniList OAuth, secure token storage, list/progress sync.

### Blocked on owner decisions

| Decision | Needed for | Note |
|---|---|---|
| Add the 4 signing secrets to the repository | Publishing the first signed release | Owner creates and backs up the keystore locally (docs/RELEASE.md §3) |
| Create the release keystore and add 4 Actions secrets | Signed releases and in-place updates | Key must be generated and backed up by the owner; it cannot be safely created or preserved in this cloud workspace |
| Choose an authorised content provider | Real anime playback | NEXUS will not integrate unauthorised sources; the integration point is now specified in [docs/PROVIDERS.md](docs/PROVIDERS.md) |
| Adopt the declarative (user-added) integration tier in v0.2 | Letting users add compatible sources without an app update | Fully specified (§7 of `docs/PROVIDERS.md`); it is a larger sub-milestone than the built-in adapter path and changes the Sources surface |
| Confirm `main` is the release branch | Tag-triggered publishing | `main` is the only branch with the milestone history; nothing has been released yet |
| Is the declarative integration tier in v0.2? (D2) | Milestones 2.2b–2.2d | The format is now frozen at v1 with a schema, tests and a threat model, so deferring it is a scoping choice, not an unknown |
| Approve `flutter_secure_storage` as a dependency (D4) | 2.2c, provider credentials | Required before any provider stores a secret; nothing is installed yet |
| Approve the schema-enforcement approach (D3) | 2.2b | Recommendation: in-repo validator for the v1 subset, no new dependency |
| Release cadence for pre-releases (D7) | Tester builds | Recommendation: `v0.2.0-alpha.N` per user-visible milestone |

---

## 7. Reproducing the verification

```bash
cd <repo>
source .toolchain/env.sh          # JAVA_HOME, ANDROID_HOME, PATH, PUB_CACHE

dart run build_runner build
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release

$ANDROID_HOME/build-tools/36.0.0/aapt2 dump badging \
  build/app/outputs/flutter-apk/app-release.apk | head -6
$ANDROID_HOME/build-tools/36.0.0/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

Without the project-local toolchain, substitute a normal Flutter 3.50 / JDK 17 / Android SDK 36 installation.

---

## 8. Provider platform architecture review — 2026-11-18 (documentation only)

The provider layer was reviewed and finalised before v0.2 development. **No source
file, database schema, UI, dependency, signing configuration or workflow was
changed by this review.** Normative result: [docs/PROVIDERS.md](docs/PROVIDERS.md).

**What the review settled**

1. Metadata and streaming are separate provider kinds with separate contracts and
   registries; AniList becomes the first `MetadataProvider` in v0.2 rather than a
   concrete client behind `MetadataRepository`.
2. Compatibility, configuration and availability are three separate axes with one
   derived presentation state, because each has a different owner and only one is
   retryable.
3. Providers are described by a descriptor envelope (stable id, contract version,
   kind, capabilities, configuration fields, origin) instead of a bare class.
4. Two integration tiers: built-in Dart adapters registered in one bootstrap file,
   and user-added declarative JSON integrations run by one sandboxed adapter.
5. Resolution collects every matching provider, honours user priority and stores a
   per-title preference, instead of stopping at the first match.
6. Typed `ProviderFailure` taxonomy replaces free-form `ProviderException`
   messages, so the UI can offer the right action (setup vs update vs retry).

**Gaps this creates in the current code** (documented, deliberately not fixed yet —
see `docs/PROVIDERS.md` §12):

| Gap | Consequence today | Where it lands |
|---|---|---|
| `ProviderRegistry` is a compile-time `const` list | A provider can only be added by rebuilding the app | v0.2 §2.2 |
| Only `sources.enabled` is persisted | No configuration, ordering or install origin; removing and re-adding a provider loses settings | v0.2 §2.2 (schema v2) |
| `ProviderAvailability` is the only axis | `needsConfiguration` is conflated with "the source is down" | v0.2 §2.1 |
| `status` is a synchronous getter | Availability cannot be refreshed or validated asynchronously | v0.2 §2.1 (`probe()`) |
| `SourceManager.lookup` returns the first match | A second usable source is invisible | v0.2 §2.1 |
| `ProviderException` carries a message only | Failure-specific UI (auth vs geo vs rate limit) is not expressible | v0.2 §2.1 |
| No `dispose()` on the contract | Clients and timers leak when a provider is removed | v0.2 §2.1 |
| AniList is wired into `MetadataRepository` | A second catalogue requires edits across the data layer | v0.2 §2.1 |

These are additive changes to `lib/integrations/`, the composition root and the
schema; screens change only where Sources shows the new states. They are not
implemented in this revision by design.

**Not verified by this review:** nothing runtime-related was re-tested, because no
code changed. The verification table in §3 still describes the v0.1.0-alpha build.

---

## 9. v0.2 preparation — 2026-11-19 (documentation only)

The provider platform was specified down to the point where implementation can
start without design decisions being made in code reviews. **No application
source, database schema, dependency, UI, signing configuration or workflow was
changed.** No APK was built or published.

**Added**

| Artefact | Role | Verified how |
|---|---|---|
| [docs/PROVIDER_MANIFEST.md](docs/PROVIDER_MANIFEST.md) | Declarative manifest format v1: lifecycle, placeholders, JSON-path subset, coercion, matching, numbering, errors, limits, validation stages, versioning, deliberate exclusions | Prose review against the platform spec |
| [docs/schema/provider-manifest.v1.schema.json](docs/schema/provider-manifest.v1.schema.json) | Machine-readable JSON Schema (draft 2020-12, `additionalProperties: false`) | `Draft202012Validator.check_schema` + all committed examples |
| `docs/schema/examples/valid-{minimal,full}.json` | Reference manifests | Both validate |
| `docs/schema/examples/invalid-*.json` (4) | One deliberate defect each: plain-HTTP origin, unbacked capability, executable field, JSONPath filter | All rejected, with the documented path |
| [docs/PROVIDER_TESTS.md](docs/PROVIDER_TESTS.md) | Contract test matrix: 24 schema, 46 adapter, 10 built-in, 15 resolution, 11 persistence, 10 Sources tests, plus requirement traceability | Review; executed from 2.2b |
| [docs/PROVIDER_SECURITY.md](docs/PROVIDER_SECURITY.md) | Threat model, per-attack protections, eight accepted residual risks, 12-point implementation checklist | Review |
| [docs/V0.2_PLAN.md](docs/V0.2_PLAN.md) | 13 milestones with dependencies, tests, completion criteria, release points and eight owner decisions | Review; roadmap scope unchanged |

**What this settles**

1. A compatible source can be added without an APK rebuild, using data only — no
   scripting, no runtime code loading, no WebView.
2. The format is constrained enough to validate offline and to enforce an egress
   allowlist before a socket opens.
3. "Secure" is stated precisely: code execution, filesystem access and
   undeclared-origin requests are impossible; misleading content, hostile media
   URLs on declared hosts and DNS rebinding are **not** prevented and are listed
   as accepted risks.
4. v0.2 is sequenced so each milestone can be built, tested and released
   independently, and so a decision to defer the manifest tier (D2) or the
   authorised provider (D1) blocks only the milestones that need them.

**Verification run for this revision**

| Check | Result |
|---|---|
| JSON Schema is a valid 2020-12 schema | ✅ `check_schema` passes |
| Both valid example manifests validate | ✅ 0 errors |
| All four invalid examples are rejected with the expected path/code | ✅ |
| Relative links across every Markdown file resolve | ✅ 15 Markdown files scanned, 0 broken |
| `git diff --check` | ✅ clean |
| Diff contains only Markdown and the schema/examples under `docs/` | ✅ |
| `flutter analyze` / `flutter test` | Not run — no Dart file changed |
| APK build / Release | Not run, by scope |

**Still not verified:** everything runtime-related, as in §3. The manifest format
has been validated as *data*; no adapter exists to execute it.

---

## 10. Reproducing the documentation and schema checks

These are documentation checks, not project dependencies: `jsonschema` is used
only to validate the committed schema and examples, and is not added to
`pubspec.yaml`.

```bash
# Schema is a valid draft 2020-12 schema, and the examples behave as documented
python3 -m pip install --quiet jsonschema
python3 - <<'PY'
import glob, json
from jsonschema import Draft202012Validator
schema = json.load(open('docs/schema/provider-manifest.v1.schema.json'))
Draft202012Validator.check_schema(schema)
v = Draft202012Validator(schema)
for f in sorted(glob.glob('docs/schema/examples/*.json')):
    errors = list(v.iter_errors(json.load(open(f))))
    expected_ok = '/valid-' in f
    print(('PASS' if (not errors) == expected_ok else 'FAIL'), f, errors[:1])
PY

# Every relative Markdown link resolves (code fences ignored)
python3 - <<'PY'
import os, re, subprocess
files = subprocess.run(['git', 'ls-files', '*.md'], capture_output=True, text=True).stdout.split()
link = re.compile(r'\]\(([^)#]+)\)')
fence = chr(96) * 3  # keeps this snippet from closing its own code block
broken = 0
for f in files:
    text = re.sub(fence + '.*?' + fence, '', open(f).read(), flags=re.S)
    for target in link.findall(text):
        if target.startswith(('http://', 'https://', 'mailto:')):
            continue
        path = target.split('#')[0]
        if path and not os.path.exists(os.path.join(os.path.dirname(f), path)):
            print('BROKEN', f, '->', target)
            broken += 1
print(len(files), 'files scanned,', broken, 'broken')
PY

git diff --check
```

Expected output: `PASS` for both valid examples and for all four `invalid-*`
files (they are expected to fail validation), no `BROKEN` lines, and no
whitespace errors from `git diff --check`.

`flutter analyze` and `flutter test` are deliberately not part of that check: it
covered a documentation-only revision.

---

## 11. v0.2.0-alpha.1 — provider platform foundation (implemented 2026-11-19)

Milestones **2.1a, 2.1b, 2.2a and 2.1c** of
[docs/V0.2_PLAN.md](docs/V0.2_PLAN.md). Application id `app.nexus`, the signing
identity and every existing user row are unchanged. The declarative manifest
tier (2.2b–2.2d) and real content (2.3a/2.3b) are deliberately **not** in this
change.

### What shipped

| Area | Result |
|---|---|
| Provider kinds | `ProviderDescriptor` envelope + `StreamingProvider` and `MetadataProvider` contracts; separate registries; compatibility evaluated once at registration |
| Three axes | `ProviderCompatibility`, `ProviderConfigurationState`, `ProviderAvailability` plus one derived `ProviderPresentationState` (6 states) |
| Lifecycle | `probe()` → timestamped `ProviderStatusSnapshot`; mandatory idempotent `dispose()` |
| Failures | Sealed `ProviderFailure`, 13 subtypes, stable codes, `AppFailure` mapping; `ProviderException` removed |
| Metadata | `AniListMetadataProvider`; `MetadataRepository` depends on the interface; `MediaPage` is provider-neutral; no `AniListClient` import outside `lib/integrations/anilist/` (test-enforced) |
| Resolution | `ProviderResolver`: all matches, stored priority, per-title preference, 4-probe cap, 2-minute match TTL, typed per-provider failures |
| Persistence | Schema v2 (`provider_entries`, `provider_title_prefs`, `provider_manifests`), `ProviderStore`, 1 → 2 migration backfilled from `sources.enabled` |
| Details screen | Source chooser when several providers match; the choice is saved as the per-title preference; collapsible source-error line |
| Player | A resume hint whose provider is gone re-resolves the title; every error is a `ProviderFailure` |
| Sources screen | One derived chip per provider (Ready / Test content only / Setup required / Sign-in rejected / Incompatible / Temporarily unavailable / Off), still the existing card |

### Database migration

Source: `test/fixtures/nexus_v1.sqlite`, a real database written by v0.1.0-alpha
and committed unchanged. On open, `onUpgrade(1 → 2)` creates three tables,
backfills `provider_entries` from `sources.enabled`, and bumps
`PRAGMA user_version` to 2. `PRAGMA foreign_keys` stays on. No v1 table or column
is altered.

`test/providers/provider_store_test.dart` proves: tables exist, `user_version = 2`,
the library row (watched 7/28), the 7 m 12 s position, all settings and both search
rows are intact; reopening does not duplicate rows; new data written after the
upgrade survives another restart; removing a provider leaves library, history and
settings byte-identical.

### Verification

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | ✅ clean, 0 files changed |
| Static analysis | `flutter analyze` | ✅ **No issues found!** |
| Tests | `flutter test` | ✅ **144/144 passed** (79 v0.1 baseline + 65 new provider tests) |
| Code generation | `dart run build_runner build` | ✅ Drift schema v2 generated |
| Migration | `test/providers/provider_store_test.dart` | ✅ v1 fixture upgraded with every row preserved |
| Release APK | `flutter build apk --release` | ✅ 109.9 MB universal APK, exit 0 |
| Package identity | `aapt2 dump badging` | ✅ `app.nexus`, versionCode **2**, versionName **0.2.0-alpha.1**, minSdk 24, targetSdk 36 |
| Signature | `apksigner verify --print-certs` | ⚠️ **Android Debug** certificate — no release keystore exists here; this APK must not be published |
| APK checksum | `sha256sum` | `34bf2a4578af693f1d1a0a268a520713d686a22adfd4c66ad2f944481a3383de` |

### Not verified (and why)

| Item | Status | Reason |
|---|---|---|
| App launch and runtime behaviour | ❌ | No Android device or emulator (decision D6); the APK was built, not run |
| Migration on a real installed app | ⚠️ | Proven against a committed v1 database file, not an installed upgrade |
| Windows build | ❌ | No Windows/MSVC host (decision D5) |
| Signed release and in-place update | ❌ | No release keystore or Actions secrets; `apksigner` reports the debug certificate |
| Multi-source UI and source-error line | ⚠️ | Widget tree compiles and the resolver is tested; the screens were not rendered on a device |
| 2.1c in-app reordering control | ❌ | Priority is stored, resolved and tested; the drag control ships in 2.2d |

### Environment repairs made in this session

Both were restored, not changed in the repository: the pub cache was truncated
(`drift_dev` was missing `lib/src/backends/build/`), and the NDK was missing its
`build/` toolchain directory because the checkpoint treats any `build` folder as
rebuildable output. The NDK toolchain tree was re-extracted from the official
r28c archive; dependencies were re-fetched from the lockfile. `build_runner` is
pinned to 2.16.2 because the published 2.17.1 + build 5.0.0 pair is internally
broken (dev tooling only).

### Next milestone

**2.2c — provider lifecycle and configuration** (install/review flow, generated
configuration form, keystore secrets, re-validation on load, removal). The v0.2
release workflow is verified and working; a new release is a deliberate
owner-triggered action, not part of every milestone.

---

## 12. Milestone 2.2b — manifest validator and interpreter (implemented 2026-11-19)

Adds the declarative tier described in
[docs/PROVIDER_MANIFEST.md](docs/PROVIDER_MANIFEST.md). No database schema, UI,
application id or signing change; the existing provider platform, failure model
and resolver are reused rather than duplicated.

### What shipped

| Area | Result |
|---|---|
| Validation | Parse (size, depth, JSON errors with byte offset) → schema → templates → paths → semantics → compatibility; every error collected as `{code, path, message}`, sorted by path |
| Model | `ProviderManifest` for identity, network envelope, configuration fields, all six requests, variant/subtitle/audio mappings and the error policy |
| Compatibility | Unknown `manifestVersion` → `requiresNewerApp`; contract outside this build → `unsupportedContract`; both keep the document for a later app |
| Interpreter | `ManifestStreamingProvider` implements `StreamingProvider`: search, match (three fixed strategies with ambiguity left to the user), seasons, episodes (absolute and season-relative), resolve with variants, subtitles, audio and stream headers |
| HTTP | HTTPS only, allowlist on parsed URIs, manual redirects re-checked per hop, credentials dropped across origins, byte caps while reading, timeouts, pacing, 4-request gate, one retry for idempotent GETs |
| Failures | Every path returns a `ProviderFailure`; `probe()` never throws, even on an unexpected bug |
| Isolation | `ManifestProviderFactory` turns one stored document into a provider or a typed failure; a bad manifest cannot affect another |
| Media safety | A variant or subtitle URL must be HTTPS, ≤ 2048 characters, free of control characters and on `mediaHosts` or an allowed origin before the player sees it |

### Verification

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | ✅ clean |
| Static analysis | `flutter analyze` | ✅ **No issues found!** |
| Tests | `flutter test` | ✅ **224/224 passed** (144 before this milestone + 80 new) |
| Committed examples | `manifest_validation_test.dart` | ✅ both `valid-*.json` accepted; each `invalid-*.json` refused with the documented code and path |
| Composed behaviour | adapter tests | ✅ resolver picks a manifest provider as a source; redirects, caps, timeouts, pacing, cancellation and credential handling asserted with a scripted transport |

No test opens a socket and no test uses a real streaming provider: the fixtures
are synthetic, which is why the suite is deterministic.

### Not verified (and why)

| Item | Status | Reason |
|---|---|---|
| Installing a manifest from the app | ❌ | Install/review UI is milestone 2.2c |
| Storing a secret in the keystore | ❌ | 2.2c; the adapter accepts a resolved configuration map and never persists it |
| Re-validating a stored manifest on load | ❌ | 2.2c; the factory is the seam it will call |
| Runtime device behaviour | ❌ | No Android device or emulator here (decision D6) |
| Real provider interoperability | ❌ | No authorised provider (decision D1); all fixtures are synthetic |
| Duplicate JSON keys | ⚠️ | `dart:convert` is last-wins and does not report the collision; documented in PROVIDER_MANIFEST.md §9 |

### Next milestone

**2.3a — the owner's authorised provider.** Blocked on decision D1; everything
else planned for v0.2 is implemented. Remaining non-code work: install the
`v0.2.0-alpha.1` APK on a device (D6) and the Windows verification (2.5a). Next
release is an owner action; nothing was tagged or published for this milestone.

---

## 13. Milestone 2.2c — provider lifecycle and configuration (implemented 2026-11-19)

Makes the declarative tier usable end to end: a pasted manifest can be reviewed,
installed, configured, enabled, disabled and removed from Settings → Sources, and
installed providers join the existing registry after revalidation. No schema
migration, application id or signing change; nothing was released.

### What shipped

| Area | Result |
|---|---|
| Installation | `ProviderLifecycleService.preview` validates without writing; `install` revalidates, refuses duplicates and built-in ids, validates configuration, writes secrets, then writes the row and manifest in one transaction; every failure rolls back both stores |
| Configuration | `ManifestConfigValidator` covers `text`, `url`, `secret`, `choice`, `bool`, required/optional, `pattern` and `maxLength`; one `ProviderConfigForm` serves installation and editing; a saved secret is shown as present and never read back |
| Secrets | `ProviderSecretStore`/`FlutterSecureStorageSecretStore` under `provider.<id>.<key>`; ordinary config stays in `provider_entries.config_json`; an inaccessible keystore reads as absent, not as a crash or a leaked error; removal deletes the credential; Android `FLAG_SECURE` while a credential field can be shown |
| Startup | Installed manifests are read from `provider_manifests`, validated again and reported as `InstalledProvider`; every provider is built through `ManifestProviderFactory`; an invalid or incompatible row disables only itself |
| Registry | `UserStreamingProvidersController` adds enabled/compatible/configured providers to the existing `StreamingProviderRegistry`, reuses unchanged instances, disposes every instance it drops and never registers a duplicate |
| Sources UI | Add source (paste → review → configure → install), installed cards with state chip, enable toggle, Configure, Remove with confirmation, diagnostics for an invalid stored manifest, and the built-in sample source still labelled *test only* |
| Routes | `/sources/import` and `/sources/:providerId/configure`, outside the shell, reusing existing tokens and components |

### Verification

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | ✅ clean |
| Static analysis | `flutter analyze` | ✅ **No issues found!** |
| Tests | `flutter test` | ✅ **258/258 passed** (224 before this milestone + 34 new) |
| Secret containment | lifecycle tests | ✅ no configured secret appears in a row, a manifest, a state value or an error message; the fake keystore holds it |
| User data preservation | removal test | ✅ library row and playback position unchanged after removing the provider |
| UI flows | widget tests | ✅ empty Sources, invalid review, valid review + install, invalid stored manifest, removal confirmation, configuration editing |

### Not verified (and why)

| Item | Status | Reason |
|---|---|---|
| Runtime device behaviour (keystore, `FLAG_SECURE`) | ❌ | No Android device or emulator here (decision D6) |
| Windows keystore | ❌ | No Windows host (decision D5, 2.5a) |
| URL manifest import | ❌ | Deliberately later work; paste is the supported mechanism |
| Real provider interoperability | ❌ | No authorised provider (decision D1); fixtures are synthetic |
| Duplicate JSON keys, DNS rebinding | ⚠️ | Unchanged from 2.2b and documented in PROVIDER_MANIFEST.md §9 / PROVIDER_SECURITY.md |

---

## 14. Milestone 2.2d — Sources surface, states and diagnostics (implemented 2026-11-19)

Completes the management surface: every derived state carries the action that can
change it, user-added sources can be ordered, and failures are explicable without
exposing a credential. No schema migration, player change or unrelated screen
change; nothing was released.

### What shipped

| Area | Result |
|---|---|
| State actions | `ProviderSourceActions` maps the existing presentation state to one primary action — Test playback / Configure / Retry / Enable / Remove — with Details and Configure where they can work; while a probe runs the card offers inspection only; built-ins are never removable |
| Ordering | Up/down controls per user-added source; one transaction rewrites a complete order with built-in rows first, so priorities stay unique; origins, enablement and per-title preferences are untouched; the resolver still applies preference ahead of priority |
| Concurrency | `ProviderManagementService` serialises reorder and enable/disable through one queue, reading fresh state per operation |
| Diagnostics | Opt-in per source, in-memory, capped at 20, cleared when switched off and on removal; *Run check* records availability or a typed failure category (network / timeout / upstream / authentication / configuration / compatibility / manifest) with timestamps |
| Redaction | URL query strings and fragments, bearer tokens, header values by name, long opaque tokens, control characters and length caps, plus `ProviderRedaction.scrub`; no response body or header value is ever collected |
| Export | Copy-to-clipboard only, behind an explicit confirmation that states what is and is not included; nothing is uploaded, logged or written to a file |
| UI | Details sheet with identity, attribution, the three axes, last observed time, invalid-manifest `path → problem` rows, opt-in switch, history, Clear, Run check and Copy; Sources cards keep the existing tokens and layout |

### Verification

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | ✅ clean |
| Static analysis | `flutter analyze` | ✅ **No issues found!** |
| Tests | `flutter test` | ✅ **299/299 passed** (258 before this milestone + 41 new) |
| State coverage | `source_actions_test.dart` | ✅ all six states, loading, built-in vs user, no impossible actions |
| Ordering | `provider_priority_test.dart` | ✅ reorder, restart, unique priorities, resolver order, preference first, disabled source, concurrent moves, unknown/built-in refusal |
| Diagnostics | `provider_diagnostics_test.dart` | ✅ opt-in gate, cap, clear/forget, failure categories, URL/token/header/secret redaction, empty export |
| UI | `provider_sources_ui_test.dart` | ✅ empty state, invalid review, install, unavailable + Retry, disabled + Enable, needsSetup, reorder, diagnostics opt-in, removal, secret never shown |

### Not verified (and why)

| Item | Status | Reason |
|---|---|---|
| Runtime device behaviour (clipboard, sheet, gestures) | ❌ | No Android device or emulator here (decision D6) |
| Requested origin hosts in the import review | ❌ | Not implemented; recorded as the remaining S10 gap |
| App-background disposal | ❌ | Not implemented; recorded as the remaining S11 gap |
| URL manifest import | ❌ | Deliberately later work; paste is the supported mechanism |
| Real provider interoperability | ❌ | No authorised provider (decision D1); fixtures are synthetic |

## 15. Milestone 2.3a — AniZone experimental streaming source (implemented 2026-11-20)

NEXUS's first real streaming source. The read-only investigation of 20 Nov 2026
established that AniZone (`anizone.to`) exposes a plain HLS master, external
SRT/ASS subtitles and multi-language audio through ordinary HTML/JSON parsing —
no login, CAPTCHA, token derivation, obfuscation or DRM. Segments are standard
HLS AES-128 whose key URI is published in the playlist, so media_kit/libmpv
handles them and NEXUS implements no decryption.

### What shipped

| Area | Detail |
|---|---|
| Parser | `anizone_parser.dart`: `JSON.parse('…')` argument decoding, search items, series page, Livewire continuation, `vidstackPlayer` payload, HLS master renditions and audio groups, duration/URL normalisation |
| Client | `anizone_client.dart`: Dio, required mobile User-Agent (the CDN answers 403 without one), 250 ms pacing, 15 s timeout, 4 MiB cap, one retry for GET, cookie jar for the Livewire POST, typed `ProviderFailure`s |
| Provider | `anizone_provider.dart`: search, scored matching with year/format guards and an ambiguity veto, paginated episode lists with partial-list notice, resolve to one HLS master variant with subtitles, audio tracks and headers |
| Contract additions | `EpisodeListNotice` — an optional interface; no capability or method changed |
| Registration | One entry in `provider_registry_bootstrap.dart`; `syncBuiltIns` inserts it **disabled**, so no existing install gains an active source |
| UI | One line in the episode tab when a list is truncated; the player, Sources, routes and schema are unchanged |

### Verification

| Check | Command | Result |
|---|---|---|
| New tests | `flutter test test/providers/anizone_parser_test.dart test/providers/anizone_provider_test.dart` | ✅ **51/51 passed** |
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | ✅ clean |
| Static analysis | `flutter analyze` | ✅ **No issues found!** |
| Full suite | `flutter test` | ✅ **350/350 passed** (299 before + 51 new) |

### Not verified (and why)

| Item | Status | Reason |
|---|---|---|
| Real Android playback | ❌ | No device or emulator here (decision D6); the required phone tests are listed in §6 |
| 10-bit H.264 on device | ❌ | Some titles (e.g. Naruto 720p, High 10) may exceed hardware decoders; needs a phone check |
| media_kit audio/subtitle switching from AniZone streams | ❌ | The tracks are advertised from the master's `#EXT-X-MEDIA` groups; switching is verified only by inspection |
| AniZone availability over time | ❌ | Third-party, unlicensed site; markup and hosting can change without notice |
