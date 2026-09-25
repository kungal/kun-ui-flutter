import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

class _PageDelegate extends RouterDelegate<Object> with ChangeNotifier {
  @override
  Future<void> setNewRoutePath(Object configuration) async {}

  @override
  Future<bool> popRoute() async => false;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      pages: const <Page<void>>[
        KunPage<void>(name: '/', child: Text('router page')),
      ],
      onDidRemovePage: (Page<Object?> page) {},
    );
  }
}

void main() {
  testWidgets('KunApp.router with a RouterConfig shows its page',
      (WidgetTester tester) async {
    final _PageDelegate delegate = _PageDelegate();
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      KunApp.router(
        routerConfig: RouterConfig<Object>(routerDelegate: delegate),
      ),
    );
    expect(find.text('router page'), findsOneWidget);
  });

  testWidgets('KunApp(home:) pushes KunPageRoutes for named routes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      KunApp(
        home: Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () => Navigator.of(context).pushNamed('/next'),
              child: const Text('home'),
            );
          },
        ),
        routes: <String, WidgetBuilder>{
          '/next': (BuildContext context) => const Text('next'),
        },
      ),
    );
    expect(find.text('home'), findsOneWidget);
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.text('next'))),
      isA<KunPageRoute<dynamic>>(),
    );
  });

  testWidgets('themeMode system follows platform brightness',
      (WidgetTester tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    late Brightness seen;
    await tester.pumpWidget(
      KunApp(
        home: Builder(
          builder: (BuildContext context) {
            seen = KunTheme.of(context).brightness;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, Brightness.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();
    expect(seen, Brightness.light);
  });

  testWidgets('themeMode light and dark override the platform',
      (WidgetTester tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    late Brightness seen;
    await tester.pumpWidget(
      KunApp(
        themeMode: KunThemeMode.light,
        home: Builder(
          builder: (BuildContext context) {
            seen = KunTheme.of(context).brightness;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, Brightness.light);

    await tester.pumpWidget(
      KunApp(
        themeMode: KunThemeMode.dark,
        home: Builder(
          builder: (BuildContext context) {
            seen = KunTheme.of(context).brightness;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, Brightness.dark);
  });

  testWidgets('messages: KunMessages.en reaches a descendant',
      (WidgetTester tester) async {
    late KunMessages seen;
    await tester.pumpWidget(
      KunApp(
        messages: KunMessages.en,
        home: Builder(
          builder: (BuildContext context) {
            seen = KunMessagesScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(identical(seen, KunMessages.en), isTrue);
  });

  testWidgets('ScrollConfiguration is a KunScrollBehavior',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KunApp(home: SizedBox()));
    final ScrollConfiguration config = tester.widget<ScrollConfiguration>(
      find.byType(ScrollConfiguration).first,
    );
    expect(config.behavior, isA<KunScrollBehavior>());
  });

  testWidgets('DefaultTextStyle is KunText.base in foreground',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KunApp(home: Text('hi')));
    DefaultTextStyle? match;
    for (final Element element in tester.elementList(
      find.byType(DefaultTextStyle),
    )) {
      final DefaultTextStyle style = element.widget as DefaultTextStyle;
      if (style.style.fontSize == KunText.base.fontSize) {
        match = style;
        break;
      }
    }
    expect(match, isNotNull);
    expect(match!.style.fontSize, KunText.base.fontSize);
    expect(match.style.color, KunThemeData.light().colors.foreground);
  });

  testWidgets(
    'a KunInput inside can be tapped and its selection menu finds the theme',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const KunApp(
          home: Center(
            child: SizedBox(width: 300, child: KunInput(value: 'hello world')),
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .controller
            .selection
            .isValid,
        isTrue,
      );

      await tester.longPress(find.byType(EditableText));
      await tester.pump();
      await tester.pump(KunDurations.base);
      expect(find.text('复制'), findsOneWidget);
      expect(find.byType(KunTheme), findsWidgets);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
