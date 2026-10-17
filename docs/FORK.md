# This fork

`kccarlos/hermes-conduit` is a fork of [kaishi00/hermes-conduit](https://github.com/kaishi00/hermes-conduit)
for a personally hosted Hermes Agent. It tracks upstream (`git fetch upstream && git merge upstream/main`)
and carries a small set of changes.

## What differs from upstream

| Area | Change |
|---|---|
| Identity | Bundle ID `io.github.kccarlos.conduit`, Automatic signing locally and manual signing in CI (`project.ci.yml`), no CarPlay entitlement (`project.yml`, `Conduit.entitlements`). The Apple team ID is not committed: `project.yml` reads `DEVELOPMENT_TEAM` from the environment when the project is generated. |
| Push relay | The default relay URL comes from the build (`CONDUIT_DEFAULT_RELAY_URL` at project generation, stored in `Info.plist` as `ConduitDefaultRelayURL`; upstream's `push.milim.dev` when empty), so it is not committed. The registration uses the app's real bundle ID instead of the hard-coded `com.milim.relay`. The shared relay `push.milim.dev` only accepts upstream's bundle ID, so a fork **must** run its own relay (the `relay/` directory of [hermes-conduit-notifier](https://github.com/kaishi00/hermes-conduit-notifier), with an APNs key for this bundle ID). Set `CONDUIT_DEFAULT_RELAY_URL` to your own HTTPS host. |
| Gemini Live on Vertex AI | `GeminiLiveProtocol.qualifiedModel` passes Vertex resource names (`projects/…`) through unchanged. The server side is [`docs/fork/conduit-push-vertex-live.patch`](fork/conduit-push-vertex-live.patch), a patch for the `conduit_push` plugin: with `CONDUIT_GEMINI_LIVE_PROVIDER=vertex` it mints a short-lived service-account OAuth token and returns the Vertex WebSocket URL. Live models are served from `us-central1`, not `global`. |
| CI | `.github/workflows/testflight.yml` builds and uploads to TestFlight. `nightly.yml` is kept (CI contract tests read it) but disabled in the fork; `opencode-review.yml` is removed. |
| Targets | The Location Push extension is dropped: its entitlement needs Apple's approval. Every other identifier, App Group and keychain service is renamed from `com.milim.relay` to `io.github.kccarlos.conduit`. |

## Building locally

```sh
DEVELOPMENT_TEAM=TEAMID CONDUIT_DEFAULT_RELAY_URL=https://your-relay.example xcodegen generate
```

Local builds use automatic signing with your own Xcode account. The macOS 26+ toolchains need the Metal
component (`xcodebuild -downloadComponent MetalToolchain`).

## TestFlight from CI

`testflight.yml` runs on pushes to `main` that change more than docs and tests, on `v*` tags, and manually
(`gh workflow run testflight.yml`). It archives and exports with **manual signing** and uploads with an App
Store Connect API key. It never submits for review. Builds show up in TestFlight after Apple's processing,
usually a few minutes later.

**Build number** is `date -u +%y%m%d%H%M`. App Store Connect needs it to rise within a version, so a manual
upload from a Mac must use the same UTC format or it is rejected as lower than a CI build.

### Why manual signing

With automatic signing, `xcodebuild archive` signs with an Apple Development certificate. A fresh runner has
no private key for one, so Xcode asks Apple to create a new "Created via API" certificate on **every run**,
and Apple caps how many may exist; the pile eventually blocks every build. Manual signing uses only the
shared Apple Distribution certificate and App Store profiles, so CI creates nothing.

### Secrets

The only GitHub secret is `OP_SERVICE_ACCOUNT_TOKEN`, in the `testflight` environment (only `main` and `v*`
tags can use it, so pull requests never see it). Everything else is read from the 1Password vault `github`:

| 1Password item | Fields | Used for |
|---|---|---|
| `app-store-connect-api-key` | `key_id`, `issuer_id`, `p8_base64` | uploading to App Store Connect |
| `apple-distribution` | `p12_base64`, `password` | the Apple Distribution certificate and key |
| `conduit-provisioning-profiles` | `profiles_base64` | zip of the five App Store profiles |
| `conduit` | `team_id`, `relay_url` | kept out of the public repository |

1Password's CLI fails intermittently on macOS 27 runners, so the workflow loads it in up to three attempts.

```sh
op read -n "op://Private/OP service account github-actions/credential" \
  | gh secret set OP_SERVICE_ACCOUNT_TOKEN -R kccarlos/hermes-conduit --env testflight
```

(`-n` matters: with a trailing newline every load fails with "(400) structure of request was invalid".)

### Refreshing the profiles

The five profiles ("Conduit App App Store", "… NotificationService …", "… widgets …", "… watchkitapp …",
"… watchkitapp.widgets …") expire with the distribution certificate (September 2027) and must be recreated
when a target gains a capability or a new target is added. App IDs and App Groups are registered by opening
the project once in Xcode with your account (the API key cannot manage App Groups). Then:

```sh
scripts/fork-ci/refresh-profiles.sh      # recreates the profiles with asc and updates the 1Password item
```

The profile names are referenced in `project.ci.yml` and `scripts/fork-ci/write-export-options.sh`.
