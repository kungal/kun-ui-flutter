# Consuming kun_ui in an app

## The dependency

```yaml
dependencies:
  kun_ui: ^0.10.0
```

`kun_ui_tokens`, `kun_ui_icons` and `kun_ui_messages` come with it from
pub.dev and are re-exported, so `import 'package:kun_ui/kun_ui.dart';` is the
only import.

While `kun_ui` is 0.x, a minor bump may break and the caret stops at it
(`^0.10.0` never resolves 0.11.0): read the
[CHANGELOG](../packages/kun_ui/CHANGELOG.md) before raising the floor.

A fix that is on `main` but not yet released can be taken from the repo,
pinned to its commit:

```yaml
dependencies:
  kun_ui:
    git:
      url: https://github.com/kungal/kun-ui-flutter
      path: packages/kun_ui
      ref: <commit>
```

## Setup

Wrap the app once:

```dart
import 'package:kun_ui/kun_ui.dart';

void main() {
  runApp(
    KunTheme(
      data: KunThemeData.light(),
      child: const App(),
    ),
  );
}
```

Dark mode is the app's switch to flip — rebuild with the other scheme, e.g.:

```dart
KunTheme(
  data: dark ? KunThemeData.dark() : KunThemeData.light(),
  child: ...,
)
```

Following the platform is `MediaQuery.platformBrightnessOf(context)` at the
top of the app; KunUI does not decide this for you.

Two things `KunTheme` does *not* do:

- It paints no background. Give your page
  `KunTheme.of(context).colors.background` (a `Scaffold.backgroundColor`,
  a `ColoredBox` — wherever your shell paints its ground).
- It brings no navigation. KunUI widgets work inside
  `MaterialApp`, `CupertinoApp` or a bare `WidgetsApp`, so keep whatever app
  shell you have. They do need the `Navigator` that shell builds: text
  fields use its `Overlay`, every anchored popup — `KunSelect`'s list,
  `KunTooltip`, `KunPopover`, `KunDropdown` — opens on the root `Overlay`,
  and `KunModal` opens as a route on the root navigator. Under `*.router` the navigator is your router delegate's to
  build, and go_router's does.

## Toasts and dialogs

Toasts need one host. Mount it around the app's navigator, under
`KunTheme`:

```dart
MaterialApp.router(
  routerConfig: router,
  builder: (BuildContext context, Widget? child) =>
      KunMessageProvider(child: child!),
)
```

`WidgetsApp.builder` and `CupertinoApp.builder` are the same parameter. Then
raise a toast from anywhere, with no `BuildContext`:

```dart
showKunMessage('Saved', KunMessageType.success);
```

The host sits above every route, so a toast shows over an open `KunModal`,
in the theme and language in force where the host is mounted. A toast
raised before the host mounts waits for it, and a debug build says once
that no host is mounted.

A confirm dialog needs no host. It opens on the root navigator:

```dart
final bool confirmed = await showKunAlert(
  context,
  title: 'Delete this post?',
  message: 'This cannot be undone.',
  type: KunAlertType.danger,
);
```

## App-wide rounding

```dart
KunThemeData.light(rounded: KunUIRounded.lg)
```

Every component whose `rounded` parameter is left null follows this — one
knob for the whole surface, matching the web's `config.rounded`.

## Navigation, avatars and images

Widgets that navigate (a tab with an `href`, a dropdown row with one, an
avatar that links to its user) or load images read a `KunUIConfigScope`. It is optional, but an app
with a router or an image cache should provide one near the top:

```dart
KunUIConfigScope(
  config: KunUIConfig(
    navigate: (context, href) => GoRouter.of(context).go(href),
    userLinkTemplate: '/user/{id}',
    avatarFallbackPool: avatarPool,
    imageProvider: CachedNetworkImageProvider.new,
  ),
  child: ...,
)
```

- Without `navigate`, a tap that would navigate does nothing. A debug build
  prints this once.
