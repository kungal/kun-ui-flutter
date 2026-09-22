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
It keeps turning under reduced motion, as the web's does (see below).

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

### The gallery also builds for Android (decided 2026-09-22)

`apps/gallery` carries an `android/` target beside `web/`. The web build is
the docs site and stays the deployable one; CI still builds only it. The
Android target exists because a class of this library's behaviour cannot be
seen anywhere else: hover is suppressed on a touch device, an IME composes
(see the `EditableText` decision), a screen reader walks the semantics tree,
and text selection has no handles. Three claims in this document were carried
for a week as "unverified on a device" for want of one, and the emulator that
answered the first of them could not present an IME.

The target is the `flutter create` template with the ecosystem's org
(`com.kungal`), the template's own TODOs dropped, and nothing else: no
signing config beyond the debug keys, no iOS, no store presence. It is a
verification vehicle, and the `.metadata` and `README.md` the template also
writes were deleted rather than carried, as they were for the web target.

Two mechanics worth not rediscovering. `FlutterActivity` reads an initial
route from an intent extra, so any demo opens directly:
`adb shell am start -n com.kungal.kun_ui_gallery/.MainActivity --es route
"/kunselect/clearable"` — the gallery's URL grammar, on a device with no URL
bar. And with a screen reader running, `adb shell uiautomator dump` prints
Flutter's semantics as the Android nodes a screen reader actually reads,
which is how the `KunSelect` clear button of 0.6.2 was finally checked
against upstream's shape instead of reasoned about.

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
Measured 2026-09-22 on a Pixel 10 Pro (Android 17, API 37), which closes that
question. The setting still ships off; with it off, typing `nihao` on the
9-key pinyin keyboard leaves the field untouched until a candidate is picked
and 你好 then arrives in one piece. With it on, the letters arrive as a
composing region and `EditableText` underlines them. That run is what found
the placeholder bug fixed in 0.6.3: the placeholder was painted under the
composing text, because it was gated on the reported `value`, which composing
deliberately does not update.

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
  builds. An app's `Navigator` provides one, so this costs an app nothing,
  but a bare widget tree (a test) has to add it. So does a router delegate
  that builds no `Navigator`, which is what this repo's gallery had until
  2026-09-16. Its text fields worked in the release build and asserted
  under `flutter run`. The earlier wording, "every `WidgetsApp` provides
  one", was false for `WidgetsApp.router`: there the delegate builds the
  `Navigator`, or nobody does.
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

Measured 2026-09-22 on the Pixel 10 Pro: long-pressing `clear me` highlights
exactly `clear`, so word selection does work. Drag handles and the toolbar are
still absent, by the decision above, which leaves a touch user able to select
a word but with nothing to copy it with.

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

### Overlays: a modal is a route, a toast is a store (decided 2026-09-16)

The web builds its overlays by hand: a Teleport to `<body>`, a focus trap, a
refcounted scroll lock, a z-index stack, an `inert` background, a
close-watcher for Android's back gesture. A Flutter `Navigator` route
already does each of those jobs, and every app shell builds a `Navigator`
(`WidgetsApp` itself, or the router delegate under `WidgetsApp.router`), so
iron rule 4 allows depending on it. The port is built on
routes, and its own code covers only the places where Flutter's defaults
differ from the web's.

- **`KunModal` is declarative, over a route.** The contract is `v-model`, so
  the widget takes `value` and `onChanged` and draws nothing where it sits.
  When `value` becomes true it pushes a popup route onto the root navigator.
  A dismissal by the user pops that route and reports `onChanged(false)`
  and then `onClose()`, the web's `dismiss()`. When the parent sets `value`
  to false, the route is popped with its exit animation if it is on top,
  and removed otherwise. A parent-driven close reports nothing, as on the
  web.
- **The route supplies what the web assembles**:
  - focus moves into the route and returns on close;
  - `ModalBarrier`'s `BlockSemantics` does what `inert` does;
  - the system back gesture pops the top route;
  - only the top route receives Escape, the web's `isTopmost`.
