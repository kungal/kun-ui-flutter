# kun-ui-flutter

KunUI for Flutter — the hand-written widget layer of the
[KunUI design system](https://github.com/kungal/kun-ui), shared by every
Flutter app in the NextMoe/KunGal ecosystem the way `@kungal/ui-vue` is
shared by every website.

One design language, two render layers, one source of truth: every color,
radius, shadow, easing, duration and icon here — and every string KunUI
renders for itself — comes from the generated
[`kun_ui_tokens`](https://pub.dev/packages/kun_ui_tokens),
[`kun_ui_icons`](https://pub.dev/packages/kun_ui_icons) and
[`kun_ui_messages`](https://pub.dev/packages/kun_ui_messages) packages,
emitted in kungal/kun-ui from the same generators as the web bundle. The widgets are
hand-written (component code cannot be generated across frameworks — see
kun-ui's `docs/architecture-flutter.md` for the constraint analysis), but
their API is verified in CI against the web library's machine-readable
component contracts, so the port cannot silently drift.

## Layout

| Path | What |
| --- | --- |
| `packages/kun_ui` | The library: `KunTheme`, the design vocabulary, the widgets. |
| `apps/gallery` | The component gallery and docs surface (builds to web). |
| `contracts/components.manifest.json` | What this port claims against the upstream contract. |

## Quick start

```dart
import 'package:kun_ui/kun_ui.dart';

runApp(
  KunTheme(
    data: KunThemeData.light(),
    child: const App(),
  ),
);

// Anywhere below:
KunButton(
  color: KunUIColor.primary,
  onPressed: save,
  child: const Text('Save'),
)
```

`KunTheme` is KunUI's own `InheritedWidget` — no Material `ThemeData`
coupling; it composes fine inside or outside a `MaterialApp`. See
`docs/INTEGRATION.md` for consuming the package today (git dependency until
the first pub.dev release) and `docs/architecture.md` for the design
decisions.

## Status

Tier 4 of the KunUI Flutter roadmap, scoped **on demand**: a component is
ported when a real app needs it, one implementation serving all apps. The
contract lists 57 portable components; the manifest is the honest record of
how many exist here today. Run `./scripts/parity.sh` for the current report.

## License

AGPL-3.0, same as kun-ui.
