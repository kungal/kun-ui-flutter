# Changelog

## 0.4.0

- `KunBadge` — a count or a dot on the corner of any widget, or on its own
  inline: the web's three sizes, four corners, `max` (a count above it shows
  as `99+`), `showZero`, `show`, any `KunUIColor`, and the background-coloured
  ring that separates an anchored badge from what it sits on. With a
  `semanticLabel` it is announced as a live region, so a changing unread count
  is read out.
- `KunUIConfigScope` and `KunUIConfig` — the app-wide settings the web keeps
  on its `KunUIConfig`: `navigate` (the app's router, for the components
  that navigate), `userLinkTemplate`, `avatarFallbackPool` and
  `imageProvider` (every image URL KunUI loads goes through it, so an app
  brings its own cache). Optional, like `KunMessagesScope`. Without
  `navigate`, a tap that would navigate does nothing, and a debug build
  says so once. `kunPickAvatarFallback` is the web's fallback pick, hash
  for hash.

## 0.3.0

- `KunTextarea` — the multi-line text field: the shared control scale
  (padding and type), a label with a required marker, helper text and an
  error, `rows`, `autoGrow` with a `maxHeight` cap, a character counter,
  `readOnly`, and the same caret, selection, focus ring and accessibility
  behaviour as `KunInput`. `maxLength` is optional, as on the web since
  kun-ui 2.39.0: without it the counter shows the bare count. `maxLength` and
  the counter count user-perceived characters, where the browser counts
  UTF-16 code units. The web's `resize` handle is browser chrome and is not
  ported.
- `KunNull` — the empty state: the bundled mascot (`KunImages.nullImage`, no
  network request) above the locale's "nothing here" line. `image` takes any
  `ImageProvider` in place of the web's `src` URL. The mascot is decorative to
  assistive technology, where the web gives it an untranslated `alt="empty"`.
- `KunSwitch` — the toggle: the web's own five-step track and thumb scale, a
  label row that is the tap target, helper and error text, and a
  keyboard-only focus ring. The track colour eases, the thumb slides on
  `KunEasing.emphasized`. Screen readers hear a switch; the web's checkbox
  input has no `role="switch"`. As in a browser checkbox, Enter does not
  toggle it on the web; Space does, and Enter does elsewhere.
- Built on kun-ui 2.39.0 (`kun_ui_tokens`, `kun_ui_icons` and
  `kun_ui_messages` ^2.39.0). Its `KunShadows` convert the web's blur instead
  of copying it, so every elevation — `KunCard`, `KunInput`, `KunTextarea` —
  now draws as tight as the browser's; 2.38.0 drew each about 20% softer.
- The `shadow` variant (`KunButton`, `KunChip`) takes its glow from
  `KunShadows.glow`. The hand-copied glow had the same unconverted blur.
- `KunButton`'s hover and press, `KunChip`'s remove button and `KunCard`'s
  hover layer and press run on the web's default transition curve
  (`KunDefaultTransition`); they had `KunEasing.standard`, which their web
  classes never name.
- `KunBreakpoints` defaults come from `KunBreakpointWidths`. The values are
  unchanged.
- `KunButton` and `KunChip`'s remove button answer Enter in a browser. Flutter
  web sends Enter as `ButtonActivateIntent`, which neither handled, so only
  Space pressed them there; other platforms were unaffected.
- A `clickable` `KunCard` takes keyboard focus and is tapped by Space and
  Enter, as the web's `<button>` card is. Like the web's, it draws no focus
  indicator.
- `KunInput`: a click or tap places the caret, and a drag, double-tap or
  long-press selects. 0.2.0 moved the caret to the end on every tap and could
  not select with the pointer at all. Touch selection handles and a copy/paste
  toolbar are still absent.
- `KunInput`: with Flutter web's accessibility turned on, the field could not
  be typed into — its semantics node never said it was enabled, and the web
  engine renders such a field as a disabled `<input>`. It now reports its
  enabled state and answers the tap and focus actions.
- `KunInput`: the focus ring fades in and out over `KunDurations.fast`, as the
  web's `transition-[color,box-shadow]` does. The border colour still changes
  at once; the web does not transition it either.
- `KunInput`: a disabled field can no longer take focus, from the keyboard or
  otherwise. Disabling a focused field blurs it and calls `onBlur`.
