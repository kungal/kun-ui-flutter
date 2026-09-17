#!/usr/bin/env bash
# Dispatch one cursor-agent executor run. See SKILL.md in this directory.
#
#   CURSOR_OUT_ROOT=<dir> dispatch.sh <slug> [--deny '<rule>']... [extra cursor-agent args...]
#
# Run it from the working tree the executor works in. Expects <CURSOR_OUT_ROOT>/<slug>/task.md.
# Writes stream.jsonl, run.json, stderr.log, cursor-config/ and xdg/ beside it. `--deny` adds a
# per-task rule (Write rules take absolute paths); everything else passes straight through.
#
# Start it detached (SKILL.md section 3): a real dispatch takes an hour or more.
set -euo pipefail

slug="${1:?usage: dispatch.sh <slug> [--deny rule]... [extra cursor-agent args...]}"
shift

root="${CURSOR_OUT_ROOT:?set CURSOR_OUT_ROOT to a writable directory under the scratchpad}"
out="$root/$slug"
[ -f "$out/task.md" ] || { echo "dispatch: missing $out/task.md" >&2; exit 2; }
# The task book travels as one argv string, and Linux caps a single argument at 128 KiB.
[ "$(wc -c <"$out/task.md")" -lt 120000 ] || { echo "dispatch: task.md is over 120 KiB" >&2; exit 2; }

tree="$PWD"
extra=()
pass=()
while [ $# -gt 0 ]; do
  case "$1" in
    --deny) extra+=("${2:?--deny needs a rule}"); shift 2 ;;
    *) pass+=("$1"); shift ;;
  esac
done

# The fence, layer one: cursor-agent permission rules (SKILL.md section 2). A Shell rule is a
# glob over each sub-command's full text, so the leading `*` is what catches `bash -c`, an
# absolute path and an `env` prefix. A relative Write rule never matches; Write rules are
# absolute or start with `**/`.
deny=(
  'Shell(*git commit*)'   'Shell(*git add*)'      'Shell(*git push*)'
  'Shell(*git reset*)'    'Shell(*git checkout*)' 'Shell(*git switch*)'
  'Shell(*git rebase*)'   'Shell(*git merge*)'    'Shell(*git stash*)'
  'Shell(*git restore*)'  'Shell(*git clean*)'    'Shell(*git branch*)'
  'Shell(*git tag*)'      'Shell(*git worktree*)' 'Shell(*git cherry-pick*)'
  'Shell(*git revert*)'   'Shell(*git am *)'      'Shell(*git update-ref*)'
  # A global option in front of the subcommand slips past every rule above.
  'Shell(*git -C*)'       'Shell(*git -c *)'      'Shell(*git --git-dir*)'
  'Shell(*git --work-tree*)'
  'Shell(gh)'             'Shell(*bin/gh *)'
  # Iron rule 5: a tag publishes an immutable version to pub.dev.
  'Shell(*pub publish*)'  'Shell(*pub logout*)'
  # `fvm use` writes .fvmrc into the tree; the binaries are called by absolute path.
  'Shell(*fvm use*)'
  # The published package's manifest and the resolution output are the orchestrator's.
  # `flutter pub get` still rewrites the lockfile through the shell, as it is meant to.
  "Write($tree/packages/kun_ui/pubspec.yaml)"
  "Write($tree/pubspec.lock)"
  # Generated output is written by the toolchain, never by hand.
  "Write($tree/**/build/**)"
  "Write($tree/**/.dart_tool/**)"
  # kungal/kun-ui is the read-only upstream (iron rule 2).
  'Write(/home/kun/Desktop/code/website/kun-ui/**)'
  # This skill directory, so an executor that loads it cannot rewrite its own fence.
  "Write($tree/.claude/**)"
)

cfg="$out/cursor-config"
mkdir -p "$cfg" "$out/xdg/gh"
jq '.permissions.deny = $ARGS.positional' "$HOME/.cursor/cli-config.json" \
  --args "${deny[@]}" "${extra[@]}" >"$cfg/cli-config.json"

