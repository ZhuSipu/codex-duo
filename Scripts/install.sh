#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
install_root="${CODEX_DUO_INSTALL_DIR:-/Applications}"
launch_app=true
stop_running_app=true

usage() {
  cat <<'EOF'
Usage: ./Scripts/install.sh [--install-dir DIRECTORY] [--no-launch] [--keep-running]

Build, verify, and safely replace a development installation of Codex Duo.

Options:
  --install-dir DIRECTORY  Install root (default: /Applications or CODEX_DUO_INSTALL_DIR)
  --no-launch              Do not launch Codex Duo after installation
  --keep-running           Do not stop another running Codex Duo (useful for isolated tests)
  -h, --help               Show this help
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --install-dir)
      if (( $# < 2 )) || [[ -z "$2" ]]; then
        echo "--install-dir requires a directory" >&2
        exit 2
      fi
      install_root="$2"
      shift 2
      ;;
    --no-launch)
      launch_app=false
      shift
      ;;
    --keep-running)
      stop_running_app=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for tool in swiftc codesign ditto; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required tool not found: $tool" >&2
    echo "Install the current Xcode Command Line Tools and try again." >&2
    exit 1
  fi
done
if [[ "$launch_app" == true ]] && ! command -v open >/dev/null 2>&1; then
  echo "Required tool not found: open" >&2
  exit 1
fi

mkdir -p "$install_root"
install_root="${install_root:A}"
destination="$install_root/Codex Duo.app"
staged="$install_root/.Codex Duo.installing.$PPID.app"
backup="$install_root/.Codex Duo.previous.$PPID.app"
install_committed=false

cleanup() {
  [[ ! -e "$staged" ]] || rm -rf "$staged"
  if [[ -e "$backup" ]]; then
    if [[ "$install_committed" == true ]]; then
      rm -rf "$backup"
    else
      [[ ! -e "$destination" ]] || rm -rf "$destination"
      mv "$backup" "$destination"
    fi
  fi
}
trap cleanup EXIT

app_path=$("$project_dir/Scripts/build_app.sh")
if [[ ! -x "$app_path/Contents/MacOS/CodexDuo" ]]; then
  echo "Build did not produce a runnable Codex Duo app: $app_path" >&2
  exit 1
fi
codesign --verify --deep --strict "$app_path"

ditto "$app_path" "$staged"
codesign --verify --deep --strict "$staged"

if [[ "$stop_running_app" == true ]]; then
  pkill -x CodexDuo 2>/dev/null || true
fi
if [[ -e "$destination" ]]; then
  mv "$destination" "$backup"
fi
if ! mv "$staged" "$destination"; then
  [[ ! -e "$backup" ]] || mv "$backup" "$destination"
  echo "Installation failed; the previous app was restored." >&2
  exit 1
fi

if ! codesign --verify --deep --strict "$destination"; then
  rm -rf "$destination"
  [[ ! -e "$backup" ]] || mv "$backup" "$destination"
  echo "Installed app verification failed; the previous app was restored." >&2
  exit 1
fi
install_committed=true
[[ ! -e "$backup" ]] || rm -rf "$backup"

if [[ "$launch_app" == true ]]; then
  open "$destination"
fi

echo "Installed Codex Duo at $destination"
