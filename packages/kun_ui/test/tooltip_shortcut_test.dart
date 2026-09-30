import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/components/kbd.dart' show kunSpeakShortcut;

Finder get panel => find.byKey(const ValueKey<String>('KunTooltip.panel'));

Widget wrap(Widget child) {
  return KunTheme(
    data: KunThemeData.light(),
    child: KunMessagesScope(
      messages: KunMessages.en,
      child: WidgetsApp(
        color: KunColors.black,
        debugShowCheckedModeBanner: false,
        home: Align(child: child),
        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
          return PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return builder(context);
            },
          );
        },
      ),
    ),
  );
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> hover(WidgetTester tester, Finder target) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
}

void main() {
  testWidgets('a shortcut draws keycaps after the text', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        const KunTooltip(
          text: 'Search',
          shortcut: 'Mod+K',
          hideOnMobile: false,
          child: Text('trigger'),
        ),
      ),
    );

    await hover(tester, find.text('trigger'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.byType(KunKbd), findsOneWidget);
  });

  testWidgets('the trigger description is the text then the spoken shortcut',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        KunTooltip(
          text: 'Search',
          shortcut: 'Mod+K',
          hideOnMobile: false,
          child: KunButton(onPressed: () {}, child: const Text('trigger')),
        ),
      ),
    );

    final String spoken = kunSpeakShortcut('Mod+K', KunMessages.en);
    expect(
      tester.getSemantics(find.byType(KunButton)).tooltip,
      'Search $spoken',
    );
    semantics.dispose();
  });
}
