# Changelog

## 0.6.2

- Built on kun-ui 2.42.2 (`kun_ui_tokens`, `kun_ui_icons` and
  `kun_ui_messages` ^2.42.2). The contract changed three descriptions and no
  names.
- **Screen readers find the clear button of a `KunSelect` again**, as on
  the web since kun-ui 2.42.2. 0.6.1 hid it, so a touch screen-reader user
  (TalkBack, VoiceOver) could not clear a `clearable` single-choice select.
  It is now a labelled button (`select.clear`) beside the trigger's value,
  not inside it, so its label is not read as part of the value. It is still
  not a keyboard focus stop, and Backspace or Delete remains the keyboard
  path.
- **Pressing the clear button while the popup is closed moves focus to the
  trigger.** The button disappears with the value, and a screen reader
  that was on it would otherwise have nowhere to be. After a mouse press
  the focus ring stays hidden until the next key press. With the popup
  open, focus stays where it was.
- The trigger's semantics node is now the value area, as the web's
  `role="combobox"` element is, rather than the whole box. Its label,
  value and actions are unchanged. The chip × is still hidden from screen
  readers. To remove a value with a screen reader, untick it in the popup.

## 0.6.1

- Built on kun-ui 2.42.1 (`kun_ui_tokens`, `kun_ui_icons` and
  `kun_ui_messages` ^2.42.1). The contract changed three descriptions and no
  names.
- **Backspace or Delete on a focused `KunSelect` trigger removes a value**,
  as on the web since kun-ui 2.42.1. A `KunSelect.multiple` loses its last
  value, `clearable` or not. A `clearable` single-choice select clears. A
  single-choice select that is not `clearable` ignores the key. The keys
  work with the popup open too. While the search field has focus, they edit
  the search text.
- **The chip × and the clear button of a `KunSelect` are pointer-only.**
  Screen readers no longer find them, and they were never keyboard focus
  stops. The web made them `aria-hidden` in the same release. Keyboard
  users now use Backspace or Delete. A screen reader user can deselect a
  `KunSelect.multiple` value from its popup.
- `KunTab` is unchanged: its keyboard focus ring was already in the tab's
  text colour from the first frame. kun-ui 2.42.1 fixed the web's ring,
  which used to fade in from primary.

## 0.6.0

- Built on kun-ui 2.42.0 (`kun_ui_tokens`, `kun_ui_icons` and
  `kun_ui_messages` ^2.42.0). The contract changed three descriptions and no
  names. The behaviour those releases changed is ported below.
- **Keyboard focus is visible** on `KunAvatar` and `KunUserChip` links, a
  `clickable` `KunCard` and the close button of a `KunMessage` toast. As on
  the web since kun-ui 2.41.0, a 2px line in primary at 50% sits 2px outside
  the control and follows its shape. Keyboard focus shows it and a tap does
  not.
- **`KunTab` shows keyboard focus** too, as the web has since 2.41.0: a line
  inside the tab, in the tab's text colour at 50%. A click leaves none, as
  the browser's `:focus-visible` does, and the next key press brings it back.
  The 0.2.0 (`KunCard`), 0.4.0 (`KunTab`) and 0.5.0 (`KunAvatar`) entries
  say these controls draw no focus indicator, like the web's. That was true
  of the web then and is no longer.
- **A horizontal `KunTab` with `fullWidth` splits the width between its
  tabs.** Before, the strip filled its parent and the tabs stayed packed at
  the start. Each tab now gets an equal share, and never less than its
  label needs. Tabs that do not fit still scroll. `align` places each label
  inside its tab. To keep the packed layout, drop `fullWidth`. A vertical
  strip is unchanged.
- **A disabled tab no longer changes colour under the mouse**, and every
  tab of a disabled `KunTab` shows the forbidden cursor. Before, a disabled
  tab took the foreground colour on hover, and only a disabled item showed
  the forbidden cursor.
- **A `KunUser` whose `id` is 0 is not a link.** `KunAvatar` and
  `KunUserChip` render it as plain content. kun-ui 2.42.0 documents `id: 0`
  as "no profile", which is what the web has always done. Pass 0 for an
  unknown or deleted author, or for a signed-out viewer.
