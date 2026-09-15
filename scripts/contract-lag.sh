#!/usr/bin/env bash
# Answers the question scripts/parity.sh structurally cannot: is the contract
# this port is pinned to still the current one?
#
# parity.sh checks the manifest against the tag pubspec.lock resolves, so it
# stays green forever while upstream moves on — drift is guarded, falling
# behind is silent. This script compares the pinned kun_ui_tokens version
# against pub.dev's latest and, when they differ, reports exactly what
# adopting the newer contract would cost: components it adds, surface it adds
# to components already claimed here, and the parity verdict under it.
#
# Adopting is a deliberate change (bump the dependency, commit the lockfile),
# never something CI does — so a lag exits non-zero purely as the signal.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
manifest="$root/contracts/components.manifest.json"

pinned=$(yq -r '.packages.kun_ui_tokens.version' "$root/pubspec.lock")
latest=$(curl -fsSL https://pub.dev/api/packages/kun_ui_tokens | jq -r '.latest.version')

echo "contract-lag: pinned kun_ui_tokens ${pinned} · latest on pub.dev ${latest}"

if [ "$pinned" = "$latest" ]; then
  echo "contract-lag: the pinned contract is the current one."
  exit 0
fi

if [ "$(printf '%s\n%s\n' "$pinned" "$latest" | sort -V | tail -1)" = "$pinned" ]; then
  echo "contract-lag: pinned version is AHEAD of pub.dev — publish upstream or fix the pin."
  exit 1
fi

upstream=$(mktemp -d)
trap 'rm -rf "$upstream"' EXIT

if ! git clone --quiet --depth 1 --branch "kun_ui_tokens-v${latest}" \
  https://github.com/kungal/kun-ui "$upstream"; then
  echo "contract-lag: kun_ui_tokens-v${latest} is on pub.dev but has no tag in kungal/kun-ui."
  exit 1
fi

git -C "$upstream" fetch --quiet --depth 1 origin \
  "refs/tags/kun_ui_tokens-v${pinned}"
git -C "$upstream" show "FETCH_HEAD:contracts/component-contracts.json" \
  > "$upstream/pinned-contracts.json"

echo
echo "Adopting kun_ui_tokens ${latest} would mean:"
jq -r -n \
  --slurpfile old "$upstream/pinned-contracts.json" \
  --slurpfile new "$upstream/contracts/component-contracts.json" \
  --slurpfile manifest "$manifest" \
  '
  def portable: .components | with_entries(select(.value.status == "portable"));
  ($old[0] | portable) as $o
  | ($new[0] | portable) as $n
  | (($n | keys) - ($o | keys)) as $added
  | (($o | keys) - ($n | keys)) as $dropped
  | [
      ($manifest[0].components | keys)[]
      | . as $c
      | select($n[$c] and $o[$c])
      | {
          component: $c,
          props: (($n[$c].props // [] | map(.name)) - ($o[$c].props // [] | map(.name))),
          events: (($n[$c].events // [] | map(.name)) - ($o[$c].events // [] | map(.name))),
          slots: (($n[$c].slots // [] | map(.name)) - ($o[$c].slots // [] | map(.name)))
        }
      | select([.props, .events, .slots] | map(length) | add > 0)
    ] as $grown
  | "  portable components: \($o | length) → \($n | length)",
    (if $added == [] then "  no new components"
     else "  new components (\($added | length)): \($added | join(", "))" end),
    (if $dropped == [] then empty
     else "  components upstream removed (\($dropped | length)): \($dropped | join(", "))" end),
    (if $grown == [] then "  no new surface on components this port claims"
     else "  new surface on claimed components:",
       ($grown[] | "    \(.component)"
         + (if .props  == [] then "" else " props: +\(.props  | join(", +"))" end)
         + (if .events == [] then "" else " events: +\(.events | join(", +"))" end)
         + (if .slots  == [] then "" else " slots: +\(.slots  | join(", +"))" end))
     end)
  '

echo
echo "Parity under the newer contract:"
node "$upstream/scripts/flutter-parity.mjs" "$manifest" || true

echo
echo "contract-lag: BEHIND by ${pinned} → ${latest}."
echo "To adopt: bump kun_ui_tokens/kun_ui_icons in packages/kun_ui/pubspec.yaml,"
echo "run flutter pub get, commit pubspec.lock, and answer any surface listed above."
exit 1
