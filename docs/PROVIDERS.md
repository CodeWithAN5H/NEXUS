# NEXUS — Provider Platform

This file is the source of truth for how content providers are described,
installed, configured, resolved and removed. [ARCHITECTURE.md](../ARCHITECTURE.md)
§5 summarises it; this document is normative.

**Status:** the platform core (§2–§5, §8, §9) is **implemented** in
`v0.2.0-alpha.1`. The declarative tier (§7 Tier B) and lifecycle configuration
(§6, keystore secrets, install/remove UI) are specified but not implemented.
§12 tracks the exact delta between this document and the code.

Companion documents:

| Document | Covers |
|---|---|
| [PROVIDER_MANIFEST.md](PROVIDER_MANIFEST.md) | The declarative manifest format (§7 Tier B), field by field, with the JSON Schema |
| [PROVIDER_TESTS.md](PROVIDER_TESTS.md) | The contract test matrix these rules are verified by |
| [PROVIDER_SECURITY.md](PROVIDER_SECURITY.md) | Threat model, protections and residual risks of the manifest tier |
| [V0.2_PLAN.md](V0.2_PLAN.md) | Milestone sequence that implements this specification |

---

## 1. Principles

1. **Metadata and streaming are separate systems.** AniList answers "what is this
   title?"; a streaming provider answers "where can I watch it, in what quality,
   with which subtitles?". They have different contracts, different lifecycles and
   different failure modes. A single "provider" abstraction covering both is how
   anime clients become unmaintainable.
2. **The user composes the app.** NEXUS ships with AniList metadata and a test
   stream library. It does not ship a closed, hardcoded list of streaming sources:
   providers are installed, configured, prioritised, disabled and removed by the
   user, and new implementations can be added without restructuring the app.
3. **Declared, never guessed.** A provider states what it can do. The UI explains
   gaps up front instead of failing during playback. Sample/demo media is always
   labelled.
4. **Nothing illegal.** No DRM circumvention, no access-control bypass, no
   unauthorised scraping, no shipped third-party stream URLs. A provider the user
   adds is their responsibility; the platform provides no mechanism whose purpose
   is to break a protection measure.
5. **Removing a provider never damages user data.** Library entries, history and
   settings are keyed by metadata identity, never by provider identity.

---

## 2. Three independent axes

The single most common design mistake is collapsing these into one "status"
enum. NEXUS keeps them separate because each has a different owner and a
different fix.

| Axis | Question | Who fixes it | Values |
|---|---|---|---|
| **Compatibility** | Can this build run this provider at all? | App update (or nothing) | `compatible`, `requiresNewerApp`, `unsupportedContract`, `unsupportedPlatform` |
| **Configuration** | Has the user supplied what it needs? | The user, in Settings → Sources | `notRequired`, `incomplete`, `configured`, `rejected` (credentials refused) |
| **Availability** | Can it serve a request right now? | Time, network, upstream | `ready`, `limited`, `degraded`, `unavailable` |

Derived presentation state (what Settings → Sources shows):

| Derived | Condition | Copy |
|---|---|---|
| Usable | compatible + configured + (ready \| limited \| degraded) | "Ready" / "Test content only" |
| Needs setup | compatible + configuration `incomplete` | "Setup required" + the missing fields |
| Rejected config | compatible + configuration `rejected` | "Sign-in rejected" + a re-enter action |
| Incompatible | compatibility ≠ `compatible` | "Needs a newer NEXUS" / "Not available on this platform" — no retry button, because retrying cannot help |
| Unavailable | compatible + configured + availability `unavailable` | "Temporarily unavailable" + last error + retry |
| Disabled | compatible but the user switched it off | "Off" — configuration is retained |

Rules:

- Compatibility is evaluated **once at install/load**, from the provider's
  declared contract version, the platform and the required base capabilities. It
  is not re-derived from a live request.
- Availability is **never** persisted as truth; it is a cached observation with a
  timestamp, refreshed on demand and after failures.
- A disabled provider keeps its configuration. Re-enabling must not require
  re-entering credentials.
- `degraded` means "some capabilities currently fail" (e.g. search works, stream
  resolution does not); it is a partial state, not an error state.

---

## 3. Provider kinds

```dart
enum ProviderKind { metadata, streaming }
```

Both kinds share the envelope below; their capability contracts differ.
Registries are separate: a metadata provider is never offered as a video source,
and a streaming provider never becomes the source of truth for titles.

### 3.1 Shared envelope

