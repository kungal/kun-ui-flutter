# CLAUDE.md — kun-ui-flutter (KunUI for Flutter)

## 铁律 (Iron Rules — non-negotiable; these override every other guideline in this file)

1. **Never hand-write a token value.** Every color, radius, shadow, easing and
   duration comes from `kun_ui_tokens` (and every icon from `kun_ui_icons`) —
   both generated in kungal/kun-ui from the same source as the web stylesheet.
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
   only ancestor a KunUI widget may require — never `Theme.of(context)`, no
   `MaterialApp` assumption, no Material widgets inside library code (forui
   and shadcn_ui made the same call: an independent design language is not a
   Material skin). The gallery app may use Material chrome; the library
   may not.
5. **A push of a `kun_ui-v*` tag publishes to pub.dev.** Pushing `main` is
   routine and needs no permission — the repo is public, CI costs nothing,
   and a branch push is reversible. A *tag* is not: it publishes an immutable
   version to pub.dev, so never tag, retag or publish on your own initiative
   — only when the user asks. The FIRST publish of the package must be run
   manually by the user (`dart pub publish`); only after that can the
   tag-triggered OIDC workflow publish. Never hand-edit a version to "fix" a
   release.
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
- `apps/widgetbook` — plays the role `apps/docs` plays in kun-ui: the
  component gallery during development (`flutter run -d chrome`) and the
  deployable docs site (`flutter build web`). Every widget gets a use case;
  a gallery that does not compile is a broken docs site, so CI builds it.
  **Being replaced.** The `widgetbook` package was ruled out on 2026-09-15 —
  it is the funnel for a paid product and answers a much larger question than
  a gallery needs — in favour of one written here and generated from the
  contract manifest. Read both decisions in `docs/architecture.md` before
  touching this app; in particular the list of things the replacement
  deliberately does not rebuild, knobs first among them.
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
flutter run -d chrome              # in apps/widgetbook — the live gallery
flutter build web --release        # in apps/widgetbook — the docs build
./scripts/parity.sh                # contract parity (KUN_UI_DIR=... for a local checkout)
```

## The CI gate (`check.yml`)

Two jobs. **check**: format → analyze → test → gallery web build.
**parity**: reads the resolved `kun_ui_tokens` version from pubspec.lock,
clones kungal/kun-ui at `kun_ui_tokens-v<version>`, runs its
`scripts/flutter-parity.mjs` against our manifest. Traps already hit:

- `flutter pub get` rewrites `analysis_options.yaml` files to exclude
  `build/**` — keep that section or the tool re-adds it in a dirty tree.
- `FocusableActionDetector.onShowHoverHighlight` is gated on the focus
  highlight mode and is suppressed entirely under touch (including the test
  environment). The web's `:hover` has no such coupling, so hover state comes
  from a plain `MouseRegion` — a touch device simply never hovers.

## Porting a component (the recipe)

Scope is on-demand (§7 decision 3 upstream): a component enters this library
when a real app needs it, and one consumer is not a component. Then:

1. Read its contract entry: `jq '.components.KunX' contracts/component-contracts.json`
   in kun-ui (at the pinned tag). That is the surface to answer for —
   `webOnlyProps` are already excluded with reasons.
2. Read the web implementation (`packages/vue/src/components/X.vue`) and the
   ui-core tables it consumes (`variants.ts`, `controlSize.ts`) — translate
   values, never re-derive by eye. `v-model` maps to `value` + `onChanged`;
   slots map to `Widget` parameters; `ariaLabel` maps to `semanticLabel`.
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
  born in kun-ui's generator, not here (iron rule 1).
- The `KunUI*` enum names look unusual next to Dart's `KunUi` casing
  convention for >2-letter acronyms, but `UI` is two letters and the names
  match the contract vocabulary exactly — grep-ability across the two repos
  wins. Do not "fix" the casing.

## Verifying work

`flutter test` is the first line (unlike kun-ui, which has no test runner).
For anything visual, run the gallery (`flutter run -d chrome` in
`apps/widgetbook`) and look — state what was measured or seen, never report
reasoned-about behaviour as observed. The web reference for any component is
the kun-ui docs site or its playground; when in doubt about a value, read the
web source, not the rendered pixels.

## Key docs

`docs/architecture.md` (this repo's design decisions and their reasons),
`docs/INTEGRATION.md` (how an app consumes kun_ui today, pre-pub.dev),
kun-ui's `docs/architecture-flutter.md` (the five-tier roadmap this repo is
tier 4 of) and `contracts/README.md` (manifest format, parity semantics).
