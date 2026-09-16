import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

void main() {
  testWidgets('KunTheme.of throws without an ancestor', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    );
    expect(KunTheme.maybeOf(captured), isNull);
    expect(() => KunTheme.of(captured), throwsFlutterError);
  });

  testWidgets('KunTheme.of returns the provided data', (tester) async {
    final data = KunThemeData.dark(rounded: KunUIRounded.full);
    late KunThemeData resolved;
    await tester.pumpWidget(
      KunTheme(
        data: data,
        child: Builder(
          builder: (context) {
            resolved = KunTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved, data);
    expect(resolved.colors, same(KunColors.dark));
    expect(resolved.rounded, KunUIRounded.full);
  });

  testWidgets('KunTheme sets the ambient icon and text color', (tester) async {
    late Color? iconColor;
    await tester.pumpWidget(
      KunTheme(
        data: KunThemeData.light(),
        child: Builder(
          builder: (context) {
            iconColor = IconTheme.of(context).color;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(iconColor, KunColors.light.foreground);
  });

  testWidgets('KunTheme sets even leading distribution', (tester) async {
    await tester.pumpWidget(
      KunTheme(
        data: KunThemeData.light(),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('hello'),
        ),
      ),
    );
    expect(
      (tester.widget<RichText>(find.byType(RichText)).text as TextSpan)
          .style!
          .leadingDistribution,
      TextLeadingDistribution.even,
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text('hello'),
      ),
    );
    expect(
      (tester.widget<RichText>(find.byType(RichText)).text as TextSpan)
          .style!
          .leadingDistribution,
      isNot(TextLeadingDistribution.even),
    );
  });

  test('breakpoints resolve mobile-first at the web widths', () {
    const breakpoints = KunBreakpoints();
    expect(breakpoints.resolve(320), KunBreakpoint.base);
    expect(breakpoints.resolve(640), KunBreakpoint.sm);
    expect(breakpoints.resolve(767), KunBreakpoint.sm);
    expect(breakpoints.resolve(768), KunBreakpoint.md);
    expect(breakpoints.resolve(1024), KunBreakpoint.lg);
    expect(breakpoints.resolve(1280), KunBreakpoint.xl);
    expect(breakpoints.resolve(1536), KunBreakpoint.xxl);
  });
}