- `KunInput` and `KunTextarea` need an `Overlay` ancestor, as every Flutter
  text field does. `WidgetsApp` — and so `MaterialApp` and `CupertinoApp` —
  provides one; a bare widget tree, such as a test, has to add it.

## 0.2.0

The first components ported on demand, chosen by how heavily the web library
is actually used across the ecosystem's sites.

- `KunCard` — the raised `content1` surface: header / cover / body / footer
  slots, the four-step padding scale, the colored tints, the hover state
  layer, and `clickable` for press feedback. Link mode stays with the app's
  router, as the contract specifies.
- `KunChip` — the pill: the variant x color matrix at chip scale, `start` and
  `end` widgets, and a removable x.
- `KunInput` — the single-line text field: the shared control scale (an input
  and a button of the same size line up), label with a required marker,
  helper text, an error that takes the border and ring to `danger`, prefix
  and suffix widgets, a clear button and a password reveal toggle.
- `KunChipMetrics` — the chip size scale, the translation of the web's
  `kunChipSizeClasses`.
- `KunMessagesScope` — the strings KunUI renders for itself (a chip's close
  button, an input's clear and reveal buttons) resolve from the generated
  `kun_ui_messages` catalogs, the same ones the web bundle resolves
  `t('chip.remove')` from; `kun_ui` re-exports the package. `zh-CN` is the
  built-in default and the scope is never required, so no widget gained an
  ancestor: wrap a subtree in `KunMessagesScope(messages: KunMessages.en,
  ...)` to switch language. It is deliberately not a field on `KunThemeData`
  — the web carries its locale on `KunUIConfig`, not on the theme, and an app
  that switches language does not switch colors.
- Spacing and type come from the tokens. `KunControlMetrics`,
  `KunChipMetrics`, `KunCardPadding` and every gap, margin, icon size and
  label style inside the widgets now read `KunSpacing` and `KunText` (new in
  `kun_ui_tokens` 2.38.0) instead of restating Tailwind's numbers, so a web
  class translates by reading its step (`px-2.5` is `KunSpacing.unit * 2.5`)
  and an upstream change reaches this port through the dependency. No value
  changed. `KunControlMetrics.textStyle` and `KunChipMetrics.textStyle` are
  now fields holding a `KunText` step; `fontSize` and `lineHeight` remain, as
  getters.
- Text sits in its line where the browser puts it. CSS splits a line's extra
  height evenly above and below the glyphs; Flutter's default splits it by
  the font's ascent/descent ratio, which set every KunUI label 1.2–2.6px
  lower than the web. Control and chip labels, input text, labels, helper
  text and errors now lay out with `TextLeadingDistribution.even`, and
  `KunTheme` sets it on the ambient text style, so an app's own text under a
  `KunTheme` that sets a `height` lines up the same way. No box changes size;
  only glyphs move inside their line.
- `KunSpinner` drops its bare black fallback color. It was unreachable:
  `IconTheme.of` already fills a missing color.
- Contract: adopted `kun_ui_tokens` / `kun_ui_icons` 2.38.0, up from the
  2.35.1 that 0.1.0 shipped against; `kun_ui_messages` arrives at the same
  version. Every hop to 2.37.0 was a lockstep version bump and 2.38.0 adds
  only the spacing and type scales above; the contract entries for
  everything this port claims are unchanged throughout — the adoption costs
  no new surface.
- `scripts/contract-lag.sh` and a weekly workflow behind it: the parity job
  pins itself to the contract in `pubspec.lock`, so it cannot see this port
  falling behind a newer upstream release. This reports that, with what
  adopting the newer contract would cost.

## 0.1.0

Initial release: the KunUI theme system and the first widgets.

- `KunTheme` / `KunThemeData` — KunUI's own `InheritedWidget` theme (no
  Material `ThemeData` coupling), carrying the generated `KunColorScheme`,
  the app-wide default corner rounding, and the responsive breakpoints.
- The design vocabulary as Dart enums: `KunUIVariant`, `KunUIColor`,
  `KunUISize`, `KunUIRounded` — the same unions the web contract speaks.
- `KunVariantStyle` — the variant × color matrix, resolved from tokens.
- `KunButton` — the full web contract surface: variants, semantic colors,
  the shared control size scale, loading, icon slots, icon-only squares.
- `KunSpinner` — the hand-written port of the one web icon no font glyph
  can carry (`svg-spinners:90-ring-with-bg`).
