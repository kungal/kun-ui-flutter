import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

void main() {
  test('KunControlMetrics.of pins the web control size table', () {
    const expected = <KunUISize, (double, double, double, double, double)>{
      KunUISize.xs: (12, 16, 10, 4, 26),
      KunUISize.sm: (14, 20, 14, 6, 34),
      KunUISize.md: (14, 20, 16, 8, 38),
      KunUISize.lg: (16, 24, 20, 10, 46),
      KunUISize.xl: (18, 28, 24, 12, 54),
    };
    const steps = <KunUISize, TextStyle>{
      KunUISize.xs: KunText.xs,
      KunUISize.sm: KunText.sm,
      KunUISize.md: KunText.sm,
      KunUISize.lg: KunText.base,
      KunUISize.xl: KunText.lg,
    };
    for (final entry in expected.entries) {
      final metrics = KunControlMetrics.of(entry.key);
      expect(metrics.fontSize, entry.value.$1, reason: entry.key.name);
      expect(metrics.lineHeight, entry.value.$2, reason: entry.key.name);
      expect(metrics.horizontalPadding, entry.value.$3, reason: entry.key.name);
      expect(metrics.verticalPadding, entry.value.$4, reason: entry.key.name);
      expect(metrics.square, entry.value.$5, reason: entry.key.name);
      expect(
        metrics.textStyle.leadingDistribution,
        TextLeadingDistribution.even,
        reason: entry.key.name,
      );
      expect(metrics.textStyle, steps[entry.key], reason: entry.key.name);
    }
  });

  test('KunChipMetrics.of pins the web chip size table', () {
    const expected = <KunUISize, (double, double, double, double)>{
      KunUISize.xs: (12, 16, 8, 2),
      KunUISize.sm: (12, 16, 8, 4),
      KunUISize.md: (14, 20, 12, 4),
      KunUISize.lg: (14, 20, 16, 6),
      KunUISize.xl: (16, 24, 24, 8),
    };
    const steps = <KunUISize, TextStyle>{
      KunUISize.xs: KunText.xs,
      KunUISize.sm: KunText.xs,
      KunUISize.md: KunText.sm,
      KunUISize.lg: KunText.sm,
      KunUISize.xl: KunText.base,
    };
    for (final entry in expected.entries) {
      final metrics = KunChipMetrics.of(entry.key);
      expect(metrics.fontSize, entry.value.$1, reason: entry.key.name);
      expect(metrics.lineHeight, entry.value.$2, reason: entry.key.name);
      expect(metrics.horizontalPadding, entry.value.$3, reason: entry.key.name);
      expect(metrics.verticalPadding, entry.value.$4, reason: entry.key.name);
      expect(
        metrics.textStyle.leadingDistribution,
        TextLeadingDistribution.even,
        reason: entry.key.name,
      );
      expect(metrics.textStyle, steps[entry.key], reason: entry.key.name);
    }
  });

  test('KunCardPadding values pin the web padding table', () {
    expect(KunCardPadding.none.value, 0);
    expect(KunCardPadding.sm.value, 12);
    expect(KunCardPadding.md.value, 20);
    expect(KunCardPadding.lg.value, 24);
  });
}
