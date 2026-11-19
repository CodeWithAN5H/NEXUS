# NEXUS — Provider Contract Test Matrix

**Status:** the built-in, resolution, persistence and **manifest** layers are
**implemented and executed** as of `v0.2.0-alpha.1` (T-A, T-M, T-B, T-R, T-P).
The Sources UI layer (T-S) and the lifecycle rows marked 2.2c are still
specifications. This matrix defines what "the provider
platform works" means, so implementation and verification cannot drift.
Contracts: [PROVIDERS.md](PROVIDERS.md) §3–§8,
[PROVIDER_MANIFEST.md](PROVIDER_MANIFEST.md),
[PROVIDER_SECURITY.md](PROVIDER_SECURITY.md).

---

## 1. How these tests run

| Layer | Location | Nature |
|---|---|---|
| Manifest schema | `test/providers/manifest_schema_test.dart` | Pure Dart: parse + validate fixture JSON. No network. |
| Manifest adapter | `test/providers/manifest_adapter_test.dart` | `ManifestStreamingProvider` driven by a fake `http.Client`; assert mapped models and `ProviderFailure`s. |
| Built-in adapter | `test/providers/builtin_adapter_test.dart` | Extends today's `test/streaming_provider_test.dart` (79 tests, all passing) to the new contract. |
| Resolution | `test/providers/resolver_test.dart` | `ProviderResolver` over several fake providers: ordering, priority, per-title preference, partial failure. |
| Persistence | `test/providers/provider_store_test.dart` | Drift-backed store: schema v2 migration, restart, disable keeps config, remove clears only its rows. |
| Widget-level | `test/providers/sources_screen_test.dart` | Sources cards render derived states and generated config forms; no provider-specific fields. |

Rules applied to every test in this document:

1. **No real network.** All HTTP goes through an injectable client. CI has no
   device, no emulator and no credentials (see `PROJECT_STATUS.md` §1).
2. **Fixtures, not mocks of our own code.** Response bodies are JSON files under
   `test/fixtures/providers/`; the client maps `(method, path)` → fixture, so a
   test fails if the adapter requests the wrong URL.
3. **Assert on the failure type, not the message.** Messages are copy and will
   change; `ProviderTimeout` is the contract.
4. **One reason to fail.** A test that checks five behaviours tells you nothing
   when it goes red.
5. **Deterministic time.** Timeouts use an injected clock, so the suite never
   waits 15 real seconds.

Baseline: 79 tests from v0.1.0-alpha (models, formatting, database, widgets,
provider contract); all still pass. The suite is **224 tests** after milestone
2.2b. The first provider milestone (2.1a–2.2a) added:

| Layer | File | Matrix IDs covered |
|---|---|---|
| Built-in adapter | `test/providers/provider_contract_test.dart` | T-A03–T-A09, ambiguity (T-A07), typed failures (T-A08) |
| Axes | `test/providers/provider_state_test.dart` | The six derived states and configuration evaluation (T-S01 fixtures) |
| Metadata interface | `test/providers/metadata_provider_test.dart` | T-A09, T-A10 |
| Resolution | `test/providers/provider_resolver_test.dart` | T-R01–T-R04, T-R07–T-R13, T-R15 |
| Persistence | `test/providers/provider_store_test.dart` | T-P01–T-P05, T-P10, T-P11, plus manifest-size and removal guards |

Milestone 2.2b added 80 more, all hermetic (a `FakeManifestTransport` answers
every request; no socket is opened):

| Layer | File | Matrix IDs covered |
|---|---|---|
| Manifest validation | `test/providers/manifest_validation_test.dart` | T-M01–T-M05, T-M07–T-M14, T-M16–T-M24 (29 tests) |
| Declaration and search/match | `test/providers/manifest_interpreter_test.dart` | T-B01–T-B15 |
| Seasons, episodes, resolve | `test/providers/manifest_adapter_test.dart` | T-B17–T-B29 |
| Status policy and redirects | same file | T-B31–T-B37 |
| Secrets, redaction, hardening | same file | T-B40, T-B45 |
| Pacing, cancellation, gate | same file | T-B41, T-B43 |
| Loading and isolation | same file | Factory isolation, resolver integration |

