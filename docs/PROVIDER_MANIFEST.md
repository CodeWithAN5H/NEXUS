# NEXUS — Provider Manifest Format (v1)

**Status:** **implemented** in v0.2.0-alpha.1 (milestone 2.2b) as
`lib/integrations/streaming/manifest/`: the validator (stages 1–4), the JSON path
reader, the template binder, the hardened HTTP layer and
`ManifestStreamingProvider`. What remains is the install/configure/remove flow
(2.2c) and the Sources surface (2.2d) — see §13. This document and
[`schema/provider-manifest.v1.schema.json`](schema/provider-manifest.v1.schema.json)
are still the normative definition. [PROVIDERS.md](PROVIDERS.md) §7 explains why this
tier exists at all; this file defines exactly what a manifest may say and what
the runtime does with it.

| Artefact | Purpose |
|---|---|
| [`schema/provider-manifest.v1.schema.json`](schema/provider-manifest.v1.schema.json) | Machine-readable JSON Schema (draft 2020-12). Normative. |
| [`schema/examples/valid-minimal.json`](schema/examples/valid-minimal.json) | Smallest useful manifest; must validate. |
| [`schema/examples/valid-full.json`](schema/examples/valid-full.json) | Every v1 section exercised; must validate. |
| `schema/examples/invalid-*.json` | One deliberate defect each; must be rejected (§11). |

---

## 1. What a manifest is

A manifest is **data that describes HTTP requests and how to read their
answers**. One generic adapter in the app interprets it. There is no scripting
language, no expression evaluator, no template logic — only placeholder
substitution and a fixed JSON path subset.

A manifest **cannot**:

- run code, define functions, or compute values;
- touch the filesystem, another app, a database, or the clipboard;
- call an origin it did not declare;
- add capabilities the adapter does not implement;
- claim a stream is DRM-protected content it may decrypt (no key handling exists).

A manifest **can**:

- declare identity, attribution, version and the contract range it targets;
- declare configuration fields the user must fill in;
- declare up to six request definitions (probe, search, match, seasons, episodes,
  resolve) against named HTTPS origins;
- map list items into series, seasons, episodes, variants, subtitles and audio
  tracks with a fixed, typed field set.

**This is not a security sandbox.** It is a constrained interpreter plus an
egress allowlist. A hostile manifest can still lie about content, return
malicious *media* URLs on hosts it declared, or serve a payload that exploits a
decoder. [PROVIDER_SECURITY.md](PROVIDER_SECURITY.md) states exactly which attacks
are prevented and which remain possible.

---

## 2. Lifecycle

```
user supplies JSON  ──▶  1. parse        (well-formed JSON, ≤ 512 KiB, depth ≤ 12)
                     ──▶  2. schema       (this document + JSON Schema)
                     ──▶  3. semantic     (capability/request pairing, templates,
                                           paths, numbering, origin derivation)
                     ──▶  4. compatibility(manifestVersion, contract range, platform)
                     ──▶  5. review screen(what it is, where it will connect, what
                                           it claims — before anything is installed)
                     ──▶  6. install      (provider_manifests + provider_entries rows)
                     ──▶  7. configure    (generated form; required fields)
                     ──▶  8. probe        (availability, never correctness)
                     ──▶  9. enable       (appears in resolution candidates)
                     ──▶ 10. remove       (rows + cache + any secrets deleted)
```

Rules:

- Steps 1–4 happen **before** the app makes a single request for this manifest.
  Validation is offline, deterministic and side-effect free.
- The review screen (5) cannot be skipped, and installation is never triggered by
  a remote list. NEXUS ships no manifest directory and fetches none.
- A manifest supplied by URL is fetched over HTTPS by the app only at the user's
  explicit request, is **shown as fetched** (raw JSON) and is validated before
  install. A failed re-validation on load disables the provider rather than
  silently trusting the stored copy.
- Validation errors are shown as a list of `path → problem` rows, exactly as the
  JSON Schema reports them, with no provider code executed to produce them.

---

## 3. Document shape

### 3.1 Top level

