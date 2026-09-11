#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
version="0.3.0-alpha.10"
machine_architecture="${1:-$(uname -m)}"

case "$machine_architecture" in
  arm64)
    release_architecture="ARM64"
    archive_sha256="4c7bc851d5fc50ffb43d4aa72c44111609dfb6d56c6657a2fab26d676ec2c5af"
    binary_sha256="aa7fbce3bdf40304af97a68abece0d78a397dfef8e702a3d5fed187c9f7908fd"
    ;;
  x86_64)
    release_architecture="X64"
    archive_sha256="76c6cffcd4d5ab719ca119c109b09746ea742074e7f29b58e29e74545f65fdd1"
    binary_sha256="c2b7ea91cffb134e491221d65fe4669f6757255f204bd4a6da30de2c63da919b"
    ;;
  *)
    echo "Unsupported macOS architecture: $machine_architecture" >&2
    exit 64
    ;;
esac

cache_root="${CODEX_DUO_VENDOR_CACHE_DIR:-$project_dir/.build/vendor}"
cache_dir="$cache_root/codex-auth/$version/$machine_architecture"
binary="$cache_dir/codex-auth"
asset="codex-auth-macOS-$release_architecture.tar.gz"
archive="$project_dir/Vendor/codex-auth/$version/$asset"

verify_sha256() {
  local file_path="$1"
  local expected="$2"
  [[ -f "$file_path" ]] && [[ "$(shasum -a 256 "$file_path" | awk '{print $1}')" == "$expected" ]]
}

if verify_sha256 "$binary" "$binary_sha256"; then
  chmod 755 "$binary"
  echo "$binary"
  exit 0
fi

mkdir -p "$cache_dir"
if ! verify_sha256 "$archive" "$archive_sha256"; then
  echo "Checksum verification failed for $asset" >&2
  exit 65
fi

rm -f "$binary"
tar -xzf "$archive" -C "$cache_dir" codex-auth
if ! verify_sha256 "$binary" "$binary_sha256"; then
  rm -f "$binary"
  echo "Checksum verification failed for extracted codex-auth" >&2
  exit 65
fi
if [[ "$(file -b "$binary")" != *"$machine_architecture"* ]]; then
  rm -f "$binary"
  echo "Downloaded codex-auth has the wrong architecture" >&2
  exit 65
fi

chmod 755 "$binary"
echo "$binary"
