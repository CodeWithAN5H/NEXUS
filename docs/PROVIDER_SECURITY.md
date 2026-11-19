# NEXUS — Provider Security and Reliability Review

**Status:** review for v0.2.0-alpha. It documents protections that can actually be
built in this app, and — just as important — attacks that will remain possible.
The manifest protections marked implemented below (S1, S2, S4, S5, S6, S7) ship
with milestone 2.2b in `lib/integrations/streaming/manifest/`; S3 and S8–S11
belong to 2.2c/2.2d. The format is defined in
[PROVIDER_MANIFEST.md](PROVIDER_MANIFEST.md), the platform in
[PROVIDERS.md](PROVIDERS.md).

---

## 1. The honest summary first

A declarative manifest is **not** a sandbox. It is:

1. a data format with no code execution path of any kind;
2. an egress allowlist enforced on parsed URLs before any socket opens;
3. a bounded interpreter (response size, item count, path depth, timeouts,
   redirects, concurrency, pacing);
4. a fixed mapping from JSON fields to known app models.

That combination removes whole classes of attack — arbitrary code execution,
filesystem access, credential exfiltration to undeclared hosts, unbounded
resource use — but it does **not** make a hostile provider safe to trust. A
hostile manifest can still serve misleading content, point media at a host it
declared, log the user's IP address, or feed a malformed stream to `libmpv`.

NEXUS therefore treats user-added providers as **untrusted input to a trusted
interpreter**, not as isolated programs. There is no OS-level process boundary,
no per-provider memory sandbox, and no way to audit what an origin does with the
request it receives. Statements to the contrary would be marketing.

---

## 2. Assets and trust boundaries

| Asset | Where it lives | Who may touch it |
|---|---|---|
| Library, history, positions, settings | SQLite | App only |
| Provider secrets (API keys, tokens) | Platform keystore | Adapter, per request; never the UI |
| Stream URLs and session headers | In memory only | Player, for the session |
| Manifest JSON | SQLite (validated copy) | Validator + adapter |
| User's IP address and request pattern | Sent to each provider origin | **Unavoidable** — the device talks directly |
| Signing key | CI secrets | Nobody in the app |

Boundaries crossed by a provider, in order: parse → validate → allowlist →
request → response cap → JSON parse → mapping → model. Every one of those
crossings has a check; the checks are listed by attack below.

---

## 3. Threats and protections

### 3.1 Server-side request forgery

NEXUS has no server, so classic SSRF (making a backend fetch an internal URL)
becomes "make the *device* fetch something it should not".

| Vector | Protection | Residual risk |
|---|---|---|
| Manifest declares `https://192.168.1.1/…` or `https://169.254.169.254/…` | The `origins`/`mediaHosts` patterns require a dotted DNS name with an alphabetic TLD, so **IP-literal hosts cannot be declared at all** | A domain that resolves to a private address still works |
| Manifest declares a public domain that resolves to `127.0.0.1` / RFC1918 (DNS rebinding) | Not preventable client-side without pinning DNS; the app does not attempt to | Partial: the request is a plain HTTPS GET with no credentials on the media path, and the allowlist still governs credentials |
| Manifest fetches a URL supplied in a response (open redirect into a chosen host) | Only five fixed request templates exist; the adapter never fetches a URL taken from a response body except media/subtitle URLs, which must match `mediaHosts` | Media URLs on an attacker-declared host can be anything on that host |
| URL tricks: `https://api.example.com@evil.test/`, `//evil.test`, `%2f`, trailing dot | Allowlist compares the **parsed** `Uri`'s scheme/host/port; the port is normalised; single- and double-slash forms cannot change the parsed host | IDN/punycode homographs (`аpi.example.com` with a Cyrillic `а`) are visually confusing but are different hosts, so they fail the allowlist |
| Redirect to an internal or foreign host | Redirects are followed manually, max `maxRedirects` (≤ 5), each hop re-checked against the allowlist; HTTP downgrade refused | None beyond "an allowed host may redirect internally" |
| Self-hosted provider on a LAN address | Allowed **only** through a user-typed `url` configuration field, which extends the allowlist for that provider; never declarable in `origins` | The user chose it; a typo points at the wrong device |

