#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/codex-duo-build.XXXXXX")
app_dir="$build_dir/Codex Duo.app"
binary_dir="$app_dir/Contents/MacOS"

mkdir -p "$binary_dir"

swiftc \
  -swift-version 5 \
  -O \
  -framework AppKit \
  -framework Foundation \
  "$project_dir"/Sources/CodexDuo/*.swift \
  -o "$binary_dir/CodexDuo"

mkdir -p "$app_dir/Contents"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
