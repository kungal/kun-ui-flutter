import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import 'design.dart';

/// The size of every text-like form control — Button today; Input, Select,
/// Textarea as they are ported — so controls of one [KunUISize] line up in a
/// row.
///
/// Translated value-for-value from `kunControlSizeClasses` and
/// `kunControlSquareClasses` in `@kungal/ui-core` (packages/ui-core/src/
/// controlSize.ts in kungal/kun-ui) — that file is the source of truth; a
/// change starts there and is mirrored here, never invented here.
///
/// Each padding is [KunSpacing.unit] times the class's own step (`px-2.5` is
/// `KunSpacing.unit * 2.5`) and each text style is the class's [KunText] step
/// (`text-xs` is [KunText.xs]), so the values are read off the web classes, not
/// retyped from them.
///
/// Padding-driven, not fixed-height: height = line height + 2·padding + 2·1px
/// border (every variant carries a 1px border, transparent on filled ones, so
/// switching variants never shifts the box). Heights: xs 26 · sm 34 · md 38 ·
/// lg 46 · xl 54.
class KunControlMetrics {
  const KunControlMetrics._({
    required this.textStyle,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.square,
  });

  /// The label [TextStyle]: a [KunText] step, so size, line height and CSS
  /// half-leading only — color and weight are the component's.
  final TextStyle textStyle;

  /// Label font size in logical pixels.
  double get fontSize => textStyle.fontSize!;

  /// Label line height in logical pixels (web line-heights 16/20/20/24/28).
  double get lineHeight => textStyle.fontSize! * textStyle.height!;

  /// Horizontal content padding.
  final double horizontalPadding;

  /// Vertical content padding.
  final double verticalPadding;

  /// Side of the fixed square an icon-only control becomes — equal to the
  /// text control's full height at the same size, borders included, so icon
  /// and text controls line up in a row.
  final double square;

  /// The content padding.
  EdgeInsets get padding => EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      );

  /// The metrics for [size].
  static KunControlMetrics of(KunUISize size) => switch (size) {
        KunUISize.xs => const KunControlMetrics._(
            textStyle: KunText.xs,
            horizontalPadding: KunSpacing.unit * 2.5,
            verticalPadding: KunSpacing.unit,
            square: 26,
          ),
        KunUISize.sm => const KunControlMetrics._(
            textStyle: KunText.sm,
            horizontalPadding: KunSpacing.unit * 3.5,
            verticalPadding: KunSpacing.unit * 1.5,
            square: 34,
          ),
        KunUISize.md => const KunControlMetrics._(
            textStyle: KunText.sm,
            horizontalPadding: KunSpacing.unit * 4,
            verticalPadding: KunSpacing.unit * 2,
            square: 38,
          ),
        KunUISize.lg => const KunControlMetrics._(
            textStyle: KunText.base,
            horizontalPadding: KunSpacing.unit * 5,
            verticalPadding: KunSpacing.unit * 2.5,
            square: 46,
          ),
        KunUISize.xl => const KunControlMetrics._(
            textStyle: KunText.lg,
            horizontalPadding: KunSpacing.unit * 6,
            verticalPadding: KunSpacing.unit * 3,
            square: 54,
          ),
      };
}

/// The size of a chip — a label, not a control, so it has its own scale.
///
/// Translated value-for-value from `kunChipSizeClasses`, the table sitting
/// beside `kunControlSizeClasses` in `@kungal/ui-core` (packages/ui-core/src/
/// controlSize.ts in kungal/kun-ui). A chip is deliberately tighter than a
/// control of the same [KunUISize]: chips sit inside rows of text, controls
/// sit in forms.
///
/// Each padding is [KunSpacing.unit] times the class's own step (`px-2.5` is
/// `KunSpacing.unit * 2.5`) and each text style is the class's [KunText] step
/// (`text-xs` is [KunText.xs]), so the values are read off the web classes, not
/// retyped from them.
///
/// Heights (line height + 2·padding + 2·1px border): xs 22 · sm 26 · md 30 ·
/// lg 34 · xl 42.
class KunChipMetrics {
  const KunChipMetrics._({
    required this.textStyle,
    required this.horizontalPadding,
    required this.verticalPadding,
  });

  /// The label [TextStyle]: a [KunText] step, so size, line height and CSS
  /// half-leading only — color and weight are the component's.
  final TextStyle textStyle;

  /// Label font size in logical pixels.
  double get fontSize => textStyle.fontSize!;

  /// Label line height in logical pixels.
  double get lineHeight => textStyle.fontSize! * textStyle.height!;

  /// Horizontal content padding.
  final double horizontalPadding;

  /// Vertical content padding.
  final double verticalPadding;

  /// The metrics for [size].
  static KunChipMetrics of(KunUISize size) => switch (size) {
        KunUISize.xs => const KunChipMetrics._(
            textStyle: KunText.xs,
            horizontalPadding: KunSpacing.unit * 2,
            verticalPadding: KunSpacing.unit * 0.5,
          ),
        KunUISize.sm => const KunChipMetrics._(
            textStyle: KunText.xs,
            horizontalPadding: KunSpacing.unit * 2,
            verticalPadding: KunSpacing.unit,
          ),
        KunUISize.md => const KunChipMetrics._(
            textStyle: KunText.sm,
            horizontalPadding: KunSpacing.unit * 3,
            verticalPadding: KunSpacing.unit,
          ),
        KunUISize.lg => const KunChipMetrics._(
            textStyle: KunText.sm,
            horizontalPadding: KunSpacing.unit * 4,
            verticalPadding: KunSpacing.unit * 1.5,
          ),
        KunUISize.xl => const KunChipMetrics._(
            textStyle: KunText.base,
            horizontalPadding: KunSpacing.unit * 6,
            verticalPadding: KunSpacing.unit * 2,
          ),
      };
}