- **`KunInput` and `KunTextarea` do not call `onChanged` while an input
  method is composing.** They report the committed text once the
  composition ends, as the web's fields do since kun-ui 2.40.3. Rebuilding
  the field during a composition no longer resets its text. Before, every
  composing edit reached `onChanged`, so a search driven by it ran on
  romanised input the user had not chosen yet.

## 0.5.0

- `KunSkeleton` — the loading placeholder: `text` (one em tall), `circle`
  and `rect`, with a `width` or a `widthFactor`, a `height` and `rounded`.
  It pulses as the web's does, and stops under reduced motion. With
  `loaded`, it shows its `child` instead. Screen readers skip it.
- `KunAvatar` and `KunUser` — a user's picture at the web's seven sizes. A
  user without a picture gets a pick from `avatarFallbackPool`, the same
  pick the web makes for the same name. A debug build warns once when the
  pool is empty. A picture that fails to load falls back to the bundled
  image. While the picture loads, the avatar pulses, and then the picture
  fades in. With a user and `isNavigation`, the avatar is a link that
  opens the profile through `KunUIConfigScope`. It scales up on hover and
  answers Space and Enter. Like the web's, it draws no focus indicator.
- `KunUserChip` — an avatar with a name and an optional description, each
  cut to one line. With a user and `isNavigation`, the whole chip is one
  link. A missing name reads as the unknown-user string. The web's chip
  is a block that fills its container, but this one is only as wide as its
  content.
- `KunSelect` and `KunSelect.multiple` — a select with a popup anchored to
  its trigger.
  - **Placement:** the popup opens below the trigger, or above it when its
    list does not fit below. It is at most 280 tall, stays 8px inside the
    screen and follows the trigger as the page scrolls.
  - **Width:** `popupWidth` makes the popup as wide as the trigger, as wide
    as its content (`auto`) or a fixed width.
  - **In a modal:** the popup is not a route, so it works inside a
    `KunModal`. Escape closes the popup first, then the modal.
  - **Multiple:** the chosen values show as removable chips in the order
    they were picked. `maxVisibleTags` collapses the rest into a `+N` chip,
    and a chosen value keeps its label after a search replaces `options`.
  - **Search:** `searchable` adds a search box. `manualFilter`, `debounce`,
    `onSearch` and `loading` cover a remote source, and filtering waits
    while an input method is composing.
  - **Keyboard:** matches the web. The arrow keys skip disabled options and
    wrap, Home and End jump, and typing on a list without a search box
    jumps to the matching option.
  - **Focus ring:** follows the browser's `:focus-visible`. A mouse press
    leaves none, and a key press brings it back.
  - **Custom rows:** `optionBuilder` builds each row, and a subclass of
    `KunSelectOption` carries extra fields to it.

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
- `KunTab` — the tab strip: the web's five variants with the sliding
  indicator, three sizes, any `KunUIColor`, vertical strips, `fullWidth`,
  `align`, and disabled tabs or a disabled strip. The value is controlled
  (`value` + `onChanged`). An item with an `href` navigates through
  `KunUIConfigScope` on every tap, including a tap on the selected tab. A
  horizontal strip wider than its parent scrolls inside it: the edges that
  can scroll fade out, chevrons page through it, and the selected tab is
  kept in view. Arrow keys move the selection and focus with it, Home and
  End jump to the ends, and Tab visits only the selected tab. Screen
  readers hear a tab bar of tabs. `tabBuilder` replaces a tab's content and
  receives the app's own `KunTabItem` subclass. The indicator re-measures
  on any relayout, such as a parent resize or a text scale change. Under
  the platform's reduced-motion setting the indicator, colours and
  scrolling jump instead of animating, as the web's base stylesheet makes
  them. Like the web's, the strip draws no focus indicator.
  `KunTabPanels` is not ported: switch content on `value`.
