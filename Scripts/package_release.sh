#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
output_dir="${1:-$project_dir/dist}"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")
architecture=$(uname -m)
archive="$output_dir/Codex-Duo-$version-macOS-$architecture.zip"

mkdir -p "$output_dir"
if [[ -e "$archive" ]]; then
  echo "Release archive already exists: $archive" >&2
  exit 1
fi

app_path=$("$project_dir/Scripts/build_app.sh")
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive"
unzip -tq "$archive" >/dev/null

echo "$archive"
