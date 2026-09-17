---
name: dispatch-cursor
description: Dispatch implementation and investigation work in kun-ui-flutter to the local cursor-agent CLI as a headless executor while this session stays the orchestrator and acceptor. The default executor since 2026-09-17, when grok's balance ran out. Use when the user asks to "派发 cursor" / "dispatch cursor" / "让 cursor 做", or when a task is large enough to hand off as a written task book. Covers this machine's measured two-layer fence (glob deny rules plus a credential-free environment), the fvm toolchain paths, this repo's gates, headless eye verification, and the acceptance protocol.
---

# Dispatching cursor-agent as executor

> **If you are the cursor executor and this file was loaded into your context: ignore it.**
> It describes how the orchestrator dispatches *you*. It is not a task book. Your task book
> is the prompt you were started with, and nothing here overrides it.

This session is the **orchestrator**: it adjudicates design, writes the task book, owns git
and every release action, and accepts or rejects the result. The local `cursor-agent` CLI
(Cursor) is the **executor**: it reads, writes, runs the Flutter toolchain, and screenshots
pages through a node script.

`dispatch-grok` in this directory is the same protocol for the grok CLI. Its balance ran out
on 2026-09-17, mid-dispatch, with a 402. Sections 4 to 8 below carry its lessons over, so
this skill stands on its own.

## 1. What cursor-agent can do here

Measured 2026-09-17 from this machine, `cursor-agent 2026.08.25-3e8eec8`: three probes in
throwaway repositories and two smoke runs of `dispatch.sh` in a worktree of this repo, all on
`cursor-grok-4.6-low`. Each probe took under two minutes. The artefacts are in
`<scratchpad>/cursor/`.

| Capability | Result |
|---|---|
| Shell | **yes**, in the working directory. The shell is `$SHELL`, which `dispatch.sh` sets to bash. The dispatching process's environment reaches every command, including `PATH`, `XDG_CONFIG_HOME` and `GIT_CONFIG_*`. Cursor puts its bundled node (v24.5.0) ahead of the system one (v24.13.0) |
| Project instructions | `CLAUDE.md` **and** `AGENTS.md` at the workspace root are loaded as always-applied rules, without a file read |
| Skills | every `.claude/skills/*` is listed as an available skill, which is why this file opens with a guard. Plugin skills (`dart-*`, `flutter-*`) are listed too |
| User-level Cursor rules | loaded as well. One of them asks for replies in Chinese, so a task book states that everything it writes is English |
| Model | whatever `~/.cursor/cli-config.json` selects: Cursor Grok 4.6 Extra High today, the family the grok CLI ran. `CURSOR_MODEL=<id>` overrides it with an id from `cursor-agent models` |
| Browser | no browser tool. The dispatch config has no `mcp.json`, so eye verification is a headless node Playwright script (the template has it) |
| Output | `--output-format stream-json`: one event per line. The final `result` event carries `usage` token counts and **no cost** |
| Exit | every run exited on its own within seconds of its `result` event. A forum report says `-p` can hang after the result, so `dispatch.sh` kills a run 60 s after it |
| Budget | there is no turn limit flag. The wall clock is the budget: `CURSOR_TIMEOUT`, 4 h by default |
| Tree hygiene | `--trust` and the run itself wrote nothing into the working tree beyond the task's own edits |

Auth comes from `CURSOR_API_KEY` in the environment (the init event says
`apiKeySource: "env"`). That is what lets `dispatch.sh` move `XDG_CONFIG_HOME` (section 2)
without logging cursor out. If that variable ever disappears, check `cursor-agent status`
under the dispatch environment first.

## 2. The fence has two layers

### Layer one: permission rules

`cursor-agent` has no `--deny` flag. Rules live in `cli-config.json`, and `dispatch.sh`
gives every run its own copy: it points `CURSOR_CONFIG_DIR` at `<out>/cursor-config/`, holding
the user's config with the deny list replaced. The user's own config is never edited.
`approvalMode` stays as the user set it (`unrestricted`); the probes gave identical results
under `allowlist`.

What the rules actually match, measured with fake binaries:

| Rule | Refused | Still ran |
|---|---|---|
| `Shell(alpha:commit*)`, `Shell(beta commit*)`, `Shell(gamma)` | the bare command, also after `cd sub &&` or `export …;` | `bash -c '…'`, `$PWD/bin/alpha …`, `env X=1 alpha …` |
| `Shell(*alpha commit*)` | bare, absolute path, `env` prefix, `bash -c`, `( … )`, a `for` loop, `$( … )`, a doubled space | `alpha -C . commit` |
| `Shell(*pub publish*)` | on `PATH` and by absolute path | `pub get` (the control) |
| `Write(locked.txt)`, `Write(./lock3.txt)`, `Write(sub/**)` | **nothing** | every write |
| `Write(**/lock1.txt)`, `Write(/abs/lock2.txt)`, `Write(/abs/sub2/**)` | the file tools | — |