- **Escape is KunUI's own action.** Flutter's modal `DismissIntent` action is
  enabled only when `barrierDismissible` is. The web keeps the two apart: an
  `alertdialog` ignores the backdrop and still honours Escape. Back follows
  Escape and `isCloseRequestDismissable`. A backdrop tap dismisses only when
  the press began on the backdrop, and Flutter's tap recognizer already
  requires that.
- **Scopes are captured.** Route content is built under the navigator, not
  where the `KunModal` sits. For that reason `KunTheme`, `KunMessagesScope`
  and `KunUIConfigScope` are `InheritedTheme`s, and the route wraps its
  content in `InheritedTheme.capture`, so a dark subtree opens a dark
  dialog.
- **`placement: auto` reads the width live** against
  `KunThemeData.breakpoints.md`. The web uses breakpoint classes only
  because of server rendering, which Flutter does not have. A sheet shows
  its drag handle, and accepts the swipe, when the platform is touch-first
  (Android, iOS, Fuchsia), the web's `(pointer: coarse)`.
- **Swipe to dismiss** uses `KunSwipeDismissPhysics` for the release rule and
  the overdrag. The web's own timers have no counterpart here, per the
  token's own note that Flutter's gesture arena and scroll notifications
  own them:
  - "no drag while the enter animation runs" means the route animation
    has not completed;
  - "no drag right after a scroll" means a scroll view under the touch is
    still scrolling, or is not exactly at its top (an overscrolled one is
    still settling, and a touch holds it before the swipe can see it move);
  - "content wins until scrolled to the top" means every `Scrollable`
    that contains the touch is at its minimum extent.
- **The swipe wins the gesture arena, under the touch slop.** A `Listener`
  that claimed the drag at `kTouchSlop` could not stop a scroll view's drag
  recognizer, which accepted in the same event: the content scrolled, or
  bounced on iOS, under a claimed swipe, and a button under the finger
  still competed for the tap. The sheet has its own recognizer, which
  decides at the web's 6px (`DRAG_START_THRESHOLD`, kept under the
  browser's slop for the same reason) and then accepts. The route page's
  `Listener` asks it to decide before the gesture binding routes each move,
  so a single move past both thresholds still reaches it first.
- **The panel is sized by layout, not by intrinsics.** On the web the panel
  is a flex item, as wide as its content between `min-w-80` and the size
  cap. `IntrinsicWidth` would reproduce that, but a `LayoutBuilder` or a
  `ListView` in the content, KunTab included, asserts when asked for an
  intrinsic width. So the panel lays its content out under the minimum
  and the cap. A `Text`, a `Column` or a `Row(mainAxisSize: min)` sizes it
  as the browser does; a widget that fills the width it is given (a
  default `Row`, an `Align`) widens it to the cap. Content that should be
  narrow and aligned, like the confirm dialog's, uses `IntrinsicWidth`
  itself.
- **Toasts are a store plus one host**, as on the web. `showKunMessage`
  needs no `BuildContext`, so a repository or a notifier can raise one. The
  app mounts a `KunMessageProvider` once, around its navigator (in
  `WidgetsApp.builder`), so toasts render above every route, a modal
  included. A call with no host mounted reports it once in a debug build.
  `richText` has no Flutter meaning, because it is HTML.
- **A confirm dialog is `showKunAlert(context, …)`, returning
  `Future<bool>`**, pushed as an `alertdialog` modal. It has no provider
  widget. The web needs `KunAlertProvider` only because a Vue store cannot
  reach the component tree, and a Flutter caller that asks the user a
  question already has a context.