# Layer two: the environment. The permission rules are pattern matches over command text, and
# this machine holds real pub.dev and GitHub credentials, so the irreversible actions also lose
# their credentials. XDG_CONFIG_HOME moves dart's pub-credentials.json and gh's hosts.yml out of
# reach (git's credential helper is gh, so pushes lose auth too), and pushInsteadOf sends every
# push, a URL with a token in it included, to a path that does not exist. Fetching is untouched.
# ~/.zshenv sources ~/.grok/env, which exports a GitHub token, so unsetting it is not enough
# while the executor's shell is zsh: the shell is bash, and a zsh finds no startup files.
mkdir -p "$out/xdg/zdotdir"
env_fence=(
  -u GITHUB_PERSONAL_ACCESS_TOKEN -u GH_TOKEN -u GITHUB_TOKEN
  SHELL=/bin/bash
  ZDOTDIR="$out/xdg/zdotdir"
  XDG_CONFIG_HOME="$out/xdg"
  GH_CONFIG_DIR="$out/xdg/gh"
  GIT_CONFIG_COUNT=4
)
i=0
for scheme in 'https://' 'http://' 'ssh://' 'git@'; do
  env_fence+=(
    "GIT_CONFIG_KEY_$i=url./nonexistent/push-denied-by-dispatch/.pushInsteadOf"
    "GIT_CONFIG_VALUE_$i=$scheme"
  )
  i=$((i + 1))
done
env_fence+=(CURSOR_CONFIG_DIR="$cfg")

model=()
[ -n "${CURSOR_MODEL:-}" ] && model=(--model "$CURSOR_MODEL")

env "${env_fence[@]}" cursor-agent -p --force --trust --sandbox disabled \
  --output-format stream-json "${model[@]}" "${pass[@]}" \
  "$(cat "$out/task.md")" >"$out/stream.jsonl" 2>"$out/stderr.log" &
pid=$!

# cursor-agent -p has a long-standing report of never exiting after its result, and it has no
# turn budget, so the wall clock is the budget.
limit="${CURSOR_TIMEOUT:-14400}"
start=$(date +%s)
seen=
reason=
while kill -0 "$pid" 2>/dev/null; do
  now=$(date +%s)
  if [ -z "$seen" ] && grep -q '"type":"result"' "$out/stream.jsonl" 2>/dev/null; then
    seen=$now
  fi
  if [ -n "$seen" ] && [ $((now - seen)) -ge 60 ]; then
    reason='hung after its result event; killed'
    kill "$pid"
    break
  fi
  if [ $((now - start)) -ge "$limit" ]; then
    reason="hit CURSOR_TIMEOUT=${limit}s; killed"
    kill "$pid"
    break
  fi
  sleep 5
done
code=0
wait "$pid" || code=$?
elapsed=$(($(date +%s) - start))

jq -c 'select(.type == "result")' "$out/stream.jsonl" 2>/dev/null | tail -n 1 >"$out/run.json" || true
calls=$(jq -s '[.[] | select(.type == "tool_call" and .subtype == "completed")] | length' \
  "$out/stream.jsonl" 2>/dev/null || echo '?')
model_name=$(jq -r 'select(.type == "system") | .model' "$out/stream.jsonl" 2>/dev/null | head -n 1 || true)

if [ ! -s "$out/run.json" ]; then
  echo "dispatch: no result event (exit=$code elapsed=${elapsed}s calls=$calls ${reason:-}); see $out/stderr.log" >&2
  tail -c 2000 "$out/stderr.log" >&2 || true
  exit 1
fi

jq -r --arg e "$elapsed" --arg c "$calls" --arg m "$model_name" --arg o "$out" \
  '"subtype=\(.subtype) is_error=\(.is_error) elapsed=\($e)s tool_calls=\($c) model=\($m) tokens_in=\(.usage.inputTokens // "?") tokens_out=\(.usage.outputTokens // "?") out=\($o)"' \
  "$out/run.json"
if [ -n "$reason" ]; then
  echo "dispatch: $reason" >&2
fi

denied=$(jq -r 'select(.type == "tool_call" and .subtype == "completed") | .tool_call | to_entries[]
  | select(.key | endswith("ToolCall")) | .value.result // {}
  | (.permissionDenied.command // empty), (.writePermissionDenied.error // empty)' \
  "$out/stream.jsonl" 2>/dev/null || true)
if [ -n "$denied" ]; then
  echo "dispatch: $(printf '%s\n' "$denied" | wc -l) call(s) were DENIED; check each rule is right:" >&2
  printf '%s\n' "$denied" | cut -c1-200 | sort | uniq -c >&2
fi

if [ -s "$out/stderr.log" ]; then
  echo '--- stderr ---' >&2
  tail -c 2000 "$out/stderr.log" >&2
fi

if [ "$(jq -r '.is_error' "$out/run.json")" != false ]; then
  echo "dispatch: the result event reports an error; inspect $out/stream.jsonl" >&2
  exit 1
fi
if [ "$code" -ne 0 ] && [ -z "$reason" ]; then
  echo "dispatch: cursor-agent exited $code after its result; inspect $out/stderr.log" >&2
  exit 1
fi
