# Changelog

## 0.13.1

Accessibility fixes from the kungal app's Android node tree. There are no
API changes.

- **A `KunButton` always has a semantics node of its own.** Without one, a
  button whose only sibling had its own node (a `KunReaction` beside it in a
  `Wrap`) lent its role, label and tap action to the enclosing node. On a
  Pixel 10 Pro the whole row came out as that button: exploring anywhere in
  the row read its label, and a double tap there pressed it. Affects every
  release before this one.
  - `KunNavItem`, `KunPopover` and `KunTooltip` now merge their own
    annotations into the slotted control's node, as `KunDropdown` already
    did, so a nav item stays selected, a popover trigger keeps its
    expanded state, and a tooltip keeps its text.
  - If a test read one of those labels with `getSemantics(...).label`,
    read `getSemanticsData().label` instead, because the node is now a merge
    boundary.
- **`KunReaction` reports its pressed state as selected**, as Flutter's own
  toggle icon button does, not as toggled. Flutter maps toggled to a
  switch, so TalkBack called a like button a switch ("开关"). It is now a
  button that is selected while on, which is the closest Flutter comes to
  the web's `aria-pressed`. Measured on the Pixel.

## 0.13.0

Built on kun-ui 2.47.2. Nothing here is a breaking change.

- **`KunReaction`**, the compact like / reaction pill: an icon, an optional
  `count` and an optional label (`child`).
  - As a toggle (`value`/`onChanged`, `count`/`onCountChanged`) it is
    announced as toggled. With `toggle: false` it is an action (share,
    more) that only calls `onPressed`, and its skin still follows `value`.
  - The web's motion comes with it: a pop on press, a ring and six sparks
    when it turns on, and a count that rolls in the direction it changed.
    All of it is off under reduced motion or `disableAnimation`.
  - The glyph defaults to the web's heart, which is filled while on.
  - For any other icon, `activeIcon` names the filled glyph. A font glyph
    cannot be filled the way the web's `fill-current` fills a stroke icon.
  - `iconBuilder` is the web's `#icon` slot, for emoji or images.
  - `color` takes a palette colour; `activeColor` takes any colour.
  - Sizes are `KunReactionSize.sm/md/lg`.
  - Like `KunSwitch`, it is controlled: write `value` and `count` back from
    the callbacks.
- **`KunScrollShadow.builder(itemCount:, itemBuilder:)`** builds a strip's
  items lazily, so a strip with no upper bound (a cast list, a screenshot
  row) no longer loads every image at once. It needs a bounded extent
  across its axis from the parent (a `SizedBox` height for a horizontal
  strip) and stretches items to it. Everything else is the same as the
  children constructor.
- `KunIcons.heart` and `KunIcons.heartFilled`, from kun_ui_icons 2.47.2.

## 0.12.0

Built on kun-ui 2.47.1. An app can now drop Material entirely: kun_ui has
the app, the pages, the page frame and the scroll behaviour, as well as the
widgets. Nothing here is a breaking change.

- **`KunApp` / `KunApp.router`** wrap `WidgetsApp`. `theme`, `darkTheme` and
  `themeMode` (`KunThemeMode.system` follows the platform) install
  `KunTheme`. `messages` and `config` install `KunMessagesScope` and
  `KunUIConfigScope`. The default text style is `KunText.base` in
  `foreground`, the scroll behaviour is `KunScrollBehavior`, and named routes
  are `KunPageRoute`s. Add `KunMessageProvider` through `builder` if you use
  toasts.
- **`KunPage` / `KunPageRoute`**, for `GoRoute.pageBuilder`
  (`KunPage(key: state.pageKey, child: …)`) and Navigator 1.
  `transition: platform | fade | slide | none`:
  - `fade` is KunUI's surface-enter motion: fade plus a 0.95 scale,
    `kun-base` in and `kun-exit` out.
  - `slide` is the iOS slide with the covered page's parallax, on `kun-slow`
    and the emphasized ease. Its edge swipe goes back.
  - `platform` is `slide` on iOS and macOS and `fade` elsewhere.
  - `none` has no motion, for full-screen viewers.
  - Android predictive back scrubs the page's own transition (measured on a
    Pixel 10 Pro).
  - Reduced motion makes all of them instant.
