# NEXUS — UI Specification

The approved direction is the supplied reference sheet (Android: Home, Explore, Details, Player; Windows: Home, Library, sidebar shell). This document records the tokens and rules that keep the app consistent with it.

## 1. Visual identity

Premium, dark, minimal, cinematic. Anime artwork supplies the colour; the interface stays quiet around it. No glassmorphism, no gradients on text, no Material-dashboard look.

### 1.1 Colour tokens (`lib/core/theme/app_colors.dart`)

| Token | Hex | Use |
|---|---|---|
| `background` | `#101014` | App background, scrims |
| `surface` | `#191920` | Cards, app bars, bottom bar |
| `surfaceSecondary` | `#22222B` | Inputs, chips, nested cards |
| `surfaceElevated` | `#292934` | Menus, dialogs, sheets, hover |
| `accent` | `#9275F5` | Primary actions, active nav, progress |
| `accentHover` | `#A58AFF` | Hover/pressed accent |
| `accentMuted` | `#57449B` | Focus borders, inactive accent |
| `textPrimary` | `#F3F2F8` | Headings, titles |
| `textSecondary` | `#AAA9B8` | Body copy |
| `textMuted` | `#777685` | Captions, inactive icons |
| `border` | `#30303B` | Hairlines |
| `success` | `#63C994` | Airing, ready |
| `warning` | `#E0B15C` | Sample content, limited sources |
| `error` | `#EF6475` | Failures, destructive actions |

No widget may declare a raw `Color(0x…)`. Derived values (`withValues(alpha:)`) are allowed.

### 1.2 Typography

Inter, bundled (400/500/600/700). Scale in `app_typography.dart`:

| Style | Size / weight | Use |
|---|---|---|
| `display` | 30 / 700, −0.6 tracking | Featured title |
| `headline` | 23 / 700, −0.4 | Screen titles |
| `sectionTitle` | 17 / 600, −0.2 | Rail and section headings |
| `cardTitle` | 14 / 600 | Poster titles, list rows |
| `bodyStrong` | 14 / 500 | Values, settings labels |
| `body` | 14 / 400 / 1.5 | Synopsis, descriptions |
| `caption` | 12 / 400 | Meta, timestamps |
| `label` | 12 / 600 | Chips, small labels |
| `button` | 14 / 600 | Buttons |

Text scaling is clamped to 0.9–1.3 in `NexusApp` so large system fonts do not break rails, while still honouring a meaningful increase.

### 1.3 Spacing, radii, motion

- Spacing scale: 4, 8, 12, 16, 24, 32, 48, 64. Page gutter: 20 (phone) / 40 (desktop).
- Radii: 8 (pills/labels), 12 (posters), 16 (cards), 18 (hero/sheets), 24 (sheet top), pill for buttons and chips.
- Motion: 90 / 140 / 220 / 360 ms with `easeOutCubic`. Hover scaling is 1.015 max. Controls fade over 220 ms.
- Shadows are used sparingly: card lift on hover, accent glow behind the primary button and the play button.

## 2. Layout and breakpoints

| Width | Shell | Poster rail | Grid |
|---|---|---|---|
| < 600 | Bottom bar (4 tabs) | 128 px | 2–4 columns |
| 600–899 | Bottom bar (4 tabs) | 128 px | 4–6 columns |
| ≥ 900 | Sidebar (236 px) | 156 px | 5–7 columns |
| ≥ 1280 | Sidebar | 172 px | 6–8 columns |

Content is centred with a 1320 px maximum width. Horizontal rails are full-bleed inside the page gutter.

## 3. Component inventory

All in `lib/core/widgets/`.

| Component | Behaviour |
|---|---|
| `NexusImage` / `AnimePoster` / `AnimeBackdrop` | Disk-cached artwork, tinted placeholder from AniList's dominant colour, neutral fallback glyph on failure. Poster shows score chip, optional progress bar, bookmark toggle on hover/always when saved |
| `AnimeRail`, `SectionHeader` | Horizontal rail with title, "See all →", hover-lift posters; skeleton variant while loading |
| `ContinueWatchingCard` / `ContinueWatchingRail` | 16:9 thumbnail, play overlay, episode pill, progress line, "S % · % · time left" caption, optional remove |
| `EpisodeTile` | 92×52 thumbnail, number + title, duration, resume bar, watched check, play/lock affordance |
| `GenreChip` | Selectable pill; accent fill when selected, elevated surface on hover |
| `MetaChip` / `ScoreChip` / `CountBadge` | Small metadata pills; accent star for ratings; tab counts |
| `NexusSearchField` | Pill input, focus ring in `accentMuted`, inline clear button, search action |
| `FilterPanel` (`showFilterPanel`) | Bottom sheet: sort, genres, season, year; "Clear all"/"Reset"/"Show results" |
| `PrimaryButton` / `SecondaryButton` / `NexusIconButton` | Accent gradient pill, outlined pill, circular icon button with active state and tooltip |
| `AsyncValueView` / `LoadingSkeleton` / `EmptyState` / `ErrorState` / `InlineMessage` | Loading, error with retry (only when retryable), empty states, inline notices |
| `NexusBottomBar` / `NexusSidebar` | Adaptive navigation, accent pill for the active item, hover states on desktop |
| `PlayerControls` | Top bar, centre transport, bottom timeline and menus (see §6) |
| `NexusMark` / `NexusWordmark` | Custom-painted angular "A" mark in the accent gradient |

Every data-dependent surface renders exactly one of: skeleton, error (with retry), empty state, content.

## 4. Screens

### 4.1 Home (Android + Windows)

