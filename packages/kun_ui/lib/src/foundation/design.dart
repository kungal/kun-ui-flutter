import 'package:kun_ui_tokens/kun_ui_tokens.dart';

// The four design unions every KunUI component speaks. Names and members
// mirror `vocabulary` in the upstream contract (contracts/
// component-contracts.json in kungal/kun-ui) so a manifest entry maps to the
// web API mechanically — do not add members here that the web does not have.

/// Visual style of a colored surface: `solid` filled, `bordered` outline,
/// `light` text-only with a tinted hover, `flat` a soft tint, `shadow`
/// filled with a colored glow.
enum KunUIVariant {
  /// Filled with the semantic color; text takes the paired on-color.
  solid,

  /// A 1px outline in the semantic color on a transparent fill.
  bordered,

  /// Text-only; a 20% tint appears under the pointer.
  light,

  /// A 20% tint fill with a deepened text color.
  flat,

  /// Like [solid], plus a colored glow shadow.
  shadow,
}

/// The KunUI semantic colors.
///
/// [neutral] is the web token `default`, renamed because `default` is a Dart
/// reserved word — the same rename `KunColorScheme.neutral` made in
/// kun_ui_tokens.
enum KunUIColor {
  /// Web `default` — the near-grey hue.
  neutral,

  /// The brand hue — blue.
  primary,

  /// The secondary hue — magenta.
  secondary,

  /// The success hue — green.
  success,

  /// The warning hue — amber.
  warning,

  /// The danger hue — red.
  danger,

  /// The informational hue — cyan.
  info,
}

/// The shared component size scale.
enum KunUISize {
  /// Extra small.
  xs,

  /// Small.
  sm,

  /// Medium — the default everywhere.
  md,

  /// Large.
  lg,

  /// Extra large.
  xl,
}

/// The corner-rounding buckets, mapping onto [KunRadius].
enum KunUIRounded {
  /// Square corners.
  none,

  /// Small radius, for small controls.
  sm,

  /// The default control radius.
  md,

  /// For containers and floating panels.
  lg,

  /// A pill — the radius is clamped to half the box height when painted.
  full,
}

/// Resolves a [KunUIColor] to its generated scale in a [KunColorScheme].
extension KunUIColorResolve on KunUIColor {
  /// The 11-step scale plus solid/onSolid for this color in [scheme].
  KunColorScale scaleOf(KunColorScheme scheme) => switch (this) {
        KunUIColor.neutral => scheme.neutral,
        KunUIColor.primary => scheme.primary,
        KunUIColor.secondary => scheme.secondary,
        KunUIColor.success => scheme.success,
        KunUIColor.warning => scheme.warning,
        KunUIColor.danger => scheme.danger,
        KunUIColor.info => scheme.info,
      };
}

/// Resolves a [KunUIRounded] bucket to its [KunRadius] value.
extension KunUIRoundedResolve on KunUIRounded {
  /// The corner radius in logical pixels.
  double get radius => switch (this) {
        KunUIRounded.none => KunRadius.none,
        KunUIRounded.sm => KunRadius.sm,
        KunUIRounded.md => KunRadius.md,
        KunUIRounded.lg => KunRadius.lg,
        KunUIRounded.full => KunRadius.full,
      };
}
