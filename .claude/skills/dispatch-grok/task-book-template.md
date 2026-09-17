# Task: <one line, imperative, what gets built>

You are the **executor**. The orchestrator wrote this task book; it is self-contained.
You cannot see the orchestrator's conversation. Everything you need is below.

## Context

Repository: `/home/kun/Desktop/code/website/kun-ui-flutter` (your working directory).
Branch: `<branch>` at `<short sha>`.

<What this repo is in one paragraph if the task needs it. Where the relevant code lives —
exact paths. What it does today. Why it is changing. Every prior adjudication this task
depends on, stated inline: `docs/architecture.md` decisions are the adjudication record, so
quote the clauses this task turns on rather than pointing at the file.>

## Your environment

- You have a shell, LSP and Playwright. Use them.
- Call the Flutter toolchain **by absolute path** — this machine uses fvm and the binaries
  on `PATH` are not the pinned ones:

      /home/kun/fvm/versions/stable/bin/flutter
      /home/kun/fvm/versions/stable/bin/dart

  Never run `fvm use`; it writes `.fvmrc` into the tree and dirties the repo.
- The repository `CLAUDE.md` is already in your context. Its six iron rules bind you.
  The two that bite hardest here:
  **(1) never hand-write a token value** — every colour, radius, shadow, easing and
  duration comes from `kun_ui_tokens`; a hex literal or an ad-hoc `Duration` in a widget
  is the defect this whole repo exists to prevent, and a missing token is a bug to
  *report*, never a local constant to invent;
  **(6) zero third-party packages** — the library depends on exactly `kun_ui_tokens` +
  `kun_ui_icons` + `kun_ui_messages` and nothing else. Do not add a dependency to any
  pubspec. If you believe one is needed, stop and report it.
- **Comments default to NONE.** A comment is earned by an incident and records the wrong
  conclusion so it is not reached again. Dartdoc on public members is different — it is
  mandatory, `public_member_api_docs` is enforced by `flutter analyze`.
- **You cannot run git writes, `gh`, `pub publish`, or `fvm use`** — they are denied at the
  permission layer and the orchestrator owns them. Do not try; report instead.
- Do not write outside the paths named in Discipline, and never write a sibling repository.
  `../kun-ui` is the read-only upstream: read it freely, change nothing in it.

## Binding constraints for this task

<Name the document and the section, with the clause quoted. Not "follow the architecture doc".>

- `docs/architecture.md` §<section title>: "<quoted line>"
- `CLAUDE.md` <rule>: "<quoted line>"

## Scope

1. <numbered, concrete, each independently checkable>
2. …

## Out of scope

- <what a helpful executor would otherwise wander into>
- Renaming, reformatting or refactoring anything not named in Scope.

## Precedent to follow

<Point at existing code that already does this correctly: file:line. Say what to copy — the
shape, the naming, the dartdoc voice — and what not to. `packages/kun_ui/lib/src/components/`
is the house style for widgets; `packages/kun_ui/test/` for tests.>

## Gates

Run these yourself, from the repository root, and iterate until they are green. The
orchestrator re-runs every one of them on acceptance, so a green claim you did not actually
run costs you the dispatch.

```sh
/home/kun/fvm/versions/stable/bin/dart format .
/home/kun/fvm/versions/stable/bin/flutter analyze
cd packages/kun_ui && /home/kun/fvm/versions/stable/bin/flutter test && cd ../..
cd <the gallery app> && /home/kun/fvm/versions/stable/bin/flutter build web --release && cd ../..
```

<Add only if the task touches contracts/components.manifest.json:>

```sh
./scripts/parity.sh      # clones kungal/kun-ui at the pinned tag; needs network
```

`flutter pub get` rewrites the `analysis_options.yaml` files to exclude `build/**`. That is
expected; keep the section, or the tool re-adds it and leaves a dirty tree.

## Eye verification

<Delete this whole section for a task with nothing visual. Keep it for anything that renders.>

`CLAUDE.md` is explicit: *"state what was measured or seen, never report reasoned-about
behaviour as observed."* So look at it. Do not use `flutter run` — it is interactive and
will block you. Build and serve the static output instead:

```sh
cd <the gallery app> && /home/kun/fvm/versions/stable/bin/flutter build web --release
cd build/web && python3 -m http.server 8731 &
```

Then drive Playwright to `http://localhost:8731/#/<route>` and take a screenshot. Navigate
to `about:blank` first and then to the real URL — going straight to a hash route on a fresh
page lands on the app's start route instead. The gallery centres each demo in the viewport.
Kill the server when you are done with `pkill -f 'http[.]server 8731'` on its own line: the
brackets stop the pattern from matching the shell that runs it (a plain pattern kills that
shell), and a non-zero exit in a `&&` chain would abort the rest of your command.

For screenshots at device scale factor 2, use a node script, not the Playwright MCP, which
cannot change its scale factor:

```js
import { chromium } from '/home/kun/.npm/_npx/9833c18b2d85bc59/node_modules/playwright/index.mjs';
const browser = await chromium.launch({
  headless: false,
  executablePath: '/home/kun/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome',
  args: ['--ignore-gpu-blocklist', '--enable-webgl', '--disable-gpu-sandbox', '--no-sandbox'],
});
const context = await browser.newContext({ viewport: { width: 1000, height: 700 }, deviceScaleFactor: 2 });
```

Run it as `DISPLAY=:0 node <script>.mjs`, with the script in the report directory, and wait
about 9 seconds after each navigation: the first frames are blank while fonts load.

Put the screenshot paths in your report and say what you actually saw in each.

## Report

Write your report to this exact absolute path:

    <GROK_OUT_ROOT>/<slug>/report.md

Structure:

```
# Report: <task>

## 1. What I changed
(file:line per change, one line each, what and why)

## 2. Anything that looks wrong — in scope or not
(report every one, at the same weight, with file:line and the quoted line. Something outside
 this task's scope belongs here, not in section 5, and not with a note that it was out of
 scope. Report it; do not fix it.)

## 3. Mechanics I chose
(any decision the task book left to the code — what you picked and the precedent you followed)

## 4. Deviations from the task book
(if none, write "None.")

## 5. Gates
(each command above, and its actual last line of output — not a summary)

## 6. What I saw
(one line per screenshot: the URL, the file path, and what is actually on screen.
 Delete if the task had no eye verification.)

## 7. What I could not verify
(be specific about what the orchestrator should check, not just "run the tests")
```

Your final stdout message: one short paragraph, the report path plus a one-line status.
Do not paste the report into stdout.

## Discipline

- Writable paths — **exactly** these, nothing else anywhere:
  - `<glob 1>`
  - `<glob 2>`
  - the report path above
- Forbidden: any git write; `gh`; `pub publish`; `fvm use`; editing
  `packages/kun_ui/pubspec.yaml`, `pubspec.lock`, any `build/` or `.dart_tool/` directory,
  or any sibling repository.
- **Report, don't work around.** If something is missing, contradictory or blocked, stop and
  write it in section 4 or 7. A blocked task reported accurately is a success; a task
  completed by inventing around the block is not. In particular: a missing **token** is
  reported, never replaced by a literal.
- **Do not rank, score or filter your findings.** You cannot see what the orchestrator knows,
  so you cannot tell which finding matters most. Report every one flat, at equal weight.
  Never demote something to "minor", "cosmetic" or "out of the requested classes" — that
  judgement is the orchestrator's and yours will be wrong.
- <Delete unless the task is a search, audit or census:> **Include a positive control.** A
  count of what you did *not* find is worthless unless the search is known to work. List what
  you checked that came back clean, with counts, so the zero can be believed.