Still not covered, and why: **T-M15** is exercised as the decoded-byte cap
(“oversized response”) rather than by asserting an early socket close; **T-B16**
(per-title preference after a user choice), **T-B30** (configuration → `rejected`),
**T-B39** (self-hosted LAN base URL end-to-end), **T-B42** (six providers probed
with the cap), **T-B46** (`dispose()` mid-flight under the resolver) and
**T-R14** belong to 2.2c; every **T-S** row belongs to 2.2d.

---

## 2. Manifest schema and validation (T-M)

Fixtures live in `test/fixtures/providers/manifests/`; the reference documents
are the ones committed under `docs/schema/examples/`.

| ID | Scenario | Fixture | Expected outcome | Milestone |
|---|---|---|---|---|
| T-M01 | Minimal valid manifest | `valid-minimal.json` | Parses; descriptor exposes id `dev.example.minimal`, 4 capabilities, 1 config field | 2.2b |
| T-M02 | Full valid manifest | `valid-full.json` | Parses; all six requests present; 4 config fields; 8 capabilities | 2.2b |
| T-M03 | Committed repository examples stay valid | `docs/schema/examples/*.json` | The two `valid-*` documents validate; the schema itself passes a meta-schema check | 2.2b |
| T-M04 | Plain-HTTP origin | `invalid-http-origin.json` | Rejected with `manifest.schema` at `/net/origins/0`; no provider object constructed | 2.2b |
| T-M05 | Capability without its request | `invalid-unbacked-capability.json` | Rejected: capability `seasons` has no `requests.seasons` | 2.2b |
| T-M06 | Executable field smuggled in | `invalid-executable-field.json` | Rejected: unknown property `script` | 2.2b |
| T-M07 | JSONPath filter | `invalid-jsonpath-filter.json` | Rejected with `manifest.path` | 2.2b |
| T-M08 | Unknown top-level key | mutate T-M01: add `"eval": "…"` | Rejected: unknown property | 2.2b |
| T-M09 | Duplicate config keys | mutate: two `baseUrl` fields | Rejected: `manifest.semantic`, duplicate key | 2.2b |
| T-M10 | `resolve.subtitles` without the capability | mutate T-M01: add `subtitles` block | Rejected: declared request not covered by a capability | 2.2b |
| T-M11 | Secret in a URL default | mutate: `secret` field with `defaultValue` | Rejected: defaults must be non-secret | 2.2b |
| T-M12 | `seasonRelative` without `map.seasonId` | mutate T-M02: drop `seasonId` | Rejected: cannot compute absolute numbers | 2.2b |
| T-M13 | `{page}` used in `resolve` | mutate T-M01 | Rejected: placeholder not available for this request | 2.2b |
| T-M14 | Path depth over limit | mutate: `$.a.b.c.d.e.f.g.h.i` | Rejected: `manifest.path`, depth > 8 | 2.2b |
| T-M15 | Response size cap | manifest `net.maxResponseBytes: 16384`; 40 KiB body | `ProviderParseFailure` with a size note; connection closed early | 2.2b |
| T-M16 | Unsupported contract version | `contract: {min: 9, max: 9}` | Not a parse error: compatibility `unsupportedContract`; provider listed but never invoked | 2.1 |
| T-M17 | Newer manifest version | `manifestVersion: 2` | Compatibility `requiresNewerApp`; installed row retained, provider disabled | 2.2b |
| T-M18 | Reserved id | `id: "nexus.demo"` and `id: "app.demo"` | Rejected: reserved prefix | 2.2b |
| T-M19 | Id collision with a built-in | `id: "sample"` is not reverse-dns → rejected; `id: "app.nexus.sample"` → reserved | Rejected | 2.2b |
| T-M20 | Manifest over 512 KiB | generated padding | Rejected before parsing (`manifest.parse`) | 2.2b |
| T-M21 | Depth over 12 | generated nesting | Rejected (`manifest.parse`) | 2.2b |
| T-M22 | Non-UTF-8 / invalid JSON | truncated fixture | Rejected; message names the byte offset | 2.2b |
| T-M23 | Validation reports every error | manifest with 3 independent defects | 3 errors returned, ordered by path, not just the first | 2.2b |
| T-M24 | No secret in any error message | secret config + invalid header template | Error text contains no configured value | 2.2b |

