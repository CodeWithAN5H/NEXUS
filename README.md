# NEXUS

**Stream. Discover. Enjoy.**

A cross-platform anime discovery and streaming app built with Flutter — dark, cinematic and fast, with Android as the primary target and Windows as a first-class desktop experience.

Current release line: **v0.1.0-alpha** (first installable Android build).

---

## What works today

Everything listed here runs in the app and is backed by real code and local storage — not mock data presented as if it were finished.

| Area | Status | Notes |
|---|---|---|
| Design system | ✅ | Central tokens (colour, spacing, radii, motion), Inter bundled, dark theme only |
| Adaptive navigation | ✅ | Bottom bar on Android, persistent sidebar on Windows/wide windows |
| Home | ✅ | Featured carousel, Continue Watching, Trending, Recently Updated, Seasonal, Top Rated |
| Explore | ✅ | Debounced search, genre/season/year filters, sort, responsive poster grid, recent searches |
| Anime details | ✅ | Cinematic backdrop, metadata, genres, expandable synopsis, episodes, details and related tabs |
| Library | ✅ | Five statuses, search, sort, grid/list layouts, progress bars, counts |
| Watch history | ✅ | Per-episode positions, resume, delete, clear all |
| Local database | ✅ | SQLite via Drift, versioned schema, data preserved across restarts (tested) |
| Metadata | ✅ | AniList GraphQL (trending, seasonal, search, filters, details, relations) |
| Provider architecture | ✅ design · 🟡 implementation | Contract, registry and source manager ship today. The provider platform (user-installed sources, configuration, priority, typed failures) and the declarative manifest format are specified and frozen for v0.2 — [docs/PROVIDERS.md](docs/PROVIDERS.md), [docs/PROVIDER_MANIFEST.md](docs/PROVIDER_MANIFEST.md) — with a test matrix and a security review |
| Video player | ✅ | media_kit, custom controls, quality/audio/subtitle menus, speed, resume, auto-next, keyboard shortcuts |
| Playback test library | ✅ | Two public test streams (Apple, Mux) to verify playback end to end |
| Settings | ✅ | Appearance, playback, subtitles, audio, sources, AniList status, about/licences |
| Windows build | ⚠️ | Code is platform-ready but **not built or run** — this environment is headless Linux |
| AniList sign-in / sync | ❌ | Planned for v0.4 (see [ROADMAP.md](ROADMAP.md)) |

### What deliberately does not exist yet

- **No anime video source.** NEXUS ships with the complete provider interface and a clearly labelled *playback test library* made of Apple/Mux public HLS example streams. The project does not implement unauthorised streaming aggregators. Any real source must be authorised and registered through the provider interface — no screen needs to change. The platform that lets users install and configure their own compatible sources is specified in [docs/PROVIDERS.md](docs/PROVIDERS.md).
- **No AniList account features.** Metadata is already served by AniList, but signing in, list sync and score updates are not implemented. The Profile screen states this rather than showing a fake "Connected" state.
- **No cloud sync.** Everything is local. The architecture leaves room for it (see [ARCHITECTURE.md](ARCHITECTURE.md)).

Screenshots will be added once a device or emulator is available to capture them; the build has only been produced headlessly so far.

---

## Technology

| Concern | Choice | Version | Why |
|---|---|---|---|
| Framework | Flutter / Dart | 3.50.0 / 3.14.0 | One codebase for Android + Windows |
| State | `flutter_riverpod` | 3.5.0 | Testable, no `BuildContext` coupling, providers are the composition root |
| Routing | `go_router` | 18.1.4 | Declarative routes + `StatefulShellRoute` keeps per-tab state |
| Networking | `dio` | 5.11.1 | Interceptors, typed errors, timeouts |
| Local database | `drift` + `drift_flutter` | 2.35.4 / 0.3.1 | Type-safe SQL, versioned migrations, SQLite on mobile and desktop |
| Metadata | AniList GraphQL | — | Free, rich, no key required for read access |
| Playback | `media_kit` (+ `media_kit_video`) | 1.2.6 / 2.0.1 | libmpv-backed: HLS, multiple audio/subtitle tracks, hardware acceleration, Android + Windows |
| Images | `cached_network_image` | 4.0.7 | Disk cache, placeholders, graceful failure |
| UI | `material_ui` | 1.11.1 | Flutter 3.50 moved Material out of `flutter/material.dart` |

**Not used on purpose:** `google_fonts` (Inter is bundled, so the app is offline-safe and tests are deterministic), `sqflite` (no Windows support), freezed/json codegen (hand-written, defensive parsing keeps the build fast and the model readable).

---

## Platform support

| Platform | State |
|---|---|
| Android | Primary target. Release APK builds; installs on API 24+. Not yet run on a physical device from this environment. |
| Windows | Code paths implemented (sidebar shell, keyboard shortcuts, media_kit Windows libs). **Build not verified** — requires a Windows host with Visual Studio C++ tools. |
| Linux | Not in scope for v0.1. `media_kit_libs_video` already covers it; the desktop shell is platform-agnostic. |