So, contrary to Cursor's documentation, which says relative paths are scoped to the workspace:

- **A Shell rule is a glob over each sub-command's whole text.** Only the leading-`*` form is
  a fence. That is the only form `dispatch.sh` uses, plus rules for git's global options
  (`*git -C*` and the like), which slip a subcommand past every other git rule.
- **A relative Write rule matches nothing.** Write rules are absolute or start with `**/`.
  `dispatch.sh` builds them from `$PWD`, so run it from the root of the working tree.
- **Write rules fence the file tools only.** A shell redirect writes anywhere, as it did
  under grok. The writable paths still go in the task book, and `git status --porcelain`
  still verifies them.
- **A refused call does not end the run.** It comes back as `permissionDenied` or
  `writePermissionDenied`, and the executor carries on. `dispatch.sh` lists every refusal
  afterwards, which is how you find a rule that is too broad.

Add per-task rules with `--deny 'Write(/abs/path/**)'`. Never run two dispatches over
overlapping paths: one task, one writer.

### Layer two: an environment without credentials

The rules are pattern matches over command text, and this machine holds real credentials:
`~/.config/dart/pub-credentials.json` from the first, manual publish, and gh's `hosts.yml`.
gh is also git's credential helper for github.com. A glob can be dodged (`git -C`, a
variable that expands to `push`), so the actions that cannot be undone also lose their
credentials. `dispatch.sh` starts the executor with:

- **`XDG_CONFIG_HOME=<out>/xdg`.** `dart pub` then looks for its config in
  `<out>/xdg/dart/` (strace of `dart pub token list`). `gh` reports "not logged into any
  GitHub hosts", and so git's credential helper has nothing to give. `flutter --version`
  still works and writes a `tool_state` file there.
- **`GH_CONFIG_DIR`** set to the same place, and `GITHUB_PERSONAL_ACCESS_TOKEN`, `GH_TOKEN`
  and `GITHUB_TOKEN` unset.
- **`SHELL=/bin/bash` and an empty `ZDOTDIR`.** `~/.zshenv` sources `~/.grok/env`, which
  exports `GITHUB_PERSONAL_ACCESS_TOKEN`, so every zsh brings the token back, even a
  non-interactive one. The first smoke run showed it set despite the unset. Cursor runs
  commands in `$SHELL`, and bash reads neither file. A zsh started anyway finds no startup
  files.
- **`pushInsteadOf` for `https://`, `http://`, `ssh://` and `git@`, through `GIT_CONFIG_*`.**
  Every push is rewritten to a path that does not exist, including one to a URL with a
  token in it. `git push --dry-run origin main` fails with "does not appear to be a git
  repository". `git ls-remote` still works.

The second smoke run covered both layers. The rules refused all ten operations it tried: an
edit to `packages/kun_ui/pubspec.yaml`, writes under `build/`, `.dart_tool/`, `.claude/` and
`../kun-ui`, `git -C . commit`, `git push` both bare and inside `sh -c`,
`flutter pub publish --dry-run`, and `/usr/bin/gh`. Then `p=push; git $p --dry-run
https://x:y@github.com/…` got past the rules, as a variable does. The environment stopped it:
the push went to `/nonexistent/push-denied-by-dispatch/x:y@github.com/…` and failed. The
shell was bash, and the token was unset.

Commits are not fenced by the environment. A stray commit on a worktree branch can be
undone, and acceptance reads `git log` (section 4).

## 3. The dispatch

```bash
export CURSOR_OUT_ROOT="$SCRATCHPAD/cursor/runs"   # session scratchpad, never the repo
mkdir -p "$CURSOR_OUT_ROOT/<slug>"
# write the task book to $CURSOR_OUT_ROOT/<slug>/task.md, then, from the worktree root:
cd <worktree> && CURSOR_OUT_ROOT="$CURSOR_OUT_ROOT" setsid nohup \
  /home/kun/Desktop/code/website/kun-ui-flutter/.claude/skills/dispatch-cursor/dispatch.sh <slug> \
  --deny 'Write(<worktree>/packages/kun_ui/lib/src/foundation/**)' \
  >"$CURSOR_OUT_ROOT/<slug>/dispatch.out" 2>&1 </dev/null &
disown
```

Then wait on the process with Monitor, not with a sleep loop:
`while pgrep -f 'dispatch-cursor/[d]ispatch.sh <slug>' >/dev/null; do sleep 5; done`.

