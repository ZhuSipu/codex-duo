#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
test_binary="$project_dir/build/ModelTests"

mkdir -p "$project_dir/build"
swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$project_dir/Sources/CodexDuo/Models.swift" \
  "$project_dir/Tests/ModelTests.swift" \
  -o "$test_binary"

"$test_binary"
