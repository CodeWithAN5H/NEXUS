# NEXUS — Roadmap

Milestones are ordered by value, not dates. Each one ends with a verified build and updated documentation.

## v0.1.0-alpha — Foundation and discovery ✅ shipped

- Design system, adaptive shell, routing.
- Home, Explore, Anime details, Library, History, Profile, Settings, Sources.
- AniList metadata with TTL cache and defensive parsing.
- Local SQLite (Drift) with versioned schema and data-preservation test.
- Provider contract, registry, source manager, capability reporting.
- media_kit player: custom controls, resume, quality/audio/subtitle menus, auto-next, gestures, keyboard shortcuts.
- Clearly labelled playback test library (Apple/Mux public HLS streams).
- 79 automated tests, analyzer clean, release APK.

**Exit criteria met:** installable APK where discovery, details and library work with persistent data.

## v0.2.0-alpha — Real content and deeper catalogues

- Register an **authorised** provider implementation (owner decision required — see “Blocked” below).
- Replace the "no source available" episode state with real episode lists for matched titles.
- Infinite scroll / paging in Explore and rails.
- Episode-level metadata from AniList (`streamingEpisodes`, air dates) for the Details tab.
- External subtitle selection surfaced in the player menu from provider tracks.
- **Windows build verification** on a Windows host (MSVC + `flutter build windows`).
- Custom launcher icon and Android splash from the brand mark.

## v0.3.0-alpha — Playback hardening

- Buffering and rebuffer reporting; automatic quality downgrade on slow links.
- Remember per-title quality and audio choice.
- Picture-in-picture on Android; proper borderless fullscreen on Windows (window plugin).
- Restore system brightness on player exit; brightness slider overlay feedback.
- Player error taxonomy with actionable messages (expired token, geo-block, offline).
- Instrumented playback test on a physical Android device; document results.

## v0.4.0-alpha — AniList account

- OAuth implicit-grant sign-in via `flutter_secure_storage`.
- Pull user lists; merge with local library without losing either side.
- Push progress and scores; conflict rule: newest `updatedAt` wins.
- Sync status on Profile; manual "sync now"; offline queue.

## v0.5.0-beta — Polish and friend testing

- Performance pass on long lists and image memory.
- Accessibility audit (semantics, focus order, contrast, 200 % text).
- Optional lightweight crash reporting (self-hostable or off by default).
- In-app update checker reading GitHub Releases.
- Feedback round with testers; fix list published in the changelog.

## v1.0.0 — Stable

- Stable Android release (signed with the permanent key, in-place updates verified).
- Windows release with an installer.
- Complete documentation set, including a tested upgrade path from every earlier release.
- No known data-loss defect; migrations exercised on real upgrade paths.

## Blocked / needs an owner decision

| Item | Why it blocks | What is needed |
|---|---|---|
| Anime content provider | NEXUS will not ship unauthorised sources | Owner selects an authorised provider (or supplies API access); implementation follows the existing contract |
| Application id | Permanent once distributed | Confirm `app.nexus` before the first published APK |
| Release keystore | Signing identity must never change | Owner approves keystore creation and stores it securely; `android/key.properties` then enables signed builds |
| GitHub Releases channel | Distribution | Owner authorises repository releases and the update-check source |
| Windows build | Needs a Windows host | Access to Windows with Visual Studio C++ workload |

## Later / evaluated

- Linux desktop (media_kit libs already cover it; shell is platform-agnostic).
- Optional sync backend (Supabase free tier or self-hosted) behind an opt-in toggle.
- Offline downloads where a provider permits it.
- MyAnimeList as a second metadata/tracking source.
