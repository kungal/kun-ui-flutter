import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child, {KunThemeData? theme}) => KunTheme(
      data: theme ?? KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 300, height: 200, child: child)),
      ),
    );

Finder get rules => find.byType(CustomPaint);

void main() {
  testWidgets('a bare divider is one rule across the width', (tester) async {
    await tester.pumpWidget(wrap(const KunDivider()));

    expect(rules, findsOneWidget);
    expect(tester.getRect(rules).width, 300);
    expect(tester.getRect(rules).height, 1);
  });

  testWidgets('a label puts a rule either side of it', (tester) async {
    await tester.pumpWidget(wrap(const KunDivider(child: Text('or'))));

    expect(rules, findsNWidgets(2));
    expect(find.text('or'), findsOneWidget);
    final Rect left = tester.getRect(rules.first);
    final Rect right = tester.getRect(rules.last);
    final Rect label = tester.getRect(find.text('or'));
    expect(left.right, lessThanOrEqualTo(label.left));
    expect(right.left, greaterThanOrEqualTo(label.right));
    // The web pads the label by px-4 on both sides.
    expect(label.left - left.right, KunSpacing.unit * 4);
    expect(right.left - label.right, KunSpacing.unit * 4);
  });

  testWidgets('a vertical divider runs down the height', (tester) async {
    await tester.pumpWidget(
      wrap(const KunDivider(orientation: KunDividerOrientation.vertical)),
    );

    expect(tester.getRect(rules).height, 200);
    expect(tester.getRect(rules).width, 1);
  });

  testWidgets('neutral takes the border token, a hue takes 20% of its solid',
      (tester) async {
    final KunThemeData theme = KunThemeData.light();
    await tester.pumpWidget(wrap(const KunDivider(), theme: theme));
    expect(
      find.byType(KunDivider),
      paints..line(color: theme.colors.border),
    );

    await tester.pumpWidget(
      wrap(const KunDivider(color: KunUIColor.primary), theme: theme),
    );
    expect(
      find.byType(KunDivider),
      paints..line(color: theme.colors.primary.solid.withValues(alpha: 0.2)),
    );
  });

  testWidgets('a dashed rule is drawn as many dashes, a solid one as one line',
      (tester) async {
    await tester.pumpWidget(wrap(const KunDivider()));
    expect(find.byType(KunDivider), paintsExactlyCountTimes(#drawLine, 1));

    await tester.pumpWidget(
      wrap(
        const KunDivider(borderStyle: KunDividerBorderStyle.dashed),
      ),
    );
    // Measured in Chrome: a dash of twice the line's thickness with the gap
    // stretched so a whole number of dashes fills the rule. 300px of 1px rule
    // is 100 dashes.
    expect(find.byType(KunDivider), paintsExactlyCountTimes(#drawLine, 100));
  });

  testWidgets('a divider is a container of its own to assistive technology',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const KunDivider(child: Text('or'))));

    expect(tester.getSemantics(find.text('or')).label, 'or');
    semantics.dispose();
  });
}