1. Header: wordmark, search shortcut, avatar (Profile).
2. Featured carousel: banner artwork with bottom scrim, `FEATURED` label, title, score/year/genres, **Watch Now** + **More Info**, page dots.
3. Continue Watching (hidden when empty) with "See all" → History.
4. Trending Anime rail.
5. Recently Updated rail.
6. Seasonal rail, titled with the computed season (`Summer 2026 Anime`).
7. Top Rated rail.
8. Pull to refresh invalidates the metadata cache.

### 4.2 Explore

Title + filter button (badge with active facet count) → search field → horizontally scrolling genre quick-chips → recent searches (when the query is empty) → results heading → responsive poster grid. Debounce 350 ms. Sorting, genre, season and year live in the filter sheet. Empty state offers "Clear filters".

### 4.3 Anime details

Collapsing header with backdrop, scrim and floating back/bookmark buttons. Content: 104×156 poster, title, alternative titles, metadata chips (score, format, year, airing state, popularity), genre chips, actions (Watch Now / Sources, Add to Library or In Library, AniList link), expandable synopsis (4 lines → full), tab row (Episodes · Details · Related).

- **Episodes**: provider episodes with watched/resume state. When no enabled source matches, an explicit empty state explains that NEXUS ships without an anime source and links to Sources. It never fabricates episodes.
- **Details**: format, episode count, length, status, season, studio, popularity, favourites, genres.
- **Related**: rail of AniList relations with relation labels.

### 4.4 Library

Title, grid/list toggle, sort menu; search field; five status tabs with counts; grid (poster + progress + `EP n` badge) or list (thumbnail, title, status, progress bar, score). Empty states are per-status and offer Explore.

### 4.5 History

Newest first list: thumbnail, title, `Episode n · position / duration · %`, relative time, remove; "Clear all". Rows resume playback directly when the source is known.

### 4.6 Profile

Local profile (no account): avatar, statistics (saved, watching, completed, tracked time, episodes marked), links to History/Sources/Settings, AniList connection card marked `v0.4`, version footer.

### 4.7 Settings

Grouped sections: Appearance (grid density, reduce motion), Playback (autoplay, remember position, default quality), Subtitles (size), Audio (preferred language), Sources, AniList (status + honest explanation), About (version, licences, AniList link). Each row states what it actually changes.

### 4.8 Sources

Intro notice that no anime source ships with the app; one card per registered provider with status chip, description, capability chips, attribution, enable switch and **Test playback** (generic: searches the provider catalogue, opens the first episode).

**Planned for v0.2 (specified in [docs/PROVIDERS.md](docs/PROVIDERS.md) §2, §6; not implemented and not yet designed in detail):** the same cards, but the chip reports the derived provider state — *Ready · Test content only · Setup required · Sign-in rejected · Needs a newer NEXUS · Not available on this platform · Temporarily unavailable · Off* — each with the one action that can change it. Cards gain priority ordering, a generated configuration sheet for providers that declare fields, a per-provider diagnostic view, and Remove (with a confirmation that states library and history are untouched). The existing layout, tokens and components are reused; no visual redesign is part of this specification.

### 4.9 Player

Full-window black surface. Artwork fills via `Video` (contain), subtitles styled from the size preference with a translucent background.

- **Top bar**: back, title + `Episode n · episode title`, `SAMPLE` badge for test media, episode list.
- **Centre**: −10 s, play/pause (64 px accent circle), +10 s.
- **Bottom**: notice line for sample media, tabular position / slider / duration, then volume icon + slider, CC, Audio, Speed, Quality, Next (when available), Fullscreen.
- **Gestures**: tap toggles chrome; double-tap left/right seeks ±10 s with a `+10s` badge; double-tap centre toggles playback; vertical drag on the left adjusts brightness (Android), on the right adjusts volume.
- **Auto-hide**: 3.5 s while playing; any interaction restores it.
- **Menus**: bottom sheets with check marks — quality (provider variants), subtitles (embedded + external + Off), audio tracks, speed (0.5–2×), episodes.
- **Keyboard (Windows)**: Space play/pause, ←/→ seek 10 s, ↑/↓ volume, F fullscreen, M mute, Esc leaves fullscreen or the player.
- **Resume**: position restored when the duration is known; progress saved every 5 s, on pause, completion and exit. Auto-play opens the next episode.

## 5. State and feedback rules

- Loading: skeletons shaped like the content, never a bare spinner in a page body.
- Errors: title from the failure type, one-sentence explanation, retry only when it can succeed.
- Empty: explains what would appear and offers the next action.
- Destructive actions confirm through labels ("Remove from library" in error colour) rather than modal dialogs.
- Transient confirmations use the themed floating snackbar.

## 6. Documented deviations from the reference sheet

| Reference | Shipped | Reason |
|---|---|---|
| Windows sidebar has Home/Explore/Library/History/Settings and no Profile entry | Same five entries; the wordmark opens Profile | Keeps the approved five-entry sidebar while keeping the profile reachable |
| Details shows a full backdrop behind the poster | Backdrop + poster in the content column, floating back/bookmark | Keeps content legible at phone widths and avoids a fixed-height clip |
| Player shows a settings gear | Explicit CC / Audio / Speed / Quality / Fullscreen buttons | Fewer taps, each control one tap away, matching the reference's bottom bar |
| Library tabs show counts only as numbers | Number badges inside the pill | Clearer active state with the accent fill |
| AniList "Connected" state in Profile | `v0.4` badge + explanation | Sign-in is not implemented; the reference must not be faked |
| Sample content in rails | Rails are pure AniList metadata | No anime stream source exists yet |

Any further deviation must be recorded here before implementation.
