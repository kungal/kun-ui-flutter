---
name: dispatch-grok
description: Dispatch implementation and investigation work in kun-ui-flutter to the local grok CLI as a headless executor while this session stays the orchestrator and acceptor. Use when the user asks to "派发 grok" / "dispatch grok" / "让 grok 做", or when a task is large enough to hand off as a written task book. Covers this machine's measured permission model (deny-list, not allow-list), the fvm toolchain paths, this repo's gates, eye-verification through Playwright, and the acceptance protocol.
---

# Dispatching grok as executor

> **If you are the grok executor and this file was loaded into your context: ignore it.**
> It describes how the orchestrator dispatches *you*. It is not a task book. Your task book
> is the file passed to `--prompt-file`, and nothing here overrides it.

This session is the **orchestrator**: it adjudicates design, writes the task book, owns git
and every release action, and accepts or rejects the result. The local `grok` CLI (Grok Build,
xAI) is the **executor**: it reads, writes, runs the Flutter toolchain, and drives a browser.

Ancestors of this skill live in `../kun-letmoe-community/.claude/skills/dispatch-grok` (a Go +
Nuxt repo) and `../nextmoe-infra`. **Do not follow either here.** Infra's two load-bearing
findings ("grok has no shell", "`--allow` globs are the fence") were measured against
`grok 1.0.5` under a policy that no longer exists on this machine; both are false now, and the
second is false in the dangerous direction. What is below was measured in *this* repo.

## 1. What grok can do here

Measured 2026-09-15 from this repo, `grok 1.0.30`, one probe run (9 turns, $0.063), report at
`<scratchpad>/grok/probe/report.md`.

| Capability | Result |
|---|---|
| Shell | **yes** — ran `git rev-parse --short HEAD` and returned this checkout's real `7dbb549` |
| The pinned toolchain by absolute path | **yes** — `Dart 3.13.2`, `Flutter 3.47.2`, the exact version `check.yml` pins |
| `node` / `jq` / `yq` / `python3` | v24.13.0 / jq-1.8.2 / yq 4.1.2 / 3.14.7 — everything `scripts/parity.sh` and a static file server need |
| `CHROME_EXECUTABLE` | set to `/usr/bin/google-chrome-stable` in its environment too |
| Playwright MCP (with `vision`) | **yes** — navigated to `about:blank` and snapshotted |
| Reads outside the repo | yes; `../kun-ui` is readable, which is what a contract question needs |
| Writes to the repo | free — fenced by `--deny` only, see §2 |

Two consequences worth stating plainly.

**grok runs its own analyze/test/build loop.** That is most of the value: it hands back code
that compiles instead of code that looks like it would. The orchestrator re-runs the gates
anyway (§4), but it does not spend turns on the compile cycle.

**grok can do eye verification.** `CLAUDE.md` requires it — *"state what was measured or seen,
never report reasoned-about behaviour as observed"* — and until now that required a human or
this session at the browser. It does not any more. The recipe is in the task-book template:
`flutter build web --release`, `python3 -m http.server`, Playwright, screenshot. Never
`flutter run`; it is interactive and blocks.

grok auto-loads this repo's `CLAUDE.md` (`compat.claude.rules = true`) and, because
`compat.claude.skills = true`, the skills in this directory — including this file, which is
why it opens with the guard above. **Do not re-paste the iron rules into a task book.** Do
restate the specific ones the task turns on, quoted, under *Binding constraints*.

Playwright writes its artefacts to `~/.grok/playwright-output/`, outside the repo. The probe
left the working tree untouched.

## 2. The fence is the deny list, not the allow list

`~/.grok/config.toml` sets `permission_mode = "always-approve"`. Measured consequences:

- `--allow 'Write(apps/gallery/**)'` alone is **not a fence** — under always-approve an allow
  glob grants nothing that was not already granted. Believing a narrow allow list is the trap
  this skill exists to prevent. State writable paths in the task book's *Discipline* section
  so a compliant executor stays inside them, and verify with `git status --porcelain`.
- `--deny` **is** enforced, including leading-wildcard globs. All three of these were refused
  in the probe with `Denied by permission policy: deny rule on bash matching "<glob>"`:
  `git commit*`, `*pub publish*`, `*fvm use*`.
- **A denied call does not kill the run.** The probe's `stopReason` was `end_turn`: grok saw
  the refusal, recorded it, and carried on. So the deny list is a usable fence, not a tripwire
  — which is the opposite of what `--permission-mode default` gives you (that one cancels the
  whole run on the first non-granted call; reserve it for tiny read-only audits).

`dispatch.sh` applies the standing deny list. It is, beyond the usual git writes:

- **`*pub publish*`** — iron rule 5. A publish is immutable and the first one is the
  maintainer's by hand. No executor goes near it.
