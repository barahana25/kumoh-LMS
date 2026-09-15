#!/usr/bin/env bash
# 웹 빌드가 쓰는 외부 런타임을 고정 버전으로 받아 web/vendor에 둔다.
# 버전은 pubspec.lock의 drift, sqlite3와 맞아야 한다. 해시가 다르면 실패한다.
set -euo pipefail
cd "$(dirname "$0")/../web/vendor"

curl -fsSL -o drift_worker.js \
  https://github.com/simolus3/drift/releases/download/drift-2.31.0/drift_worker.js
curl -fsSL -o sqlite3.wasm \
  https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-2.9.4/sqlite3.wasm

tmp="$(mktemp -d)"
curl -fsSL https://registry.npmjs.org/libcurl.js/-/libcurl.js-0.7.4.tgz | tar -xz -C "$tmp"
cp "$tmp/package/libcurl.js" "$tmp/package/libcurl.wasm" .
cp "$tmp/package/LICENSE" LICENSE.libcurl.js.txt
rm -rf "$tmp"

sha256sum -c SHA256SUMS
