# Changelog

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
- Contract: adopted `kun_ui_tokens` / `kun_ui_icons` 2.37.0, up from the
  2.35.1 that 0.1.0 shipped against. Every hop was a lockstep version bump
  with no token or icon changes, and the contract entries for everything this
  port claims are unchanged — the adoption costs no new surface.
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