```dart
abstract class ProviderDescriptor {
  String get id;                    // stable, reverse-dns: 'anilist', 'sample', 'dev.example'
  String get name;                  // display name
  String get description;           // one line, shown in Settings → Sources
  String get version;               // the provider's own semver
  ProviderContractRange get contract; // the contract range it supports
  ProviderKind get kind;
  List<ProviderConfigField> get configuration;
  String get attribution;           // licence / credit line, shown wherever content appears
  ProviderOrigin get origin;        // builtIn | userAdded
  Set<ProviderPlatform> get platforms;
}
```

`capabilities` is declared by each kind, not in the shared envelope:
`Set<ProviderCapability>` for streaming, `Set<MetadataCapability>` for metadata.
The two contracts do not share a capability vocabulary, and putting one in the
envelope would have forced a metadata adapter to answer streaming questions.

`id` is permanent for a given provider: it is the key in preferences, in
`provider_entries` and in saved resume hints. Renaming a display name is free;
changing an id is a new provider.

`contractVersion` is compared against `ProviderContract.current` (an integer this
repository increments only for breaking changes). Providers declare a minimum and
maximum they support; a provider whose range excludes the current contract is
`unsupportedContract` and is never invoked.

### 3.2 Streaming capabilities

```dart
enum ProviderCapability {
  search,           // free-text catalogue search
  seriesMatching,   // map a metadata title to a provider series
  seasons,          // season structure
  episodes,         // episode list
  streams,          // resolve playable variants
  qualities,        // more than one variant with heights
  subtitles,        // external subtitle tracks
  audioTracks,      // multiple audio tracks
  continueWatching, // provider-side resume position (optional)
}
```

Capabilities gate the UI and the resolver; they are not suggestions. A provider
that lacks `subtitles` must return an empty subtitle list, and the player menu
says "this source provides no subtitles" rather than showing an empty sheet.

### 3.3 Metadata capabilities

```dart
enum MetadataCapability {
  trending, seasonal, topRated, recentlyUpdated,
  search, filters, details, relations, genres,
  streamingEpisodes, airSchedule, externalIds,
}
```

AniList is the first `MetadataProvider`, not a special case wired into screens.
`MetadataRepository` depends on the interface, so a second catalogue (MyAnimeList,
a self-hosted instance, an offline cache) is an addition, not a rewrite.

---

## 4. Streaming contract

Methods are grouped; a provider implements the groups its capabilities claim.
The resolver checks capability **before** calling, so unsupported methods are
never reached in normal operation.

```dart
abstract class StreamingProvider implements ProviderDescriptor {
  Future<ProviderStatusSnapshot> probe();                 // refresh availability
  Future<List<ProviderSeries>> search(String query, {int page});
  Future<ProviderSeries?> match(Anime anime);             // null when absent
  Future<List<ProviderSeason>> seasons(ProviderSeries series);
  Future<List<ProviderEpisode>> episodes(ProviderSeries series, {String? seasonId});
  Future<EpisodeStream> resolve(ProviderSeries series, ProviderEpisode episode);
  Future<void> dispose();                                 // release clients, timers
}
```

Contract rules:

- `match()` returns `null` when the provider has no entry. It never returns a
  best guess, a fuzzy top result, or a series for a different title. Ambiguity is
  resolved by the user, not invented by the provider.
- `episodes()` returns a complete, ordered list for the requested scope, with
  absolute numbering. Providers that only expose season-relative numbers must
  normalise.
- `resolve()` may return a short-lived URL. It is called at playback time, never
  cached beyond the session, and its failure never destroys the episode list.
- Streaming URLs and headers exist only in memory and in `PlaybackRequest`
  transit. They are never written to SQLite, logs, release notes or crash
  reports.
- `dispose()` is mandatory: HTTP clients, timers and cached tokens must be
  released when a provider is disabled or removed.
- Long operations accept an optional cancellation signal; the resolver enforces
  per-call timeouts (default 15 s search, 10 s match, 20 s resolve).

---

## 5. Resolution pipeline

```
Details screen
  └─ sourceResolutionProvider(animeId)
       └─ ProviderResolver.lookup(anime)
            1. candidates  = installed ∩ enabled ∩ compatible ∩ configured
                             ∩ has(seriesMatching)
            2. order       = user priority (default: install order)
            3. probe       = concurrent, per-provider timeout, failures recorded
            4. result      = every match, not just the first
            5. persist     = preferred provider per anime id (optional override)
```

