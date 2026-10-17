#!/usr/bin/env bash
# Recreate the five App Store provisioning profiles with the asc CLI and store
# them in the 1Password item conduit-provisioning-profiles (vault github).
# Needs: asc logged in (App Manager or Admin key), op signed in, zip.
# The App IDs must already exist with their capabilities (open the project once
# in Xcode); this script only makes profiles. Run it when a target changes or
# before the distribution certificate expires.
set -euo pipefail
prefix=io.github.kccarlos.conduit
dist="${DIST_CERT_ID:-}"
if [[ -z "$dist" ]]; then
  dist="$(asc certificates list --output json | python3 -c "
import json,sys
c=[x for x in json.load(sys.stdin)['data'] if x['attributes']['certificateType'] in ('DISTRIBUTION','IOS_DISTRIBUTION')]
print(c[0]['id'] if len(c)==1 else '')")"
  [[ -n "$dist" ]] || { echo "Set DIST_CERT_ID: there is not exactly one distribution certificate" >&2; exit 1; }
fi
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
asc bundle-ids list --output json | python3 -c "
import json,sys
for b in json.load(sys.stdin)['data']:
    i=b['attributes']['identifier']
    if i=='$prefix' or i.startswith('$prefix.'): print(b['id'], i)" >"$work/ids.txt"
[[ "$(wc -l <"$work/ids.txt")" -eq 5 ]] || { echo "Expected 5 bundle IDs under $prefix" >&2; cat "$work/ids.txt" >&2; exit 1; }
while read -r id ident; do
  suffix="${ident#"$prefix"}"; suffix="${suffix#.}"
  name="Conduit ${suffix:-App} App Store"
  # Replace an existing profile of the same name (its certificate may be old).
  old="$(asc profiles list --output json | python3 -c "
import json,sys
print(' '.join(p['id'] for p in json.load(sys.stdin)['data'] if p['attributes']['name']==sys.argv[1]))" "$name")"
  for p in $old; do asc profiles delete --id "$p" --confirm >/dev/null; done
  pid="$(asc profiles create --name "$name" --profile-type IOS_APP_STORE --bundle "$id" --certificate "$dist" \
    | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"]["id"])')"
  asc profiles download --id "$pid" --output "$work/${suffix:-app}.mobileprovision" >/dev/null
  echo "$name -> $pid"
done <"$work/ids.txt"
(cd "$work" && zip -q -j profiles.zip ./*.mobileprovision)
op item edit conduit-provisioning-profiles --vault github "profiles_base64[concealed]=$(base64 -i "$work/profiles.zip" | tr -d '\n')" >/dev/null
echo "Updated 1Password item conduit-provisioning-profiles"