- **`KunScaffold`** replaces `Scaffold` for a page frame: `body`,
  `bottomBar`, `extendBody`, `backgroundColor` (the theme background by
  default) and `resizeToAvoidBottomInset`. The insets follow Scaffold's
  rules. With `extendBody`, the body's `MediaQuery.padding.bottom` is the
  bar's height, so pad the last item with it. The bar sees the `MediaQuery`
  without its top padding, so a `SafeArea` around it pads only the bottom.
- **`KunScrollBehavior`** gives stretch overscroll on Android, bounce on iOS
  and macOS, and a `KunScrollbar` on desktop. The mouse does not
  drag-scroll, as on the web; opt in per strip with `KunScrollShadow`.
- **`KunScrollbar`**, the web's thin KunUI scrollbar: an 8px rounded thumb in
  neutral 300, 400 when hovered or dragged, and no track.
- **`KunScrollShadow`**, newly portable in kun-ui 2.47.1.
  - Edge fades show only while there is more content on that side.
  - `wheel: on` lets a vertical mouse wheel scroll a horizontal strip, and
    `contain` also keeps the page still at the ends.
  - `draggable` gives mouse grab-to-scroll, and a card inside doesn't click
    after a drag.
  - `scrollbar: hide | thin | auto`, `shadowColor`, `shadowSize` and
    `semanticLabel` (no English default).
  - Flutter-only: `spacing`, `padding` and `controller`. Give horizontal
    children a width.

## 0.11.0

Built on kun-ui 2.47.0. Both items are gaps the kungal app hit on a Pixel
10 Pro. There are no API changes. Two things can still surface in your code,
and both are listed under the first item.

- **`KunInput` and `KunTextarea` have selection handles and a selection
  menu.** A long press on a touch device used to select a word with no way
  to copy it, and paste worked only through the keyboard's clipboard key.
  - **Handles.** KunUI now draws them in the field's `color`: a teardrop,
    or a lollipop on iOS and macOS. You can drag them to extend the
    selection.
  - **Touch menu.** A bar above the selection, or below it when there is no
    room. It offers Cut, Copy, Paste, Share and Select all as the platform
    allows, followed by any actions the system adds, such as Android's
    Translate. A tap on the caret's handle brings up Paste.
  - **iOS 16+** gets the native edit menu.
  - **Desktop.** A right-click opens a vertical menu at the pointer.
  - **Design.** The visuals are the web's `KunContextMenu`: the `content1`
    panel, `light` rows, a minimum width of 192, and 12px from the viewport
    edges.
  - **Labels** come from kun_ui_messages' new `textSelection` group, so
    they follow `KunMessagesScope`. The menu reaches a `KunTheme` or
    `KunMessagesScope` you put inside a route.
  - **Accessibility.** Each item is a labelled button to a screen reader,
    in the order it is drawn.
  - **Not affected.** On Flutter web the browser's own context menu still
    shows, as it does for every `EditableText`. KunSelect's search field is
    not wired yet.
  - **Tests.** A plain tap on these fields now needs an `Overlay` ancestor.
    An app's `Navigator` already provides one, but a widget test that
    builds a bare tree has to add one.
  - **Custom catalogs.** kun_ui_messages 2.47.0 adds a required
    `textSelection` group to `KunMessages`, so a `KunMessages` you build
    yourself needs it too.


- **A `KunImage` with a skeleton or a `thumbhash` now fills a box its parent
  sizes.** With no `width`, `height` or `aspectRatio`, the picture used to
  lay out at its own ratio inside a tight parent and sit in the top-left
  corner, with the placeholder showing in the rest of the box, so `fit` had
  no visible effect. In a `SizedBox(width: 150, height: 214)`, a 792x1000
  picture drew at 150x189. It now fills the box as `fit` says, as a bare
  image and the web's `size-full` img always did. A loose parent still gets
  the picture's own size. Affects 0.10.0. You can drop an `aspectRatio` you
  added as a workaround.

## 0.10.0

Built on kun-ui 2.45.0. Most items are gaps the kungal app hit on a Pixel
10 Pro. The avatar frames come with the 2.45.0 contract. Nothing here is a
breaking change.

- **A `fullWidth` `KunButton` no longer fills a bounded height.** It
  centred its label through `Container.alignment`, whose `Align` fills every
  bounded axis, so four full-width buttons in a bottom bar took the whole
  screen. The button now stretches to the full width and keeps its own
  height, which is what the web's `w-full` does. Affects every release
  before this one. Remove any `IntrinsicHeight` you added as a workaround.
