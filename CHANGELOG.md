# Changelog

All notable changes to NEXUS are recorded here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning](https://semver.org/).

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
