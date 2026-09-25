import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  Size size = const Size(800, 600),
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      padding: padding,
      viewPadding: padding,
      viewInsets: viewInsets,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: KunTheme(
        data: KunThemeData.light(),
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('background defaults to the theme background',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(const KunScaffold(body: SizedBox.expand())),
    );
    final ColoredBox box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(KunScaffold),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(box.color, KunThemeData.light().colors.background);
  });

  testWidgets('backgroundColor overrides the theme',
      (WidgetTester tester) async {
    final Color override = KunThemeData.light().colors.content1;
    await tester.pumpWidget(
      wrap(
        KunScaffold(
          backgroundColor: override,
          body: const SizedBox.expand(),
        ),
      ),
    );
    final ColoredBox box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(KunScaffold),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(box.color, override);
  });

  testWidgets(
    'with a 56-px bar and extendBody false the body ends at the bar',
    (WidgetTester tester) async {
      late double bodyPaddingBottom;
      late double barPaddingBottom;
      const Key bodyKey = Key('body');
      const Key barKey = Key('bar');
      await tester.pumpWidget(
        wrap(
          padding: const EdgeInsets.only(bottom: 34),
          KunScaffold(
            extendBody: false,
            bottomBar: Builder(
              builder: (BuildContext context) {
                barPaddingBottom = MediaQuery.paddingOf(context).bottom;
                return const SizedBox(key: barKey, height: 56);
              },
            ),
            body: Builder(
              builder: (BuildContext context) {
                bodyPaddingBottom = MediaQuery.paddingOf(context).bottom;
                return const SizedBox.expand(key: bodyKey);
              },
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(bodyKey)).height, 600 - 56);
      expect(
        tester.getBottomLeft(find.byKey(bodyKey)).dy,
        tester.getTopLeft(find.byKey(barKey)).dy,
      );
      expect(bodyPaddingBottom, 0);
      expect(barPaddingBottom, 34);
    },
  );

  testWidgets(
    'with extendBody true the body fills the screen and pads for the bar',
    (WidgetTester tester) async {
      late double bodyPaddingBottom;
      const Key bodyKey = Key('body');
      await tester.pumpWidget(
        wrap(
          padding: const EdgeInsets.only(bottom: 34),
          KunScaffold(
            extendBody: true,
            bottomBar: const SizedBox(height: 56),
            body: Builder(
              builder: (BuildContext context) {
                bodyPaddingBottom = MediaQuery.paddingOf(context).bottom;
                return const SizedBox.expand(key: bodyKey);
              },
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(bodyKey)).height, 600);
      expect(bodyPaddingBottom, 56);
    },
  );

  testWidgets(
    'resizeToAvoidBottomInset true shrinks the body and removes the inset',
    (WidgetTester tester) async {
      late double bodyViewInsets;
      const Key bodyKey = Key('body');
      await tester.pumpWidget(
        wrap(
          viewInsets: const EdgeInsets.only(bottom: 300),
          KunScaffold(
            resizeToAvoidBottomInset: true,
            body: Builder(
              builder: (BuildContext context) {
                bodyViewInsets = MediaQuery.viewInsetsOf(context).bottom;
                return const SizedBox.expand(key: bodyKey);
              },
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(bodyKey)).height, 300);
      expect(bodyViewInsets, 0);
    },
  );

  testWidgets(
    'resizeToAvoidBottomInset false keeps the body height and the inset',
    (WidgetTester tester) async {
      late double bodyViewInsets;
      const Key bodyKey = Key('body');
      await tester.pumpWidget(
        wrap(
          viewInsets: const EdgeInsets.only(bottom: 300),
          KunScaffold(
            resizeToAvoidBottomInset: false,
            body: Builder(
              builder: (BuildContext context) {
                bodyViewInsets = MediaQuery.viewInsetsOf(context).bottom;
                return const SizedBox.expand(key: bodyKey);
              },
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(bodyKey)).height, 600);
      expect(bodyViewInsets, 300);
    },
  );

  testWidgets('the bar loses only its top padding, as Scaffold\'s does',
      (WidgetTester tester) async {
    late EdgeInsets barPadding;
    late double barViewInsets;
    await tester.pumpWidget(
      wrap(
        padding: const EdgeInsets.only(top: 24, bottom: 34),
        viewInsets: const EdgeInsets.only(bottom: 300),
        KunScaffold(
          bottomBar: Builder(
            builder: (BuildContext context) {
              barPadding = MediaQuery.paddingOf(context);
              barViewInsets = MediaQuery.viewInsetsOf(context).bottom;
              return const SafeArea(child: SizedBox(height: 56));
            },
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );
    expect(barPadding.top, 0);
    expect(barPadding.bottom, 34);
    expect(barViewInsets, 300);
    expect(tester.getSize(find.byType(SafeArea)).height, 56 + 34);
  });

  testWidgets(
      'without resizing, the bar keeps the view padding under a keyboard',
      (WidgetTester tester) async {
    late double barPaddingBottom;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 600),
          viewPadding: EdgeInsets.only(bottom: 34),
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: KunTheme(
            data: KunThemeData.light(),
            child: KunScaffold(
              resizeToAvoidBottomInset: false,
              bottomBar: Builder(
                builder: (BuildContext context) {
                  barPaddingBottom = MediaQuery.paddingOf(context).bottom;
                  return const SizedBox(height: 56);
                },
              ),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    expect(barPaddingBottom, 34);
  });

  testWidgets('lays out a real KunButton body and KunNavItem bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        KunScaffold(
          bottomBar: KunNavItem(
            label: 'Home',
            icon: const Icon(KunIcons.search),
            stacked: true,
            current: true,
            onPressed: () {},
          ),
          body: KunButton(
            onPressed: () {},
            child: const Text('Go'),
          ),
        ),
      ),
    );
    expect(find.text('Go'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.text('Go'));
    await tester.pump();
  });
}
