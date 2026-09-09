# Changelog

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
