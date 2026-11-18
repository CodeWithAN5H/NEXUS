# NEXUS — Project Status

**Last updated:** 2026-11-18
**Milestone:** v0.1.0-alpha — committed and pushed to `main`; release pending signing secrets
**Latest change:** provider architecture finalised for v0.2 — documentation only, no source, schema, UI or workflow change (§8)
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

**Immediate (v0.2.0-alpha)** — sequenced; details in [ROADMAP.md](ROADMAP.md) and [docs/PROVIDERS.md](docs/PROVIDERS.md).

1. Install the APK on a real Android device; verify launch, rails, search, details, library persistence and playback of the test streams. Record results here.
2. Provider platform core: `MetadataProvider` split, descriptor envelope, three axes, `probe()`/`dispose()`, sealed `ProviderFailure`, collect-all resolution with priority and per-title preference.
3. User-managed provider configuration: install/configure/prioritise/remove, declarative config schema, secrets in the keystore, additive schema v2 (`DATABASE.md` §6).
4. Declarative integration tier for user-added compatible sources, if the owner confirms it is in v0.2 scope (see blocked table).
5. Replace the Playback Test Library with the owner's chosen authorised provider through one of the two integration tiers (blocked — see below).
6. Real episode lists and provider subtitle tracks in the player; AniList `streamingEpisodes` and air dates merged into the Episodes tab.
7. Add pagination to Explore and rails.
8. Verify the Windows build on a Windows host.
9. Ship a custom launcher icon + splash from the brand mark.

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
