# NEXUS — Architecture

## 1. Principles

1. **The UI never knows where data comes from.** Screens read Riverpod providers; providers read repositories; repositories talk to AniList, SQLite or a content provider.
2. **Metadata and video are different concerns.** AniList supplies metadata only. Playback comes from a `StreamingProvider` implementation. Conflating them is the usual reason anime apps become unmaintainable. They are therefore separate provider kinds with separate contracts and registries ([docs/PROVIDERS.md](docs/PROVIDERS.md)).
3. **Local data is user data.** The database is versioned, migrated and never cleared to make an update work.
4. **Every screen has four states.** Loading, error (retryable where possible), empty, data — implemented once in `AsyncValueView`, not per screen.
5. **No fake functionality.** Unsupported capabilities are declared as unsupported and surfaced in the UI.

## 2. Layers

```
lib/
├── app/                  App root, router, adaptive shell, navigation model
├── core/                 Cross-cutting: theme tokens, errors, utilities, widgets
│   ├── constants/        App-wide constants
│   ├── errors/           AppFailure hierarchy (user-facing failures)
│   ├── theme/            Colours, spacing, radii, motion, typography, ThemeData
│   ├── utils/            Formatters, feedback, deterministic ids
│   └── widgets/          Reusable components (poster, rail, states, buttons …)
├── data/                 Data layer
│   ├── models/           Domain models (Anime, LibraryEntry, WatchProgress …)
│   ├── database/         Drift schema + generated code
│   ├── repositories/     Library, history, search history, preferences, metadata
│   └── providers/        Riverpod composition root and screen providers
├── integrations/         External systems
│   ├── anilist/          GraphQL documents + typed client
│   ├── metadata/         MetadataProvider contract (AniList adapter lives here in v0.2)
│   ├── playback/         PlaybackSession (only place media_kit is imported)
│   └── streaming/        StreamingProvider contract, descriptors, sample provider,
│                         registry, resolver, declarative integration adapter
└── features/             One folder per screen/flow
    ├── home/ explore/ anime_details/ library/ history/ profile/ settings/ player/
```

**Dependency rule:** `features` → `data`/`core` → `integrations`. Nothing in `integrations` imports a feature, and no widget imports Drift or Dio.

## 3. State management

Riverpod 3 without code generation. The composition root is `lib/data/providers/app_providers.dart`:

```
databaseProvider ─┬─ libraryRepositoryProvider ──┐
                  ├─ historyRepositoryProvider ──┤
                  ├─ searchHistoryRepository ────┤
                  └─ preferencesRepository ──────┤
dioProvider ── aniListClientProvider ── metadataRepositoryProvider
                                              │
settingsProvider (AsyncNotifier) ── appSettingsProvider ── sourceManagerProvider
providerRegistryProvider ─────────────────────────────────┘
providerStoreProvider (v0.2, schema v2) ── installed providers, config, order
```

- `settingsProvider` is an `AsyncNotifier<AppSettings>`: it loads once, then writes through to SQLite on every change.
- `appSettingsProvider` flattens the `AsyncValue` to a plain `AppSettings` (defaults while loading) so widgets stay simple.
- Screen providers live in `content_providers.dart` (rails, explore, library, details, sources).
- Provider state (installed set, non-secret configuration, priority) joins the composition root as its own store in v0.2; `SourceManager` then reads that store instead of `AppSettings.enabledProviderIds`.
- Streams from Drift power reactive UI: saving a title updates the poster bookmark and library counts without a refresh.

There is no auto-dispose. Rails are cached for the session; `MetadataRepository.invalidate()` plus provider invalidation drives pull-to-refresh.

## 4. Metadata flow (AniList)

```
AnimeDetailsScreen
   └─ animeDetailsProvider(id)         FutureProvider.family
        └─ MetadataRepository.details  (5-minute TTL memo cache)
             └─ AniListClient.details  (Dio POST, GraphQL document)
                  └─ Anime.fromAniList (defensive mapping)
```

Design notes:

- GraphQL documents are constants in `anilist_queries.dart`; only fields the UI renders are requested.
- `Anime.fromAniList` treats the payload as untrusted: every read is null-tolerant, unknown enums degrade to `null`.
- Errors are translated to `AppFailure` subtypes (`RateLimitFailure`, `NetworkFailure`, `ParseFailure`, …) so the UI can offer the right retry.
- AniList is rate limited and public: identical rail requests inside the TTL never leave the device.

## 5. Provider platform

Normative specification: [docs/PROVIDERS.md](docs/PROVIDERS.md). This section is
the architectural summary; where the two disagree, that document wins.