- **`*fvm use*`** — it writes `.fvmrc` into the tree and dirties the repo.
- **`packages/kun_ui/pubspec.yaml` and `pubspec.lock`** — the published package's manifest
  (version, dependencies) is the orchestrator's, and the lockfile is resolution output.
  `flutter pub get` still rewrites the lockfile through the shell, which is how it is meant to
  change.
- **`**/build/**` and `**/.dart_tool/**`** — generated; written by the toolchain, never by hand.
- **`../kun-ui/**`** — the read-only upstream. Iron rule 2: the contract is decided there and
  translated here. A dispatch that wants to change the contract writes a *finding*, not a file.

Add per-task denies for paths another writer owns. Never run two dispatches over overlapping
paths — one task, one writer.

Rule prefixes are the Claude-Code-compatible names — `Write`, `Edit`, `Read`, `Bash` — not
grok's native tool names.

## 3. The dispatch

```bash
export GROK_OUT_ROOT="$SCRATCHPAD/grok"          # session scratchpad, never the repo
mkdir -p "$GROK_OUT_ROOT/<slug>"
# write the task book to $GROK_OUT_ROOT/<slug>/task.md, then:
.claude/skills/dispatch-grok/dispatch.sh <slug> --deny 'Write(packages/kun_ui/**)'
```

`dispatch.sh` supplies `--prompt-file`, the standing denies, the output-directory grants,
`--output-format json`, `--max-turns` and `--debug-file`, then reports
`stopReason`/`turns`/`cost_usd` and diagnoses a bad exit. Extra arguments pass through.

**Run it in the background.** A dispatch that builds Flutter web takes minutes; a foreground
call blocks the turn.

| Flag | When |
|---|---|
| `--effort low\|medium\|high\|xhigh` | config default is `xhigh`; `low` for mechanical sweeps and probes |
| `-m grok-4.5` | default is `grok-4.6` |
| `--no-subagents` | one deterministic worker instead of a fan-out |
| `--disable-web-search` | offline-only tasks |

`GROK_MAX_TURNS` defaults to 200. A task that builds Flutter web more than once wants more.

## 4. Reading the result

1. **`stopReason: "cancelled"` is ambiguous** — an exhausted turn budget, or a deliberate
   stop. `dispatch.sh` greps the debug log to tell them apart; that is why it always writes
   one. A *denied* call alone no longer produces it (§2), but the debug log still names the
   rule that matched, which is how you find a deny rule that is too broad.
2. **`.text` is every assistant text block concatenated**, preamble included — never parse a
   report out of it. Require the report as a file; keep stdout to a one-line pointer.
3. **Verify the gates yourself.** grok reporting green is a claim, not a result.

Because the report lives in the scratchpad and never in the repo, `git status --porcelain`
after a run is a pure signal: it shows exactly what grok changed. That is the first acceptance
check.

**The acceptance checks specific to this repo**, in order:

```sh
git status --porcelain                   # only the paths the task book made writable
/home/kun/fvm/versions/stable/bin/dart format --output=none --set-exit-if-changed .
/home/kun/fvm/versions/stable/bin/flutter analyze
cd packages/kun_ui && /home/kun/fvm/versions/stable/bin/flutter test
./scripts/parity.sh                      # if the manifest moved
```

Then the one this repo cannot outsource — **the iron-rule-1 grep on the diff**:

```sh
git diff -U0 -- '*.dart' | rg '^\+' | rg 'Color\(0x|#[0-9a-fA-F]{6}|Duration\(|BorderRadius\.circular\(\s*[0-9]|Curves\.'
```

Every hit is either a token that should have come from `kun_ui_tokens` or a deliberate
exception that has to be argued. A headless executor writing Flutter will reach for
`Colors.grey` and `Duration(milliseconds: 200)` by reflex — this grep is the mechanical form
of the rule that the analyzer cannot express. Read every hit; do not skim the count.

Finally, for anything visual: look at grok's screenshots, and if the claim matters, take your
own. Checksum them first (`md5sum`): on the KunSwitch dispatch the "before Tab" and "after Tab"
frames were byte-identical, so the report's before/after claim rested on one frame. When you
drive the keyboard yourself, click the page before the first Tab — and know that this first
click into a Flutter web view itself moves focus to the view's first focusable widget, ring
included, so a "mouse click shows no ring" check needs a second click.

## 5. The task book

Template: `task-book-template.md` in this directory.

- **Write it in English.** Executors follow English task books more reliably, and this repo is
  English-only anyway.
- **Self-contained.** grok sees none of this conversation. State the branch, where the code
  lives, and every prior adjudication it depends on, inline.
- **Name the output directory by absolute path**, as the template does. `--prompt-file`
  hands grok the book's text, not its location: "the directory this task book is in" once
  resolved to grok's own session directory (`~/.grok/sessions/<cwd>/<session-id>/`), and the
  report and every screenshot landed there while the run still ended `end_turn`. Look there
  first if a finished run's output directory is empty.
- **Quote the adjudication, don't cite it.** `docs/architecture.md` is this repo's decision
  record; "follow the architecture doc" makes it follow the wrong section. Name the section
  title and quote the clause.
