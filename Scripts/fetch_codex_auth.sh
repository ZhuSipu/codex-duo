#!/bin/zsh
set -euo pipefail

version="0.3.0-alpha.10"
package_name="@loongphy/codex-auth-darwin-arm64"
tarball_url="https://registry.npmjs.org/@loongphy/codex-auth-darwin-arm64/-/codex-auth-darwin-arm64-${version}.tgz"
integrity="sha512-p2NGVa05jDE555hNmNEpK8V1xblztXeTC6BdPViW9q+PORTnQo86ieLaJ/e1nmU0Sj5K9A+uAJtQlLNDsk5Mqg=="

if [[ $# -ne 2 ]]; then
  print -u2 -- "Usage: $0 <binary-destination> <license-destination>"
  exit 64
fi

if [[ "$(/usr/bin/uname -s)" != "Darwin" || "$(/usr/bin/uname -m)" != "arm64" ]]; then
  print -u2 -- "${package_name} is only available for Apple Silicon macOS builds."
  exit 1
fi

binary_destination="$1"
license_destination="$2"
cache_root="${CODEX_DUO_CACHE_DIR:-$HOME/Library/Caches/CodexDuo}"
archive_path="$cache_root/codex-auth-darwin-arm64-${version}.tgz"
stage_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-duo-codex-auth.XXXXXX")"

cleanup() {
  /bin/rm -rf "$stage_root"
}
trap cleanup EXIT

proxy_settings=""
if [[ -z "${HTTP_PROXY:-}${http_proxy:-}${HTTPS_PROXY:-}${https_proxy:-}${ALL_PROXY:-}${all_proxy:-}" ]]; then
  proxy_settings=$(/usr/sbin/scutil --proxy 2>/dev/null || true)
fi

proxy_value() {
  print -r -- "$proxy_settings" | /usr/bin/awk -F ' : ' -v key="$1" '$1 == "  " key { print $2; exit }'
}

set_proxy_if_needed() {
  local enabled_key="$1"
  local host_key="$2"
  local port_key="$3"
  local scheme="$4"
  local upper_name="$5"
  local lower_name="$6"
  local enabled host port value

  [[ -n "$proxy_settings" ]] || return
  enabled=$(proxy_value "$enabled_key")
  host=$(proxy_value "$host_key")
  port=$(proxy_value "$port_key")
  if [[ "$enabled" == "1" && -n "$host" && "$port" == <-> ]]; then
    value="$scheme://$host:$port"
    typeset -gx "$upper_name=$value"
    typeset -gx "$lower_name=$value"
  fi
}

set_proxy_if_needed HTTPEnable HTTPProxy HTTPPort http HTTP_PROXY http_proxy
set_proxy_if_needed HTTPSEnable HTTPSProxy HTTPSPort http HTTPS_PROXY https_proxy
set_proxy_if_needed SOCKSEnable SOCKSProxy SOCKSPort socks5h ALL_PROXY all_proxy

verify_archive() {
  [[ -f "$archive_path" ]] || return 1
  local digest
  digest=$(/usr/bin/openssl dgst -sha512 -binary "$archive_path" | /usr/bin/base64 | /usr/bin/tr -d '\n')
  [[ "sha512-$digest" == "$integrity" ]]
}

/bin/mkdir -p "$cache_root"
if ! verify_archive; then
  /usr/bin/curl --fail --location --retry 3 --connect-timeout 15 --max-time 120 \
    --output "$archive_path" "$tarball_url"
fi
if ! verify_archive; then
  print -u2 -- "The downloaded ${package_name}@${version} archive failed integrity verification."
  exit 1
fi

/usr/bin/tar -xzf "$archive_path" -C "$stage_root" package/bin/codex-auth package/LICENSE
binary_source="$stage_root/package/bin/codex-auth"
license_source="$stage_root/package/LICENSE"
if [[ ! -x "$binary_source" || ! -f "$license_source" ]]; then
  print -u2 -- "The ${package_name}@${version} archive is missing required files."
  exit 1
fi

/bin/mkdir -p "${binary_destination:h}" "${license_destination:h}"
/usr/bin/install -m 755 "$binary_source" "$binary_destination"
/usr/bin/install -m 644 "$license_source" "$license_destination"

print -u2 -r -- "Bundled ${package_name}@${version}"
