# kun-ui-flutter — architecture

This repo is **tier 4** of the KunUI Flutter roadmap. The constraint
analysis, the industry survey and the five-tier plan live upstream in
kungal/kun-ui `docs/architecture-flutter.md`; this document records only the
decisions made *here*, and why.

## Where this repo sits

```
kungal/kun-ui (upstream, generates)          this repo (hand-written)
├── gen-tokens.mjs ─────► kun_ui_tokens ───► KunTheme / widgets paint with it
├── gen-icons-flutter ──► kun_ui_icons ────► re-exported, used by apps
├── motion-physics.mjs ─► KunShatterPhysics► future KunShatter port
└── gen-flutter-contracts
      └── contracts/component-contracts.json ─► CI parity vs our manifest
                                                 (contracts/components.manifest.json)
```

- **One shared library, N apps.** Exactly the `@kungal/ui-vue` model: apps
  depend on `kun_ui`, never copy widgets. "On demand" (upstream §7 decision
  3) selects *which* components get built — the first app needing one
  triggers one implementation here, then every app has it.
- **The contract version is the pinned `kun_ui_tokens` version.** No
  separate contract versioning: `scripts/parity.sh` reads pubspec.lock and
  checks kun-ui out at that release tag. Upgrading the tokens dependency is
  adopting a new contract, in the same change.

## Decisions

### Own theme system, not Material `ThemeData` (decided 2026-09-09)

`KunTheme` is a plain `InheritedWidget` carrying `KunThemeData`. Verified
upstream (2026-09): the modern independent design systems on Flutter —
forui's `FTheme`, shadcn_ui's `ShadTheme` — do not hang off Material's
`ThemeData`, and KunUI is its own design language, not a Material skin.
Consequences:

- Library code never reads `Theme.of(context)` and never renders Material
  widgets; `KunTheme` is the only required ancestor, so widgets work under
  `WidgetsApp`, `MaterialApp` or `CupertinoApp` alike.
- `kun_ui_tokens` stays theme-system-agnostic plain consts (its design
  goal); this repo is the layer that binds them to a widget tree.
- `KunTheme` sets the ambient `DefaultTextStyle` color and `IconTheme` to
  the scheme foreground — the analogue of the web page root's `color` and
  icons inheriting `currentColor`.

### The design tables are translations, not designs

`KunVariantStyle` mirrors `kunVariantClasses` (ui-core `variants.ts`) cell
for cell; `KunControlMetrics` mirrors `kunControlSizeClasses` +
`kunControlSquareClasses` (`controlSize.ts`) value for value. The web files
are the single source of truth for the 5 × 7 matrix and the control scale —
a design change starts there and is mirrored here. The web's `dark:`
overrides become `Brightness` branches; everything else is mode-correct by
construction because the token scheme itself flips (solid/onSolid are
WCAG-AA-verified pairs in both modes by the upstream generator).

### Vocabulary enums mirror the contract verbatim

`KunUIVariant` / `KunUIColor` / `KunUISize` / `KunUIRounded` are the
contract's `vocabulary` unions with their web names, so manifest entries map
mechanically. Web `default` becomes `neutral` (`default` is a Dart reserved
word) — the same rename `KunColorScheme` made in kun_ui_tokens.

### Contract-to-Dart API conventions

Fixed here so every port maps the same way:

| Web | Dart |
| --- | --- |
| `click` event | `onPressed` (buttons) / `onTap` |
| `modelValue` + `update:modelValue` | `value` + `onChanged` |
| slot | `Widget` parameter (`default` → `child`) |
| `ariaLabel` | `semanticLabel` |
| boolean prop + same-named slot (e.g. Button `icon`) | one nullable `Widget` |
| `disabled` prop | `disabled` prop — null `onPressed` does *not* gray out |

The last row is deliberate: the web contract separates looks from listeners,
so Material's `onPressed: null == disabled` convention is not carried over.

### KunSpinner is a widget, not an icon