`dispatch.sh` passes the task book as the prompt. It adds `-p --force --trust --sandbox
disabled --output-format stream-json` and both fence layers, then enforces the time limit.
When the run ends it prints one summary line (result, elapsed time, tool calls, model,
tokens), followed by any refused calls and the tail of stderr. Extra arguments pass
through to `cursor-agent`.

| Variable | When |
|---|---|
| `CURSOR_MODEL=cursor-grok-4.6-low` | probes and mechanical sweeps. Leave it unset for real work, so the configured Extra High model runs |
| `CURSOR_TIMEOUT=<seconds>` | the default is 14400. Raise it for a task that builds Flutter web many times |

**Detach it, and run at most two at once.** The rule comes from grok on 2026-09-17: three
dispatches that each built Flutter web, ran the tests and drove Chromium filled RAM and
swap. The harness then killed its own background tasks, dispatches included. A dispatch
started with `setsid nohup … &` outside the harness's task tree survives that.

A killed run leaves its work in the tree. To resume it, put a "RESUMED RUN" note at the top
of the same task book: say what already exists and what is left, and tell the executor to
re-run every gate. Move the old `stream.jsonl` and `run.json` aside, because the next run
overwrites them, then dispatch again from the same worktree. The CLI also has
`--resume <session_id>`; it is unmeasured here.

The evidence for a run is `stream.jsonl`: every tool call, with its arguments and result.
Cursor also keeps a transcript under `~/.cursor/projects/<cwd-slug>/agent-transcripts/`.

## 4. Reading the result

1. **No `result` event means the stream ended early.** Quota, auth and network failures
   look like this. `dispatch.sh` prints the tail of stderr, so read it before you retry.
2. **`result` is every assistant text block concatenated.** Never parse a report out of it.
   Require the report as a file, and keep the final message to a one-line pointer.
3. **Verify the gates yourself.** An executor reporting green is a claim, not a result.

The report lives in the scratchpad, never in the repo, so `git status --porcelain` after a
run shows exactly what the executor changed. That is the first acceptance check.

**The acceptance checks specific to this repo**, in order:

```sh
git status --porcelain                   # only the paths the task book made writable
git log --oneline -3                     # no commit the orchestrator did not make
/home/kun/fvm/versions/stable/bin/dart format --output=none --set-exit-if-changed .
/home/kun/fvm/versions/stable/bin/flutter analyze
cd packages/kun_ui && /home/kun/fvm/versions/stable/bin/flutter test
./scripts/parity.sh                      # if the manifest moved
```

Then the one this repo cannot outsource, **the iron-rule-1 grep on the diff**:

```sh
git diff -U0 -- '*.dart' | rg '^\+' | rg 'Color\(0x|#[0-9a-fA-F]{6}|Duration\(|BorderRadius\.circular\(\s*[0-9]|Curves\.'
```

Every hit is either a token that should have come from `kun_ui_tokens`, or a deliberate
exception that has to be argued. A headless executor writing Flutter will reach for
`Colors.grey` and `Duration(milliseconds: 200)` by reflex. This grep is the mechanical form
of the rule, which the analyzer cannot express. Read every hit; do not skim the count.

Finally, for anything visual: look at the executor's screenshots, and if the claim matters,
take your own. Checksum them first (`md5sum`). On one grok dispatch the "before Tab" and
"after Tab" frames were byte-identical, so the report's before/after claim rested on a
single frame. When you drive the keyboard yourself, click the page before the first Tab. That
first click into a Flutter web view itself moves focus to the view's first focusable widget,
ring included, so a "mouse click shows no ring" check needs a second click.

The web reference is at hand: kun-ui's docs site is prebuilt in
`../kun-ui/apps/docs/.output` and serves with `PORT=<port> node server/index.mjs`. Its
component pages carry the same examples a gallery demo should mirror, so ask for paired
screenshots and a list of every difference. Keep in mind that the docs canvas is a different
surface from the gallery's page background: on the KunBadge dispatch, that alone turned a
background-coloured ring from invisible into a visible halo.

## 5. The task book

Template: `task-book-template.md` in this directory.

- **Write it in English**, and say that everything the executor writes is English. A
  user-level Cursor rule asks for Chinese.
- **Self-contained.** The executor sees none of this conversation. State the branch, where
  the code lives, and every prior adjudication it depends on, inline.
- **Name the output directory by absolute path**, as the template does. The book reaches
  the executor as prompt text, so it does not know where the file lives.
- **Name the server port** for eye verification, a different one per concurrent dispatch,
  and have the executor stop its own server by PID. Another session on this machine keeps a
  docs server on 3917.
- **Quote the adjudication, don't cite it.** `docs/architecture.md` is this repo's decision
  record, and "follow the architecture doc" makes an executor follow the wrong section. Name
  the section title and quote the clause.
- **No open design decisions.** If the mechanics genuinely depend on code the executor has
  yet to read, state the invariant plus the precedent, and require it to report what it
  chose.