| Field | Type | Req. | Meaning |
|---|---|---|---|
| `manifestVersion` | `1` | yes | Schema version. Unknown values are refused with `unsupportedManifestVersion` (compatibility, not a parse error). |
| `id` | string | yes | Reverse-dns, lowercase, at least two segments, ≤ 80 chars. Permanent. Reserved: `nexus.*`, `app.*`, `com.*`. Must not collide with a built-in id. |
| `name` | string | yes | Display name, 1–60 chars. Changing it is free; changing `id` is a new provider. |
| `version` | semver | yes | The manifest's own version, shown in diagnostics. |
| `description` | string | no | ≤ 280 chars, shown on the review and Sources cards. |
| `kind` | `"streaming"` | yes | Metadata manifests are **not** defined in v1; a manifest cannot pretend to supply titles. |
| `contract` | `{min, max}` | yes | Provider-platform contract range. Outside the app's range → `unsupportedContract`, never invoked. |
| `attribution` | string | yes | Licence/credit line, ≥ 3 chars. Displayed wherever the provider's content appears. |
| `homepage` | https URL | no | Informational only; never fetched. |
| `capabilities` | array | yes | Subset of the nine streaming capabilities in [PROVIDERS.md](PROVIDERS.md) §3.2, excluding `continueWatching` (not expressible in v1). |
| `config` | array | no | Up to 12 declared fields (§4). |
| `net` | object | yes | Egress envelope (§5). |
| `requests` | object | yes | At least one of `probe`, `search`, `match`, `seasons`, `episodes`, `resolve` (§6). |
| `errors` | object | no | Status-code and message policy (§8). |
| `notice` | string | no | Line shown in the player for every stream from this provider. |

`additionalProperties` is `false` at every level. An unknown key is an error, not
a warning: silently ignoring a key is how a manifest and its adapter drift apart.

### 3.2 Capabilities must be backed

The schema enforces the pairing, so "capability theatre" fails validation:

| Capability | Requires |
|---|---|
| `search` | `requests.search` |
| `seriesMatching` | `requests.match` |
| `seasons` | `requests.seasons` |
| `episodes` | `requests.episodes` |
| `streams` | `requests.resolve` |
| `subtitles` | `requests.resolve` **and** `resolve.subtitles` |
| `audioTracks` | `requests.resolve` **and** `resolve.audio` |
| `qualities` | `requests.resolve` (more than one variant expected; not enforceable statically) |

The reverse direction is also enforced semantically: declaring
`requests.subtitles` without the `subtitles` capability is a validation error,
because the resolver would never ask for it and the player would never offer it.

---

## 4. Configuration fields

```json
{ "key": "apiKey", "label": "API key", "type": "secret",
  "required": true, "hint": "Created in your account settings." }
```

| Property | Rules |
|---|---|
| `key` | Lowercase first letter, `[a-z][a-zA-Z0-9_]{0,31}`, unique in the manifest. Referenced as `{config.<key>}`. |
| `label` | 1–60 chars, shown in the generated form. |
| `type` | `text`, `url`, `secret`, `choice`, `bool`. |
| `required` | Default `false`. A missing required value → configuration `incomplete`. |
| `defaultValue` | Bounded string. For `url`, must be an HTTPS URL. For `bool`, `"true"`/`"false"`. Must be one of `choices` when `type` is `choice`. |
| `choices` | 2–16 strings, required for `choice`. Substituted literally. |
| `pattern` | Optional regex ≤ 200 chars, applied only to the user's input for this field — never to response bodies. Invalid regex fails validation. |
| `maxLength` | 1–512, default 256. |

Storage rules (unchanged from [PROVIDERS.md](PROVIDERS.md) §6):

- `secret` values go to the platform keystore under `provider.<id>.<key>`; they
  never appear in SQLite, logs, exports, diagnostics or screenshots.
- Non-secret values go to `provider_entries.config_json` and survive restarts.
- Secrets are never echoed back; the form shows "configured" with Replace.
- A `url` field's value contributes an **additional allowed origin** at runtime
  (§5.2), which is how a self-hosted instance works without editing the manifest.

**Manifests cannot read secrets.** `{config.apiKey}` may be substituted into a
request URL, query, header or body — because *the platform* builds that request —
but a secret is never available to mapping expressions, never returned in a
stream object, and never written to a diagnostic log.

---

## 5. Network envelope

### 5.1 `net` fields

