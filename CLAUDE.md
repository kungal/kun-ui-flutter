# CLAUDE.md — kun-ui-flutter (KunUI for Flutter)

## 铁律 (Iron Rules — non-negotiable; these override every other guideline in this file)

1. **Never hand-write a token value.** Every color, radius, shadow, spacing
   step, type size, easing and duration comes from `kun_ui_tokens` (and every
   icon from `kun_ui_icons`) — all generated in kungal/kun-ui from the same
   source as the web stylesheet.
   The moment a hex literal or an ad-hoc `Duration` appears in a widget, web
   and Flutter fork silently; shadcn's `zinc.dart` (three ports, three
   different greys) is the exhibit the whole architecture exists to prevent.
   A missing token is a kun-ui issue, not a local constant.
2. **This repo is upstream for every Flutter app in the ecosystem** — the same
   rule kun-ui carries for the websites: consumers never modify KunUI locally,
   they report here; every change here ships to every app. Additive first;
   treat an API change as a breaking-change review. And this repo is itself
   *downstream of kun-ui*: the design (variant matrix, control scale, contract
   surface) is decided there and translated here — never invented here. When a
   web component's design looks wrong, fix it in kun-ui first.
3. **The contract is a floor you must answer for.** A component claimed in
   `contracts/components.manifest.json` must cover or explicitly omit (with a
   reason) every prop/event/slot the upstream contract lists — CI diffs the
   manifest against kungal/kun-ui checked out at the pinned release tag and
   fails on drift. Never claim a component you have not fully answered for,
   and never "fix" a parity failure by deleting the claim of a shipped widget.
   Absence is not drift: unported components are information (scope is
   on-demand), so an unstarted component needs no manifest entry.
