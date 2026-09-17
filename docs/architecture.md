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
├── gen-messages-flutter► kun_ui_messages ─► KunMessagesScope resolves from it
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

### The gallery is written here, not taken from Widgetbook (decided 2026-09-15)

`apps/widgetbook` was built on the `widgetbook` package. It was replaced by
`apps/gallery`, written in this repo, and deleted once the replacement
covered every component the manifest claims. Two reasons, in the order they
weigh:

- **It is a commercial product with the OSS package as its funnel.**
  widgetbook.io sells Widgetbook Cloud, and the free package advertises it:
  the welcome screen carries two promotional cards ("Deploy your Widgetbook
  with our managed-hosting solution", "Detect visual changes in your PRs with
  Widgetbook Cloud") and the sidebar footer a permanent "Golden test with
  Widgetbook Cloud" link. Capability follows the same line — grepping the
  3.25.0 package for `golden|toImage|snapshot` returns nothing, because
  visual regression is the paid tier. A dependency whose feature boundary is
  drawn by someone's pricing page is not one this repo's docs surface should
  sit on.
- **It answers a larger question than the one we have.** Of its 8,919 lines,
  6,049 — fields, knobs, addons — exist to adjust a widget's props from a
  panel at runtime. What a gallery owes a reader is narrower: show what the
  component looks like, and let them click it. shadcn_ui's `playground/` and
  forui's `docs_snippets/` both stop exactly there, and both are ~450 and
  ~780 lines of machinery respectively. Neither has knobs.

What made this decision cheap, and would make the reverse decision cheap
too: `packages/kun_ui` contains zero references to `widgetbook`. The entire
coupling is one file — `apps/widgetbook/lib/main.dart`, 574 lines, ten use
cases — plus two lines of pubspec. The library, the contracts, the parity
job and the tests are untouched by this.

**The floor the replacement must hit**, and its ceiling:

- One URL per use case, addressable and shareable.
- No chrome around the widget by default. The gallery page *is* what an
  `<iframe>` would show, which is the interface shadcn_ui and forui hand-wrote
  their demo apps to expose (and which Widgetbook spelled `?preview`).
- Theme and language switch from the URL — `KunTheme` and
  `KunMessagesScope` are both plain `InheritedWidget`s, so this is a wrapper,
  not a system.
- Real widgets, really interactive. A button presses, an input takes text.
- An index listing the components, because there is no JS documentation site
  in this repo to provide navigation. kun-ui's `apps/docs` serves the web
  library; a `/flutter` subpath there, iframing this, is the eventual shape.

**Deliberately not rebuilt** — this list exists so the gallery does not grow
back into Widgetbook one convenience at a time: a knob/field system, runtime
prop panels, search, device frames, zoom, grid overlays, time dilation, the
inspector, and visual-regression tooling.

The one real cost: four of the ten use cases were "Playground" cases driven
by 33 knob calls, and could not survive as written. They became enumerated
demos — which for a documentation surface is the better artifact anyway. A
knob that toggles `disabled` shows one state at a time and only to someone
holding the mouse; a matrix shows both states at once, in a screenshot, to a
reader. Knobs serve exploration during development, which is the smaller
need, and the one a `flutter run` and an edit already serve.

One page was dropped outright rather than ported: a `_colorGrid` that painted
eleven shades of all seven scales plus solid/onSolid. It was the only page in
the old app that was not a component, so it is also the only one the manifest
cannot name and the generator cannot check — a foundation page would have
been a hand-written surface inside a gallery whose whole argument is that the
contract drives it. The palette is `kun_ui_tokens`, generated upstream from
the same source as the web stylesheet: the place to read it is there or on
kun-ui's docs site, not in a grid this repo maintains downstream of it. If a
foundation section is ever wanted here, it starts from that argument, not
from a page inherited because deleting it felt lossy.

The gallery is generated from `contracts/components.manifest.json` rather
than hand-written — see the next decision. That is what makes the
replacement an improvement rather than merely a smaller dependency: no
generic tool can know this repo's contract, and the current gallery hand-
copies axes (variant, color, size) the contract already carries.

### The gallery's demos are generated from the contract (decided 2026-09-15)

`contracts/components.manifest.json` already names, per claimed component,
every contract prop and how this port answers it. The gallery hand-copies a
subset of that: twenty-one `for (final … in …values)` sites spelling out
variant × color × size axes the contract carries. A hand-copy is a drift
surface — the thing this repo's whole design exists to close — and it is the
same discipline forui applies to its docs, where the code a reader sees is
extracted from compiling Dart rather than typed into a Markdown fence.

So the gallery's registry and its coverage pages are emitted from the
manifest. Two things follow that no third-party gallery could do, because
none of them can know this contract:

- **Coverage becomes visible.** Each component's page states what the
  contract lists, what this port answers, and what it omits with the reason
  already recorded in the manifest — information that today exists only in
  `parity.sh`'s terminal output.
- **A demo-parity gate.** `parity.sh` proves a claimed prop is *implemented*;
  nothing proves it is *shown*. Generation makes the second check
  mechanical, and iron rule 3's floor extends to the docs surface.

**Amended 2026-09-15, on writing the generator.** A third claim stood here:
that generation stops the *axes* drifting, so a variant added upstream would
appear in every matrix on the next generate. The premise was wrong. Those
twenty-one hand-copied sites are `for (final v in KunUIVariant.values)`
loops, and a `.values` loop already picks up a new member the moment
`design.dart` gains one — enum-member drift was closed by Dart before this
decision was written. What actually drifts is narrower, and was never
covered by anything: a prop the manifest newly *claims* that no demo shows.
That is what the gate closes, and it closes it without a generator writing
widget trees.

The boundary, so the generator is not asked to be clever: **it emits data,
not widget trees.** The registry, the per-component coverage tables, and the
check that the two agree are all derivable from JSON. A demo body is not —
the widget expression at the centre of one is exactly the taste the ruling
above says a gallery owes a reader, and a Dart template held in a JSON string
is a worse hand-copy than the hand-copy. So demo bodies stay hand-written in
`apps/gallery/lib/src/demos/`, and `apps/gallery/gallery.spec.json` declares,
for every name the manifest claims, either the demo that shows it or the
reason it has none. Nothing may be silent: that file is the adjudication and
the generator only enforces it, which is why a prop with no demo yet is
recorded with that as its reason and rendered as a gap rather than left out.

This also cuts the cost of the decision above. What a future gallery rewrite
has to port is a registry shape and a set of demo functions, not a generator.

### Text fields are `EditableText`, not Material's `TextField` (decided 2026-09-15)

Iron rule 4 leaves no other option, and it is worth being explicit about the
cost, because every form control to come inherits this choice. `KunInput` and
`KunTextarea` are built on `EditableText` from `flutter/widgets` and pass no
`selectionControls`. Pointer selection, the keyboard, obscured text and the
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

Corrected 2026-09-16. The first version of this section said mouse selection
worked. That was reasoned, not measured, and wrong: `KunInput` 0.2.0 passed
`rendererIgnoresPointer: true` without the gesture builder that makes the flag
safe, so a click never placed the caret (a widget test tapping the start of
`hello world` got offset 11) and a drag selected nothing. `EditableText` alone
is not a text field. What `TextField` wraps around it, every KunUI text field
now wraps too, all of it from `flutter/widgets`:

- **`TextSelectionGestureDetectorBuilder`** — a tap places the caret; drag,
  double-tap and long-press select. It also makes `EditableText` create its
  selection overlay on a tap, which asserts an `Overlay` ancestor in debug
  builds. Every `WidgetsApp` provides one, so this costs an app nothing, but
  a bare widget tree (a test) has to add it.
- **`Semantics(enabled: …, onTap: …, onFocus: …)`** — Flutter web renders a
  text field whose semantics node does not say it is enabled as a *disabled*
  `<input>`. With accessibility turned on, nothing could be typed into
  `KunInput` 0.2.0; measured in Chrome, the element read `disabled: true`
  before this and accepted typing after.
- **`TextFieldTapRegion`** — so a tap on the field's own clear or reveal
  button is not a tap outside the field, which unfocuses it on touch.

A multi-line field needs one more: `EditableText` replaces the inherited
`ScrollBehavior` with one that shows scrollbars whenever it is multiline, so
an ancestor `ScrollConfiguration` hides nothing — `scrollbar-hide` is a
`scrollBehavior` passed to the `EditableText` itself.

Whether long-press now highlights a word on Android is unverified on a
device. Drag handles and the toolbar are still absent, by the decision above.

### KunUI's own strings are a scope, not a theme field (decided 2026-09-15)

A few strings belong to the library rather than to the app: the accessible
name of a chip's close button, of an input's clear and reveal buttons. The web
resolves them from a message catalog on `KunUIConfig`; since 2.37.0 the same
catalogs also generate a Dart package, `kun_ui_messages`, so this port reads
them instead of mirroring them.

`KunMessagesScope` is a plain `InheritedWidget` holding a `KunMessages`, and
`KunMessagesScope.of` falls back to `KunMessages.zhCN` when there is none.
Two constraints decided that shape:

- **Not a field on `KunThemeData`.** The web keeps its locale on
  `KunUIConfig`, deliberately apart from the theme, and the separation is
  right here too: an app that switches language does not switch colors, and a
  theme carrying strings would repaint every surface to change one label.
- **Never a required ancestor.** Iron rule 4 permits exactly one and
  `KunTheme` already spends it. A missing theme is an integration mistake
  worth throwing on — the colors would be wrong. A missing language is not:
  zh-CN is KunUI's built-in default on both platforms, so the fallback is a
  correct answer rather than a silent failure.

How this port got here is worth recording, because the starting point was an
iron-rule-2 violation. Before the catalogs existed the four strings lived as
hand-mirrored Chinese literals behind props the web contract does not
have — `KunChip.closeSemanticLabel` and three more on `KunInput`. Parity
cannot catch surface invented locally: it checks that the contract's surface
is covered, not that nothing extra was added. The props are gone in the same
change that made them unnecessary, and they never reached a release. The
general form: when a port wants a knob the contract lacks, the missing piece
is almost always upstream.

### Navigation and image loading are an app-level scope (decided 2026-09-16)

The web's `KunUIConfig` is where the Vue library stops depending on Nuxt:
the host hands KunUI its router (`navigate`), the path an avatar links to
(`userLinkTemplate`), the images for users with no avatar
(`avatarFallbackPool`) and its image component (`imageComponent`). KunTab,
KunAvatar and KunUserChip read those keys, so this port needs the same seam
before it can port them. `KunUIConfigScope` holds a `KunUIConfig` with four
fields. The web type's other four keys have a home already or no Flutter
meaning: `rounded` is `KunThemeData.rounded`, `locale` is
`KunMessagesScope`, and a link component and an icon component have no
counterpart when a link is a tap and an icon is `IconData`.

- **Never a required ancestor**, for the reason `KunMessagesScope` gives:
  every field has a working default.
- **`navigate` defaults to nothing, with a debug message.** The web's
  default is a full page load, and Flutter has no universal equivalent.
  `Navigator.pushNamed` fails under `Router`-based apps. Replaying the
  platform's route push (the path a deep link takes) works under both, but
  only through `WidgetsBinding.handlePushRoute`, which is protected and
  visible for testing. So a widget that navigates still looks like a link.
  A tap on it does nothing, and a debug build says once that nothing is
  configured. That is the web's own answer to a silent misconfiguration: it
  warns once about an empty avatar pool.
- **`imageProvider` replaces `imageComponent`.** A URL becomes an
  `ImageProvider`, `NetworkImage` by default, so an app brings its own
  caching (for example `CachedNetworkImageProvider.new`) without `kun_ui`
  taking the dependency (iron rule 6).
- **The avatar fallback pick is the web's hash, bit for bit**
  (`kunPickAvatarFallback`), over the same UTF-16 code units. A user shows
  the same fallback image in the app and on the site. The test vectors come
  from ui-core's function, and the Dart hash was run compiled to JS as well
  as on the VM, because integer arithmetic differs between the two.

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
  in the gallery. Goldens enter when the first visual regression actually
  bites (they are platform-brittle and each one is a maintenance contract).
  Note that leaving Widgetbook costs nothing here: its OSS package never
  carried golden tooling, only a link to the paid tier that does.

## Risk register

The dominant failure mode is the same as upstream's: **drift**. The guards,
in order: tokens are dependencies (cannot drift), the contract parity job
(API cannot silently drift), and iron rule 1 in CLAUDE.md (values cannot
drift without a hand-written literal, which review rejects). What none of
these catch is *behavioural* nuance — hover semantics, animation feel — for
which the only guard is reading the web source when porting and looking at
both surfaces side by side.