| Field | Default | Rules |
|---|---|---|
| `origins` | — | 1–8 HTTPS origins (`scheme://host[:port]`, no path). |
| `mediaHosts` | `[]` | 0–16 host patterns, `example.com` or `*.example.com`. Governs stream and subtitle URLs only. |
| `maxRedirects` | 3 | 0–5. Every hop must still be inside the allowlist. |
| `minRequestIntervalMs` | 250 | 0–10000; enforced per provider across all calls. |
| `timeoutMs` | 15000 | 1000–20000. Per-request `timeoutMs` may lower it, never raise it past the cap. |
| `maxResponseBytes` | 1048576 | 16384–2097152. Enforced while reading, not after buffering. |

### 5.2 Effective allowlist

```
allowed = net.origins
        ∪ origins of every configured `url` field
```

A request whose resolved URL leaves `allowed` is refused **before** connecting,
with `ProviderOriginRejected`. Points worth being precise about:

- The check happens on the parsed `Uri` (scheme, host, effective port), not on
  the string, so `https://api.example.com@evil.test/` and `…?next=//evil.test`
  cannot slip through.
- Redirects are followed manually (max `maxRedirects`); each hop is re-checked.
  A redirect to plain HTTP or to an unlisted host is refused, not followed and not
  silently downgraded.
- Media URLs (`resolve` variants, subtitles) may leave `allowed`, but only onto
  `mediaHosts` and only over HTTPS. Anything else → `ProviderInvalidStream`.
- Credentials are attached only to requests the adapter builds. A URL that
  happens to contain a query token is passed through unchanged; the adapter never
  appends a configured secret to a media URL.

---

## 6. Requests

### 6.1 Shared request fields

| Field | Rules |
|---|---|
| `method` | `GET` or `POST` (`HEAD` additionally for `probe`). |
| `url` | Template ≤ 512 chars, no whitespace/quotes/angle brackets. Must start with `https://` or a `{baseUrl}`/`{config.*}` placeholder. |
| `query` | ≤ 12 name→template pairs. Names `[A-Za-z][A-Za-z0-9-]{0,31}`. |
| `headers` | ≤ 10 pairs. Values are templates. `Host`, `Cookie`, `Set-Cookie`, `Content-Length`, `Connection`, `Transfer-Encoding`, `Upgrade`, `Expect` are refused by the schema. |
| `body` | `POST` only, ≤ 12 flat key→scalar pairs (string/number/bool). No nested objects, no arrays. |
| `timeoutMs` | 1000–20000, clamped by `net.timeoutMs`. |
| `maxBytes` | 16384–2097152, clamped by `net.maxResponseBytes`. |
| `notFoundStatus` | Status codes (100–599) that mean "this provider does not have it" → `ProviderNotFound`, not an error worth a retry. |

### 6.2 Placeholders

Substituted literally; **no expressions, filters, arithmetic or conditionals**.

| Placeholder | Available in | Value |
|---|---|---|
| `{baseUrl}` | all | The resolved value of the `baseUrl` URL field (the field, if declared, must have `key: "baseUrl"` to get this alias; otherwise use `{config.<key>}`). |
| `{config.<key>}` | all | A configured value (secret included). |
| `{query}` | `search`, `match` | The search text, or the anime title for `match`. |
| `{title}` | `match` | AniList title (user-preferred, else romaji, else english). |
| `{titleRomaji}`, `{titleEnglish}` | `match` | The other known titles, when present. |
| `{year}` | `match` | Start year, or empty string. |
| `{page}` | `search` | 1-based page number. |
| `{seriesId}` | `seasons`, `episodes`, `resolve` | Series id as returned by this provider. |
| `{seasonId}`, `{seasonIndex}` | `episodes` | Season id/index, or empty. |
| `{episodeId}` | `resolve` | Episode id as returned by this provider. |

Substitution rules:

1. Values are URI-encoded when placed in the path or query component
   (`Uri.encodeComponent`), so a provider id containing `/` or `&` cannot change
   the request shape.
2. A header value is refused if the substituted result contains CR, LF, `:`
   breaking rules, or exceeds 1024 bytes — header injection is impossible by
   construction, not by escaping.
3. A placeholder not in the table above is a validation error
   (`manifest.placeholder.unknown`), not an empty string.
4. `{page}` only appears in `search`; declaring it elsewhere fails validation.

### 6.3 JSON path subset

