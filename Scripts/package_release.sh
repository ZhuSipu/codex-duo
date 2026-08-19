#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
output_dir="${1:-$project_dir/dist}"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")
architecture=$(uname -m)
archive="$output_dir/Codex-Duo-$version-macOS-$architecture.zip"
dmg="$output_dir/Codex-Duo-$version-macOS-$architecture.dmg"

mkdir -p "$output_dir"
if [[ -e "$archive" || -e "$dmg" ]]; then
  echo "Release output already exists for version $version" >&2
  exit 1
fi

app_path=$("$project_dir/Scripts/build_app.sh")
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive"
unzip -tq "$archive" >/dev/null

dmg_staging=$(mktemp -d "${TMPDIR:-/tmp}/codex-duo-dmg.XXXXXX")
trap 'rm -rf "$dmg_staging"' EXIT
ditto "$app_path" "$dmg_staging/Codex Duo.app"
ln -s /Applications "$dmg_staging/Applications"
hdiutil create -quiet -fs HFS+ -format UDZO -volname "Codex Duo" -srcfolder "$dmg_staging" "$dmg"
hdiutil imageinfo "$dmg" >/dev/null

if [[ -n "${CODEX_DUO_NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$dmg" --keychain-profile "$CODEX_DUO_NOTARY_PROFILE" --wait
  xcrun stapler staple "$dmg"
fi

echo "$archive"
echo "$dmg"