Credentials are attached per request by the adapter, never inherited: a
redirect to a different host drops `Authorization`/`X-Api-Key` (§3.4).

### 3.2 Origin and host validation

- Effective allowlist = `net.origins` ∪ origins of configured `url` fields.
- Comparison is on `Uri.scheme`, `Uri.host` (lowercased, punycode-normalised) and
  effective port; default ports are folded (`https://x` == `https://x:443`).
- Only `https` is accepted at runtime, in every build: the implemented adapter
  has no development exception, so a loopback HTTP base URL is refused like any
  other downgrade. (This is stricter than the original note above proposed; a
  local-dev exception was not added because nothing needs it yet.)
- Wildcards exist only in `mediaHosts` (`*.example-cdn.net`), never in `origins`,
  and never match the apex domain implicitly.
- A provider whose request URL cannot be proven inside the allowlist is refused
  at validation time, so the user sees the problem before installing.

### 3.3 Malicious or malformed responses

| Attack | Protection |
|---|---|
| Non-JSON / truncated body | Parse guarded; failure is `ProviderParseFailure`, never an exception from the JSON decoder reaching the UI |
| Wrong shape (`[]` where an object is expected) | Every mapping step is typed and null-tolerant; a wrong type fails that item or the request, never the app |
| Huge JSON depth / nesting bomb | Parsing is preceded by a size cap; the JSON reader tolerates deep nesting without recursion, and mapping paths are depth-limited |
| Decompression bomb (small gzip, huge output) | Byte counting happens on **decoded** bytes while streaming, not on `Content-Length`; exceeding `maxBytes` aborts the read |
| Huge arrays | `maxResults`, 2000 episodes, 32 variants, 64 subtitles, 32 audio tracks; excess truncated and flagged |
| HTML/script in text fields | Titles and synopses are plain `Text` widgets, tags are not parsed, control characters stripped; there is no `WebView` anywhere in the app |
| Path traversal in ids | Ids are opaque strings used as query values and database keys, never as file paths; nothing opens a file by provider-supplied name |
| Integer overflow in durations | Seconds are parsed to `int` with bounds (0 … 24 h) and clamped |
| Regex denial of service | `pattern` in config is bounded to 200 chars and only ever applied to short user input, not to response bodies; Dart's `RegExp` has no timeout, so a pathological *user* pattern could still stall a form (§5, R4) |
| Unicode/zero-width spoofing in titles | Text is displayed as-is; the UI never renders a provider-supplied icon or masquerades a provider as "verified" — attribution is shown verbatim |

### 3.4 Sensitive configuration

- Secrets (`type: secret`) live in the platform keystore, keyed
  `provider.<id>.<key>`; they are absent from SQLite, preference files, logs,
  diagnostics, crash reports and exports.
- Secrets are substituted only into the adapter-built request (URL, query,
  header, flat POST body), never into media URLs, never into mapping output.
- Secret fields are write-only in the UI: "configured" plus Replace. Nothing
  echoes a value, including validation errors.
- Log redaction: URLs are logged without query strings and fragments; header
  names may be logged, values never.
- Diagnostics are opt-in, in-memory, per provider, and can be cleared; they are
  shown with the same redaction, and exporting them is a user action with a
  warning.
- `FLAG_SECURE` on Android for the secret-entry screen is a planned, small
  addition (§5, S3) — not implemented today.
- Config values are never sent anywhere except the provider's own requests, and
  never to an origin outside the allowlist.

### 3.5 Invalid or hostile stream URLs

Player-facing validation, applied before `PlaybackSession.load()`:

| Rule | Failure |
|---|---|
| Scheme must be `https` (dev loopback excepted) | `ProviderInvalidStream` |
| Host must match `mediaHosts` (or an allowed origin) | `ProviderInvalidStream` |
| `file:`, `content:`, `intent:`, `data:`, `javascript:`, `about:` refused | `ProviderInvalidStream` |
| URL length ≤ 2048, no control characters | variant dropped |
| Query strings are passed through unchanged; no secret is appended | — |
| At least one variant must survive, else the episode reports "no playable stream" and the rest of the screen stays usable | `EpisodeStream.isEmpty` handling |

