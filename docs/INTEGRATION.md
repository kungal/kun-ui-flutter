# Consuming kun_ui in an app

## Today: git dependency

`kun_ui` is not yet on pub.dev (the first publish is a manual step still
ahead). Until then, depend on the repo directly:

```yaml
dependencies:
  kun_ui:
    git:
      url: https://github.com/kungal/kun-ui-flutter
      path: packages/kun_ui
      ref: main # or pin a commit for reproducible builds — recommended
```

`kun_ui_tokens` and `kun_ui_icons` come with it from pub.dev and are
re-exported, so `import 'package:kun_ui/kun_ui.dart';` is the only import.

After the first pub.dev release this becomes `kun_ui: ^<version>` — watch
the repo's releases.

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
- It brings no navigation, snackbars or dialogs. KunUI widgets work inside
  `MaterialApp`, `CupertinoApp` or a bare `WidgetsApp` — keep whatever app
  shell you have.

## App-wide rounding

```dart
KunThemeData.light(rounded: KunUIRounded.lg)
```

Every component whose `rounded` parameter is left null follows this — one
knob for the whole surface, matching the web's `config.rounded`.

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
