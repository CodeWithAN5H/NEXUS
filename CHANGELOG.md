# Changelog

All notable changes to NEXUS are recorded here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased] — provider lifecycle and configuration (milestone 2.2c)

User-added declarative providers are now installable, configurable, enablable and
removable from Settings → Sources, with credentials kept in the platform
keystore. No schema migration, application id or signing change, and nothing was
released.

### Added

- `ProviderSecretStore` + `FlutterSecureStorageSecretStore`: `type: secret` fields
  live under `provider.<id>.<key>` in `flutter_secure_storage`; non-secret values
  stay in `provider_entries.config_json`. An unreadable keystore is treated as
  "absent" (setup required) — never a crash and never an error that contains a
  credential.
- `ProviderLifecycleService`: preview → install (revalidate, refuse duplicates and
  built-in ids, write secrets then one transaction, roll back both on failure),
  `updateConfiguration` (replace, keep or clear a secret; revert on failure),
  `remove` (rows, manifest, per-title choices and credentials; library, progress
  and preferences untouched) and `setEnabled`.
- `ManifestConfigValidator`: every documented field type and rule — required,
  `url` (https, no embedded credentials), `choice`, `bool`, `text`, `secret`,
  `pattern`, `maxLength` — shared by the form and the service so they cannot
  disagree.
- Generated configuration form (`ProviderConfigForm`) used for installation and
  later editing alike; a saved secret renders as "Saved securely" and is never
  read back into the UI.
- Settings → Sources: **Add source** (paste → review identity, attribution,
  capabilities and every validation error → configure → install), the installed
  list with enable/disable, configure, remove-with-confirmation, diagnostics for
  an invalid stored manifest, and the built-in test source still labelled
  test-only.
- Registry integration: `UserStreamingProvidersController` adds installed,
  enabled, compatible and configured providers to the existing
  `StreamingProviderRegistry`, reuses unchanged instances and **disposes** every
  instance it drops.
- Android `FLAG_SECURE` through a small `app.nexus/secure_screen` method channel
  while a credential field can be on screen.
- 34 hermetic tests (fake keystore, scripted transport, in-memory database):
  install, refusal and rollback; every config type; secret absence and replacement;
  restart, corrupt and incompatible stored manifests; disable/re-enable; removal
  and disposal; and the Sources, import, configuration and removal widget flows.

### Limitations

- Manifest import is paste-only; fetching from a URL is still later work.
- Windows keystore support is unverified (no Windows host), and `FLAG_SECURE` is
  Android-only, so no screenshot claim is made for other platforms.
- Duplicate JSON keys remain last-wins and DNS rebinding is unchanged.
- Reordering providers, the full derived-state action set and diagnostics export
  remain milestone 2.2d.

## [Unreleased] — declarative provider manifests (milestone 2.2b)

One generic adapter can now interpret a validated JSON manifest, so a supported
source is described as data rather than compiled into the app. No UI, database
schema, application id or signing configuration changed, and nothing was
released.

### Added

- `ManifestValidator` (`lib/integrations/streaming/manifest/manifest_validator.dart`):
  offline stages parse → schema → templates → paths → semantics → compatibility,
  collecting **every** problem as `{code, path, message}` instead of stopping at
  the first. Hard caps of 512 KiB and depth 12 are enforced before decoding.
- `ProviderManifest`: immutable model of a validated document, including the
  network envelope and all six request definitions. A newer `manifestVersion`
  yields `requiresNewerApp`; a contract outside this build yields
  `unsupportedContract`, both without pretending the document is malformed.
- `JsonPath`: the documented read-only selector subset (`$`, `.key`, `["key"]`,
  `[n]`, one trailing `[*]`), with filters, slices, recursion and depth over 8
  refused at validation and at read time.
- `TemplateBinder`: literal placeholder substitution with percent-encoding for
  URL components, raw binding for query values that `Uri` encodes once, and
  header hardening that refuses CR/LF, control characters and values over
  1024 bytes.
- `ManifestHttp`: HTTPS-only egress with the allowlist checked on parsed URIs,
  manual redirects re-checked hop by hop (credentials dropped across origins,
  HTTP downgrade refused), decoded-byte caps enforced while reading, per-request
  timeouts, per-provider pacing, a 4-request gate, one retry for idempotent GETs,
  and the documented status policy (not-found, auth, rate-limit with clamped
  `Retry-After`, 451, 5xx).
- `ManifestStreamingProvider`: implementation of the existing `StreamingProvider`
  contract for search, match, seasons, episodes, resolve, subtitles and audio
  tracks, with the documented coercions (integers, booleans, durations,
  protocols, languages), list caps, `seasonRelative` numbering and media-URL
  validation before anything reaches the player.
