import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Finder get panel => find.byKey(const ValueKey<String>('KunModal.panel'));
Finder get panelTransform =>
    find.byKey(const ValueKey<String>('KunModal.panelTransform'));

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

double transformY(WidgetTester tester) {
  return tester.widget<Transform>(panelTransform).transform.getTranslation().y;
}

Widget scopeLabel(String prefix) {
  return Builder(
    builder: (BuildContext context) {
      final KunModalScope? scope = KunModalScope.maybeOf(context);
      return Text(
        scope == null
            ? '$prefix:none'
            : '$prefix:${scope.size.name}/${scope.isSheet}',
      );
    },
  );
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        KunButton(
          onPressed: () => setState(() => _count++),
          child: Text('count:$_count'),
        ),
        scopeLabel('modal'),
      ],
    );
  }
}

class _Pages extends StatefulWidget {
  const _Pages();

  @override
  State<_Pages> createState() => _PagesState();
}

class _PagesState extends State<_Pages> {
  final List<Page<Object?>> pages = <Page<Object?>>[
    KunPage<void>(
      key: const ValueKey<String>('home'),
      child: Center(child: scopeLabel('home')),
    ),
  ];

  void push(Page<Object?> page) => setState(() => pages.add(page));

  void replaceTop(Page<Object?> page) =>
      setState(() => pages[pages.length - 1] = page);

  @override
  Widget build(BuildContext context) {
    return Navigator(
      pages: List<Page<Object?>>.of(pages),
      onDidRemovePage: (Page<Object?> page) {
        setState(() => pages.remove(page));
      },
    );
  }
}

Future<_PagesState> _pumpPages(WidgetTester tester) async {
  await tester.pumpWidget(
    KunTheme(
      data: KunThemeData.light(),
      child: WidgetsApp(
        color: KunColors.black,
        debugShowCheckedModeBanner: false,
        builder: (BuildContext context, Widget? child) => const _Pages(),
      ),
    ),
  );
  return tester.state<_PagesState>(find.byType(_Pages));
}

KunModalPage<void> tagPage({
  String title = 'Tag',
  bool canPop = true,
  bool? isDismissable,
  PopInvokedWithResultCallback<void>? onPopInvoked,
}) {
  return KunModalPage<void>(
    key: const ValueKey<String>('tag'),
    title: title,
    canPop: canPop,
    isDismissable: isDismissable,
    onPopInvoked: onPopInvoked ?? (bool didPop, void result) {},
    child: const _Counter(),
  );
}

void main() {
  testWidgets('the dialog is the route, over a page that stays painted',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    final _PagesState pages = await _pumpPages(tester);
    pages.push(tagPage());
    await tester.pumpAndSettle();

    expect(panel, findsOneWidget);
    expect(find.text('Tag'), findsOneWidget);
    expect(find.text('home:none'), findsOneWidget);
    expect(find.text('modal:md/false'), findsOneWidget);

    pages.replaceTop(tagPage(title: 'Tag 2'));
    await tester.pumpAndSettle();
    expect(find.text('Tag 2'), findsOneWidget);
  });

  testWidgets('a page pushed from the dialog covers it and pops back to it',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    final _PagesState pages = await _pumpPages(tester);
    pages.push(tagPage());
    await tester.pumpAndSettle();
    await tester.tap(find.text('count:0'));
    await tester.pump();
    expect(find.text('count:1'), findsOneWidget);

    pages.push(
      const KunPage<void>(
        key: ValueKey<String>('work'),
        child: Center(child: Text('work')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('work'), findsOneWidget);
    expect(panel, findsNothing);
    expect(find.text('home:none'), findsNothing);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('work'), findsNothing);
    expect(panel, findsOneWidget);
    expect(find.text('count:1'), findsOneWidget);
    expect(pages.pages, hasLength(2));
  });

  testWidgets('backdrop, Escape, close and back each pop the route',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    final _PagesState pages = await _pumpPages(tester);
    final NavigatorState navigator =
        tester.state<NavigatorState>(find.byType(Navigator));

    Future<void> expectPopped(Future<void> Function() close) async {
      pages.push(tagPage());
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      await close();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(pages.pages, hasLength(1));
      expect(find.text('home:none'), findsOneWidget);
    }

    await expectPopped(() => tester.tapAt(const Offset(5, 5)));
    await expectPopped(
      () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
    );
    await expectPopped(
      () => tester.tap(find.byIcon(KunIcons.x)),
    );
    await expectPopped(() async {
      expect(await navigator.maybePop(), isTrue);
    });
  });

  testWidgets('canPop false refuses every dismissal and reports each',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    final _PagesState pages = await _pumpPages(tester);
    final List<bool> invoked = <bool>[];
    pages.push(
      tagPage(
        canPop: false,
        onPopInvoked: (bool didPop, void result) => invoked.add(didPop),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();

    expect(panel, findsOneWidget);
    expect(pages.pages, hasLength(2));
    expect(invoked, <bool>[false, false, false, false]);
  });

  testWidgets('isDismissable false keeps the backdrop and Escape out',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    final _PagesState pages = await _pumpPages(tester);
    pages.push(tagPage(isDismissable: false));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);

    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(pages.pages, hasLength(1));
  });

  testWidgets('the phone sheet swipes the route away, or springs back',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    try {
      setView(tester, const Size(400, 800));
      final _PagesState pages = await _pumpPages(tester);
      pages.push(tagPage());
      await tester.pumpAndSettle();
      expect(find.text('modal:md/true'), findsOneWidget);

      await tester.drag(panel, Offset(0, tester.getSize(panel).height * 0.5));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(pages.pages, hasLength(1));

      pages.push(tagPage(canPop: false));
      await tester.pumpAndSettle();
      await tester.drag(panel, Offset(0, tester.getSize(panel).height * 0.5));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(transformY(tester), closeTo(0, 1));
      expect(pages.pages, hasLength(2));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a declarative KunModal gives its content the scope too',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    await tester.pumpWidget(
      KunTheme(
        data: KunThemeData.light(),
        child: WidgetsApp(
          color: KunColors.black,
          debugShowCheckedModeBanner: false,
          pageRouteBuilder:
              <T>(RouteSettings settings, WidgetBuilder builder) =>
                  KunPageRoute<T>(settings: settings, builder: builder),
          home: KunModal(
            value: true,
            title: 'Rating',
            size: KunModalSize.lg,
            child: scopeLabel('modal'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('modal:lg/false'), findsOneWidget);
  });
}