---

## Getting started

### Prerequisites

- Flutter **3.50.0** stable (Dart 3.14.0)
- JDK **17** for Android builds
- Android SDK with platform **36** and build-tools **36.0.0**

```bash
flutter --version
flutter doctor -v
```

### Run

```bash
flutter pub get
dart run build_runner build     # generates lib/data/database/nexus_database.g.dart
flutter run                     # add -d windows on a Windows host
```

### Verify

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze                 # must report: No issues found!
flutter test                    # 79 tests
```

### Build an APK locally (unsigned preview)

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

Without `android/key.properties` this falls back to debug signing. That output is for local testing only and is never published.

### Getting a release APK

Installable builds come from **GitHub Releases**: open [Releases](https://github.com/CodeWithAN5H/NEXUS/releases), download `NEXUS-<version>-universal.apk`, and install over the previous version (do not uninstall — that deletes your library and history). Each release carries a `SHA256SUMS.txt`.

Releases are built and signed by `.github/workflows/release.yml` from tag `v<version>`; the signing keystore lives only in repository secrets and is never committed. Setup, verification and update rules: [docs/RELEASE.md](docs/RELEASE.md).

---

## Project layout

```
lib/
  app/            app root, router, adaptive shell, navigation model
  core/           design tokens, errors, utilities, reusable widgets
  data/           models, Drift database, repositories, Riverpod providers
  integrations/   AniList client, streaming provider contracts, playback session
  features/       home, explore, anime_details, library, history, profile,
                  settings, player
docs/             release policy, provider platform + manifest specification,
                  JSON Schema and examples, test matrix, security review, v0.2 plan
test/             unit, database, provider and widget tests
```

---

## Contributing and releases

Workflow for every milestone: analysis + tests → review → commit and push → tag → CI builds, signs and publishes the APK → documentation and status updated. `main` in this repository is the source of truth. See [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/RELEASE.md](docs/RELEASE.md).

## Documentation

| Document | Purpose |
|---|---|
| [PRD.md](PRD.md) | Product requirements and scope |
| [UI_SPEC.md](UI_SPEC.md) | Approved visual direction, tokens, component inventory |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layers, decisions, data flow, provider/player abstractions |
| [docs/PROVIDERS.md](docs/PROVIDERS.md) | Provider platform: kinds, capabilities, configuration, integration tiers, errors |
| [docs/PROVIDER_MANIFEST.md](docs/PROVIDER_MANIFEST.md) | Declarative manifest format (v1) used by user-added sources |
| [docs/schema/provider-manifest.v1.schema.json](docs/schema/provider-manifest.v1.schema.json) | JSON Schema for that format, with valid and invalid examples beside it |
| [docs/PROVIDER_TESTS.md](docs/PROVIDER_TESTS.md) | Contract test matrix: manifest schema, adapters, resolution, persistence, Sources UI |
| [docs/PROVIDER_SECURITY.md](docs/PROVIDER_SECURITY.md) | Provider threat model, protections and accepted residual risks |
| [docs/V0.2_PLAN.md](docs/V0.2_PLAN.md) | v0.2 milestones, dependencies, completion criteria and open decisions |
| [DATABASE.md](DATABASE.md) | Schema, migration policy, data-preservation guarantees |
| [ROADMAP.md](ROADMAP.md) | Milestones from v0.1 to v1.0 |
| [CHANGELOG.md](CHANGELOG.md) | What changed in each version |
| [PROJECT_STATUS.md](PROJECT_STATUS.md) | Current state, verified vs unverified, known issues |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Workflow, conventions, review checklist |
| [docs/RELEASE.md](docs/RELEASE.md) | APK signing, versioning and distribution policy |

---

## Content and legal position

NEXUS is a client. Anime metadata and artwork come from the [AniList](https://anilist.co) public GraphQL API. The only playable media shipped with the app are public example streams published by Apple and Mux for HLS testing, clearly labelled `SAMPLE` in the player. The project contains no scrapers for protected services, no DRM circumvention and no hardcoded third-party stream URLs.

Adding a real source means implementing `StreamingProvider` against a provider you are authorised to use, or installing a compatible declarative integration. Doing so requires no changes to the home, details or player screens; the rules are in [docs/PROVIDERS.md](docs/PROVIDERS.md), the manifest format in [docs/PROVIDER_MANIFEST.md](docs/PROVIDER_MANIFEST.md), and its limits in [docs/PROVIDER_SECURITY.md](docs/PROVIDER_SECURITY.md).

## Credits

Metadata © AniList and its contributors. HLS example streams © Apple Inc. and Mux, Inc. Font: Inter (SIL Open Font License 1.1).
