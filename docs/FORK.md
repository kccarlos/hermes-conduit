# This fork

`kccarlos/hermes-conduit` is a fork of [kaishi00/hermes-conduit](https://github.com/kaishi00/hermes-conduit)
for a personally hosted Hermes Agent. It tracks upstream (`git fetch upstream && git merge upstream/main`)
and carries a small set of changes.

## What differs from upstream

| Area | Change |
|---|---|
| Identity | Bundle ID `io.github.kccarlos.conduit`, Automatic signing, no CarPlay entitlement (`project.yml`, `Conduit.entitlements`). The Apple team ID is not committed: `project.yml` reads `DEVELOPMENT_TEAM` from the environment when the project is generated. |
| Push relay | The default relay URL comes from the build (`CONDUIT_DEFAULT_RELAY_URL` at project generation, stored in `Info.plist` as `ConduitDefaultRelayURL`; upstream's `push.milim.dev` when empty), so it is not committed. The registration uses the app's real bundle ID instead of the hard-coded `com.milim.relay`. The shared relay `push.milim.dev` only accepts upstream's bundle ID, so a fork **must** run its own relay (the `relay/` directory of [hermes-conduit-notifier](https://github.com/kaishi00/hermes-conduit-notifier), with an APNs key for this bundle ID). Set `CONDUIT_DEFAULT_RELAY_URL` to your own HTTPS host. |
| Gemini Live on Vertex AI | `GeminiLiveProtocol.qualifiedModel` passes Vertex resource names (`projects/…`) through unchanged. The server side is [`docs/fork/conduit-push-vertex-live.patch`](fork/conduit-push-vertex-live.patch), a patch for the `conduit_push` plugin: with `CONDUIT_GEMINI_LIVE_PROVIDER=vertex` it mints a short-lived service-account OAuth token and returns the Vertex WebSocket URL. Live models are served from `us-central1`, not `global`. |
| CI | `.github/workflows/testflight.yml` builds and uploads to TestFlight. Upstream's `nightly.yml` and `opencode-review.yml` are removed. |

## Building locally

```sh
DEVELOPMENT_TEAM=TEAMID CONDUIT_DEFAULT_RELAY_URL=https://your-relay.example xcodegen generate
```

## TestFlight from CI

`testflight.yml` runs on pushes to `main` that change more than docs, on `v*` tags, and manually
(`gh workflow run testflight.yml`). It archives with `xcodebuild -allowProvisioningUpdates` using an
App Store Connect API key (cloud signing), then `-exportArchive` with `destination = upload`. It never
submits for review. Builds appear in TestFlight after Apple's processing, usually a few minutes.

**Build number** is `date -u +%y%m%d%H%M`. App Store Connect needs it to rise within a version, so a
manual upload from a Mac must use the same UTC format or it will be rejected as lower than a CI build.

### Secrets and variables

They live in the `testflight` environment, which only `main` and `v*` tags may use, so pull
requests never see them.

| Name | Kind | Notes |
|---|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | secret | Key ID of the API key |
| `APP_STORE_CONNECT_ISSUER_ID` | secret | Issuer ID (Users and Access > Integrations) |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | secret | `base64 -i AuthKey_XXXX.p8` |
| `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD` | secret, optional | Apple Distribution certificate; only needed if cloud signing cannot supply one (below) |
| `DEVELOPMENT_TEAM` | secret | Apple Developer Team ID. A secret rather than a variable because this repository is public and variables are printed in logs |
| `CONDUIT_DEFAULT_RELAY_URL` | secret, optional | The push relay the app uses unless Settings overrides it |
| `CI_MACOS_RUNNER`, `CI_XCODE_APP` | variable, optional | Defaults `xcode-27` and `/Applications/Xcode_27.0.app`; fall back to `macos-26` and `/Applications/Xcode_26.6.app` if the image is unavailable |

```sh
R=kccarlos/hermes-conduit
gh secret set APP_STORE_CONNECT_API_KEY_ID     -R $R --env testflight --body 'KEYID'
gh secret set APP_STORE_CONNECT_ISSUER_ID      -R $R --env testflight --body 'ISSUER-UUID'
base64 -i AuthKey_KEYID.p8 | gh secret set APP_STORE_CONNECT_API_KEY_P8_BASE64 -R $R --env testflight
gh secret set DEVELOPMENT_TEAM -R $R --env testflight --body 'TEAMID'
gh secret set CONDUIT_DEFAULT_RELAY_URL -R $R --env testflight --body 'https://your-relay.example'
```

### Things that went wrong elsewhere, so check them first

- The API key needs the **Admin** role for cloud signing. An App Manager key fails the export with
  "Cloud signing permission error".
- A fresh runner often cannot create an Apple Distribution certificate on its own. If the export says no
  signing certificate was found, export the certificate from Keychain Access as a `.p12` and set the two
  `APPLE_CERTIFICATE_*` secrets.
- `gh secret set` reads only stdin when it is not run interactively; an empty password makes the `.p12`
  import fail with a "passphrase is not correct" error.
- Create the app record in App Store Connect before the first upload (the API cannot), and make sure the
  bundle ID has Push Notifications enabled.
- Deleting the secrets or the key makes the job fail at "Install signing material"; the app is unaffected.