`$.data.items[*].title` — paths are read-only selectors into an already-parsed
JSON document.

| Syntax | Meaning |
|---|---|
| `$` | the document root |
| `.key` / `["key"]` | object member (`.` form: `[A-Za-z_][A-Za-z0-9_]{0,63}`) |
| `[3]` | array index |
| `[*]` | the only wildcard, at most once, taken as "all items" on a `list` and as "first" inside a `map` |

Refused by the schema and by the reader: recursive descent (`..`), filters
(`[?()]`), slices (`[1:3]`), unions (`['a','b']`), functions, regexes, and any
path over 256 characters or deeper than 8 segments.

A path that resolves to nothing yields `null` for an optional field and a
`ProviderParseFailure` for a required one. The adapter never guesses.

### 6.4 Mapping and type coercion

Each request's `map` names a **fixed** provider field. Unknown names are schema
errors, so a manifest cannot invent new model fields.

| Request | Required map fields | Optional |
|---|---|---|
| `search`, `match` | `seriesId`, `title` | `coverImage`, `synopsis`, `year`, `episodeCount` |
| `seasons` | `seasonId`, `label`, `index` | `episodeCount`, `year` |
| `episodes` | `episodeId`, `number`, `title` | `seasonId`, `durationSeconds`, `thumbnail`, `description` |
| `resolve` → variants | `label`, `uri` | `height`, `protocol`, `isDefault` |
| `resolve` → subtitles | `label`, `uri` | `language`, `isDefault` |
| `resolve` → audio | `label` | `language`, `isDefault` |

Coercion is defined once, in the adapter:

| Target | Accepted input | Otherwise |
|---|---|---|
| integer (`number`, `index`, `height`, `year`, `episodeCount`) | JSON number, integral float, or numeric string | item rejected |
| boolean (`isDefault`) | `true`/`false`, `1`/`0`, `"true"`/`"false"` | `false` |
| duration (`durationSeconds`) | number of seconds, `"mm:ss"`, `"hh:mm:ss"`, ISO-8601 duration | `null` |
| URI (`uri`) | absolute HTTPS URL, or a path resolved against the request origin | item rejected |
| protocol | `"hls"`, `"dash"`, `"progressive"`, or a URL ending `.m3u8`/`.mpd` | `defaultProtocol` |
| language (`language`) | BCP-47 or ISO-639-1/2 tag | `null` |
| text | string; numbers stringified | item rejected for required fields |

Item-level rules:

- A list item missing a **required** mapped field is dropped, and the drop is
  counted in diagnostics. An entire response with zero valid items is a
  `ProviderParseFailure`, not an empty list — an empty list is reserved for a
  genuinely empty result.
- Text is trimmed; control characters are stripped; HTML tags are **not** parsed
  (the UI renders plain text, so no HTML injection path exists).
- Strings are capped: `title` 300, `synopsis` 4000, `label` 40, `description`
  2000, `uri` 2048. Longer values are truncated, never executed or logged raw.
- Lists are capped (`maxResults`, default 30 for `search`/`match`, 2000 episodes,
  32 variants, 64 subtitle tracks, 32 audio tracks). Over-long lists are
  truncated and flagged.

---

## 7. Matching

`search` returns candidates. `match` decides whether one of them is *the* title.
The manifest chooses a fixed strategy; it cannot supply its own comparison:

| `strategy` | Accepts a candidate when |
|---|---|
| `exactTitle` | the mapped `title` equals one of the known AniList titles exactly |
| `normalisedTitle` | equal after case folding, diacritic folding, punctuation and whitespace removal, and dropping a trailing season marker (`Season 2`, `2nd Season`, `S2`) |
| `normalisedTitleAndYear` | as above **and** `year` differs by at most 1 (when both are known) |

`minConfidence` (0–1, default 0.9) is a floor on a confidence the adapter
computes — normalised equality = 1.0, one edit-distance step = 0.8, year
mismatch subtracts 0.2. It is a filter, not a ranking invented by the provider.

Ambiguity: if more than one candidate passes, the adapter returns `null` from
`match()` and records the candidates as an *ambiguous match*, which the details
screen offers as an explicit "Choose the right series" action. A provider never
picks for the user, and never returns a different title's streams.

---

## 8. Errors, timeouts and limits

### 8.1 Status mapping

