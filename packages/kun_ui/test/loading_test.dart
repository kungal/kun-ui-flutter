import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child, {KunMessages? messages}) {
  Widget tree = Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: SizedBox(width: 400, child: child)),
  );
  if (messages != null) {
    tree = KunMessagesScope(messages: messages, child: tree);
  }
  return KunTheme(data: KunThemeData.light(), child: tree);
}

Finder get mascot => find.byType(Image);

void main() {
  testWidgets('standalone it draws the bundled mascot and the locale line',
      (tester) async {
    await tester.pumpWidget(wrap(const KunLoading()));

    expect(
      tester.widget<Image>(mascot).image,
      KunImages.loadingImage,
    );
    expect(find.text(KunMessages.zhCN.loading.description), findsOneWidget);
  });

  testWidgets('the locale supplies the line, and description overrides it',
      (tester) async {
    await tester.pumpWidget(wrap(const KunLoading(), messages: KunMessages.en));
    expect(find.text(KunMessages.en.loading.description), findsOneWidget);

    await tester.pumpWidget(
      wrap(const KunLoading(description: 'Fetching posts')),
    );
    expect(find.text('Fetching posts'), findsOneWidget);
  });

  testWidgets('spinner mode draws a ring at the size scale, no mascot',
      (tester) async {
    const Map<KunUISize, double> rings = <KunUISize, double>{
      KunUISize.xs: KunSpacing.unit * 4,
      KunUISize.sm: KunSpacing.unit * 6,
      KunUISize.md: KunSpacing.unit * 8,
      KunUISize.lg: KunSpacing.unit * 10,
      KunUISize.xl: KunSpacing.unit * 12,
    };
    for (final MapEntry<KunUISize, double> entry in rings.entries) {
      await tester.pumpWidget(
        wrap(KunLoading(spinner: true, size: entry.key)),
      );
      await tester.pump();
      expect(mascot, findsNothing, reason: entry.key.name);
      expect(
        tester.widget<KunSpinner>(find.byType(KunSpinner)).size,
        entry.value,
        reason: entry.key.name,
      );
    }
  });

  testWidgets('a child is dimmed and veiled only while loading',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunLoading(
          child: SizedBox(height: 200, child: Text('content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double contentOpacity() => tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
        .opacity;
    double veilOpacity() => tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).last)
        .opacity;

    expect(find.text('content'), findsOneWidget);
    expect(contentOpacity(), 1);
    expect(veilOpacity(), 0);

    await tester.pumpWidget(
      wrap(
        const KunLoading(
          loading: true,
          child: SizedBox(height: 200, child: Text('content')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(contentOpacity(), 0.5);
    expect(veilOpacity(), 1);
    // The content is still there, so the page does not jump.
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('a veiled block is at least the web min-h-24', (tester) async {
    await tester.pumpWidget(
      wrap(const KunLoading(child: SizedBox(height: 8))),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byType(KunLoading)).height,
      KunSpacing.unit * 24,
    );
  });

  testWidgets('it announces itself as a live status naming what it says',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const KunLoading(spinner: true, description: 'Fetching posts')),
    );
    await tester.pump();

    final SemanticsData data =
        tester.getSemantics(find.text('Fetching posts')).getSemanticsData();
    // The status role is the live region: Flutter asserts a node cannot be
    // both, because its status role already announces politely.
    expect(data.role, SemanticsRole.status);
    expect(data.label, 'Fetching posts');
    semantics.dispose();
  });
}