- `ManifestProviderFactory`: validates a stored document and returns either a
  provider or a typed failure, so one broken manifest cannot affect another.
- `ProviderRedaction`: query-free URI descriptions, header name-only listings
  and secret scrubbing for the few places the adapter describes a request.
- 80 hermetic tests across `test/providers/manifest_validation_test.dart`,
  `manifest_interpreter_test.dart` and `manifest_adapter_test.dart`, using a
  scripted transport — no test opens a socket or depends on a real provider.
- `ProviderUpstreamError` gained an optional `retryable` flag so a non-idempotent
  4xx is not advertised as retryable. Existing call sites are unchanged.

### Security

- A manifest cannot execute code, read files, reach an undeclared host, exceed its
  declared response/redirect/time budget, or hand an unvalidated URL to the
  player. These are enforced in the adapter and asserted by tests; the honest
  residual risks (DNS rebinding, duplicate JSON keys, unlocked pacing check) are
  listed in [docs/PROVIDER_SECURITY.md](docs/PROVIDER_SECURITY.md) §5.

### Not included

- Installing, configuring, reviewing or removing a manifest in the UI, keystore
  secret storage and re-validation of a stored manifest on load — milestone 2.2c.
- The Sources state actions, diagnostics and import review screen — 2.2d.

---

## [0.2.0-alpha.1] — 2026-11-19 — provider platform foundation

Milestones **2.1a, 2.1b, 2.2a and 2.1c** of
[docs/V0.2_PLAN.md](docs/V0.2_PLAN.md). The application id (`app.nexus`), the
release-signing identity and every existing library, history, progress and
setting row are preserved. Schema v2 is an additive migration from a committed v1
database fixture.

### Added

- `ProviderDescriptor` envelope shared by both provider kinds: stable id, name,
  description, version, origin, contract range, platform set, declared
  configuration fields and attribution (`lib/integrations/providers/`).
- Two independent registries with compatibility evaluated once at registration:
  `StreamingProviderRegistry` and `MetadataProviderRegistry`.
- The three independent axes — `ProviderCompatibility`, `ProviderConfigurationState`,
  `ProviderAvailability` — plus the single derived `ProviderPresentationState`
  (usable, needs setup, rejected config, incompatible, unavailable, disabled).
- Sealed `ProviderFailure` taxonomy (13 subtypes) with stable machine codes and an
  `AppFailure` mapping; `ProviderException` is gone.
- Lifecycle: `probe()` returns a timestamped `ProviderStatusSnapshot`, and
  `dispose()` is mandatory and idempotent on both contracts.
- `MetadataProvider` contract, `AniListMetadataProvider`, and `MediaPage` moved to
  `lib/data/models/` so no file outside `lib/integrations/anilist/` imports
  `AniListClient`.
- `ProviderResolver`: collects **every** matching provider, honours stored
  priority, applies a per-title preference, caps concurrent probes at 4, caches
  matches for a 2-minute TTL, and keeps every failure typed per provider.
- `ProviderStore` and additive schema v2 (`provider_entries`,
  `provider_title_prefs`, `provider_manifests`) with a 1 → 2 migration that
  backfills from `sources.enabled` and preserves every existing row.
- Details screen: selects among multiple matching sources, persists that choice as
  the per-title preference, and collapses source failures into one expandable line.
- `test/providers/` suites and `test/fixtures/nexus_v1.sqlite` (a real v0.1
  database) covering contract honesty, the three axes, resolution, metadata
  independence and the migration.

### Changed

- `SourceManager`/`ProviderRegistry` replaced by `ProviderResolver` and the two
  registries; `ProviderStatus.status` replaced by `probe()`.
- AniList now sits behind `MetadataProvider`; `MetadataRepository` depends on the
  interface and keeps the TTL cache above it.
- Provider enablement is written to both `provider_entries` (authoritative) and the
  legacy `sources.enabled` preference, which stays readable for this release
  (decision D8).
- Version `0.2.0-alpha.1` (versionCode 2); `AppConstants.databaseSchemaVersion` 2.

### Tooling

- `build_runner` pinned to 2.16.2 (build 4.x). The published 2.17.1/5.0.0 pair
  references an `AssetId` extension that `build` 5.0.0 does not contain, so
  generation cannot run with it. Dev tooling only — no runtime dependency changed.

### Verified

- `dart format --set-exit-if-changed` clean, `flutter analyze` 0 issues,
  `flutter test` **144/144 passed** (79 baseline + 65 new), release APK builds with
  `app.nexus` / `0.2.0-alpha.1` / versionCode 2.
