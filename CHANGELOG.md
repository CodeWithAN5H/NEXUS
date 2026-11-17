# Changelog

All notable changes to NEXUS are recorded here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning](https://semver.org/).

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