v0.1 stops at the first matching provider. v0.2 changes this to collect all
matches and keep a user preference per title, because "the first provider that
recognises a title" is not the same as "the provider the user wants to watch it
from". The observed shape of the fix is documented in §12 and is **not**
implemented by this revision.

Additional rules:

- A failure in one provider never fails the screen. `SourceLookup` carries
  `Map<providerId, ProviderFailure>` and the details Episodes tab shows a
  collapsible "source errors" line.
- Probing is capped (default 4 concurrent providers) so adding ten sources does
  not melt the device or trigger rate limits.
- Provider results are cached per session with a short TTL for `match()` and
  `episodes()`; `resolve()` is never cached.
- Removing or disabling the provider recorded in a saved resume hint must degrade
  to re-resolving the title, not to a crash or an empty player.

---

## 6. Configuration model

Configuration is declared data, not provider-specific UI.

```dart
class ProviderConfigField {
  final String key;          // 'baseUrl', 'apiKey'
  final String label;
  final ProviderConfigType type; // text | url | secret | choice | boolean
  final bool required;
  final String? hint;
  final String? defaultValue;
  final List<String> choices;
}
```

- Settings → Sources renders the form from the declaration. No screen contains
  provider-specific fields.
- `secret` values are stored in the platform keystore (`flutter_secure_storage`,
  introduced when the first provider with credentials is integrated), never in
  SQLite, preferences, logs, crash reports or screenshots.
- Non-secret values live with the provider row (§9), so they survive restarts and
  are exportable.
- Validation is declarative (required, URL shape, non-empty) plus an optional
  provider-side `validate()` for credentials, which is what turns
  configuration into `configured` or `rejected`.
- Secrets are never echoed back into the UI; the field shows "configured" with a
  replace action.
- A provider with no fields reports `notRequired` and is usable immediately.

---

## 7. Integration tiers

"Dynamically add providers" needs an honest answer about what Flutter can do.

**Constraint.** Flutter release builds are AOT-compiled: arbitrary Dart code
cannot be loaded at runtime, there is no JIT and no plugin loading from a
downloaded archive. Any design that claims to "install provider code" without an
app rebuild is either lying or is secretly a WebView/scraper, which this project
rejects.

NEXUS therefore supports two explicit tiers.

### Tier A — adapter in the app (built in, rebuilt with the app)