- Not verified: runtime behaviour (no device/emulator), Windows build, and the
  migration on a real installed app rather than the committed v1 fixture.

### Not in this release

Declarative manifests (2.2b), provider configuration/secrets (2.2c), the Sources
state surface and diagnostics (2.2d), an authorised content provider (2.3a), real
episodes/subtitles (2.3b). No UI redesign.

## [Unreleased] — provider platform specification and v0.2 plan (documentation only)

No application behaviour changed in these revisions: no source file, database
schema, UI, dependency, signing configuration or workflow was modified, and no
APK was built or published. They finalise the provider platform, freeze the
declarative manifest format and sequence the v0.2 milestone before implementation.

### Added

- `docs/PROVIDERS.md` — normative provider platform specification: two provider
  kinds, the descriptor envelope, capability sets, the three axes (compatibility,
  configuration, availability), lifecycle, the streaming contract, the resolution
  pipeline, the configuration model, the two integration tiers, the error
  taxonomy, the planned schema-v2 tables, security rules and a review checklist.
- `docs/PROVIDER_MANIFEST.md` — normative declarative manifest format (v1):
  install lifecycle, request definitions, the placeholder set, the JSON-path
  subset, type coercion, matching strategies, episode numbering, status and error
  mapping, timeouts and pacing, validation stages with error codes, versioning,
  and the capabilities the format deliberately does not have.
- `docs/schema/provider-manifest.v1.schema.json` — machine-readable JSON Schema
  (draft 2020-12, closed objects) enforcing HTTPS origins, the path and template
  grammars, capability/request pairing and the absence of executable fields.
- `docs/schema/examples/` — two manifests that must validate and four that must be
  rejected (plain-HTTP origin, unbacked capability, executable field, JSONPath
  filter), used as the first schema tests.
- `docs/PROVIDER_TESTS.md` — provider contract test matrix across six layers
  (manifest schema, manifest adapter, built-in adapter, resolution, persistence,
  Sources UI), with an expected outcome per test and traceability to PRD §4.6.
- `docs/PROVIDER_SECURITY.md` — security and reliability review: SSRF and redirect
  handling, origin validation, malformed and oversized responses, timeouts and
  pacing, secret storage, stream-URL validation, failure containment, eight
  accepted residual risks, and a 12-point implementation checklist. States
  explicitly that a manifest is not a sandbox.
- `docs/V0.2_PLAN.md` — 13 small milestones (2.1a → 2.5b) with dependencies, tests,
  completion criteria, release points, a definition of done and eight open owner
  decisions. Roadmap scope unchanged.

### Changed

- `ROADMAP.md` — v0.2 rewritten as a sequenced provider-platform milestone
  (core → user-managed configuration → real content → catalogue depth → platform
  and branding). All previously planned v0.2 items are retained; v0.3–v1.0 are
  unchanged.
- `ARCHITECTURE.md` — §5 rewritten as the provider platform (two kinds, three
  axes, registration, resolution); layer map, composition-root graph and decision
  table updated.
- `PRD.md` — new §4.6 provider-platform requirements (F-S1–F-S11), constraints and
  success criteria aligned; metadata-without-streaming added as an invariant.
- `DATABASE.md` — §6 records the planned additive schema v2 for installed
  providers, per-title source preferences and user-added manifests (not implemented).
- `PROJECT_STATUS.md` — §8 documents the review, the architecture gaps it creates
  and where each is resolved.
- `UI_SPEC.md` — Sources section notes the planned v0.2 provider management
  states; no layout was redesigned or implemented.
- `CONTRIBUTING.md` — provider contribution steps and review checklist aligned with
  the specification.
- `README.md` — provider rows, documentation index and repository layout updated.
- `docs/PROVIDERS.md` — Tier B now points at the normative manifest format; the
  example uses `manifestVersion` + `contract`; §9 records manifest validation and
  re-validation on load; §10 and §12 link the security review and the test matrix.
- `ROADMAP.md` — v0.2 sections mapped to their plan milestones and specification
  documents; three new owner decisions recorded (secrets dependency, schema
  enforcement, release cadence).
- `ARCHITECTURE.md` — planned `integrations/streaming/manifest/` files, the
  manifest's non-sandbox status, and provider test layers added to §10.
- `PRD.md` — F-S12 (validated, versioned manifests) and the privacy consequence of
  direct provider requests.
- `DATABASE.md` — schema v2 rules for validated manifest storage, stored contract
  and format versions, and non-destructive removal.
- `PROJECT_STATUS.md` — §9 records this preparation with what was and was not
  verified; next actions now follow the milestone sequence.
