#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/codex-duo-build.XXXXXX")
app_dir="$build_dir/Codex Duo.app"
binary_dir="$app_dir/Contents/MacOS"
helper_dir="$app_dir/Contents/Helpers"
resource_dir="$app_dir/Contents/Resources"

mkdir -p "$binary_dir" "$helper_dir" "$resource_dir"

swiftc \
  -swift-version 5 \
  -O \
  -framework AppKit \
  -framework Foundation \
  -framework ServiceManagement \
  -framework SystemConfiguration \
  "$project_dir"/Sources/CodexDuo/*.swift \
  -o "$binary_dir/CodexDuo"

mkdir -p "$app_dir/Contents"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/CodexDuo.icns" "$resource_dir/CodexDuo.icns"
cp "$project_dir/THIRD_PARTY_NOTICES.md" "$resource_dir/THIRD_PARTY_NOTICES.md"
helper_source=$("$project_dir/Scripts/prepare_codex_auth.sh" "$(uname -m)")
cp "$helper_source" "$helper_dir/codex-auth"
chmod 755 "$helper_dir/codex-auth"
xattr -cr "$app_dir"
sign_identity="${CODEX_DUO_SIGN_IDENTITY:--}"
codesign --force --options runtime --sign "$sign_identity" "$helper_dir/codex-auth"
codesign --force --deep --options runtime --sign "$sign_identity" "$app_dir"

echo "$app_dir"