---

## 3. Manifest adapter behaviour (T-B)

| ID | Scenario | Setup | Expected outcome | Milestone |
|---|---|---|---|---|
| T-B01 | Search maps results | fixture with 3 items | 3 `ProviderSeries`, ids/titles/covers mapped, `providerId` stamped from the manifest | 2.2b |
| T-B02 | Empty search results | fixture `{"results": []}` | Empty list, **no** failure, no retry | 2.2b |
| T-B03 | Search HTTP 500 | client returns 500 | `ProviderUpstreamError(500)`, `isRetryable` true | 2.2b |
| T-B04 | Search timeout | clock advances past `timeoutMs` | `ProviderTimeout`, one retry attempted for GET, then failure | 2.2b |
| T-B05 | Offline / socket error | client throws `SocketException` | `ProviderUpstreamError` mapped once; no raw exception escapes | 2.2b |
| T-B06 | Malformed JSON body | `{"results": [` | `ProviderParseFailure`, message names the provider id, body not logged raw | 2.2b |
| T-B07 | Wrong shape (object instead of list) | `{"results": {}}` | `ProviderParseFailure` | 2.2b |
| T-B08 | Item missing a required field | one item without `title` | Item dropped, other two returned, drop counted in diagnostics | 2.2b |
| T-B09 | All items malformed | every item missing `seriesId` | `ProviderParseFailure` (not an empty list) | 2.2b |
| T-B10 | List longer than `maxResults` | 120 items, cap 30 | Exactly 30 returned, truncation flagged | 2.2b |
| T-B11 | Exact-title match | candidate with identical title | `match()` returns that series | 2.2b |
| T-B12 | Normalised match | `"Frieren: Beyond Journey's End"` vs `"frieren beyond journeys end"` | Match accepted by `normalisedTitle` | 2.2b |
| T-B13 | Year guard | same title, year 2019 vs 2023, strategy `normalisedTitleAndYear` | No match → `null` | 2.2b |
| T-B14 | Non-match | no candidate resembles the title | `null`, never a best guess | 2.2b |
| T-B15 | Duplicate candidates | two identical titles | `null` + ambiguous-match record; details screen can offer a chooser | 2.2b |
| T-B16 | Ambiguity resolved by the user | choose candidate 2 | `provider_title_prefs` row written; later lookups skip matching | 2.2c |
| T-B17 | Episodes absolute numbering | `numbering: absolute` | Numbers preserved | 2.2b |
| T-B18 | Episodes season-relative | seasons 12 + 24 episodes, `numbering: seasonRelative` | Season 2 episode 1 becomes absolute 13 | 2.2b |
| T-B19 | Missing `episodeCount` for an earlier season | same as T-B18, count absent | `ProviderParseFailure` — numbering cannot be invented | 2.2b |
| T-B20 | Missing episodes | fixture `{"episodes": []}` | Empty list; UI shows "this source lists no episodes"; no crash | 2.2b |
| T-B21 | Missing streams | `resolve` returns `{"sources": []}` | `EpisodeStream.isEmpty`; player shows "no playable stream", episode list intact | 2.2b |
| T-B22 | Invalid stream URL — plain HTTP | `"file": "http://cdn/…"` | Variant dropped; if none remain, `ProviderInvalidStream` | 2.2b |
| T-B23 | Invalid stream URL — wrong host | `https://evil.test/a.m3u8` | Dropped: host not in `mediaHosts` | 2.2b |
| T-B24 | Invalid stream URL — other scheme | `file:///etc/passwd`, `intent://…`, `data:…` | Dropped before the player sees it | 2.2b |
| T-B25 | Variant quality selection | 360/720/1080 variants, preference 720 | `bestVariant(preferredHeight: 720)` returns 720; preference 900 returns 720 | 2.2b |
| T-B26 | Subtitle capability honesty | manifest without `subtitles` capability | Empty subtitle list, no request made, player shows "this source provides no subtitles" | 2.2b |
| T-B27 | Subtitle tracks returned | two text tracks | Two `SubtitleTrackInfo` with labels and languages | 2.2b |
| T-B28 | Audio capability honesty | manifest without `audioTracks` | Empty audio list; menu hidden | 2.2b |
| T-B29 | Bad subtitle URI | `uri: ""` | Track dropped, variants unaffected | 2.2b |
| T-B30 | Auth rejected | 401 from `search` | `ProviderAuthRejected`; configuration → `rejected`; no retry | 2.2c |
| T-B31 | Rate limited | 429 + `Retry-After: 30` | `ProviderRateLimited(retryAfter: 30s)`; countdown shown; one retry after it | 2.2b |
| T-B32 | Retry-After absurd | `Retry-After: 999999` | Clamped to `maxRetryAfterSeconds` | 2.2b |
| T-B33 | Geo restricted | 451 or `notFoundStatus` per policy | `ProviderGeoRestricted` when configured, else upstream error | 2.2b |
| T-B34 | Redirect inside allowlist | 302 → `https://api.example.com/v2/search` | Followed once, result parsed | 2.2b |
| T-B35 | Redirect outside allowlist | 302 → `https://evil.test/` | `ProviderOriginRejected`; second request never made | 2.2b |
| T-B36 | Redirect downgrade | 302 → `http://api.example.com/` | Refused, not followed | 2.2b |
| T-B37 | Too many redirects | 6 hops, `maxRedirects: 3` | Refused at hop 4 | 2.2b |
| T-B38 | Absolute URL not in origins | `url: "https://evil.test/x"` | Registry refuses at install validation; at runtime `ProviderOriginRejected` | 2.2b |
| T-B39 | Self-hosted base URL | `baseUrl` config `https://media.mine.lan` | Allowed because a configured `url` field extends the allowlist | 2.2c |
| T-B40 | Secret not sent to media host | `X-Api-Key` configured; variant on `mediaHosts` | Media request carries only `streamHeaders`; no API key | 2.2b |
| T-B41 | Pacing | two searches back to back, interval 300 ms | Second request starts ≥ 300 ms later (injected clock) | 2.2b |
| T-B42 | Concurrency cap | 6 providers probed | At most 4 in flight | 2.2c |
| T-B43 | Cancellation | screen disposed mid-request | `ProviderCancelled`, no failure surfaced, no log noise | 2.2b |
| T-B44 | Unknown placeholder | `{episodeId}` in `search.url` | Rejected at validation, not at runtime | 2.2b |
| T-B45 | Header injection attempt | config value `"x\r\nX-Evil: 1"` | Substitution refused; request never sent; no raw value echoed | 2.2b |
| T-B46 | `dispose()` | disable provider with in-flight request | Client closed, request cancelled, no `dispose`-after-`dispose` error | 2.2c |

