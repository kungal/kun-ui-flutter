#!/usr/bin/env bash
# Runs the upstream parity checker (kungal/kun-ui scripts/flutter-parity.mjs)
# against contracts/components.manifest.json.
#
# The contract version IS the resolved kun_ui_tokens version — there is no
# separate contract versioning — so upstream is checked out at the release
# tag pubspec.lock implies. Set KUN_UI_DIR to a local kun-ui checkout to skip
# the clone (local runs); mind that a local checkout is whatever it is, not
# necessarily the pinned tag.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
version=$(yq -r '.packages.kun_ui_tokens.version' "$root/pubspec.lock")

if [ -n "${KUN_UI_DIR:-}" ]; then
  upstream="$KUN_UI_DIR"
  echo "parity: using local upstream at ${upstream} (pinned contract is kun_ui_tokens-v${version})"
else
  upstream=$(mktemp -d)
  trap 'rm -rf "$upstream"' EXIT
  git clone --quiet --depth 1 --branch "kun_ui_tokens-v${version}" \
    https://github.com/kungal/kun-ui "$upstream"
  echo "parity: upstream kungal/kun-ui at tag kun_ui_tokens-v${version}"
fi

node "$upstream/scripts/flutter-parity.mjs" "$root/contracts/components.manifest.json"
