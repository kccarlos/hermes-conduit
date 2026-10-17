#!/usr/bin/env bash
# Write an ExportOptions.plist that exports AND uploads to App Store Connect
# (TestFlight) with manual signing: the Apple Distribution certificate and
# one App Store profile per bundle ID (the names match project.ci.yml).
# Usage: write-export-options.sh <output.plist>
# Env:   DEVELOPMENT_TEAM (required)
set -euo pipefail
out="${1:?usage: write-export-options.sh <output.plist>}"
team="${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM}"
id=io.github.kccarlos.conduit
cat >"$out" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>${team}</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>${id}</key><string>Conduit App App Store</string>
    <key>${id}.NotificationService</key><string>Conduit NotificationService App Store</string>
    <key>${id}.widgets</key><string>Conduit widgets App Store</string>
    <key>${id}.watchkitapp</key><string>Conduit watchkitapp App Store</string>
    <key>${id}.watchkitapp.widgets</key><string>Conduit watchkitapp.widgets App Store</string>
  </dict>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
plutil -lint "$out"
