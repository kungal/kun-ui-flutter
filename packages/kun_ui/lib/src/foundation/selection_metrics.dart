import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import 'design.dart';

/// The size of every selection control — a checkbox, a radio and the options
/// inside their groups — so a checkbox and a radio of one [KunUISize] draw
/// identically.
///
/// Translated value-for-value from `kunSelectionSizeClasses` in
/// `@kungal/ui-core` (packages/ui-core/src/controlSize.ts in kungal/kun-ui),
/// which is the source of truth: a change starts there and is mirrored here.
/// Each length is [KunSpacing.unit] times the class's own step (`size-3.5` is
/// `KunSpacing.unit * 3.5`) and each text style is the class's [KunText] step.
class KunSelectionMetrics {
  const KunSelectionMetrics._({
    required this.box,
    required this.dot,
    required this.check,
    required this.textStyle,
    required this.gap,
    required this.dash,
  });

  /// The checkbox box and the radio circle, web `size-*`.
  final double box;

  /// The radio's filled centre, web `dot`.
  final double dot;

  /// The check glyph inside a checked box, web `check`.
  final double check;

  /// The label's [KunText] step.
  final TextStyle textStyle;

  /// The gap between the control and its label.
  final double gap;

  /// The indeterminate dash's width. The web keeps this on `KunCheckBox`
  /// rather than in the shared table; it is here because it scales with the
  /// box and nothing else uses it.
  final double dash;

  /// The metrics for [size].
  static KunSelectionMetrics of(KunUISize size) => switch (size) {
        KunUISize.xs => const KunSelectionMetrics._(
            box: KunSpacing.unit * 3,
            dot: KunSpacing.unit * 1.5,
            check: KunSpacing.unit * 2,
            textStyle: KunText.xs,
            gap: KunSpacing.unit * 1.5,
            dash: KunSpacing.unit * 2,
          ),
        KunUISize.sm => const KunSelectionMetrics._(
            box: KunSpacing.unit * 3.5,
            dot: KunSpacing.unit * 1.5,
            check: KunSpacing.unit * 2.5,
            textStyle: KunText.sm,
            gap: KunSpacing.unit * 2,
            dash: KunSpacing.unit * 2.5,
          ),
        KunUISize.md => const KunSelectionMetrics._(
            box: KunSpacing.unit * 4,
            dot: KunSpacing.unit * 2,
            check: KunSpacing.unit * 3,
            textStyle: KunText.sm,
            gap: KunSpacing.unit * 2,
            dash: KunSpacing.unit * 2.5,
          ),
        KunUISize.lg => const KunSelectionMetrics._(
            box: KunSpacing.unit * 5,
            dot: KunSpacing.unit * 2.5,
            check: KunSpacing.unit * 3.5,
            textStyle: KunText.base,
            gap: KunSpacing.unit * 2.5,
            dash: KunSpacing.unit * 3,
          ),
        KunUISize.xl => const KunSelectionMetrics._(
            box: KunSpacing.unit * 6,
            dot: KunSpacing.unit * 3,
            check: KunSpacing.unit * 4,
            textStyle: KunText.lg,
            gap: KunSpacing.unit * 3,
            dash: KunSpacing.unit * 3.5,
          ),
      };
}
