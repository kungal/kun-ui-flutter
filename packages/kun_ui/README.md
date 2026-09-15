# kun_ui

KunUI for Flutter: the hand-written widget layer of the
[KunUI design system](https://github.com/kungal/kun-ui), painted exclusively
with the generated [`kun_ui_tokens`](https://pub.dev/packages/kun_ui_tokens)
— so a `KunButton` here and a `KunButton` on the web ship the exact same
colors, radii, sizes and motion, from one generator.

## Usage

Wrap the app once in `KunTheme` (KunUI's own `InheritedWidget` — no Material
`ThemeData` coupling; it works inside or outside a `MaterialApp`):

```dart
import 'package:kun_ui/kun_ui.dart';

runApp(
  KunTheme(
    data: KunThemeData.light(), // or KunThemeData.dark()
    child: const App(),
  ),
);
```

`kun_ui` re-exports `kun_ui_tokens`, `kun_ui_icons` and `kun_ui_messages`, so
one import serves an app: `KunColors`, `KunRadius`, `KunShadows`, `KunEasing`,
`KunDurations`, `KunIcons` and `KunMessages` all come with it.

The strings KunUI renders for itself — a chip's close button, an input's clear
and reveal buttons — come from `KunMessages`, with `zh-CN` as the built-in
default. Wrap a subtree to change language; nothing is required:

```dart
KunMessagesScope(
  messages: KunMessages.en,
  child: const App(),
)
```

```dart
KunButton(
  variant: KunUIVariant.solid,
  color: KunUIColor.primary,
  size: KunUISize.md,
  loading: saving,
  onPressed: save,
  child: const Text('Save'),
)

const KunSpinner(size: 24)
```

The design vocabulary — `KunUIVariant` (`solid`/`bordered`/`light`/`flat`/
`shadow`), `KunUIColor` (`neutral` + six semantic hues), `KunUISize`
(`xs`–`xl`), `KunUIRounded` (`none`–`full`) — mirrors the web library's
prop unions verbatim, and every widget's API is verified in CI against the
web component contracts.

## Theming

- `KunThemeData.rounded` is the app-wide default corner rounding: every
  component whose `rounded` parameter is null follows it, so one knob
  squares or rounds every KunUI surface at once.
- The theme paints no background; put
  `KunTheme.of(context).colors.background` behind your page.
- `KunThemeData.breakpoints` carries the web's responsive breakpoints
  (Tailwind's widths), with `resolve(width)` for layout switches.

This package is upstream for every KunUI Flutter app: report issues at the
[kun-ui-flutter repository](https://github.com/kungal/kun-ui-flutter) rather
than patching locally.
