import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import 'design.dart';

/// The resolved paint of one variant × color cell.
///
/// Translated cell-for-cell from the web's single source of truth for this
/// matrix, `kunVariantClasses` in `@kungal/ui-core` (packages/ui-core/src/
/// variants.ts in kungal/kun-ui). Change the design there first; this file
/// only mirrors it. The web's `dark:` overrides become [Brightness] branches
/// here — everything else is mode-correct by construction because the token
/// scheme itself flips.
class KunVariantStyle {
  const KunVariantStyle._({
    required this.background,
    required this.foreground,
    required this.border,
    this.hoverOverlay,
    this.shadows = const [],
  });

  /// Fill color; fully transparent for `bordered` and `light`.
  final Color background;

  /// Text and icon color.
  final Color foreground;

  /// 1px border color. Transparent on filled variants — the width is always
  /// painted (web parity: every cell carries an explicit border width so
  /// switching variants never shifts the box by a pixel).
  final Color border;

  /// `light` only: the 20% tint that replaces [background] under the pointer.
  final Color? hoverOverlay;

  /// `shadow` only: the colored glow (Tailwind `shadow-lg` geometry tinted
  /// with the semantic color at 40%).
  final List<BoxShadow> shadows;

  /// Resolves the cell for [variant] × [color] against [scheme].
  ///
  /// [brightness] must be the mode [scheme] was built for — it selects the
  /// web's `dark:` text overrides on the `flat` variant.
  static KunVariantStyle resolve({
    required KunColorScheme scheme,
    required Brightness brightness,
    required KunUIVariant variant,
    required KunUIColor color,
  }) {
    final scale = color.scaleOf(scheme);
    final dark = brightness == Brightness.dark;
    const transparent = Color(0x00000000);
    // Web `bordered`/`light` for color `default` set no text class — the text
    // inherits the page foreground instead of taking the near-grey solid.
    final tinted =
        color == KunUIColor.neutral ? scheme.foreground : scale.solid;
    switch (variant) {
      case KunUIVariant.solid:
        return KunVariantStyle._(
          background: scale.solid,
          foreground: scale.onSolid,
          border: transparent,
        );
      case KunUIVariant.bordered:
        return KunVariantStyle._(
          background: transparent,
          foreground: tinted,
          border: scale.solid,
        );
      case KunUIVariant.light:
        return KunVariantStyle._(
          background: transparent,
          foreground: tinted,
          border: transparent,
          hoverOverlay: scale.solid.withValues(alpha: 0.2),
        );
      case KunUIVariant.flat:
        // The web deepens the text per color so it clears AA on the 20% tint,
        // and re-lightens the bright hues in dark mode (`dark:text-…`).
        final foreground = switch (color) {
          KunUIColor.neutral => scale.shade700,
          KunUIColor.primary || KunUIColor.secondary => scale.shade600,
          KunUIColor.success ||
          KunUIColor.warning =>
            dark ? scale.solid : scale.shade700,
          KunUIColor.danger => dark ? scale.shade500 : scale.shade600,
          KunUIColor.info => dark ? scale.shade500 : scale.shade700,
        };
        return KunVariantStyle._(
          background: scale.solid.withValues(alpha: 0.2),
          foreground: foreground,
          border: transparent,
        );
      case KunUIVariant.shadow:
        final glow = scale.solid.withValues(alpha: 0.4);
        return KunVariantStyle._(
          background: scale.solid,
          foreground: scale.onSolid,
          border: transparent,
          // Tailwind's `shadow-lg` geometry with the tint `shadow-{color}/40`.
          shadows: [
            BoxShadow(
              color: glow,
              offset: const Offset(0, 10),
              blurRadius: 15,
              spreadRadius: -3,
            ),
            BoxShadow(
              color: glow,
              offset: const Offset(0, 4),
              blurRadius: 6,
              spreadRadius: -4,
            ),
          ],
        );
    }
  }
}
