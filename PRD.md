# NEXUS — Product Requirements

## 1. Vision

A premium anime application that feels native on Android and genuinely desktop-class on Windows: fast discovery, a real player, a library that never loses data, and an architecture that can grow to a wider audience without a rewrite.

Reference for tone and density: [reanime.cz](https://reanime.cz/home) (simplicity and functionality), with NEXUS's own approved visual direction.

## 2. Users

| User | Need |
|---|---|
| Primary: the owner | One place to track what they watch, with playback that actually works |
| Secondary: friends on Android | Install an APK, browse, save titles, watch, keep progress |
| Future: public | Stability, privacy, no forced accounts, updates that preserve data |

## 3. Scope of v1.0

### In scope

1. Anime discovery from AniList metadata: trending, seasonal, recently updated, top rated, search with genre/season/year filters.
2. Anime details: artwork, synopsis, genres, studios, relations.
3. Local library with five statuses, search, sorting, grid/list views, per-title progress.
4. Playback through pluggable, authorised content providers, with quality/audio/subtitle selection, resume and auto-next.
5. Local-first data: library, history, positions and settings persisted and migrated safely.
6. Adaptive UI: bottom navigation on Android, sidebar on Windows, keyboard shortcuts in the player.
7. AniList account: sign-in, list sync, progress and score updates.
8. Release engineering: versioned APKs from GitHub Releases, stable application id and signing key, in-app update check.

### Explicitly out of scope

- Scraping or aggregating unauthorised streaming sources, DRM circumvention, or shipping third-party stream URLs.
- Social features, comments, watch parties.
- Offline downloads (evaluate after v1.0).
- iOS, web, TV builds.
- A paid backend. Any sync must remain free or self-hostable.

## 4. Functional requirements

### 4.1 Discovery

| ID | Requirement | Acceptance |
|---|---|---|
| F-D1 | Home shows featured, trending, recently updated, seasonal and top-rated rails | Rails load from AniList; each rail has skeleton, error+retry and empty states |
| F-D2 | Seasonal rail matches the device date | Title and query use the computed current season |
| F-D3 | Continue Watching reflects real positions | Populated from SQLite; hidden when empty; removing hides the card |
| F-D4 | Search debounces and records history | One request per typing pause; history trimmed to 20, de-duplicated |
| F-D5 | Filters combine | Genre + season + year + sort are applied together server-side |

### 4.2 Details and library

| ID | Requirement | Acceptance |
|---|---|---|
| F-L1 | Details shows metadata, synopsis, relations | All fields degrade gracefully when missing |
| F-L2 | Save/toggle/status change works without account | Bookmark flips instantly via Drift streams; status sheet persists |
| F-L3 | Library filters, sorts and searches | Five tabs with counts; search is local and instant |
| F-L4 | Watching the final episode marks the title completed | `markEpisodeWatched` flips status at the last episode |

### 4.3 Playback

| ID | Requirement | Acceptance |
|---|---|---|
| F-P1 | Play streams through the provider abstraction | Player resolves variants from `StreamingProvider`, never a hardcoded URL |
| F-P2 | Quality/audio/subtitle selection | Menus list actual tracks/variants; selection applies immediately |
| F-P3 | Resume and progress | Position restored; saved every 5 s, on pause and exit |
| F-P4 | Auto-play next | Triggered on completion when enabled and another episode exists |
| F-P5 | Chrome auto-hides and gestures work | Tap toggles, double-tap seeks, vertical drag adjusts volume/brightness |
| F-P6 | Sample content is unmistakable | `SAMPLE` badge and notice when the stream comes from a limited provider |

### 4.4 Data

| ID | Requirement | Acceptance |
|---|---|---|
| F-DB1 | Versioned schema with migrations | `schemaVersion` constant, additive `onUpgrade`, documented policy |
| F-DB2 | Data survives updates | Reopening the database file preserves library, progress and settings (tested) |

### 4.5 Accounts and sync (v0.4+)

| ID | Requirement | Acceptance |
|---|---|---|
| F-A1 | AniList OAuth sign-in | Token stored in secure storage, never in source or logs |
| F-A2 | Push/pull progress and scores | Conflicts resolved by newest timestamp; local data never lost |
| F-A3 | Optional only | The app remains fully usable signed out |

## 5. Non-functional requirements

- **Performance:** cold start to first rail under 3 s on a mid-range device; no frame drops while scrolling rails (images cached and sized); position updates must not rebuild whole screens.
- **Reliability:** a failed metadata request never crashes a screen; a failed migration never deletes data.
- **Privacy:** no analytics, no account requirement, no data leaves the device except AniList queries and the chosen provider's stream requests.
- **Accessibility:** semantic labels on navigation, `Tooltip`s on icon buttons, text scaling clamped 0.9–1.3, minimum 40 px touch targets, contrast checked against the dark palette.
- **Maintainability:** analyzer-clean, formatted, tested; providers and metadata sources replaceable without touching screens.

## 6. Constraints

1. Android first; Windows must be a real desktop experience, not a stretched phone layout.
2. No paid dependencies or paid backend.
3. Only authorised content providers.
4. No fake capability: if it is not implemented, the UI says so.
5. The application id and signing key are permanent once distribution starts.

## 7. Success criteria

- v0.1: an installable APK where discovery, details and the library work and data persists. **Met.**
- v0.2–v0.3: playback of authorised content, resume, subtitles. **Architecture complete, awaiting an authorised provider.**
- v1.0: stable Android + Windows releases, AniList sync, documented release process, no known data-loss defect.
