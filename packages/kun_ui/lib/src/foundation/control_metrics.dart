import 'package:flutter/widgets.dart';

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
/// Padding-driven, not fixed-height: height = line height + 2·padding + 2·1px
/// border (every variant carries a 1px border, transparent on filled ones, so
/// switching variants never shifts the box). Heights: xs 26 · sm 34 · md 38 ·
/// lg 46 · xl 54.
class KunControlMetrics {
  const KunControlMetrics._({
    required this.fontSize,
    required this.lineHeight,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.square,
  });

  /// Label font size in logical pixels.
  final double fontSize;

  /// Label line height in logical pixels (web line-heights 16/20/20/24/28).
  final double lineHeight;

  /// Horizontal content padding.
  final double horizontalPadding;

  /// Vertical content padding.
  final double verticalPadding;

  /// Side of the fixed square an icon-only control becomes — equal to the
  /// text control's full height at the same size, borders included, so icon
  /// and text controls line up in a row.
  final double square;

  /// The label [TextStyle] (size and line height only — color and weight are
  /// the component's).
  TextStyle get textStyle =>
      TextStyle(fontSize: fontSize, height: lineHeight / fontSize);

  /// The content padding.
  EdgeInsets get padding => EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      );

  /// The metrics for [size].
  static KunControlMetrics of(KunUISize size) => switch (size) {
        KunUISize.xs => const KunControlMetrics._(
            fontSize: 12,
            lineHeight: 16,
            horizontalPadding: 10,
            verticalPadding: 4,
            square: 26,
          ),
        KunUISize.sm => const KunControlMetrics._(
            fontSize: 14,
            lineHeight: 20,
            horizontalPadding: 14,
            verticalPadding: 6,
            square: 34,
          ),
        KunUISize.md => const KunControlMetrics._(
            fontSize: 14,
            lineHeight: 20,
            horizontalPadding: 16,
            verticalPadding: 8,
            square: 38,
          ),
        KunUISize.lg => const KunControlMetrics._(
            fontSize: 16,
            lineHeight: 24,
            horizontalPadding: 20,
            verticalPadding: 10,
            square: 46,
          ),
        KunUISize.xl => const KunControlMetrics._(
            fontSize: 18,
            lineHeight: 28,
            horizontalPadding: 24,
            verticalPadding: 12,
            square: 54,
          ),
      };
}