- `userLinkTemplate` defaults to the web's `/user/{id}/info`.
- `avatarFallbackPool` is the list of absolute image URLs the web's
  `avatarFallbackPool` holds, and should be the same list. The pick is the
  web's hash, so a user gets the same image in the app as on the site. Load
  the list once, not per screen. While it is empty, every user without an
  avatar shows the bundled image.
- `imageProvider` turns every image URL KunUI loads into an
  `ImageProvider`. It defaults to `NetworkImage`; pass your cache's provider
  here instead of wrapping each widget.

## Images

`KunImage` is the web's `KunImage`: a URL through `KunUIConfig.imageProvider`
(so your cache applies), with the ThumbHash blur-up, the pulse skeleton, an
aspect-ratio box, `fit`, `fallbackSrc` and `onLoad`/`onError`.

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(KunRadius.md),
  child: KunImage(
    src: cover.url,
    thumbhash: cover.thumbhash,
    aspectRatio: 3 / 4,
    cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
  ),
)
```

- Rounding is a `ClipRRect` around it, as the web rounds the wrapper with a
  class.
- The placeholder stays until the image has faded in, then fades itself, so
  an image never fades in over the bare page.
- `KunThumbHashImage(hash)` paints the placeholder on its own, for a screen
  that holds the image back (a sensitive cover, for example). It decodes to
  raw RGBA, with no PNG step and no package.
- A sensitive-content veil is app policy and has no KunUI design yet. Build
  it over `KunImage` or `KunThumbHashImage`.

## Pull to refresh

`KunRefreshIndicator(onRefresh: ..., child: listView)` in place of
Material's `RefreshIndicator`. The gesture is the same, the spinner and the
surface are KunUI's, and `edgeOffset` and `displacement` work the same.

## Code

Code and `kbd` set in the web's code face: merge
`KunFontFamilies.monoStyle` onto a `KunText` step, e.g.
`KunText.sm.merge(KunFontFamilies.monoStyle)`. The stack ends in
`monospace`, which Android resolves to its own fixed-width face.

## The app shell's own navigation

`KunNavItem` is one destination: a full-width `KunButton`, `flat` in
`color` and announced as selected while `current`, `light` otherwise. It is
what the forum's rail and sidebar hand-write, and what this document used to
give as a recipe.

```dart
KunNavItem(
  label: '消息',
  icon: KunBadge(count: unread, child: const Icon(LucideIcons.bell)),
  current: index == 2,
  stacked: true, // icon over label: a rail or a bottom bar
  onPressed: () => onSelect(2),
)
```

- KunUI does not read the route: you decide which item is `current`. With
  `href` the item goes through `KunUIConfig.navigate` instead of
  `onPressed`.
- A bare `Icon` takes 20px stacked and 16px inline. Destination icons come
  from your app's own set: `kun_ui_icons` carries only the glyphs the
  components use.
- The containers are yours. A bottom bar is a `Row` of `Expanded` items in
  a `SafeArea(top: false)`; a rail is a `Column` in a `SizedBox`. The
  websites answer a phone with a drawer, not a bottom bar, so there is no
  shared design for the bar itself.

A row of section links *inside* a page — a sub-navigation, not the shell —
is `KunTab` with an `href` on every item. Such a strip goes to pages rather
than switching panels, so it reports itself as navigation instead of a
tablist: every link is its own tab stop and the arrow keys do not move
between them. Give `KunUIConfig.navigate` to route them.

## The rules (same as the websites)

- **Never modify KunUI from an app** — report at
  https://github.com/kungal/kun-ui-flutter/issues instead. A local patch
  helps one app once; a fix here ships to every app forever.
- **Missing a component?** That is the on-demand trigger working as
  designed: open an issue naming the component and the screen that needs
  it. The contract already defines its API surface; what is needed from you
  is the demand signal, not a design.
- **Missing a token or icon?** That is a kungal/kun-ui issue (the values
  generate there), not a kun-ui-flutter one — and never a local constant in
  your app.