- `KunInput` takes `controller`, `focusNode`, `textInputAction` and
  `onSubmitted`, and `KunTextarea` takes `controller` and `focusNode`. These
  are Flutter-only: the web's caret and Enter key are native `<input>`
  behaviour. With a controller, its text is the field's text and `value` is
  ignored; leave `value` unset, or a debug assert fires. The controller is
  how you insert at the selection, for example an uploaded image's markdown
  in a composer. `onChanged` still reports user edits and not the
  controller's, as Flutter's own fields do. The clear button and the char
  count follow the controller, including changes you make to it, and the
  count leaves out an open IME composition. A search field can now run on
  the keyboard's action key:
  `textInputAction: TextInputAction.search, onSubmitted: ...`.
- `KunRefreshIndicator`, KunUI's own pull-to-refresh, with no Material
  import. The web has no counterpart because the browser draws pull-to-refresh
  there, so KunUI draws it itself, as it does all browser-owned touch chrome.
  The gesture is Flutter's `RefreshIndicator` gesture, top edge only. The
  drawing is KunUI's: the spinner on the floating surface popovers use, in
  `color` (`primary` by default). `edgeOffset` and `displacement` work as
  they do in Material's widget. The spinner keeps turning under reduced
  motion, as `KunSpinner` does.
  Unlike Material's, it keeps the Android overscroll glow away for the
  whole pull: measured on the device, Material's condition let the glow draw
  across the list as soon as the pull armed.