---

## 4. Built-in adapter (T-A)

The same behavioural matrix applies to Tier A, adapted where the adapter owns
logic rather than data.

| ID | Scenario | Expected outcome | Milestone |
|---|---|---|---|
| T-A01 | Sample provider `match()` | Always `null`; a real anime is never shown test video (exists today, keep) | 2.1 |
| T-A02 | Sample provider honesty | Declares `limited` availability; every stream carries `isSample: true` and a notice | 2.1 |
| T-A03 | Capability/behaviour parity | For every declared capability, the corresponding method does not throw `ProviderUnsupported`; for every undeclared one, it does | 2.1 |
| T-A04 | `probe()` shape | Returns a snapshot with a timestamp, availability and message; never throws | 2.1 |
| T-A05 | `dispose()` releases resources | HTTP client closed; second `dispose()` is a no-op | 2.1 |
| T-A06 | Empty catalogue | Provider with no titles → empty search, `match()` null, no failure | 2.1 |
| T-A07 | Duplicate titles in a catalogue | Ambiguous record, no arbitrary pick | 2.1 |
| T-A08 | Failure mapping | Each adapter throws only `ProviderFailure` subtypes; a generic `Exception` is wrapped as `ProviderParseFailure`/`UnexpectedFailure` at the boundary | 2.1 |
| T-A09 | Metadata provider independent of streaming | Remove every streaming provider: home, explore, details, library and history still render from `MetadataProvider` | 2.1 |
| T-A10 | AniList behind the interface | `MetadataRepository` compiles against `MetadataProvider`; no file imports `AniListClient` outside `integrations/anilist` | 2.1 |