Tier 1's honest count was 29 of 30 icons crossing: the web's loading icon
(`svg-spinners:90-ring-with-bg`) is an *animated* SVG no font glyph can
carry. `KunSpinner` is that 30th icon, hand-written to the SVG's exact
geometry (24-unit viewBox, 3-unit ring at 25% opacity, 90° arc, 750ms/turn
linear). It is not the contract's `KunLoading` (a loading *overlay* with
description/image surface) — that ports separately when an app needs it.

### Widgetbook is both the playground and the docs site

One app, two jobs: `flutter run -d chrome` during development,
`flutter build web` as the deployable gallery — the role split kun-ui solves
with two apps (`apps/docs` + `apps/playground`) collapses here because
Widgetbook's knobs *are* the playground. CI builds it so the docs surface
can never silently break. Prop reference tables need no separate generator:
`public_member_api_docs` forces dartdoc on the whole API, and the contract
manifest records the web mapping.

### Text fields are `EditableText`, not Material's `TextField` (decided 2026-09-15)

Iron rule 4 leaves no other option, and it is worth being explicit about the
cost, because every form control to come inherits this choice. `KunInput` is
built on `EditableText` from `flutter/widgets` and passes no
`selectionControls`. Mouse selection, the keyboard, obscured text and the
clipboard shortcuts all work; what is absent is the **touch selection UI** —
the drag handles and the copy/paste toolbar — because every ready-made
implementation of those (`materialTextSelectionControls`,
`cupertinoTextSelectionControls`) drags in a foreign design language along
with its localizations.

Verified 2026-09: the ports that claim independence do not actually hold this
line — shadcn_ui and forui both reach for Material's text field internals
here. KunUI takes the honest version instead: no Material, and a gap that is
named. When a real app needs touch selection, the answer is a KunUI-drawn
toolbar and handles, which is the design-system-correct answer anyway — not a
Material import.

Observed 2026-09-15 on an Android 16 emulator (Pixel 9 profile, API 36,
Impeller): long-pressing text in a `KunInput` produces no selection highlight,
no drag handles and no copy/paste toolbar — the gap above, confirmed rather
than reasoned. Everything else on the touch path works: tap focuses, the soft
keyboard opens, the field scrolls above it, the caret renders, the clear button
appears only with text, and typing through the IME commits correctly.

One finding worth carrying into that future work: Gboard's Simplified Chinese
keyboard ships with **"Inline composing" off by default**, so pinyin never
reaches the field as a composing region — it stays in Gboard's own candidate
bar and only committed characters arrive. The composing underline
`EditableText` draws is therefore invisible to a default-configured Gboard
user, but not to the third-party IMEs (Sogou, Baidu) that do compose inline.
That path is still unverified: the emulator's IME stopped presenting after its
language config changed, so the real pinyin test belongs on hardware.

### Deferred, deliberately

- **Input modality and breakpoint theme dimensions** (forui models
  touch/pointer and breakpoints as theme axes): breakpoints shipped in
  `KunThemeData.breakpoints`; a modality axis waits until a component
  actually branches on it. Flutter's `MouseRegion` already scopes hover to
  pointer environments, which covers today's need.
- **Per-component theme overrides** (`KunButtonTheme` etc.): additive when a
  real app needs one; premature now.
- **Ripple**: the web button's ripple is not contract surface; press
  feedback is the web's `active:scale-[0.97]`. Revisit if an app asks.
- **Touch text-selection handles and toolbar**: see the `EditableText`
  decision above. The trigger is the first app that edits text on a
  touchscreen.
- **Golden tests**: behaviour is widget-tested; visuals are verified by eye
  in Widgetbook. Goldens enter when the first visual regression actually
  bites (they are platform-brittle and each one is a maintenance contract).

## Risk register

The dominant failure mode is the same as upstream's: **drift**. The guards,
in order: tokens are dependencies (cannot drift), the contract parity job
(API cannot silently drift), and iron rule 1 in CLAUDE.md (values cannot
drift without a hand-written literal, which review rejects). What none of
these catch is *behavioural* nuance — hover semantics, animation feel — for
which the only guard is reading the web source when porting and looking at
both surfaces side by side.
