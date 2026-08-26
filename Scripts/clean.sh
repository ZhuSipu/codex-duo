#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"

rm -rf \
  "$project_dir/.build" \
  "$project_dir/build"

if [[ "${1:-}" == "--all" ]]; then
  rm -rf "$project_dir/dist"
fi

find "$project_dir" -name .DS_Store -type f -delete