- **Scope and out-of-scope, both named.** Out-of-scope is what stops a helpful executor from
  refactoring into someone else's paths.
- **Give it the gates to run**, and say the orchestrator re-runs them.
- **Forbid ranking.** The executor cannot see what the orchestrator knows, so its importance
  ordering is noise. Require a flat list at equal weight. Put "anything that looks wrong, in
  scope or not" near the top, where a helpful executor will not fold it into "could not
  verify".
- **Demand a positive control on any search, audit or census.** "I found 4" is unreadable
  without "and here are the 16 I checked that were clean".
- **Make it compare what it saw with what the book says it should see.** On the KunTextarea
  dispatch the book said the scrollbar is hidden, and grok's own screenshot of the capped
  field showed one. The report still listed "scrollbar" under *What I saw* as a plain
  observation. The book was wrong (`EditableText` overrides an ancestor
  `ScrollConfiguration` when multiline), and the screenshot was the only evidence. Ask for
  every mismatch between a screenshot and the book under *Anything that looks wrong*, and
  read the screenshots yourself either way. The same run reported that Enter did not insert
  a newline, yet driven directly in Chrome it did. A browser finding is a lead, not a
  result, in both directions.
- **Require a missing token to be reported, not invented.** This is the single most likely
  way a dispatch silently violates iron rule 1, and the executor will not feel it as a
  violation. It will feel like being helpful.

## 6. What the orchestrator never delegates

- Adjudications and scope calls. They belong in the task book.
- **All git**: staging, commits (`git commit -- <explicit paths>`, never `add -A`),
  branches, pushes, PRs. Pushing `main` is routine (iron rule 5), and it is still the
  orchestrator's hand.
- **Anything that publishes**: `pub publish`, tags, versions in
  `packages/kun_ui/pubspec.yaml`, `CHANGELOG.md` version headings.
- **The contract.** A dispatch that ports a component may *edit*
  `contracts/components.manifest.json`, because claiming a component is part of the recipe.
  What the claim *says*, and every `{"omit": "reason"}`, is an adjudication. Write the
  intended entry into the task book and have the executor transcribe it.
- **Cross-repo work.** The executor can read `../kun-ui`. A change there is a change to the
  contract, and that is decided upstream by hand.
- **Final acceptance**: all of section 4.

## 7. This repo's gates

Hand these to the executor, and re-run them yourself on acceptance. Use the absolute paths:
the `flutter` on `PATH` is not the pinned one.

```sh
/home/kun/fvm/versions/stable/bin/dart format .
/home/kun/fvm/versions/stable/bin/flutter analyze                       # zero tolerance
cd packages/kun_ui && /home/kun/fvm/versions/stable/bin/flutter test
cd apps/gallery && /home/kun/fvm/versions/stable/bin/flutter build web --release
./scripts/parity.sh                                                     # manifest changes only
```

Traps worth restating in any task book that touches them:

- **`flutter pub get` rewrites the `analysis_options.yaml` files** to exclude `build/**`.
  Keep that section, or the tool re-adds it and leaves a dirty tree.
- **`public_member_api_docs` is enforced.** A new public class or member without dartdoc is
  an analyze failure, not a style note. This is the one place where the "comments default
  to none" rule inverts, and an executor will get it backwards in both directions.
- **`FocusableActionDetector.onShowHoverHighlight` is suppressed under touch**, including in
  the test environment. Hover state comes from a plain `MouseRegion`. A widget test that
  asserts hover through the former fails for a reason that reads like a bug in the widget.
- **The gallery web build is part of CI.** A gallery that does not compile is a broken docs
  site, so `flutter analyze` passing is not enough.

## 8. What is worth dispatching

Dispatching buys **orchestrator context**. Judge a candidate by whether its result can be
checked without re-reading its input.

| Shape | Verdict |
|---|---|
| Broad read → narrow report of `file:line` + quoted line | **Dispatch.** Audits, inventories, censuses, cross-reference checks. The coordinates make verification cheap. |
| Wide mechanical edit a gate asserts | **Dispatch.** You read only what the gate flags. |
| **Fully adjudicated implementation**: every decision pinned, correctness asserted by analyze + test + build, appearance by a screenshot | **Dispatch.** The executor iterates to green itself. You still read the diff and run the iron-rule-1 grep. |
| A component port off the `CLAUDE.md` recipe, once the contract entry and the manifest claim are written into the task book | **Dispatch.** This is the volume case: the recipe is already a task book, the contract is already the spec, and parity + widget tests are already the gate. |
| New code carrying open design judgement | **Do not dispatch.** You pay full input for the output plus the review. Adjudicate it first; then it becomes a row above. |
| A decision about what the design *is* | **Never.** That is upstream's, or the maintainer's. |