A Dart class implementing the contract, registered in
`lib/integrations/streaming/provider_registry_bootstrap.dart`. This is how
first-party adapters (the test library, the owner's authorised source) ship.

Adding one:

1. Implement `StreamingProvider` (and `ProviderDescriptor`).
2. Declare honest capabilities, contract version, configuration fields and
   attribution.
3. Append it to the registry list.
4. Add tests for `match()` returning `null` on a non-match, capability honesty
   and variant selection.

No screen, repository, route or database change is required. The registry is the
only composition point.

### Tier B — user-added declarative integration (v0.2)

A JSON manifest describing an HTTP catalogue, executed by one generic adapter.
This is what lets a user add a compatible provider without a new APK.

**Normative format:** [PROVIDER_MANIFEST.md](PROVIDER_MANIFEST.md) and
[`schema/provider-manifest.v1.schema.json`](schema/provider-manifest.v1.schema.json).
The example below is abbreviated but structurally valid; it omits `probe`,
seasons, subtitles, audio, error policy and every limit, which the format document
defines.

```json
{
  "manifestVersion": 1,
  "contract": { "min": 1, "max": 1 },
  "id": "dev.example.catalog",
  "name": "Example Catalogue",
  "version": "1.0.0",
  "kind": "streaming",
  "attribution": "Content © Example; used with permission",
  "capabilities": ["search", "seriesMatching", "episodes", "streams"],
  "config": [
    { "key": "baseUrl", "label": "API base URL", "type": "url", "required": true }
  ],
  "net": { "origins": ["https://api.example.com"] },
  "requests": {
    "search": {
      "url": "{baseUrl}/search",
      "query": { "q": "{query}" },
      "list": "$.results",
      "map": { "seriesId": "$.id", "title": "$.title", "coverImage": "$.poster" }
    },
    "match": {
      "url": "{baseUrl}/search",
      "query": { "q": "{title}" },
      "list": "$.results",
      "strategy": "normalisedTitle",
      "map": { "seriesId": "$.id", "title": "$.title" }
    },
    "episodes": {
      "url": "{baseUrl}/series/{seriesId}/episodes",
      "list": "$.episodes",
      "map": { "episodeId": "$.id", "number": "$.number", "title": "$.title" }
    },
    "resolve": {
      "url": "{baseUrl}/episodes/{episodeId}/sources",
      "variants": {
        "list": "$.sources",
        "map": { "label": "$.quality", "uri": "$.url", "height": "$.height" }
      }
    }
  }
}
```

Sandbox rules for Tier B (details and limits in
[PROVIDER_MANIFEST.md](PROVIDER_MANIFEST.md) §5–§10; honest weaknesses in
[PROVIDER_SECURITY.md](PROVIDER_SECURITY.md) §5):

- **Declarative only.** Substitution of `{placeholders}` and JSON-path selection.
  No script, no expression evaluation, no templating language with logic.
- **HTTPS only** (HTTP allowed only for loopback during development).
- **Origin pinning.** Requests may only go to origins declared by the provider's
  own configuration or manifest; credentials are never attached to a different
  origin than the one that issued them.
- **No local access.** No file paths, no assets, no `content://`, no `intent://`.
- **Bounded.** Response size cap, per-request timeout, redirect limit, no
  unbounded paging.
- **Visible.** The manifest is shown to the user before install (id, origin,
  capabilities, requested hosts); every request it makes is shown in a
  per-provider diagnostic log.
- **Removable.** Uninstall deletes the manifest, its config and its cache, and
  nothing else.
- **Reviewed.** A manifest that only exists to bypass a paywall, DRM or geo-block
  is out of scope for this project; the app does not ship a directory of such
  manifests and does not fetch one automatically.

A Tier B provider is subject to exactly the same contract, capability, error and
lifecycle rules as Tier A — the resolver cannot tell them apart.

**A manifest is not a sandbox.** It cannot execute code or reach an undeclared
host, but it can serve misleading content, point media at a host it declared, or
feed a malformed stream to the player. NEXUS treats user-added providers as
untrusted input to a trusted interpreter, and says so in the install review.
The format is versioned: `manifestVersion` (format) and `contract` (platform
range) are independent, so an old manifest keeps working across an app update.

---

## 8. Errors and degradation

`ProviderFailure` is a sealed type, mapped to `AppFailure` for the UI:

| Failure | Retryable | UI treatment |
|---|---|---|
| `ProviderNotConfigured` | no | "Set this source up in Settings → Sources" with a deep link |
| `ProviderAuthRejected` | no | "Sign-in rejected" + replace credentials |
| `ProviderNotFound` | no | Episode/title absent; offer another source |
| `ProviderRateLimited(retryAfter)` | yes | Countdown, then retry |
| `ProviderGeoRestricted` | no | "Not available in this region" |
| `ProviderUpstreamError(status)` | yes | "Source error (HTTP n)" + retry |
| `ProviderTimeout` | yes | "Source took too long" + retry |
| `ProviderParseFailure` | no | "Unexpected response" — a provider bug, reported honestly |
| `ProviderUnsupported(feature)` | no | "This source has no …" |
| `ProviderCancelled` | no | Silent (user left the screen) |

Rules: a provider exception never escapes to the router; one failing provider
never empties a screen that another provider can fill; raw exception strings are
never shown — they are logged locally with the provider id and mapped to a
message.

---

## 9. Persistence (planned — schema v2, not implemented)

v1 stores only `enabledProviderIds` inside `preference_entries`. That cannot
express configuration, ordering, install origin or per-title preference. v0.2
adds, as an additive migration (see [DATABASE.md](../DATABASE.md) §6):

| Table | Purpose |
|---|---|
| `provider_entries` | one row per installed provider: `provider_id` (PK), `origin` (builtIn/userAdded), `manifest_version`, `contract_version`, `enabled`, `priority`, `config_json` (non-secret), `installed_at` |
| `provider_title_prefs` | `anime_id` + `provider_id` (composite PK): the user's chosen source per title |
| `provider_manifests` | `provider_id` (PK), `manifest_json`, `source_url`, `installed_at` — only for user-added integrations |

Secrets do not go in SQLite; they go to secure storage under
`provider.<id>.<key>`. `provider_id` values in `progress_entries` remain resume
hints only.

A `provider_manifests` row is written only after the manifest passes the full
validation pipeline ([PROVIDER_MANIFEST.md](PROVIDER_MANIFEST.md) §2, §9) and is
re-validated on load; a row that no longer validates disables only its provider.
Manifests are capped at 512 KiB, and `manifest_version` in `provider_entries`
records which format version was stored so an older app can report
`requiresNewerApp` instead of failing to parse.

No table here changes or replaces an existing one, and the migration is additive.

---

## 10. Security and privacy

Full threat model, per-attack protections and the residual risks that are
accepted: [PROVIDER_SECURITY.md](PROVIDER_SECURITY.md).

- No analytics, no telemetry, no remote provider directory.
- Credentials: keystore only; never logged, never included in exports, never
  shown back in full.
- Stream URLs, cookies and headers are session-only.
- Diagnostic logs redact query strings on URLs that carry tokens, and are opt-in.
- A provider declaring an origin other than its configured host is refused.
- The platform never proxies content: the device talks to the provider directly,
  so the provider sees the user's IP exactly as a browser would.

---

## 11. Architecture rules for contributors

1. No screen may reference a concrete provider type or check `provider.id`.
2. No provider-specific field may enter a domain model (`Anime`, `LibraryEntry`,
   `WatchProgress`). Provider identity is a hint, not a model property.
3. Capabilities are the only branching mechanism.
4. Adding a provider must not require a database migration, a route change or a
   screen change — if it does, the abstraction is wrong and the fix belongs in
   the platform, not in the provider.
5. Every new provider ships tests proving `match()` can return `null`, that
   declared capabilities match behaviour, and that failures surface as
   `ProviderFailure`.

---

## 12. Current implementation vs this specification

| Area | v0.1.0-alpha | v0.2.0-alpha.1 (now) | Remaining |
|---|---|---|---|
| Kinds | One contract | ✅ `ProviderKind`, `MetadataProvider`, AniList behind it, separate registries | — |
| Registration | `const ProviderRegistry([...])` | ✅ `StreamingProviderRegistry` + `MetadataProviderRegistry` in one bootstrap file | Installable descriptors from the database (2.2c) |
| Configuration | None | ✅ Declared fields, evaluation to `notRequired`/`incomplete`/`configured` | Generated form, validation, keystore secrets (2.2c) |
| Compatibility | One availability enum | ✅ Three axes + one derived state (§2) | Per-state UI actions (2.2d) |
| Lifecycle | Enable/disable flag | ✅ `probe()`, idempotent `dispose()`, persisted enablement | Install/configure/verify/remove commands (2.2c) |
| Ordering | First enabled match | ✅ All matches, stored priority, per-title preference | Reorder control (2.2d) |
| Errors | `ProviderException(message)` | ✅ Sealed `ProviderFailure` taxonomy (§8) | — |
| Status | Synchronous getter | ✅ `probe()` → timestamped snapshot | — |
| User-added providers | Not possible | ✅ Tier B: `ManifestStreamingProvider` interprets a validated manifest (2.2b) | Install/review screen and removal (2.2c) |
| Manifest validation | None | ✅ Offline pipeline: parse → schema → templates → paths → semantics → compatibility, all errors reported ([PROVIDER_MANIFEST.md](PROVIDER_MANIFEST.md) §9) | Re-validation of a stored copy on load (2.2c) |
| Network egress | No provider-level allowlist | ✅ Manifest adapter: HTTPS only, allowlist on parsed URIs, manual redirects re-checked per hop, decoded-byte cap, timeouts, pacing, one idempotent retry | Nothing further for manifest providers |
| Provider tests | Contract honesty | ✅ 145 provider tests: contract, axes, resolution, metadata, migration, manifest validation, adapter and security | Sources suites ([PROVIDER_TESTS.md](PROVIDER_TESTS.md)) |
| Persistence | `sources.enabled` | ✅ Schema v2 tables + `ProviderStore` (§9), including manifest storage | Configuration and manifest writes on install (2.2c) |

---

## 13. Review checklist for a new provider

- [ ] Authorised source; no DRM circumvention, paywall bypass or unauthorised scraping.
- [ ] Stable `id`, declared `contractVersion`, attribution and licence.
- [ ] Capabilities match real behaviour in both directions.
- [ ] `match()` returns `null` rather than a guess; ambiguity is surfaced.
- [ ] Episodes are complete, ordered and absolutely numbered.
- [ ] Failures map to `ProviderFailure`; no raw exceptions reach the UI.
- [ ] `dispose()` releases clients and timers.
- [ ] Configuration is declared, not hardcoded into a screen.
- [ ] Secrets go to secure storage; nothing sensitive is logged.
- [ ] Tests cover non-match, capability honesty and error mapping.
- [ ] Disabling/removing it leaves library, history and settings intact.