| Condition | Failure |
|---|---|
| `notFoundStatus` (default `[]`) | `ProviderNotFound` |
| `errors.unauthorisedStatus` (default `401, 403`) | `ProviderAuthRejected` |
| `errors.rateLimitedStatus` (default `429`) | `ProviderRateLimited` with `Retry-After` (capped by `maxRetryAfterSeconds`) |
| other 4xx | `ProviderUpstreamError(status)`, retryable only for 408/425 |
| 5xx | `ProviderUpstreamError(status)`, retryable |
| timeout | `ProviderTimeout` |
| malformed JSON / schema-shaped mismatch | `ProviderParseFailure` |
| response over `maxBytes` | `ProviderResponseTooLarge` → surfaced as `ProviderParseFailure` with a size note |
| URL outside the allowlist | `ProviderOriginRejected` |
| media URL not on `mediaHosts`, or non-HTTPS | `ProviderInvalidStream` |
| required config missing | `ProviderNotConfigured` |
| manifest invalid at load | `ProviderManifestInvalid` (provider disabled, not retried) |
| `manifestVersion` unknown | compatibility `requiresNewerApp` |
| `contract` range excludes the app | compatibility `unsupportedContract` |

`errors.messagePath` may extract an upstream message for **diagnostics only**. It
is never shown verbatim in the UI: the failure's own copy is shown, because an
upstream message is attacker-controlled text.

### 8.2 Timeouts and pacing

- Default budget per call: search 15 s, match 10 s, seasons/episodes 15 s,
  resolve 20 s — the manifest may lower these, never raise them.
- At most 4 concurrent manifest requests app-wide; a fifth waits.
- `minRequestIntervalMs` is enforced by the adapter, not trusted to the manifest
  author to respect.
- One retry is allowed for `ProviderTimeout` and 5xx, with 500 ms + jitter, and
  only for idempotent GETs. `POST` bodies are never retried automatically.

---

## 9. Validation stages and error codes

Validation runs in this order and collects **all** errors it can, so the user
sees a complete list rather than one problem at a time.

| Stage | Code prefix | Examples |
|---|---|---|
| Parse | `manifest.parse` | invalid JSON, duplicate keys, depth > 12, > 512 KiB |
| Schema | `manifest.schema` | unknown property, bad type, pattern mismatch, unbacked capability |
| Templates | `manifest.template` | unknown placeholder, `{page}` in `resolve`, non-HTTPS absolute URL, header name forbidden |
| Paths | `manifest.path` | filter/slice syntax, depth > 8, `[*]` used twice |
| Semantics | `manifest.semantic` | `resolve.subtitles` without the capability, `seasonRelative` without `map.seasonId`, duplicate config keys, secret used in a `url` field default |
| Compatibility | `manifest.compat` | unknown `manifestVersion`, contract range excludes this build, id collides with a built-in |

Each error is reported as `{code, path, message}`; the UI shows `path` and
`message`. No error message ever includes a substituted secret.

**Known limitation — duplicate object keys.** `dart:convert` keeps the last of
two identical keys and does not report the collision, so a document with a
duplicated key is accepted with last-wins semantics rather than rejected at the
parse stage. Validation and interpretation read the *same* decoded map, so this
cannot create a validator/adapter disagreement (the security-relevant case); it
only means an author cannot rely on an error for the mistake. Detecting it would
require a second tokenizer, which this milestone deliberately did not add.

---

## 10. Versioning

Two independent numbers, with different owners:

| Number | Owner | Changes when | Effect |
|---|---|---|---|
| `manifestVersion` | this document | the *format* changes incompatibly | app supports a set; unknown → `requiresNewerApp` |
| `contract` (`min`/`max`) | [PROVIDERS.md](PROVIDERS.md) §3.1 | the *provider contract* changes breakingly | outside range → `unsupportedContract` |

Planning rules:

- v1 is additive-only: new optional keys may be added to a later
  `manifestVersion: 1` revision **only** if an older app can ignore them safely —
  and since `additionalProperties` is `false`, an older app cannot. Therefore any
  new key requires `manifestVersion: 2`, and v1 stays frozen.
- When v2 ships, the app keeps the v1 validator, so installed manifests keep
  working across an app update; a manifest is never rewritten in place.