- `KunModal` — the dialog. It is controlled (`value` + `onChanged`, then
  `onClose` after a dismissal by the user) and opens as a route on the root
  `Navigator`, so it draws nothing where it sits. It has the web's five
  sizes, `placement` (`auto` is a bottom sheet below `md` and follows a
  resize while open), inside or outside scrolling, the `alertdialog` role,
  `withContainer: false`, the header, the close button and the drag handle.
  The backdrop, Escape, the system back gesture and the close button
  dismiss it under the web's rules; with `isCloseRequestDismissable: false`,
  back closes the dialog and goes back on the page, as a browser's close
  request does. Focus moves into the dialog (onto its first control when it
  was opened from the keyboard), Tab stays inside, and focus returns to the
  trigger on close. On Android and iOS a sheet can be swiped down to
  dismiss, with the web's thresholds; a swipe never scrolls or taps what it
  started on, and scrolled content keeps the drag until it is back at its
  top. Screen readers hear a dialog named by its title. The content sees the
  theme, language and `KunUIConfigScope` in force where the `KunModal` sits.
  Under reduced motion it opens and closes at once. The panel is as wide as
  its content lays out, between the web's minimum and the size cap: a child
  that fills the width it is given, like a default `Row`, makes it as wide
  as the cap, where the browser would size it by its content.
- `showKunMessage` and `KunMessageProvider` — toasts. `showKunMessage`
  needs no `BuildContext`, so a repository or a notifier can raise one.
  Mount `KunMessageProvider` once, around the app's navigator
  (`WidgetsApp.builder`), and toasts render above every route, a `KunModal`
  included. It has the web's four types and six positions. An identical
  toast is counted instead of repeated, and each position shows at most
  five. The timer pauses while a mouse is over the toast or a pointer is
  pressed on it, and a progress bar shows the time left. A close button and
  a horizontal swipe dismiss a toast, and `dismissKunMessage` removes one by
  id. Toasts keep clear of the safe areas, and the bottom stacks rise above
  the on-screen keyboard, which the web's containers do not do. Screen
  readers hear `error` and `warn` toasts assertively and the others
  politely. `richText` is not ported, because it is HTML.
- `showKunAlert` — the confirm dialog, returning `Future<bool>`. It
  resolves `true` on confirm and `false` on cancel, Escape, back or the
  close button. A second call replaces the open dialog's content, and the
  first call then resolves `false`. The web's three types set the confirm
  color, and `confirmColor` overrides it. The backdrop does not dismiss it,
  as the `alertdialog` role requires. It needs no provider widget: the web
  has `KunAlertProvider` only because a Vue store cannot reach the component
  tree.
- `KunTheme`, `KunMessagesScope` and `KunUIConfigScope` are
  `InheritedTheme`s, so `InheritedTheme.capture` carries them into a route.
  A route is built under the navigator, not where it was opened: without
  this, a dialog opened inside a dark or differently localised subtree came
  up in the app's defaults.
- Built on kun-ui 2.40.2 (`kun_ui_tokens`, `kun_ui_icons` and
  `kun_ui_messages` ^2.40.2). The contract is unchanged for every claimed
  component. Font weights and the `border-kun` hairline now come from its
  `KunFontWeights` and `KunColorScheme.border`; no value changed.
- `KunCard` with `color: KunUIColor.neutral` is tinted at 21% instead of 30%.
  The web's `bg-default-100/30` starts from a `default-100` that already
  carries the global opacity (`KunColors.globalOpacity`, 0.7); the other
  colors' tints are unchanged.
- A tinted `KunCard` and `KunTab`'s scroll chevrons no longer show their
  shadow through their translucent fill. `BoxDecoration` paints a shadow
  under the box as well as around it, and CSS does not. 0.3.0 drew a
  tinted card about 6% darker than the web's, with a lighter rim inside
  its edge.
- `KunButton`'s focus ring fills its 2px gap as the web's
  `ring-offset-background` does: the page background at the global opacity,
  over the inner half of a 4px ring. 0.3.0 left the gap clear.
- Docs: `KunInput` and `KunTextarea` need an `Overlay` above them, as every
  Flutter text field does. 0.3.0 said every `WidgetsApp` provides one, which
  is not true: under `WidgetsApp.router` the `Overlay` comes from the
  `Navigator` the router delegate builds, and a delegate that builds none
  leaves the fields without one. A touch tap then asserts in a debug build.
  The dartdoc and `INTEGRATION.md` now say so.
- Reduced motion: when the platform asks for it
  (`MediaQuery.disableAnimations`), every transition is instant, as kun-ui's
  base stylesheet makes it under `prefers-reduced-motion`. That covers
  `KunButton`'s hover and press, `KunCard`'s hover layer and press,
  `KunChip`'s remove button, the focus ring and text colour of `KunInput`
  and `KunTextarea`, and `KunSwitch`'s track and thumb. `KunSpinner` keeps
  turning, as the web's does.

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
