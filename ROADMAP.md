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

## v0.2.0-alpha — Provider platform, real content and deeper catalogues

The milestone is sequenced: 2.1 and 2.2 are the platform the rest depends on;
2.3 can land after 2.2 on its own; 2.4 and 2.5 are independent of each other.
The normative provider specification is [docs/PROVIDERS.md](docs/PROVIDERS.md).

Implementation is broken into small, independently testable milestones with
dependencies, completion criteria and owner decisions in
[docs/V0.2_PLAN.md](docs/V0.2_PLAN.md). Those sub-milestones deliver exactly the
items below; they do not add scope.

| Roadmap section | Plan milestones | Specification |
|---|---|---|
| 2.1 Provider platform core | 2.1a contract, 2.1b metadata kind, 2.1c resolution | [PROVIDERS.md](docs/PROVIDERS.md) §2–§5, §8 |
| 2.2 User-managed configuration | 2.2a store + schema v2, 2.2b manifest adapter, 2.2c lifecycle, 2.2d Sources surface | [PROVIDER_MANIFEST.md](docs/PROVIDER_MANIFEST.md), [PROVIDER_SECURITY.md](docs/PROVIDER_SECURITY.md) |
| 2.3 Real content | 2.3a authorised provider, 2.3b episodes and subtitles | [PROVIDERS.md](docs/PROVIDERS.md) §4, §13 |
| 2.4 Catalogue depth | 2.4a Explore pagination, 2.4b AniList episode metadata | [DATABASE.md](DATABASE.md), AniList documents |
| 2.5 Platform and branding | 2.5a Windows verification, 2.5b icon and splash | [UI_SPEC.md](UI_SPEC.md) |
| Verification | every milestone | [PROVIDER_TESTS.md](docs/PROVIDER_TESTS.md) |

**Progress (2026-11-19):** 2.1a, 2.1b, 2.2a and 2.1c are implemented, tested and
built as `v0.2.0-alpha.1`; publication waits on the release keystore. Remaining:
2.2b–2.2d (declarative manifests, lifecycle, Sources surface), 2.3a–2.3b, 2.4a–2.4b,
2.5a–2.5b. See [PROJECT_STATUS.md](PROJECT_STATUS.md) §11 and
[docs/V0.2_PLAN.md](docs/V0.2_PLAN.md).

**2.1 — Provider platform core**

- Split the contract into two kinds: `MetadataProvider` (AniList as the first
  implementation, no longer wired directly into screens) and `StreamingProvider`.
- Separate **compatibility** (can this build run it) from **configuration**
  (has the user supplied what it needs) from **availability** (can it serve a
  request now); derive one presentation state from the three.
- Add a provider descriptor envelope: stable id, contract version, attribution,
  declared capabilities, declared configuration fields, install origin.
- Asynchronous `probe()` returning a timestamped status snapshot instead of a
  synchronous status getter; mandatory `dispose()`.
- Sealed `ProviderFailure` taxonomy (not configured, auth rejected, not found,
  rate limited, geo-restricted, upstream, timeout, parse, unsupported,
  cancelled) mapped to `AppFailure` with actionable copy.
- Resolution collects **all** matching providers instead of stopping at the
  first, honours a user priority order, and records a per-title source
  preference; per-provider failures stay visible without failing the screen.

**2.2 — User-managed provider configuration**

- Extensible provider integration system: built-in adapters registered in one
  bootstrap file, plus an installable integration path for compatible sources.
- User-managed provider configuration: install, configure, enable, prioritise,
  disable and remove providers independently; disabling never discards settings.
- Declarative configuration schema rendered by Settings → Sources (text, URL,
  secret, choice, boolean) with validation; secrets in the platform keystore,
  never in SQLite or logs.
- Persistence for installed providers, their non-secret configuration and their
  order (additive schema migration — see [docs/PROVIDERS.md](docs/PROVIDERS.md) §9).
- Declarative JSON integration format executed by one generic adapter, so a
  compatible catalogue can be added without a new APK (bounded: HTTPS only,
  origin-pinned, JSON-path mapping only, no scripting). Format, limits and
  validation: [docs/PROVIDER_MANIFEST.md](docs/PROVIDER_MANIFEST.md).
- Sources screen shows availability, compatibility and configuration as
  distinct states, with a per-provider diagnostic view.

**2.3 — Real content**

- Register an **authorised** provider implementation (owner decision required — see “Blocked” below), through either integration tier.
- Replace the "no source available" episode state with real episode lists for matched titles.
- Provider-supplied subtitle tracks surfaced in the player menu, with language labels and a clear "this source has none" state.

**2.4 — Catalogue depth**

- Infinite scroll / paging in Explore and rails.
- Episode-level metadata from AniList (`streamingEpisodes`, air dates) for the Details tab, merged with provider episodes by absolute number.

**2.5 — Platform and branding**

- **Windows build verification** on a Windows host (MSVC + `flutter build windows`), including the provider management surface at desktop width.
- Custom launcher icon and Android splash from the brand mark.

**Exit criteria:** metadata still works with every streaming provider removed; a
compatible provider can be added and configured without restructuring the app
(user-added integration where the tier is adopted, otherwise one adapter file);
and real episode lists and subtitles appear for matched titles.

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
| Anime content provider | NEXUS will not ship unauthorised sources | Owner selects an authorised provider (or supplies API access); implementation follows the contract in [docs/PROVIDERS.md](docs/PROVIDERS.md) |
| Installable integration tier | The app ships no provider catalogue, and an unverified format with no real provider to validate it risks becoming an abandonment trap | Owner confirms whether v0.2 includes the declarative (user-added) tier or only the built-in adapter path; both are specified, and the format is now frozen at v1 ([docs/PROVIDER_MANIFEST.md](docs/PROVIDER_MANIFEST.md)). Decision D2 in [docs/V0.2_PLAN.md](docs/V0.2_PLAN.md) §5 |
| Application id | Permanent once distributed | **Resolved:** `app.nexus` confirmed permanent by the owner on 2026-11-17 — no action needed |
| Provider secrets store | A keystore plugin is a new dependency (`flutter_secure_storage`) | Owner approves the dependency before the first provider with credentials (decision D4, [docs/V0.2_PLAN.md](docs/V0.2_PLAN.md) §5) |
| JSON Schema enforcement | A general schema package is a new dependency | Recommendation: an in-repo validator for the v1 subset (decision D3) |
| Release cadence | Testers need a build to report against | Recommendation: pre-release tags `v0.2.0-alpha.N` per user-visible milestone (decision D7) |
| Release keystore | Signing identity must never change | Owner approves keystore creation and stores it securely; `android/key.properties` then enables signed builds |
| GitHub Releases channel | Distribution | Owner authorises repository releases and the update-check source |
| Windows build | Needs a Windows host | Access to Windows with Visual Studio C++ workload |

## Later / evaluated

- Linux desktop (media_kit libs already cover it; shell is platform-agnostic).
- Signed, shareable integration manifests with a review checklist, if v0.2's declarative tier is adopted — the format and its threat model already exist ([docs/PROVIDER_MANIFEST.md](docs/PROVIDER_MANIFEST.md), [docs/PROVIDER_SECURITY.md](docs/PROVIDER_SECURITY.md)); what is missing is signing and distribution policy.
- Additional metadata providers behind the same interface (see `MetadataCapability`).
- Optional sync backend (Supabase free tier or self-hosted) behind an opt-in toggle.
- Offline downloads where a provider permits it.
- MyAnimeList as a second metadata/tracking source.
