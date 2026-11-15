#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
cd "$ROOT_DIR"
swiftc modules/scrollblock/ios/Core/RuleSet.swift modules/scrollblock/ios/Core/DNSPacket.swift \
  tests/native/main.swift -o "$TEST_DIR/scrollblock-tests"
"$TEST_DIR/scrollblock-tests"