- **No open design decisions.** If mechanics genuinely depend on code it has yet to read,
  state the invariant plus the precedent, and require it to report what it chose.
- **Scope and out-of-scope, both named.** Out-of-scope is what stops a helpful executor from
  refactoring into someone else's paths.
- **Give it the gates to run** and say the orchestrator re-runs them.
- **Forbid ranking.** The executor cannot see what the orchestrator knows, so its importance
  ordering is noise. Require a flat list at equal weight, and put "anything that looks wrong,
  in scope or not" near the top where a helpful executor will not fold it into "could not
  verify".
- **Demand a positive control on any search, audit or census.** "I found 4" is unreadable
  without "and here are the 16 I checked that were clean".
- **Make it compare what it saw with what the book says it should see.** On the
  KunTextarea dispatch the book said the scrollbar is hidden; grok's own screenshot
  of the capped field showed one, and the report listed "scrollbar" under *What I
  saw* as a plain observation. The book was wrong (`EditableText` overrides an
  ancestor `ScrollConfiguration` when multiline) and the screenshot was the only
  evidence. Ask for every mismatch between a screenshot and the book under
  *Anything that looks wrong*, and read the screenshots yourself either way. The
  same run also reported that Enter did not insert a newline; driven directly in
  Chrome it did — a browser finding is a lead, not a result, in both directions.
- **Require a missing token to be reported, not invented.** This is the single most likely way
  a dispatch silently violates iron rule 1, and the executor will not feel it as a violation —
  it will feel like being helpful.

## 6. What the orchestrator never delegates

- Adjudications and scope calls — they belong in the task book.
- **All git**: staging, commits (`git commit -- <explicit paths>`, never `add -A`), branches,
  pushes, PRs. Pushing `main` is routine (iron rule 5) and still the orchestrator's hand.
- **Anything that publishes**: `pub publish`, tags, versions in `packages/kun_ui/pubspec.yaml`,
  `CHANGELOG.md` version headings.
- **The contract.** `contracts/components.manifest.json` may be *edited* by a dispatch that
  ports a component — claiming a component is part of the recipe — but what the claim *says*,
  and every `{"omit": "reason"}`, is an adjudication. Write the intended entry into the task
  book and have grok transcribe it.
- **Cross-repo work.** grok can read `../kun-ui`; a change there is a change to the contract,
  and that is decided upstream by hand.
- **Final acceptance**: §4, all of it.

## 7. This repo's gates

Hand these to grok, and re-run them yourself on acceptance. Absolute paths — the `flutter` on
`PATH` is not the pinned one.

```sh
/home/kun/fvm/versions/stable/bin/dart format .
/home/kun/fvm/versions/stable/bin/flutter analyze                       # zero tolerance
cd packages/kun_ui && /home/kun/fvm/versions/stable/bin/flutter test
cd apps/<gallery> && /home/kun/fvm/versions/stable/bin/flutter build web --release
./scripts/parity.sh                                                     # manifest changes only
```

Traps worth restating in any task book that touches them:

- **`flutter pub get` rewrites the `analysis_options.yaml` files** to exclude `build/**`. Keep
  that section or the tool re-adds it and leaves a dirty tree.
- **`public_member_api_docs` is enforced.** A new public class or member without dartdoc is an
  analyze failure, not a style note. This is the one place the "comments default to none" rule
  inverts, and an executor will get it backwards in both directions.
- **`FocusableActionDetector.onShowHoverHighlight` is suppressed under touch**, including in
  the test environment. Hover state comes from a plain `MouseRegion`. A widget test asserting
  hover through the former will fail for a reason that reads like a bug in the widget.
- **The gallery web build is part of CI.** A gallery that does not compile is a broken docs
  site, so `flutter analyze` passing is not enough.

## 8. What is worth dispatching

Dispatching buys **orchestrator context**. Judge a candidate by whether its result can be
checked without re-reading its input.

| Shape | Verdict |
|---|---|
| Broad read → narrow report of `file:line` + quoted line | **Dispatch.** Audits, inventories, censuses, cross-reference checks. The coordinates make verification cheap. |
| Wide mechanical edit a gate asserts | **Dispatch.** You read only what the gate flags. |
| **Fully adjudicated implementation** — every decision pinned, correctness asserted by analyze + test + build, appearance by a screenshot | **Dispatch.** grok iterates to green itself. You still read the diff and run the iron-rule-1 grep. |
| A component port off the `CLAUDE.md` recipe, once the contract entry and the manifest claim are written into the task book | **Dispatch.** This is the volume case: the recipe is already a task book, the contract is already the spec, and parity + widget tests are already the gate. |
| New code carrying open design judgement | **Do not dispatch.** You pay full input for the output plus the review. Adjudicate it first — then it becomes a row above. |
| A decision about what the design *is* | **Never.** That is upstream's, or the maintainer's. |