### 5.1 Two kinds, two contracts

| Kind | Contract | Registry | Owns |
|---|---|---|---|
| Metadata | `MetadataProvider` (`trending`, `seasonal`, `search`, `details`, `relations`, `streamingEpisodes`, …) | `MetadataRegistry` | Titles, artwork, air dates |
| Streaming | `StreamingProvider` (`search`, `match`, `seasons`, `episodes`, `resolve`) | `ProviderRegistry` | Episode lists, variants, subtitles |

v0.1 has the streaming contract only, and `MetadataRepository` depends on the
concrete `AniListClient`. v0.2 moves AniList behind `MetadataProvider` so a
second catalogue is an addition rather than an edit to every screen. Metadata
stays functional with zero streaming providers installed — that invariant is
worth testing explicitly.

### 5.2 The streaming contract

`lib/integrations/streaming/streaming_provider.dart` defines it today:

```dart
abstract class StreamingProvider {
  String get id, name, description, attribution;
  Set<ProviderCapability> get capabilities;   // declared, never guessed
  ProviderStatus get status;                  // ready | limited | needsConfiguration | unavailable
  Future<List<ProviderSeries>> search(String query);
  Future<ProviderSeries?> match(Anime anime); // null when the provider has no entry
  Future<List<ProviderSeason>> seasons(ProviderSeries series);
  Future<List<ProviderEpisode>> episodes(ProviderSeries series, {String? seasonId});
  Future<EpisodeStream> resolve(ProviderSeries series, ProviderEpisode episode);
}
```

`EpisodeStream` carries variants (with heights for quality selection), subtitles,
audio tracks, required HTTP headers, and an `isSample` flag.
`EpisodeStream.bestVariant()` never selects a quality above the user's preference.

v0.2 extends the envelope with a provider descriptor (stable id, contract
version, kind, declared configuration fields, install origin) and adds `probe()`
and `dispose()`. See [docs/PROVIDERS.md](docs/PROVIDERS.md) §3–§4 for the exact
shape and §12 for the delta from today's code.

### 5.3 Three axes, one derived state

```
compatibility  (can this build run it)      → compatible | requiresNewerApp |
                                              unsupportedContract | unsupportedPlatform
configuration  (has the user set it up)     → notRequired | incomplete |
                                              configured | rejected
availability   (can it serve right now)     → ready | limited | degraded | unavailable
                          ↓
                 presentation state for Settings → Sources
        Usable · Needs setup · Rejected config · Incompatible · Unavailable · Disabled
```

Collapsing these into a single enum is the mistake this split exists to prevent:
"needs a newer app", "enter your API key" and "the source is down" have
different owners and different UI treatments, and only one of them is retryable.

### 5.4 Registration and user composition

`ProviderRegistry` (built in `provider_registry_bootstrap.dart`) is the only
place built-in providers are registered. `SourceManager` applies the user's
enabled set and probes providers in order, collecting per-provider failures for
the UI.

**Adding a built-in provider:**

1. Implement `StreamingProvider` and its descriptor.
2. Declare honest `capabilities`, `status` and configuration fields.
3. Add it to the list in `provider_registry_bootstrap.dart`.

No screen, route, repository or schema changes. The sample provider exists to
prove this: it advertises *limited* availability and `match()` always returns
`null`, so a real anime is never shown sample video.

**User-added providers** are declarative JSON manifests executed by one generic
adapter, sandboxed to HTTPS, origin-pinned hosts and JSON-path mapping with no
scripting. Flutter release builds are AOT-compiled and cannot load Dart code at
runtime; a manifest adapter is the only mechanism that adds providers without an
APK rebuild and without becoming a WebView scraper, which this project rejects.
The resolver cannot distinguish the two tiers.

### 5.5 Resolution

```
Details → sourceResolutionProvider(animeId) → ProviderResolver.lookup(anime)
   candidates = installed ∩ enabled ∩ compatible ∩ configured ∩ seriesMatching
   order      = user priority (default install order)
   probe      = concurrent, capped, per-provider timeout
   result     = every match + Map<providerId, ProviderFailure> + per-title preference
```

v0.1 returns the first match. v0.2 keeps all matches and a user preference per
title, because "the first provider that knows this show" is not "the provider the
user wants". A failing provider degrades its own entry; it never fails the screen,
and the Episodes tab lists source errors in a collapsible line.

Provider state that must survive a restart: installed providers, non-secret
configuration, priority order and per-title preference. Secrets live in the
platform keystore. Saved `provider_id`/`series_id` hints in `progress_entries`
stay hints — if that provider is gone, the title is re-resolved instead of
failing.