- Deprecations are announced one release ahead in `CHANGELOG.md` and in this
  document's changelog table.
- A manifest with a valid but *newer* `manifestVersion` is installed in a
  `requiresNewerApp` state rather than deleted, so an app update revives it.

---

## 11. Rejected examples (kept in the repository)

| File | Defect | Expected error |
|---|---|---|
| `invalid-http-origin.json` | `net.origins` contains `http://` | `manifest.schema` at `/net/origins/0` |
| `invalid-unbacked-capability.json` | declares `seasons` without `requests.seasons` | `manifest.schema`, `'seasons' is a required property` |
| `invalid-executable-field.json` | a `script` key inside `requests.search` | `manifest.schema`, unexpected property |
| `invalid-jsonpath-filter.json` | JSONPath with a filter expression | `manifest.path` at `/requests/search/list` |

These are validated by the documentation check and by
`test/providers/manifest_validation_test.dart`, which asserts the documented code
and path for each committed example (see [PROVIDER_TESTS.md](PROVIDER_TESTS.md)).

---

## 12. What v1 deliberately cannot express

Documented so no one promises it later:

1. **Metadata manifests.** `kind` is fixed to `streaming`. Catalogue manifests
   need a much larger mapping surface (genres, relations, pagination cursors,
   schedules) and would compete with AniList as a source of truth. Out of scope.
2. **Provider-side continue-watching.** `continueWatching` is refused; resume
   positions stay local and, as today, provider identity is only a hint.
3. **Authenticated OAuth flows.** Secrets are static field values. Redirect-based
   browser auth belongs in a built-in adapter (Tier A).
4. **GraphQL.** `POST` bodies are flat scalars, not nested queries. A GraphQL
   source needs a Tier A adapter.
5. **Response transforms.** No arithmetic, no concatenation, no date parsing
   beyond the fixed duration formats, no conditional fields.
6. **Personalised/geo endpoints beyond a config `choice`** — the manifest can send
   a region value, but the app cannot attest or enforce region.
7. **DRM.** No key exchange, no licence endpoints, no `drm` capability. A stream
   URL that is DRM-protected will simply fail in the player; the format offers no
   mechanism to defeat that, by design.

---

## 13. Implementation notes (implemented)

The files exist, at the paths this document originally reserved:

```
lib/integrations/streaming/manifest/
├── provider_manifest.dart            // immutable model, built only after validation
├── manifest_validator.dart           // stages 1–4 of §9, returns List<ManifestError>
├── manifest_error.dart               // ManifestError + validation status
├── json_path_reader.dart             // §6.3 subset + depth/length guards
├── template_binder.dart              // §6.2 substitution + header hardening
├── manifest_http.dart                // allowlist, redirects, caps, pacing, retry
└── manifest_streaming_provider.dart  // Tier B adapter + ManifestProviderFactory
```

Decisions taken during implementation:

- **No JSON-Schema package and no bundled schema asset.** The validator is a
  hand-written, in-repository implementation of this document and of
  `schema/provider-manifest.v1.schema.json` (decision D3). The schema file stays
  the reference an author reads; the committed `valid-*`/`invalid-*` examples are
  the cross-check, and the validator has no dependency to drift.
- **`ManifestStreamingProvider` implements the same `StreamingProvider` contract
  as Tier A.** The resolver cannot tell them apart (proved by
  `test/providers/manifest_adapter_test.dart`).
- **One HTTP seam.** `ManifestTransport` is the only place a socket is opened;
  every security decision (allowlist, redirects, caps, pacing, retries, status
  policy) lives above it in `ManifestHttp`, so a test cannot bypass them with a
  different transport.
- **Media URLs are validated before return**, in the adapter: HTTPS, length,
  control characters, and host membership in `mediaHosts` or an allowed origin.
- **Host-side DNS resolution is never used for allowlist decisions**; the
  allowlist compares the parsed URL's host string (see
  [PROVIDER_SECURITY.md](PROVIDER_SECURITY.md) §3 for the honest limits of that).
- **Not implemented here (2.2c/2.2d):** the install/review screen, generated
  configuration form, keystore secret storage, manifest re-validation on load,
  removal, and the Sources state actions. `ManifestProviderFactory.create`
  returns a provider or a typed failure for one stored document, which is the
  seam those milestones call.
