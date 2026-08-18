#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
install_root="${CODEX_DUO_INSTALL_DIR:-/Applications}"
destination="$install_root/Codex Duo.app"
app_path=$("$project_dir/Scripts/build_app.sh")

mkdir -p "$install_root"
pkill -x CodexDuo 2>/dev/null || true
ditto "$app_path" "$destination"
codesign --verify --deep --strict "$destination"
open "$destination"

echo "Installed Codex Duo at $destination"