---

## 5. Resolution and user composition (T-R)

| ID | Scenario | Setup | Expected outcome | Milestone |
|---|---|---|---|---|
| T-R01 | Multiple providers match one title | A, B both match, priority A first | Both returned, ordered A, B; UI shows both | 2.1 |
| T-R02 | Priority follows the user | drag B above A | B first after the change and after restart | 2.1 |
| T-R03 | Per-title preference wins over priority | preference A for title X, B first globally | X resolves to A first, with B still listed | 2.1 |
| T-R04 | Preference for a removed provider | A preferred, A removed | Falls back to priority order; no crash, stale row ignored | 2.1 |
| T-R05 | Enable/disable lifecycle | disable B | B leaves candidates immediately; configuration retained; re-enable needs no re-entry | 2.2c |
| T-R06 | Remove lifecycle | remove B | `provider_entries`, `provider_manifests`, secrets and caches for B gone; library/history/settings untouched; other providers unaffected | 2.2c |
| T-R07 | One provider fails, one succeeds | A times out, B matches | Screen shows B's episodes plus a collapsible "source errors" line for A | 2.1 |
| T-R08 | All providers fail | every candidate times out | Screen shows a retryable error listing each provider's failure; details metadata still visible | 2.1 |
| T-R09 | No provider matches | both return `null` | Empty state: "No source has this title" + Manage sources action | 2.1 |
| T-R10 | Incompatible provider skipped | contract range excludes the build | Not probed at all (asserted by the fake client receiving no request) | 2.1 |
| T-R11 | Unconfigured provider skipped | required field empty | Not probed; state `Needs setup` | 2.2c |
| T-R12 | Capability gate | provider without `seriesMatching` | Never a candidate for resolution, even if enabled | 2.1 |
| T-R13 | Probe cap and caching | 10 providers, 4-concurrency cap | At most 4 in flight; repeated lookups within TTL reuse the cached match | 2.1 |
| T-R14 | Cancelled screen | user leaves details during lookup | No setState after dispose; failures recorded silently | 2.1 |
| T-R15 | Stale resume hint | `progress_entries.provider_id` points at a removed provider | Re-resolve the title instead of failing; player still opens if another provider matches | 2.1 |

---

## 6. Persistence and restart (T-P)