- `KunImage`, now portable in the 2.45.0 contract. The URL goes through
  `KunUIConfig.imageProvider`, so your cache applies. It has the ThumbHash
  blur-up (`thumbhash`), the pulse `skeleton`, `aspectRatio`, `fit` (the
  web's `objectFit`), `width`/`height`, `fallbackSrc`, and
  `onLoad`/`onError`, each reported once per URL tried. `cacheWidth` and
  `cacheHeight` decode at thumbnail size. The placeholder stays until the
  image has faded in and only then fades itself, as kun-ui 2.45.0 fixed it on
  the web. `alt` has no English default: an unlabelled image is announced as
  an image, and `alt: ''` makes it decorative. Round it with a `ClipRRect`.
- `KunThumbHashImage(hash)`, the blur-up placeholder as an `ImageProvider`
  of its own, for a screen that holds the real image back. The decoder is a
  hand port of the reference ThumbHash (MIT), byte-exact against it, with no
  package. It builds the image from raw RGBA, not a PNG, and the blur was
  measured painting on a Pixel 10 Pro, where a package's PNG output fails to
  decode.
- `KunNavItem`, one destination of an app shell's navigation (kun-ui 2.45.0),
  replacing the recipe `docs/INTEGRATION.md` gave. A full-width `KunButton`,
  `flat` in `color` and announced as selected while `current`, `light`
  otherwise. `stacked` puts a 20px icon over the label for a rail or a bottom
  bar; otherwise the item is a left-aligned sidebar row. The `icon` takes any
  widget, so `KunBadge(count: n, child: Icon(...))` shows an unread count.
  `href` goes through `KunUIConfig.navigate`. The bar and the rail stay
  yours.
- **Avatar frames** (kun-ui 2.44.0). `KunUser` gains an optional
  `avatarDecoration: KunAvatarDecoration(src:, animatedSrc:)`. A `KunAvatar`
  at `md` or larger draws the frame 1.2 times its size around it, so
  `KunUserChip` gets frames with no change at the call site. The frame
  changes no layout and takes no taps. `decoration: KunAvatarDecorationMode`
  picks when the animated asset plays: `hover` (the default, while hovered or
  keyboard-focused), `always`, `static` or `none`. Reduced motion always
  shows the still image. Users without a decoration look exactly as before.
- `KunAvatar`'s loading pulse now holds as a flat fill until the picture has
  faded in, then fades itself, like `KunImage`. Before, it vanished the
  moment the picture started to fade in.
- `KunFontFamilies` from `kun_ui_tokens` 2.45.0 is re-exported: the web's
  code face, `--kun-font-mono`, as `mono` plus a `monoFallback` list. Merge
  `KunFontFamilies.monoStyle` onto a `KunText` step to set code in it:
  `KunText.sm.merge(KunFontFamilies.monoStyle)`. The fallback ends in
  `monospace`, which Android resolves to its own fixed-width face.
- The generated family now floors at `^2.45.0` (`kun_ui_tokens`,
  `kun_ui_icons`, `kun_ui_messages`).

## 0.9.1

- **0.9.0 could not compile for a consumer pinned to an older token family.**
  It called `KunImages.loadingImage`, new in `kun_ui_icons` 2.43.0, while
  declaring `kun_ui_icons: ^2.42.3` — so an app whose lockfile already held
  2.42.3 kept it, and `KunLoading` failed to build. The three generated
  dependencies now floor at `^2.43.0`, which is what the code needs. Upgrade
  straight to this version; 0.9.0 resolves correctly only from a clean
  lockfile.
- CI gained a third job that resolves the *lowest* version every constraint
  allows and analyzes and tests against it. `pub get` takes the newest, so
  nothing in the gate could see a floor that was too low.

## 0.9.0

- `KunAutocomplete` — the combobox the anchored-popup decision named as its
  last follower. The value is the field's *text*, not a chosen option: the
  user may type anything unless `allowCustomValue` is false, which empties a
  field whose text matches nothing shortly after it loses focus, and
  `onSelected` carries the whole option when one is committed. The keyboard
  never leaves the field — the arrow keys move the highlight, Enter commits,
  Escape and the Android back gesture close the list — because the list only
  suggests. `manualFilter` hands filtering to `onSearch` for a remote source,
  `debounce` holds that call until the user pauses, and the spinner covers
  both the wait and the request so a pending fetch never reads as "no
  matches". The field is a `KunInput`, so a label, helper text, an error and
  the control scale all come with it.
- `KunLoading` — the loading state, unblocked by kun-ui 2.43.0. With a child
  it is a veil: the content stays in place, dimmed, under the mascot, so the
  page does not jump when the request lands; without one it is the loader
  alone. `spinner` swaps the mascot for a ring at the five sizes, for a
  loading state beside a button. The mascot is the bundled
  `KunImages.loadingImage` — the same bytes the web inlines, and no network
  request. A veiled loader scales down rather than overflowing a block
  shorter than the mascot; the web spills out of the overlay instead, which
  CSS permits and a Flutter `Column` reports.
- Built on kun-ui 2.43.0 (`kun_ui_tokens`, `kun_ui_icons` and
  `kun_ui_messages` ^2.43.0), which emits that mascot and fixes
  `KunProgress`'s reported range — `aria-valuemax` was `max` beside a
  percentage `aria-valuenow`, so a bar of 60 out of 60 announced "100 out of
  60". This port already reported 0..100, and now says so rather than
  calling the web's range a bug.

## 0.8.1

Three accessibility defects an Android node dump found, none of which the
widget tests could see.

- **A `KunDropdown` trigger has a name again.** The wrapper excluded the
  trigger's own semantics and supplied no replacement, so the node was
  nameless — Android showed no node for it at all. The two are merged now,
  as the web's wrapper carries `role="button"` while the slotted trigger
  supplies the accessible name; it reads as `android.widget.Button` with the
  trigger's label, over a menu of `MenuItem`s. Affects 0.7.0.
- **`KunProgress` reports itself a progressbar.** It set a label and a value
  but no role, so Android rendered it as a plain `android.view.View` with
  the percentage as its text where the web has `role="progressbar"`. It now
  carries `SemanticsRole.progressBar`, and an indeterminate one still
  reports no value.
- **`KunCheckBox` no longer tells a screen reader it is disabled when it
  merely has no callback.** Its semantics node took `enabled` from the
  callback as well as the `disabled` prop, so a box an app drives from
  elsewhere announced itself disabled. `KunSwitch` and `KunButton` have
  always taken it from the prop alone, and the checkbox now does too — the
  callback still decides whether a tap does anything. Found in an Android
  accessibility-node dump, where the states demo's boxes read
  `enabled=false`.

## 0.8.0

The form and layout primitives every app reaches for.

- `KunCheckBox` — the box: the shared selection scale, a label that is part
  of the tap target, helper text, an error that takes precedence over it, a
  keyboard-only focus ring and the `single` circular shape. `indeterminate`
  is the select-all parent's "some but not all": a dash in place of the
  check, reported as a mixed check state, and visual only — the value only
  changes when the user toggles it, exactly as on the web.
- `KunCheckBoxGroup` — several choices out of many, in three presentations
  (`classic`, `pill`, `card`), either stacked or wrapped in a row. `max`
  caps the selection: past it an unchosen option dims and refuses, calling
  `onInvalid`, while a chosen one still toggles off. `onChanged` carries the
  new list rather than a read-back, so it is never a click behind. The
  keyboard is the WAI-ARIA checkbox pattern — every box its own tab stop,
  Space or Enter to toggle, and no arrow-key selection, which belongs to
  radios.
- `KunRadioGroup` — one choice out of several, in the same three
  presentations. Its keyboard is the radio pattern instead: the group is one
  tab stop, and the arrow keys move *and* choose in one step, skipping
  disabled options and wrapping. Tab lands on the chosen option, or on the
  first enabled one when nothing is chosen.
- `KunSelectionMetrics` — the shared box/dot/check/gap scale the three read,
  so a checkbox and a radio of one `KunUISize` draw identically. The
  translation of `kunSelectionSizeClasses`.
- `KunProgress` — the bar and the ring: `solid`, `gradient`, `striped` and
  `circle`, five thicknesses, the rounding steps and an optional label on
  the bar or inside the ring. `indeterminate` sweeps the bar and spins the
  ring, and reports no value to assistive technology; every looping
  animation stops under reduced motion.
- `KunDivider` — the separator, with an optional label in the middle. Every
  hue is drawn at 20% and `neutral` takes the shared border token, as the
  web tints a separator down deliberately. A dashed rule is measured, not
  guessed: Chrome draws a dash of twice the line's thickness and stretches
  the gap so a whole number of dashes fills the rule, and so does this.

`KunLoading` is not ported. Its default form renders `KUN_LOADING_IMAGE`,
and `kun_ui_icons` carries only `nullImage` and `avatarFallback` — the
mascot has to be generated upstream before the component can exist here, so
it has been reported rather than hand-added.

## 0.7.0

The anchored-popup family the `KunSelect` portal decision was made for.

- `KunTooltip` — the hint: it opens on hover and on focus after `delayShow`,
  lingers for `delayHide`, closes on Escape, and flips to the opposite side
  when there is no room. `hideOnMobile` suppresses it under the `sm`
  breakpoint, as the web's `hidden sm:block` does. The trigger keeps its own
  semantics and carries the text as its description, which is what a screen
  reader reads; the panel itself is excluded, so nothing is announced twice.
  `content` replaces the text with a widget in the panel only.
- `KunPopover` — the anchored dialog: twelve placements, `autoPosition` to
  flip, shift and cap it to the room available, a caret, `fullWidth`, and a
  controller for opening it from application code. It behaves as a dialog
  and not only reports itself as one: opening moves focus into the panel and
  closing returns it. `openOn: KunPopoverTrigger.hover` is the navigation
  menu — it opens without taking focus, a `group` makes a row of them behave
  as a menu bar, and a coordinate safe triangle lets the pointer cut the
  corner to reach the panel without it closing. A touch still opens it with
  a tap.
- `KunDropdown` — the action menu, with the WAI-ARIA menu-button keyboard:
  one tab stop, Down or Enter opening on the first row and Up on the last,
  arrow keys that skip disabled rows and wrap, Home and End, type-ahead, and
  Escape or Tab to close with focus back on the trigger. Rows carry a
  colour, an optional icon and an optional `href` that goes through
  `KunUIConfig.navigate`. It is deliberately not built on `KunPopover`, as
  the web keeps them apart: a `dialog` cannot carry `menu`/`menuItem`.
- All three register with the dismiss-layer stack 0.6.6 introduced, so the
  Android back gesture closes the innermost one and leaves the page alone.
- `opaque` is not ported (`KunPopover`). It forces a panel opaque against a
  globally lowered `--kun-surface-opacity`, a CSS variable a site sets to
  frost every surface; this port has no such knob and paints `content1`
  opaque already.

## 0.6.6

- **A back gesture dismisses the innermost layer only.** 0.6.5 gave the
  `KunSelect` trigger a `PopScope`, which closed the popup instead of the
  page — but inside a `KunModal` it closed the popup *and* the modal,
  because a portal has no route of its own, so its scope registers with the
  route it was opened from and a route invokes every scope registered with
  it. The layers now share a stack: a modal route and an anchored popup
  each push themselves while open, and a scope acts only when it is on top.
  One back on a select open inside a modal closes the popup and leaves the
  modal; the next one closes the modal. A `showKunAlert` dialog registers
  the same way, so back still resolves its future with `false`. Nothing
  changes for a select or a modal on its own, and a closed one never blocks
  a back. Measured on a Pixel 10 Pro with the navigation bar's Back button:
  one press on a select open inside a modal left the modal standing, the
  next closed it, and on a plain page one press closed the popup with the
  app still in front. A *searchable* select takes two, because the first
  press closes the soft keyboard — Android's own behaviour, not ours.

## 0.6.5

- **A `KunSelect` trigger reads what it paints.** Its semantics value was
  the trigger *text*, which for a `multiple` select is a count, so a
  TalkBack user heard "2, Frameworks" while two named chips were on screen
  and had to swipe through them — nodes of their own — to learn which two.
  The web's `role="combobox"` has no value of its own: a screen reader
  reads its content, and the chips are that content. The value is now the
  painted chip labels (`Vue, Solid`, with `+N` when `maxVisibleTags`
  collapses the rest), and the painted content is no longer a node beside
  it. Measured on a Pixel 10 Pro: the node went from `2, Frameworks` with
  `Vue` and `Solid` beside it to `Vue, Solid, Frameworks` with no chip
  nodes. A single select reads as before, minus the duplicate child node
  that repeated its value.
- **The system back gesture closes an open popup instead of the page.**
  The popup is a portal, not a route, so back went past it to the page:
  with the popup open it popped the whole screen and dismissed nothing
  (measured with `handlePopRoute`, the message the engine sends on a back
  gesture). The trigger now carries a `PopScope` that blocks the pop while
  the popup is open and closes the popup instead — what Escape does on the
  web, and what Android's back means. A second back leaves the screen as
  usual, and a closed select never blocks anything. Inside a `KunModal`,
  back still closes the modal as well: both scopes are registered with the
  modal's route and a route invokes every one of them. That is what
  happened before this change too; dismissing only the innermost layer
  needs a shared scope, noted as an open gap in `docs/architecture.md`.

## 0.6.4

- Built on kun-ui 2.42.3 (`kun_ui_tokens`, `kun_ui_icons` and
  `kun_ui_messages` ^2.42.3). The contract and the generated packages are
  unchanged from 2.42.2; the release carries the web fix below.
- **A `KunTab` whose items all carry an `href` is navigation, not a
  tablist**, as on the web since kun-ui 2.42.3. Such a strip goes to pages,
  so nothing there controls a tab panel: it no longer reports
  `SemanticsRole.tabBar` or `SemanticsRole.tab`, and only the current item
  is reported selected — the flag Flutter renders as the web's
  `aria-current` — instead of every item carrying a selected-or-not tab
  role. Every enabled item is now its own tab stop, where a roving tab stop
  left only the current one reachable, and KunTab no longer handles the
  arrow keys, Home or End, each of which used to be a page navigation.
  Enter and Space still activate the focused item, which is what the web
  gets from the anchor. A mixed strip, where only some items link, stays a
  tablist. Measured on the gallery's release web build: `/kuntab/links`
  reports `role="button"` per item with `aria-current="true"` on the current
  one alone, while `/kuntab/basic` still reports `role="tablist"` and three
  `role="tab"`. The item stays a tappable node rather than a Flutter link:
  link semantics render an `<a>` whose `href` the browser may follow, and a
  `KunTabItem.href` is whatever string the app's `KunUIConfig.navigate`
  understands, not necessarily a URL.

## 0.6.3

- **A `KunInput` or `KunTextarea` hides its placeholder while an IME is
  composing.** The placeholder was painted under the composing text, because
  it was shown while the *reported* `value` was empty and composing text is
  deliberately not reported until it commits. It now follows what the field
  paints. Measured with Gboard's Simplified Chinese keyboard on a Pixel 10
  Pro: "Inline composing" ships off, and with it on, `ni hao` overlapped the
  placeholder. The web never had this: its `<input>` carries the composing
  text as its own value, so the browser drops the native placeholder.

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