Media URLs are **not** proxied, rewritten or redacted: the player fetches exactly
what the provider returned. That is a deliberate privacy/property trade-off — a
proxy would need a backend, and PRD §3 forbids one.

A DRM-protected stream is not detected or decrypted. It fails in the player, and
the format provides no licence or key mechanism, by design.

### 3.6 Provider isolation and failure containment

There is no process isolation; containment is therefore enforced on behaviour:

| Concern | Protection |
|---|---|
| Runaway requests | Per-call timeout, one retry for idempotent GETs only, cancellation on screen disposal |
| Device load | Global cap of 4 concurrent manifest requests plus 4 concurrent probes; `minRequestIntervalMs` pacing per provider |
| Licensing/rate abuse | Pacing plus the `Retry-After` countdown; the app never retries a 429 before the hinted delay |
| One provider breaking a screen | Every call returns `ProviderFailure`; resolution collects per-provider failures and the Episodes tab stays usable |
| Leaked resources | Mandatory `dispose()` on disable/remove; HTTP clients closed, timers cancelled |
| Cross-provider contamination | No provider receives another's configuration, credentials or cached results; match caches are keyed by `(providerId, animeId)` |
| Stale resume hints | A saved `provider_id` is a hint only; if that provider is gone, the title is re-resolved rather than failing |
| Manifest tampering at rest | The stored manifest is re-validated on load; failure disables that provider only, never blocks app start |
| Manifest changing under the user | Manifests are fixed at install. The *content* they point to can change at any time — which is why the review screen shows the origin and capabilities, and why installed manifests are listed with their version |

### 3.7 Legal and ethical constraints

- No DRM circumvention, key extraction, paywall bypass or access-control bypass
  exists in the format or the adapter, and none will be added as a "feature".
- The app ships **no** provider directory and fetches none; a manifest is supplied
  by the user or by the project owner for an authorised source.
- Provider attribution is mandatory and displayed wherever its content appears.
- Reviewing a manifest is allowed to be a human gate: the checklist in
  [PROVIDERS.md](PROVIDERS.md) §13 applies before a built-in adapter ships.

---

## 4. Privacy consequences of a user-added provider

Stated plainly because the UI must not imply otherwise:

1. The device talks directly to the provider's hosts, so the provider sees the
   user's IP, user agent, timing and search terms — exactly as a browser would.
2. The provider can correlate searches with later stream requests from the same
   address.
3. The app sends no analytics, but the provider's own server may.
4. Media hosts named by the provider receive the playback requests, including any
   `streamHeaders` the manifest declared.

The install/review screen says (paraphrased, final copy decided with the UI work):
"Requests from this source come from your device directly. NEXUS does not proxy
them and cannot hide your address from it."

---

## 5. What is *not* protected

| ID | Residual risk | Why it is accepted | Mitigation if it ever matters |
|---|---|---|---|
| R1 | A malicious manifest can return content that is not what its title claims | The interpreter cannot judge truthfulness of remote data | Attribution shown; user-supplied origins only; no auto-directory |
| R2 | A declared origin can serve malware-laden media to `libmpv` | Treating media as trusted requires a sandboxed player, which does not exist on this stack | Keep `media_kit` current; refuse non-HTTPS; never auto-play an unlabelled source |
| R3 | DNS rebinding to a private address | Client-side prevention needs DNS pinning/DoH control the app does not have | Refuse IP-literal origins (done); require user intent for LAN base URLs |
| R4 | A pathological user-supplied regex could stall a config form | Bounded length, user-entered, local only | Run validation off the UI isolate if it becomes a problem |
| R5 | A provider can exhaust the user's mobile data with large media | Media size is the player's domain, outside the manifest | Data-saver/wifi-only preference is a v0.3 candidate |
| R6 | Credentials are protected by the platform keystore, not by app crypto | The keystore is the correct boundary on Android/Windows | none needed |
| R7 | Secrets can appear on screen if the user screenshots the entry field | `FLAG_SECURE` is applied on Android; other platforms still rely on the user | Extend to other platforms only if the platform supports it (2.5a) |
| R8 | A provider can stop working at any time (API change, takedown) | External dependency | Typed failures + diagnostics keep it explicable |