- **Anchored popups are portals, not routes** (decided with `KunSelect`,
  their first consumer, for Popover, Tooltip, Dropdown and Autocomplete to
  follow). The popup is an `OverlayPortal.overlayChildLayoutBuilder` on the
  root overlay whose child is the trigger. It paints above the page, like
  the web's teleport to `<body>`, but it is built under the trigger: it
  inherits the trigger's theme, language and config, and its focus nodes
  sit in the trigger's focus scope. So the two bugs
  `useKunFloatingLayer.ts` exists for cannot happen here: a modal's focus
  trap already contains the popup, and an Escape the popup's own key
  handler consumes never reaches the modal's `DismissIntent`.
  - The layout builder runs on every frame while frames run, so the popup
    follows its trigger through scrolling and resizing (floating-ui's
    `autoUpdate`). It applies the web's recipe (offset, flip, an 8px shift
    margin, the size caps) against the view's box less the view's padding
    and keyboard, read from the view because a `SafeArea` above the
    trigger may have removed them from the ambient `MediaQuery`.
  - A tap outside closes it through one `TapRegion` group spanning the
    trigger and the popup.
  - A popup is not a route, so a modal's focus trap treats it as part of
    the page it was opened from — but **the system back gesture must not**.
    Measured with `handlePopRoute`, the message the engine sends on a back
    gesture: with the popup open, back popped the whole page, leaving the
    user a screen back with nothing dismissed. The trigger
    therefore carries a `PopScope` whose `canPop` is false while the popup
    is open, and closes the popup instead — Android's back is the platform's
    Escape, and Escape is what the web closes on. The popup being a portal
    is why the `PopScope` sits on the trigger: the overlay child has no
    route of its own to register with. On a device, measure this with a
    real back gesture — an injected `KEYCODE_BACK` never reaches an app
    that registers an `OnBackInvokedCallback`, which Flutter does as soon
    as a `PopScope` blocks the pop (logcat says
    `setTopOnBackInvokedCallback` the moment the popup opens).
  - **Open gap: only the innermost layer should dismiss.** A popup open
    inside a `KunModal` registers its `PopScope` with the modal's own
    route, and a route invokes *every* entry registered with it, so one
    back closes the popup and the modal together — what it did before the
    scope existed, not a regression, but not the rule either. Dismissing
    the innermost layer alone needs a scope the overlay owners share
    (the modal session is not visible to descendants today), and that is a
    decision to take once, for every portal that follows KunSelect, rather
    than per component.

### Reduced motion collapses every transition (decided 2026-09-17)

kun-ui's base stylesheet sets every transition and animation to 0.01ms
under `prefers-reduced-motion: reduce`, so a web component never needs its
own check. Flutter's counterpart is `MediaQuery.disableAnimations`. Nothing
applies it globally, so each widget runs its durations through `kunMotion`
(`lib/src/foundation/motion.dart`, not exported):

- An implicit animation takes `kunMotion(context, KunDurations.x)`.
- A widget that animates by hand (KunTab's indicator, a route's
  transition) reads `kunReducedMotion(context)` and jumps.
- `KunSpinner` is the exception. The web spinner turns by SMIL
  `<animateTransform>`, which the stylesheet rule does not reach, so the
  spinner keeps turning there and here.

KunUI 0.3.0 ignored the setting everywhere. It was found while accepting
KunTab, whose web scroll code checks `prefers-reduced-motion` by hand.

### Shadows are painted outside the box (decided 2026-09-17)

CSS paints `box-shadow` only outside the border box. `BoxDecoration` also
paints every shadow under the box. An opaque fill hides the difference,
but a translucent fill shows the shadow through it. KunUI 0.3.0 drew a
tinted `KunCard` about 6% darker than the web's, with a lighter rim where
its inset shadow ended. The first toast port also drew its dark 90% fill
greener than the web's, because its colored ring showed through.

So a box with a translucent fill and a shadow splits its decoration.
`KunOuterShadowDecoration` (`lib/src/foundation/outer_shadow.dart`, not
exported) paints the shadows with `BoxDecoration`'s geometry, clipped to
the outside of the shape. Inside it, a `BoxDecoration` paints the fill and
no shadows. Opaque boxes keep `BoxDecoration.boxShadow`: there the two
render identically, and the clip would add cost to a long list of cards.

This was found by comparing toast pixels in headless Chromium: every light
color matched, and only the dark fills did not.

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