## 6. Playback abstraction

`lib/integrations/playback/playback_session.dart` is the only file importing `media_kit`. It exposes:

- `load(EpisodeStream, preferredHeight, startAt)` → picks a variant, opens the media, applies a resume position when a duration is known.
- Transport: `play`, `pause`, `playOrPause`, `seek`, `seekBy`, `setVolume`, `setRate`.
- Track selection: `selectSubtitle`, `addExternalSubtitle`, `selectAudio`, `audioForLanguage`.
- Typed streams for position, duration, playing, buffering, completion, tracks and player errors.

Swapping engines (a native ExoPlayer/Media3 implementation, for example) means reimplementing this one class. `PlayerScreen` and `PlayerControls` only speak in these terms.

`PlayerScreen` owns session state as `ValueNotifier`s (position, duration, playing, buffering, volume) so high-frequency position updates repaint only the controls, not the whole route. Structural changes (loading, error, variant, tracks) use `setState`.

Progress is written to SQLite every 5 seconds while playing, on pause, on completion, and when the route is popped; playback never blocks on persistence.

## 7. Navigation

`go_router` with a single `StatefulShellRoute.indexedStack` containing six branches: Home, Explore, Library, Profile, History, Settings.

- Android shows four tabs; History and Settings keep the Profile tab highlighted (matching the approved reference where Settings shows the bottom bar).
- Windows shows five sidebar entries and no Profile entry — the avatar in the logo area opens it.
- Details, Sources and the player are top-level routes pushed above the shell: the player is full-window by design, and details is a focused view on both platforms.

Branch indices are fixed and mirrored in `navigation_destinations.dart`; the router asserts the same order.

## 8. Error handling

`AppFailure` is a sealed hierarchy: `NetworkFailure`, `ServerFailure`, `NotFoundFailure`, `RateLimitFailure`, `ParseFailure`, `UnsupportedFailure`, `StorageFailure`, `CancelledFailure`, `UnexpectedFailure`. Repositories convert low-level exceptions once; `AppFailure.from` also maps `DioException` types and HTTP status codes. The UI renders `failure.title`, `failure.message` and a retry only when `failure.isRetryable`.

## 9. Decisions and trade-offs

| Decision | Alternative | Why |
|---|---|---|
| Drift + DriftFlutter | sqflite, Hive, Isar | sqflite has no Windows support; Drift gives migrations, type safety and SQLite on both targets. `sqlite3_flutter_libs` is EOL, `drift_flutter` bundles natives. |
| Riverpod without codegen | riverpod_generator | 2-vCPU build environment; codegen would add ~2 minutes per build for little gain at this size. Rules are followed manually. |
| Hand-written JSON mapping | freezed + json_serializable | External payloads need defensive parsing, not generated casts; avoids a second codegen pipeline. |
| Bundled Inter (4 weights, 66 KB each) | google_fonts | No runtime font fetch, deterministic widget tests, works offline. |
| Custom player controls | media_kit's Material controls | The approved design needs a specific chrome; the built-in controls are Material-styled. |
| `material_ui` package | `package:flutter/material.dart` | Flutter 3.50 deprecated the latter in favour of the extracted package (the template itself imports it). |
| Providers as declared descriptors + capability sets | A closed enum of known sources | The app must not be limited to a hardcoded list; descriptors let built-in and user-installed providers share one resolver ([docs/PROVIDERS.md](docs/PROVIDERS.md)). |
| Declarative JSON integrations for user-added sources | Runtime code loading, or a WebView wrapper | Flutter AOT cannot load Dart at runtime; a manifest adapter is sandboxable, reviewable and does not become a scraper. |
| Three separate provider axes | One `status` enum | Compatibility, configuration and availability have different fixes; merging them produces dead-end retry buttons. |
| Dark theme only | light/dark switch | The approved direction is dark; a half-baked light theme would violate the design brief. |

## 10. Testing

| Layer | File | What it proves |
|---|---|---|
| Formatters / ids | `test/formatters_test.dart` | Display formatting, deterministic local ids |
| Models | `test/models_test.dart` | AniList mapping, fallbacks, filters, settings round-trip |
| Providers | `test/streaming_provider_test.dart` | Contract honesty, variant selection, source manager behaviour |
| Database | `test/database_test.dart` | Schema, repository behaviour, data preservation across re-open |
| Widgets | `test/widgets_test.dart` | Poster, chips, states, bottom bar, player controls |

Not covered yet: full-screen golden tests, real network calls, device/emulator instrumentation. See [PROJECT_STATUS.md](PROJECT_STATUS.md).