| ID | Scenario | Expected outcome | Milestone |
|---|---|---|---|
| T-P01 | Migration 1 → 2 | Open a v1 database file, run `onUpgrade` | Three new tables exist; existing rows byte-identical; `sources.enabled` backfilled into `provider_entries` | 2.2c |
| T-P02 | Migration is re-runnable | run upgrade path twice | No duplicate rows, no error | 2.2c |
| T-P03 | Restart preserves installed providers | install A, B; close; reopen | Both present with id, origin, priority, enabled flag, non-secret config | 2.2c |
| T-P04 | Restart preserves ordering | reorder, close, reopen | Order identical | 2.2c |
| T-P05 | Restart preserves per-title preference | set preference, close, reopen | Preference intact | 2.2c |
| T-P06 | Secrets are not in SQLite | configure a secret | Dump of every table contains no secret value; keystore has `provider.<id>.<key>` | 2.2c |
| T-P07 | Secrets are not in exports/logs | run diagnostics with a secret configured | No secret in diagnostic buffer, export file, or error text | 2.2c |
| T-P08 | Manifest survives restart | install manifest, close, reopen | Manifest still validates and loads; provider usable without re-import | 2.2c |
| T-P09 | Corrupt stored manifest | mutate `manifest_json` to invalid JSON | Provider disabled with `ProviderManifestInvalid`; app starts; other providers unaffected; no crash | 2.2c |
| T-P10 | User data untouched by provider churn | library + history + positions; install, disable, remove all providers | All rows unchanged; library UI identical | 2.2c |
| T-P11 | Data preservation across an app update | v1 file with data, upgrade to v2, use, reopen | Nothing lost (extends today's close/reopen test) | 2.2c |

---

## 7. Sources screen (T-S)

| ID | Scenario | Expected outcome | Milestone |
|---|---|---|---|
| T-S01 | Derived state per axis | 6 fixtures covering the §2 table | Each card shows exactly one derived chip and the action that can change it | 2.2d |
| T-S02 | Incompatible has no retry | `requiresNewerApp` | Card shows update hint, no retry button | 2.2d |
| T-S03 | Setup required lists missing fields | two required fields empty | Chip + field names; tapping opens the generated form | 2.2d |
| T-S04 | Generated form | manifest with text/url/secret/choice/bool | Five controls, no provider-specific widget, validation messages from the declaration | 2.2d |
| T-S05 | Secret never echoed | configured secret | Field shows "configured" + Replace, never the value | 2.2d |
| T-S06 | Import review | paste a manifest | Review lists id, origin, capabilities, hosts; Install disabled until valid | 2.2d |
| T-S07 | Import rejection | paste `invalid-http-origin.json` | Error rows with paths; nothing installed | 2.2d |
| T-S08 | Remove confirmation copy | remove a provider | Confirms that library, history and settings are unaffected | 2.2d |
| T-S09 | Empty state | no providers installed | Explains providers are user-supplied; AniList metadata still works | 2.2d |
| T-S10 | Desktop width | 1280 px window | Cards/form usable, no overflow (widget test with a fixed surface size) | 2.5 |

---

## 8. Traceability

Every requirement in [PRD.md](../PRD.md) §4.6 maps to at least one test:

| Requirement | Tests |
|---|---|
| F-S1 separate kinds | T-A09, T-A10 |
| F-S2 user composition | T-R05, T-R06, T-P03 |
| F-S3 no restructuring | T-A03, T-S04, and the manifest fixture set (no code per provider) |
| F-S4 standardised contract | T-B01…T-B46 (one adapter, one contract) |
| F-S5 declared capabilities | T-B26, T-B28, T-A03 |
| F-S6 three axes | T-M16, T-R10, T-R11, T-S01…T-S03 |
| F-S7 declarative config | T-S04, T-S05, T-P06, T-B45 |
| F-S8 graceful failure | T-B03…T-B09, T-R07, T-R08 |
| F-S9 all matches | T-R01…T-R04 |
| F-S10 non-destructive removal | T-R05, T-R06, T-P10 |
| F-S11 no bypass | T-B22…T-B24, T-B34…T-B37, T-M04 |
| F-S12 validated manifests | T-M01…T-M24 |

A requirement with no test is a specification bug; fix the matrix before writing
the code.
