#!/usr/bin/env bash
# Dispatch one grok executor run. See SKILL.md in this directory.
#
#   GROK_OUT_ROOT=<dir under /tmp> dispatch.sh <slug> [extra grok args...]
#
# Expects <GROK_OUT_ROOT>/<slug>/task.md to exist. Writes run.json, stderr.log and
# debug.log beside it. Extra arguments pass straight through to grok — that is where
# per-task --deny rules for paths another writer owns belong.
#
# Run this in the background: a real dispatch takes minutes.
set -euo pipefail

slug="${1:?usage: dispatch.sh <slug> [extra grok args...]}"
shift

root="${GROK_OUT_ROOT:?set GROK_OUT_ROOT to a writable directory under /tmp}"
out="$root/$slug"
[ -f "$out/task.md" ] || { echo "dispatch: missing $out/task.md" >&2; exit 2; }

# The fence. ~/.grok/config.toml sets permission_mode = "always-approve", so an --allow
# glob grants nothing it did not already have — only --deny is enforced, ahead of YOLO.
# These are the operations that are the orchestrator's regardless of the task (SKILL.md 6).
deny=(
  --deny 'Bash(git commit*)'   --deny 'Bash(git add*)'      --deny 'Bash(git push*)'
  --deny 'Bash(git reset*)'    --deny 'Bash(git checkout*)' --deny 'Bash(git switch*)'
  --deny 'Bash(git rebase*)'   --deny 'Bash(git merge*)'    --deny 'Bash(git stash*)'
  --deny 'Bash(git restore*)'  --deny 'Bash(git clean*)'    --deny 'Bash(git branch*)'
  --deny 'Bash(git tag*)'      --deny 'Bash(git worktree*)' --deny 'Bash(gh *)'
  # Iron rule 5: a tag publishes an immutable version to pub.dev, and the first
  # publish is the maintainer's by hand. No executor goes near either.
  --deny 'Bash(*pub publish*)'
  # `fvm use` writes .fvmrc into the tree; the binaries are called by absolute path.
  --deny 'Bash(*fvm use*)'
  # The published package's manifest (version, dependencies, description) and the
  # resolution output are the orchestrator's. `flutter pub get` still rewrites the
  # lockfile through the shell, which is how it is supposed to change.
  --deny 'Write(packages/kun_ui/pubspec.yaml)' --deny 'Edit(packages/kun_ui/pubspec.yaml)'
  --deny 'Write(pubspec.lock)'                 --deny 'Edit(pubspec.lock)'
  # Generated output is written by the toolchain, never by hand.
  --deny 'Write(**/build/**)'      --deny 'Edit(**/build/**)'
  --deny 'Write(**/.dart_tool/**)' --deny 'Edit(**/.dart_tool/**)'
  # kungal/kun-ui is the read-only upstream; a change there is a change to the
  # contract, which is decided upstream and translated here (iron rule 2).
  --deny 'Write(/home/kun/Desktop/code/website/kun-ui/**)'
  --deny 'Edit(/home/kun/Desktop/code/website/kun-ui/**)'
)

grok --prompt-file "$out/task.md" \
     "${deny[@]}" \
     --allow "Write($out/**)" \
     --allow "Read($out/**)" \
     --output-format json \
     --max-turns "${GROK_MAX_TURNS:-200}" \
     --debug-file "$out/debug.log" \
     "$@" \
     >"$out/run.json" 2>"$out/stderr.log" || true

if [ ! -s "$out/run.json" ]; then
  echo "dispatch: grok produced no JSON; see $out/stderr.log" >&2
  tail -c 2000 "$out/stderr.log" >&2 || true
  exit 1
fi

stop=$(jq -r '.stopReason // "?"' "$out/run.json")
turns=$(jq -r '.num_turns // "?"' "$out/run.json")
cost=$(jq -r '.total_cost_usd // "?"' "$out/run.json")
printf 'stopReason=%s turns=%s cost_usd=%s out=%s\n' "$stop" "$turns" "$cost" "$out"

[ -s "$out/stderr.log" ] && { echo '--- stderr ---' >&2; tail -c 2000 "$out/stderr.log" >&2; }

if [ "$stop" != "end_turn" ]; then
  # stopReason "cancelled" covers both a denied tool call and turn exhaustion.
  # Only the debug log distinguishes them, which is why it is always written.
  if grep -q 'PermissionCancelled' "$out/debug.log" 2>/dev/null; then
    echo 'dispatch: a tool call was DENIED — it hit a deny rule; check whether the rule is right' >&2
    grep -o 'deny rule matched[^"]*tool=[a-z_]*' "$out/debug.log" | sort -u >&2 || true
  elif [ "$turns" -ge "${GROK_MAX_TURNS:-200}" ] 2>/dev/null; then
    echo 'dispatch: turn budget exhausted — raise GROK_MAX_TURNS or split the task' >&2
  else
    echo "dispatch: run ended as '$stop'; inspect $out/debug.log" >&2
  fi
  exit 1
fi