- `CONTRIBUTING.md` — how to add a manifest, and that the format is frozen for v1.
- `UI_SPEC.md` — planned import-review and generated-form behaviour on Sources.

## [0.1.0-alpha] — 2026-11-17

First installable Android build: discovery, details, library, history, settings and a working player with sample media.

### Added

**Application shell**
- Adaptive shell: persistent bottom navigation on Android/small windows, 236 px sidebar on Windows/wide windows; per-tab state preserved via `StatefulShellRoute`.
- Router with six shell branches (Home, Explore, Library, Profile, History, Settings) plus focused routes for details, sources and the player.
- Dark theme built on central tokens; Inter bundled at four weights.

**Design system and components**
- Colour, spacing, radius, motion and typography tokens; brand mark painted in code.
- Components: `NexusImage`, `AnimePoster`, `AnimeRail`, `SectionHeader`, `ContinueWatchingCard`, `EpisodeTile`, `GenreChip`, `MetaChip`, `ScoreChip`, `CountBadge`, `NexusSearchField`, `FilterPanel`, `PrimaryButton`, `SecondaryButton`, `NexusIconButton`, `AsyncValueView`, `LoadingSkeleton`, `EmptyState`, `ErrorState`, `InlineMessage`, `NexusBottomBar`, `NexusSidebar`, `PlayerControls`.

**Discovery**
- Home: featured carousel, Continue Watching, Trending, Recently Updated, Seasonal (computed from device date), Top Rated; pull to refresh.
- Explore: 350 ms debounced search, genre/season/year filters, five sort orders, responsive poster grid, recent searches with clear.
- Anime details: collapsing backdrop, metadata chips, expandable synopsis, Episodes/Details/Related tabs, library status sheet, AniList deep link.

**Library and history**
- Five library statuses with counts, local search, four sort orders, grid and list layouts, progress bars, `EP n` badges.
- History with resume, relative timestamps, per-row delete and clear-all.

**Playback**
- media_kit (libmpv) player behind a `PlaybackSession` abstraction.
- Custom chrome: top bar, centre transport, tabular timeline, volume, CC, audio, speed, quality, next episode, fullscreen.
- Quality switching with position retention; embedded and external subtitle selection; audio track selection honouring the preferred-language setting; 0.5–2× speed.
- Resume from the saved position; progress saved every 5 s, on pause, completion and exit; auto-play next episode.
- Gestures: tap to toggle chrome, double-tap to seek ±10 s (with feedback badge), vertical drag for volume/brightness. Chrome auto-hides after 3.5 s.
- Windows keyboard shortcuts: Space, ←/→, ↑/↓, F, M, Esc.

**Data**
- Drift/SQLite schema v1: `library_entries`, `progress_entries`, `recent_searches`, `preference_entries`.
- Repositories for library, history, search history, preferences and metadata (5-minute TTL cache).
- Typed `AppFailure` hierarchy mapping `DioException` types and HTTP status codes.

**Content providers**
- `StreamingProvider` contract with declared capabilities, availability status, series matching, seasons, episodes and stream resolution.
- `ProviderRegistry` + `SourceManager`; sources screen with per-provider status, capability chips, enable switch and generic playback test.
- Built-in **Playback Test Library** (`SAMPLE` badge) using Apple and Mux public HLS example streams — no anime content is claimed.

**Platform**
- Android release build; INTERNET/WAKE_LOCK permissions; `NEXUS` app label; provisional application id `app.nexus`.
- Gradle release signing scaffold that activates from `android/key.properties` (debug-signed fallback for testers).

**Quality**
- 79 automated tests: formatters, models, provider contract, database/repository behaviour, data preservation across close/reopen, widget tests for poster, chips, states, bottom bar and player controls.
- `flutter analyze`: no issues. `dart format`: clean.

### Known limitations

- No anime streaming source ships with the app; the episode tab explains this instead of inventing data (`ROADMAP.md` → Blocked).
- AniList sign-in, list sync and score updates are not implemented (Profile says so).
- Windows build is not verified — this session ran on headless Linux with no Windows host.
- Release APK is debug-signed until the owner approves a keystore.
- Default Flutter launcher icon; custom icon planned for v0.2.
- Rails have no pagination yet; each rail shows up to 12 titles.
- Android fullscreen uses immersive mode + landscape; Windows fullscreen is window-level only (needs a window plugin for true borderless).
- Brightness control is Android-only; it is skipped silently elsewhere.
- Player speech: no subtitle styling beyond size/colour/background; no subtitle delay control.

[0.1.0-alpha]: https://github.com/CodeWithAN5H/NEXUS/releases/tag/v0.1.0-alpha
