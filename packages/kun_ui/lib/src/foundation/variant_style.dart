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
  /// [brightness] must be the mode [scheme] was built for. Since kun-ui 2.56.0
  /// no cell depends on it: the `dark:` text overrides of `flat` became the
  /// `text` token, which flips with the scheme.
  static KunVariantStyle resolve({
    required KunColorScheme scheme,
    required Brightness brightness,
    required KunUIVariant variant,
    required KunUIColor color,
  }) {
    final scale = color.scaleOf(scheme);
    const transparent = Color(0x00000000);
    // Web `bordered`/`light` for color `default` set no text class — the text
    // inherits the page foreground instead of taking the near-grey solid.
    final tinted = color == KunUIColor.neutral ? scheme.foreground : scale.text;
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
        return KunVariantStyle._(
          background: scale.solid.withValues(alpha: 0.2),
          foreground: scale.text,
          border: transparent,
        );
      case KunUIVariant.shadow:
        return KunVariantStyle._(
          background: scale.solid,
          foreground: scale.onSolid,
          border: transparent,
          // Web `shadow-lg shadow-{color}/40`.
          shadows: KunShadows.glow(scale.solid.withValues(alpha: 0.4)),
        );
    }
  }
}
