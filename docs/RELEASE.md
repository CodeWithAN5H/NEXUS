# NEXUS — Release and Signing Policy

This file is the source of truth for how NEXUS is versioned, signed and distributed. Android updates are unforgiving: a changed application id or signing key means every installed copy must be uninstalled, which destroys user data.

## 1. Permanent identity

| Item | Value | Status |
|---|---|---|
| Application id | `app.nexus` | **Provisional** — must be confirmed by the owner before the first published APK, then never changed |
| Release keystore | `nexus-release.jks`, held by the owner (and in GitHub Actions secrets) | **Not created yet** — requires owner action; see §3 |
| Signing algorithm | RSA 2048, validity 10 000 days | Planned |

`applicationId` and `namespace` live in `android/app/build.gradle.kts`. Changing either after distribution is a breaking change for every installed copy.

## 2. Versioning

| Field | Source | Rule |
|---|---|---|
| `versionName` | `pubspec.yaml` `version:` before `+` (e.g. `0.1.0-alpha`) | Human-facing; pre-1.0 uses `-alpha` / `-beta` |
| `versionCode` | `pubspec.yaml` after `+` (e.g. `0.1.0-alpha+1`) | **Must increase by at least 1 for every distributed build.** Android refuses to install an update with an equal or lower code |

The release tag must equal `v<versionName>` — the workflow fails if `pubspec.yaml` and the tag disagree.

Checklist before every release:

1. Bump the code after `+`.
2. Update `AppConstants.appVersion` and `AppConstants.versionCode` (shown in Settings/Profile).
3. Update `CHANGELOG.md` and `PROJECT_STATUS.md`.
4. Commit, push, then tag.

## 3. Establishing the signing identity (owner action, one time)

The keystore must be generated **on the owner's own machine**, not in this cloud workspace. A file created here cannot be safely preserved or transferred to you, and the workflow below never needs it to exist on any server.

### 3.1 Generate the key

```bash
keytool -genkeypair -v \
  -keystore nexus-release.jks \
  -alias nexus \
  -keyalg RSA -keysize 2048 -validity 10000
```

Use a strong, unique password and record it in a password manager.

### 3.2 Back it up — this is the critical step

- Keep the `.jks` file in **at least two** independent, durable places: an encrypted backup plus offline media (USB drive kept separately).
- Back up the password and alias alongside it (e.g. encrypted vault note).
- **Losing this file means no future version can ever update an installed copy.** Users would have to uninstall — losing their library, history and settings.
- Never email it, never paste it into a chat, never commit it.

### 3.3 Add it to GitHub Actions secrets

Only repository secrets are used; no credentials live in the repo or in a build log.

In the repository: **Settings → Secrets and variables → Actions → New repository secret**, add:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The keystore encoded as base64, one line |
| `ANDROID_KEYSTORE_PASSWORD` | Store password |
| `ANDROID_KEY_ALIAS` | `nexus` |
| `ANDROID_KEY_PASSWORD` | Key password |

Encode the keystore on your machine:

```bash
# macOS
base64 -i nexus-release.jks | tr -d '\n' | pbcopy
# Linux
base64 -w0 nexus-release.jks
# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("nexus-release.jks")) | Set-Clipboard
```

Paste the output into the `ANDROID_KEYSTORE_BASE64` secret. The workflow decodes it into `$RUNNER_TEMP`, uses it, and deletes it — it is never written to the workspace or a release asset.

### 3.4 Verify the identity

The workflow refuses to publish if the APK is debug-signed, and prints the certificate to the run summary. To check locally:

```bash
$ANDROID_HOME/build-tools/<version>/apksigner verify --print-certs app-release.apk
```

Expected: your certificate DN, **not** `CN=Android Debug`.

## 4. Publishing a release

Releases are built and published by CI (`.github/workflows/release.yml`), never from a developer machine, so the signing key never leaves its secret store.

```bash
# 1. Land the milestone on main
git push origin main

# 2. Tag it (must match pubspec.yaml version)
git tag -a v0.1.0-alpha -m "NEXUS v0.1.0-alpha"
git push origin v0.1.0-alpha
```

The workflow then:

1. Checks the tag against `pubspec.yaml`.
2. Fails immediately if any signing secret is missing.
3. Runs `flutter analyze` and `flutter test`.
4. Decodes the keystore, writes `android/key.properties`, builds the release APK.
5. Verifies the package id, the signing certificate (rejects debug signing) and computes SHA-256.
6. Creates the GitHub Release, attaching `NEXUS-<tag>-universal.apk` and `SHA256SUMS.txt`, with generated notes plus install/signature/checksum instructions.
7. Deletes the keystore and `key.properties` from the runner.

A failing analyze or test run blocks the release — the tag stays, but no APK is published.

You can also publish without touching a terminal: **Actions → Release APK → Run workflow**, enter `v0.1.0-alpha`. That builds the branch you selected and creates the tag at that commit, so no local tag push is needed. Re-running it for an existing tag rebuilds and replaces the attached assets.

Note that the tag must match `pubspec.yaml` (`version: 0.1.0-alpha+N` → tag `v0.1.0-alpha`); the workflow fails early otherwise.

## 5. What a release contains

1. `NEXUS-<tag>-universal.apk` — signed with the permanent key
2. `SHA256SUMS.txt`
3. Release notes: generated commit notes plus install instructions, signature statement, checksum usage and links to `CHANGELOG.md` / `PROJECT_STATUS.md`

## 6. In-place updates

An APK updates an installed copy only when **all** hold:

- identical application id,
- identical signing certificate,
- `versionCode` greater than the installed build,
- the device permits installation from that source.

Consequences:

- A debug-signed APK can never upgrade a release-signed build (and vice versa): Android rejects it with a signature mismatch, and the only workaround is uninstalling — which deletes data. This is why no debug build is ever published.
- Downgrades are refused. A broken release is fixed by publishing a **higher** versionCode, never by re-tagging lower.
- Verify with `adb install -r <new apk>` over the previous release before announcing it: this is the only real proof that updates work.

## 7. Local data across updates

Library, watch history, positions and settings live in SQLite (`nexus.sqlite`) in app-private storage and survive in-place updates. Schema changes ship with additive migrations (`DATABASE.md` §3); a release must never ask users to clear app data or reinstall.

## 8. Release checklist

- [ ] Application id confirmed and permanent
- [ ] Version name and code bumped, mirrored in `AppConstants`
- [ ] `CHANGELOG.md` and `PROJECT_STATUS.md` updated with honest verification status
- [ ] `dart format`, `flutter analyze`, `flutter test` clean locally
- [ ] Commit pushed to `main`, tag matches `pubspec.yaml`
- [ ] Signing secrets present in repository settings
- [ ] Workflow run green; certificate in the summary is the release key
- [ ] APK asset and `SHA256SUMS.txt` present on the Release page
- [ ] `adb install -r` over the previous release verified on a device
- [ ] Known issues and unverified areas listed in the notes