**No claim is made that a manifest is sandboxed, audited or safe.** What is
claimed, and is testable (see [PROVIDER_TESTS.md](PROVIDER_TESTS.md)): it cannot
execute code, cannot reach an undeclared host, cannot read local files, cannot
exceed its declared resource envelope, and cannot take the app down with it.

---

## 6. Implementation checklist (v0.2)

| ID | Requirement | Milestone |
|---|---|---|
| S1 | Allowlist enforced on parsed URIs, before connecting, for every request and every redirect hop | 2.2b |
| S2 | Response byte cap counted on decoded bytes while streaming | 2.2b |
| S3 | `FLAG_SECURE` on secret entry; keystore-backed secret store | 2.2c — implemented (Android `FLAG_SECURE`, `flutter_secure_storage`) |
| S4 | Log redaction helper used by every provider log line | 2.2b |
| S5 | Header-template hardening (refuse CR/LF/`:` injection, 1024-byte cap) | 2.2b |
| S6 | Media URL validator (scheme + `mediaHosts` + length) before the player | 2.3 |
| S7 | Concurrency cap + per-provider pacing + `Retry-After` clamping | 2.2b |
| S8 | Manifest re-validation on load; failure disables only that provider | 2.2c — implemented |
| S9 | Diagnostics buffer, opt-in, cleared on remove, redacted on export | 2.2d |
| S10 | Review screen showing id, origin, capabilities, hosts before install | 2.2d |
| S11 | `dispose()` on every path (disable, remove; app background in 2.2d) | 2.2c — implemented for disable and remove |
| S12 | Security regression tests T-B22…T-B24, T-B34…T-B37, T-B45, T-P06, T-P07 | 2.2b–2.2c |

Implemented in 2.2b and covered by `test/providers/manifest_adapter_test.dart`:
**S1** (allowlist on parsed URIs before connecting, re-checked on every redirect
hop), **S2** (decoded-byte cap counted while reading), **S4**
(`ProviderRedaction` for URIs, headers and secrets), **S5** (header templates
refuse CR/LF and values over 1024 bytes), **S6** (media URL validator: scheme,
`mediaHosts`, length, control characters) and **S7** (4-request gate for manifest
work, per-provider pacing, clamped `Retry-After`).

Implemented in 2.2c and covered by `test/providers/provider_lifecycle_test.dart`
and `test/providers/provider_sources_ui_test.dart`: **S3** (a `type: secret`
value is written to `flutter_secure_storage` under `provider.<id>.<key>`, never to
SQLite, and `FLAG_SECURE` is applied on Android while a credential field can be
shown), **S8** (every stored manifest goes through `ManifestValidator` on load
and through `ManifestProviderFactory` before a provider is built; a bad row
produces a typed failure and disables only itself) and **S11** for disable and
removal (the registry controller disposes every instance it drops).

Still to come: **S9** (diagnostics buffer), **S10** (the full review-screen field
set is present in 2.2c, the remainder is 2.2d) and **S11** for app-background
disposal — 2.2d.

Honest limits that remain true of the implemented adapter:

- **Duplicate JSON keys** are last-wins (`dart:convert`) rather than a parse
error; validation and the adapter read the same decoded map, so this is an
author-ergonomics gap, not a bypass.
- **DNS rebinding** is still unprevented (§5 R3); only IP-literal *origins* are
refused outright.
- **Pacing** is checked-then-waited without a lock, so two simultaneous calls on
  one provider can both pass the check before either sends. The global 4-request
  gate bounds the effect; it is not a rate limiter against a hostile provider.
- A **media URL** on a declared `mediaHosts` suffix is passed to the player
  unchanged: the app does not proxy, rewrite or inspect media bytes.