4. **No Material coupling.** `KunTheme` (KunUI's own `InheritedWidget`) is the
   only KunUI ancestor a widget may require, and beyond it nothing an app
   shell does not already build: a `Navigator` and the `Overlay` it carries
   (a text field needs the `Overlay`, as every Flutter text field does, and a
   modal is pushed onto the `Navigator`). `WidgetsApp` builds the `Navigator`
   itself, or leaves it to the router delegate under `WidgetsApp.router`, and
   every real delegate builds one. Never
   `Theme.of(context)`, no `MaterialApp` assumption, no Material widgets
   inside library code (forui
   and shadcn_ui made the same call: an independent design language is not a
   Material skin). The gallery app may use Material chrome; the library
   may not.
5. **A push of a `kun_ui-v*` tag publishes to pub.dev.** Pushing `main` is
   routine and needs no permission — the repo is public, CI costs nothing,
   and a branch push is reversible. A *tag* is not: it publishes an immutable
   version to pub.dev, so a release is a decision, never a side effect of
   other work. Since 2026-09-16 the maintainer has delegated that decision
   to the orchestrating session; a dispatched executor never tags, retags or
   publishes. The first publish had to be run manually by the user (0.1.0,
   2026-09-15); from 0.2.0 on, the tag-triggered OIDC workflow publishes.
   Never hand-edit a version to "fix" a release.
6. **A new dependency needs a capability argument, never a convenience one**
   — inherited from kun-ui verbatim. The library depends on exactly the
   generated family — `kun_ui_tokens` + `kun_ui_icons` + `kun_ui_messages`,
   all emitted upstream on one release train — and **zero** third-party
   packages, which is the intended steady state: Flutter ships layout,
   gestures, animation and painting in the framework, so the honest default
   answer to "should kun_ui use package X" is no. A sibling arriving from
   kun-ui is not a new dependency in this sense; anything else is.

## What this repo is

The tier-4 component implementations of the KunUI Flutter roadmap
(kungal/kun-ui `docs/architecture-flutter.md` §5): hand-written widgets on the
generated tokens, one shared library consumed by all Flutter apps — the exact
analogue of `@kungal/ui-vue` serving N websites. Tiers 0–2 (tokens, icons,
motion — and the message catalogs) generate in kun-ui and arrive here as pub
dependencies; tier 3 (the contracts) lives in kun-ui and is enforced here by
CI.

Pub workspace (Dart 3.6+), one lockfile at the root:

- `packages/kun_ui` — the library. `KunTheme`/`KunThemeData`, the design
  vocabulary enums (`KunUIVariant`/`KunUIColor`/`KunUISize`/`KunUIRounded` —
  the contract's unions verbatim, with web `default` → `neutral` because
  `default` is a Dart reserved word), `KunVariantStyle` (the variant × color
  matrix), `KunControlMetrics` (the shared control size scale), and the
  widgets, plus `KunMessagesScope` (KunUI's own strings, resolved from
  `kun_ui_messages`, never a required ancestor). Re-exports all three
  generated packages so consumers import one thing.
- `apps/gallery` — plays the role `apps/docs` plays in kun-ui: the component
  gallery during development (`flutter run -d chrome`) and the deployable
  docs site (`flutter build web`). Every claimed component gets a page; a
  gallery that does not compile is a broken docs site, so CI builds it. One
  URL per demo, theme and locale from the query string, no chrome around the
  widget. `gallery.spec.json` says which demo shows which contract name and
  `tool/gen_gallery.dart` emits the registry and the coverage pages from it
  and the manifest — so a claimed name with neither a demo nor a recorded
  reason fails generation, and CI re-runs the generator to prove the checked-in
  output is current. The `widgetbook` package it replaced was ruled out on
  2026-09-15: read both decisions in `docs/architecture.md` before growing
  this app, in particular the list of things it deliberately does not rebuild,
  knobs first among them.
- `contracts/components.manifest.json` — what this port claims, in the format
  documented in kun-ui `contracts/README.md`.

**Versioning is independent of the 2.x lockstep.** `kun_ui` has its own
version (0.x today); the *contract* version is the `kun_ui_tokens` version
pubspec.lock resolves, and `scripts/parity.sh` checks upstream out at exactly
that tag. Bumping the tokens dependency IS adopting a new contract — expect
parity to surface new surface to answer for, in the same change.

## Commands

The maintainer's machine uses fvm; call the binaries by absolute path
(`/home/kun/fvm/versions/stable/bin/{flutter,dart}`), never `fvm use` (it
dirties the repo with `.fvmrc`). CI pins the same version (3.47.2) in
`check.yml` — keep the two in lockstep when upgrading.

```bash
flutter pub get                    # once, at the root (workspace-wide)
dart format .                      # CI rejects unformatted code
flutter analyze                    # workspace-wide, zero tolerance
flutter test                       # in packages/kun_ui
flutter run -d chrome              # in apps/gallery — the live gallery
flutter build web --release        # in apps/gallery — the docs build
dart run tool/gen_gallery.dart     # in apps/gallery — regenerate the registry
./scripts/parity.sh                # contract parity (KUN_UI_DIR=... for a local checkout)

# On a real Android device (touch, IME and screen-reader behaviour only shows there)
flutter build apk --debug          # in apps/gallery, then: adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.kungal.kun_ui_gallery/.MainActivity --es route "/kunselect/clearable"
```

## The CI gate (`check.yml`)

Three jobs. **check**: format → analyze → test → gallery web build.
**floors**: `flutter pub downgrade` → analyze → test. `pub get` resolves the
*newest* version each constraint allows, so a dependency floor that is too
low passes every other check and fails only in a consumer whose lockfile
pins an older one — 0.9.0 shipped calling `KunImages.loadingImage` while
declaring `kun_ui_icons: ^2.42.3`, which does not have it, and the kungal app
could not compile. **Bumping the generated family means bumping the floor,
not just the resolved version.**
**parity**: reads the resolved `kun_ui_tokens` version from pubspec.lock,
clones kungal/kun-ui at `kun_ui_tokens-v<version>`, runs its
`scripts/flutter-parity.mjs` against our manifest. Traps already hit:

- `flutter pub get` rewrites `analysis_options.yaml` files to exclude
  `build/**` — keep that section or the tool re-adds it in a dirty tree.
- `FocusableActionDetector.onShowHoverHighlight` is gated on the focus
  highlight mode and is suppressed entirely under touch (including the test
  environment). The web's `:hover` has no such coupling, so hover state comes
  from a plain `MouseRegion` — a touch device simply never hovers.
- Flutter web sends Enter as `ButtonActivateIntent`, not `ActivateIntent`
  (`WidgetsApp` keeps a separate web shortcut map), so a pressable widget
  handles both — and a test proving it binds the web map itself, because
  the VM's defaults send Enter as `ActivateIntent` and hide the bug.
- `Container(alignment: …)` fills a bounded parent: its `Align` has no size
  factors. A web `inline-flex items-center justify-center` box that
  shrink-wraps its text centres with `Align(widthFactor: 1, heightFactor: 1)`
  instead. A task book that said `Container.alignment` produced a standalone
  KunBadge 800px wide.
- A `SemanticsRole` can carry requirements the ARIA role does not.
  `progressBar` asserts the node has a value, a minValue and a maxValue, all
  parseable numbers with the value between the bounds — so an indeterminate
  bar takes no role at all, where ARIA allows `role="progressbar"` with no
  `aria-valuenow`. `status` refuses to be a live region as well, because it
  already is one. Both fired at runtime, not at compile time.
- In `flutter test` the paragraph cache does not key on
  `leadingDistribution`: laying the same string out again with only that
  changed returns the first layout's metrics, which reads as "even and
  proportional place glyphs identically". Assert on the resolved
  `TextStyle` instead, or use a different string per measurement.

## Cutting a release (a decision, not a side effect — iron rule 5)

1. The CHANGELOG already carries the version's heading. Bump
   `packages/kun_ui/pubspec.yaml` **and** the gallery's `kun_ui:` constraint:
   while the package is 0.x, `^0.1.0` does not admit 0.2.0 and the
   workspace stops resolving.
2. `flutter pub publish --dry-run` in `packages/kun_ui` — the only
   acceptable warning is the uncommitted tree.
3. Commit, push, and wait for `check.yml` to pass on that commit.
4. `git tag -a kun_ui-v<version>` on it and push the tag; `publish-pub.yml`
   uploads. The job log's "Successfully uploaded" is the verdict — the
   pub.dev API can take up to 10 minutes to list the version.
5. `gh release create kun_ui-v<version>` with the CHANGELOG section as the
   notes.

## Porting a component (the recipe)

Scope is on-demand (§7 decision 3 upstream): a component enters this library
when a real app needs it, and one consumer is not a component. Then:

1. Read its contract entry: `jq '.components.KunX' contracts/component-contracts.json`
   in kun-ui (at the pinned tag). That is the surface to answer for —
   `webOnlyProps` are already excluded with reasons.
2. Read the web implementation (`packages/vue/src/components/X.vue`) and the
   ui-core tables it consumes (`variants.ts`, `controlSize.ts`) — translate
   values, never re-derive by eye. A spacing class is `KunSpacing.unit`
   times its own step (`px-2.5` → `KunSpacing.unit * 2.5`; a value built
   from several classes writes the class steps out, not their sum), and
   `text-<step>` is `KunText.<step>`, `font-<weight>` is
   `KunFontWeights.<weight>`, a bare `rounded-<step>` (no `kun-`) is
   `KunRounded.<step>`, `border-kun` is `scheme.border`, and
   `animate-pulse` / `animate-spin` are `KunPulse` / `KunSpin`. Only an
   arbitrary value (`size-[26px]`) or a non-spacing width (`ring-2`) stays
   a literal. The schemes store every color opaque, but the web draws
   `background` and `default-100` at `KunColors.globalOpacity`, and an
   opacity modifier multiplies it: `bg-background/80` is alpha 0.56, and
   `ring-offset-background` paints its gap at 0.7 rather than leaving it
   clear.
   `v-model` maps to `value` + `onChanged`; slots map to `Widget`
   parameters; `ariaLabel` maps to `semanticLabel`.
3. Write the widget in `packages/kun_ui/lib/src/components/`, export it from
   `kun_ui.dart`, dartdoc every public member (`public_member_api_docs` is
   enforced — the dartdoc is the docs surface, as JSDoc is on the web).
4. Claim it in `contracts/components.manifest.json` — map every contract name
   to its Dart name or `{"omit": "reason"}`. Run `./scripts/parity.sh`.
5. Widget tests for behaviour (this repo HAS a test runner — use it: sizes,
   press/disabled/loading semantics, theme resolution). Golden tests are
   deliberately not used yet; the eye-verification surface is the gallery.
6. A demo in the gallery. Mechanical axes — enum crosses, boolean states —
   are generated from the manifest, not typed out; hand-write only a demo
   that needs judgment, and say which it is.
7. A `CHANGELOG.md` entry under the next version heading. English.

## Conventions

- Path-scoped commits (`git commit -- <paths>`), never `add -A`; message via
  `-F <file>` (everything after `--` is a path). English-only commit
  messages, comments, changelog and docs.
- Comments follow kun-ui's rule: **default none** — a comment is earned by an
  incident and records the wrong conclusion so it is not reached again.
  Dartdoc on public members is documentation, not a comment, and is
  mandatory.
- Widgets take `disabled` as a prop (the web contract separates looks from
  listeners); a null callback does nothing but does not gray the widget out —
  unlike Material's `onPressed: null` convention. Keep that consistent.
- Animations use `KunEasing`/`KunDurations` from tokens; anything ballistic
  shares its physics via `KunShatterPhysics`-style generated constants — if a
  new animation needs a constant the tokens don't carry, that constant is
  born in kun-ui's generator, not here (iron rule 1). Every duration goes
  through `kunMotion`, or the widget checks `kunReducedMotion` and jumps:
  kun-ui's base stylesheet collapses every transition under reduced motion,
  and nothing in Flutter does that for us.
- The `KunUI*` enum names look unusual next to Dart's `KunUi` casing
  convention for >2-letter acronyms, but `UI` is two letters and the names
  match the contract vocabulary exactly — grep-ability across the two repos
  wins. Do not "fix" the casing.

## Verifying work

`flutter test` is the first line (unlike kun-ui, which has no test runner).
For anything visual, run the gallery (`flutter run -d chrome` in
`apps/gallery`) and look — state what was measured or seen, never report
reasoned-about behaviour as observed. Touch, IME and screen-reader behaviour
is not visible in a browser or in `flutter test`: build the gallery's Android
target and measure it on the device (`docs/architecture.md`, "The gallery also
builds for Android"). A desktop browser hovers, a hardware keyboard commits
text without composing, and a widget test's semantics tree is not the Android
node tree a screen reader reads. The web reference for any component is the
kun-ui docs site or its playground; when in doubt about a value, read the web
source, not the rendered pixels.

Two rules the 0.7.0/0.8.0 round earned, where five of six defects came from
the gallery or the device and none from a test:

- **A widget that takes a slotted child is tested with a real one.**
  `KunPopover` and `KunDropdown` could not be opened at all when their
  trigger was a `KunButton` — a nested `GestureDetector` wins the gesture
  arena outright, where a DOM click bubbles to the wrapper — and every test
  passed, because they all slotted a bare `Text`. A `Text` or a `SizedBox`
  exercises none of the interaction, focus or semantics a real KunUI widget
  brings, so each such component gets at least one test that passes one.
- **Dump the Android node tree after porting a component, not only before a
  release.** `uiautomator dump` caught three accessibility defects in
  0.8.0 that the semantics tree in `flutter test` renders perfectly well: a
  trigger with no accessible name, a progress bar that was a plain `View`,
  and a checkbox announcing itself disabled. What the widget test asserts is
  the Flutter tree; what a screen reader reads is the platform one.

## Key docs

`docs/architecture.md` (this repo's design decisions and their reasons),
`docs/INTEGRATION.md` (how an app consumes kun_ui),
kun-ui's `docs/architecture-flutter.md` (the five-tier roadmap this repo is
tier 4 of) and `contracts/README.md` (manifest format, parity semantics).
