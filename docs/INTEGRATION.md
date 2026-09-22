# Consuming kun_ui in an app

## The dependency

```yaml
dependencies:
  kun_ui: ^0.8.1
```

`kun_ui_tokens`, `kun_ui_icons` and `kun_ui_messages` come with it from
pub.dev and are re-exported, so `import 'package:kun_ui/kun_ui.dart';` is the
only import.

While `kun_ui` is 0.x, a minor bump may break and the caret stops at it
(`^0.8.1` never resolves 0.9.0): read the
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

## The app shell's own navigation (there is no KunNavBar)

KunUI owns no navigation component, on either side: the web contract's 69
components have none, and `KunHeader` is a page title, not a nav. Every
kungal website builds its own — the forum's collapsed rail and expanded
sidebar are both a list of `KunButton`s, `flat` while current and `light`
otherwise, with an icon over a small label. That *is* the design, and it
translates directly, so a Flutter app shell writes the same thing rather
than waiting for a widget:

```dart
class NavDestination extends StatelessWidget {
  const NavDestination({
    required this.icon,
    required this.label,
    required this.current,
    required this.onTap,
    this.stacked = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool current;
  final VoidCallback onTap;

  /// Icon over label, as a rail or a bottom bar draws it. False puts the
  /// icon beside the label, as an expanded sidebar does.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final Widget text = Text(label, style: KunText.xs);
    return KunButton(
      onPressed: onTap,
      variant: current ? KunUIVariant.flat : KunUIVariant.light,
      color: current ? KunUIColor.primary : KunUIColor.neutral,
      fullWidth: true,
      icon: stacked ? null : Icon(icon, size: KunSpacing.unit * 4),
      child: stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              spacing: KunSpacing.unit,
              children: <Widget>[Icon(icon, size: KunSpacing.unit * 5), text],
            )
          : text,
    );
  }
}
```

A bottom bar is then a `Row` of those in `Expanded`s over
`KunTheme.of(context).colors.content1`, inside a `SafeArea(top: false)` so
the gesture inset is not painted over; a rail is a `Column` of them in a
`SizedBox` of your width. The control scale is padding-driven, so a
two-line destination grows the button instead of clipping it — the same
thing the web's `h-auto` does.

Two things this recipe does not solve:

- **Icons.** `kun_ui_icons` carries only the glyphs the components
  themselves use, so destination icons come from your app's own set. The
  web has no such limit — its `KunIcon` renders any Iconify name.
- **Which shape on which screen.** The websites answer a phone with a
  drawer, not a bottom bar; an Android app usually answers it with a bottom
  bar. That divergence is the app's call, not KunUI's.

If you find yourself copying this into a second app, say so in an issue:
the forum already hand-writes it once, so a second consumer is the demand
signal that turns it into a component, and the design above is what it
would be.

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
