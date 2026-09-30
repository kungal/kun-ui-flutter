import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

const Size phone = Size(390, 844);
const Size desktop = Size(1000, 700);

Widget wrap(Widget child, {Size size = phone}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: KunMessagesScope(
      messages: KunMessages.en,
      child: KunTheme(
        data: KunThemeData.light(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: size.width, height: 400, child: child),
          ),
        ),
      ),
    ),
  );
}

Widget popWrap(Widget child, {Size size = phone}) {
  return WidgetsApp(
    color: KunColors.black,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: KunMessagesScope(
        messages: KunMessages.en,
        child: KunTheme(
          data: KunThemeData.light(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: size.width, height: 400, child: child),
          ),
        ),
      ),
    ),
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
  );
}

class _Alive extends StatefulWidget {
  const _Alive({required this.label});

  final String label;

  @override
  State<_Alive> createState() => _AliveState();
}

class _AliveState extends State<_Alive> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      excludeFromSemantics: true,
      onTap: () => setState(() => count += 1),
      child: Text('${widget.label}:$count'),
    );
  }
}

List<String> unnamedActionable(SemanticsNode root) {
  final List<String> found = <String>[];
  void walk(SemanticsNode node) {
    final SemanticsData data = node.getSemanticsData();
    final bool actionable = data.hasAction(SemanticsAction.tap) ||
        data.hasAction(SemanticsAction.longPress) ||
        data.hasAction(SemanticsAction.customAction);
    if (actionable && data.label.isEmpty) {
      found.add(
        'id=${node.id} tap=${data.hasAction(SemanticsAction.tap)} '
        'label="${data.label}" rect=${node.rect}',
      );
    }
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
  }

  walk(root);
  return found;
}

void main() {
  Widget sized(Size window, double layoutWidth, Widget child) => MediaQuery(
        data: MediaQueryData(size: window),
        child: KunMessagesScope(
          messages: KunMessages.en,
          child: KunTheme(
            data: KunThemeData.light(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: layoutWidth, height: 400, child: child),
              ),
            ),
          ),
        ),
      );

  testWidgets('the layout measures its own width, not the window', (
    WidgetTester tester,
  ) async {
    bool? narrow;
    final Widget layout = KunChatLayout(
      showConversation: true,
      sidebar: const Text('sidebar'),
      child: Builder(
        builder: (BuildContext context) {
          narrow = KunChatLayout.narrowOf(context);
          return const Text('conversation');
        },
      ),
    );

    // A 1000 window whose content area beside a side rail is 700 wide.
    await tester.pumpWidget(sized(desktop, 700, layout));
    expect(narrow, isTrue);
    expect(find.text('sidebar'), findsNothing);
    expect(find.text('conversation'), findsOneWidget);

    await tester.pumpWidget(sized(phone, 780, layout));
    expect(narrow, isFalse);
    expect(find.text('sidebar'), findsOneWidget);

    await tester.pumpWidget(
      sized(
        desktop,
        700,
        Builder(
          builder: (BuildContext context) {
            narrow = KunChatLayout.narrowOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(narrow, isNull);
  });

  testWidgets("the header's mobile back follows the layout", (
    WidgetTester tester,
  ) async {
    const KunChatUser haru = KunChatUser(
      id: '1002',
      name: 'Haru',
      avatar: 'https://example.test/haru.webp',
    );
    Widget chat(Size window, double width) => sized(
          window,
          width,
          const KunChatLayout(
            showConversation: true,
            sidebar: Text('sidebar'),
            child: KunChatHeader(user: haru),
          ),
        );

    await tester.pumpWidget(chat(desktop, 700));
    expect(find.byIcon(KunIcons.arrowLeft), findsOneWidget);

    await tester.pumpWidget(chat(phone, 780));
    expect(find.byIcon(KunIcons.arrowLeft), findsNothing);

    await tester.pumpWidget(
      sized(desktop, 700, const KunChatHeader(user: haru)),
    );
    expect(find.byIcon(KunIcons.arrowLeft), findsNothing);
  });

  testWidgets('wide shows the sidebar and empty when closed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const KunChatLayout(
          sidebar: Text('sidebar'),
          empty: Text('empty'),
          child: Text('conversation'),
        ),
        size: desktop,
      ),
    );
    expect(find.text('sidebar'), findsOneWidget);
    expect(find.text('empty'), findsOneWidget);
    expect(find.text('conversation'), findsNothing);
    expect(find.text('conversation', skipOffstage: false), findsOneWidget);
  });

  testWidgets('wide shows the sidebar and child when open', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const KunChatLayout(
          showConversation: true,
          sidebar: Text('sidebar'),
          empty: Text('empty'),
          child: Text('conversation'),
        ),
        size: desktop,
      ),
    );
    expect(find.text('sidebar'), findsOneWidget);
    expect(find.text('conversation'), findsOneWidget);
    expect(find.text('empty'), findsNothing);
  });

  testWidgets('narrow shows one pane at a time', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const KunChatLayout(
          sidebar: Text('sidebar'),
          empty: Text('empty'),
          child: Text('conversation'),
        ),
      ),
    );
    expect(find.text('sidebar'), findsOneWidget);
    expect(find.text('conversation'), findsNothing);
    expect(find.text('empty'), findsNothing);

    await tester.pumpWidget(
      wrap(
        const KunChatLayout(
          showConversation: true,
          sidebar: Text('sidebar'),
          empty: Text('empty'),
          child: Text('conversation'),
        ),
      ),
    );
    expect(find.text('conversation'), findsOneWidget);
    expect(find.text('sidebar'), findsNothing);
    expect(find.text('sidebar', skipOffstage: false), findsOneWidget);
  });

  testWidgets('narrow panes keep their state', (WidgetTester tester) async {
    Future<void> pump({required bool open}) {
      return tester.pumpWidget(
        wrap(
          KunChatLayout(
            showConversation: open,
            sidebar: const _Alive(label: 'list'),
            child: const _Alive(label: 'chat'),
          ),
        ),
      );
    }

    await pump(open: false);
    await tester.tap(find.text('list:0'));
    await tester.pump();
    expect(find.text('list:1'), findsOneWidget);

    await pump(open: true);
    expect(find.text('list:1'), findsNothing);
    expect(find.text('list:1', skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('chat:0'));
    await tester.pump();
    expect(find.text('chat:1'), findsOneWidget);

    await pump(open: false);
    expect(find.text('list:1'), findsOneWidget);
    expect(find.text('chat:1', skipOffstage: false), findsOneWidget);
  });

  testWidgets('sidebarWidth is the wide list pane', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const KunChatLayout(
          sidebarWidth: 200,
          sidebar: ColoredBox(color: Color(0xFF000000), child: Text('sidebar')),
          empty: Text('empty'),
        ),
        size: desktop,
      ),
    );
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('sidebar'),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
      200,
    );
  });

  testWidgets('crossing md with onBack trips no semantics assertion', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    for (final bool resizable in <bool>[false, true]) {
      final GlobalKey listKey = GlobalKey();
      final GlobalKey chatKey = GlobalKey();
      Future<void> pump(Size size) => tester.pumpWidget(
            popWrap(
              KunChatLayout(
                resizable: resizable,
                showConversation: true,
                onBack: () {},
                sidebar: KeyedSubtree(
                  key: listKey,
                  child: ListView(
                    children: const <Widget>[_Alive(label: 'list')],
                  ),
                ),
                child: KeyedSubtree(
                  key: chatKey,
                  child: const Column(
                    children: <Widget>[
                      _Alive(label: 'chat'),
                      KunInput(value: '', autofocus: true),
                    ],
                  ),
                ),
              ),
              size: size,
            ),
          );

      await pump(desktop);
      await pump(phone);
      await tester.pumpAndSettle();
      await pump(desktop);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'resizable $resizable');
      await tester.pumpWidget(const SizedBox());
    }
    handle.dispose();
  });

  testWidgets('a resizable layout keeps unkeyed panes across md', (
    WidgetTester tester,
  ) async {
    Future<void> pump(Size size) => tester.pumpWidget(
          popWrap(
            KunChatLayout(
              resizable: true,
              showConversation: true,
              onBack: () {},
              sidebar: const _Alive(label: 'list'),
              child: const _Alive(label: 'chat'),
            ),
            size: size,
          ),
        );

    await pump(desktop);
    await tester.tap(find.text('list:0'));
    await tester.tap(find.text('chat:0'));
    await tester.pump();
    await pump(phone);
    await tester.pumpAndSettle();
    await pump(desktop);
    await tester.pumpAndSettle();
    expect(find.text('list:1'), findsOneWidget);
    expect(find.text('chat:1'), findsOneWidget);
  });

  testWidgets('onBack fires only when narrow and showing the conversation', (
    WidgetTester tester,
  ) async {
    final List<String> log = <String>[];

    Future<void> pump({
      required Size size,
      required bool open,
      VoidCallback? onBack,
    }) {
      return tester.pumpWidget(
        popWrap(
          KunChatLayout(
            showConversation: open,
            onBack: onBack,
            sidebar: const Text('sidebar'),
            empty: const Text('empty'),
            child: const Text('conversation'),
          ),
          size: size,
        ),
      );
    }

    await pump(size: phone, open: true, onBack: () => log.add('back'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(log, <String>['back']);
    expect(find.text('conversation'), findsOneWidget);

    log.clear();
    await pump(size: desktop, open: true, onBack: () => log.add('back'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(log, isEmpty);

    await pump(size: phone, open: false, onBack: () => log.add('back'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(log, isEmpty);

    await pump(size: phone, open: true);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(log, isEmpty);
  });

  testWidgets('a real slotted child opens and has no unnamed actionable node', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        KunChatLayout(
          sidebar: KunButton(
            onPressed: () => taps += 1,
            child: const Text('Open Haru'),
          ),
          empty: const Text('empty'),
          child: const Text('conversation'),
        ),
        size: desktop,
      ),
    );
    await tester.tap(find.text('Open Haru'));
    await tester.pump();
    expect(taps, 1);
    expect(
      unnamedActionable(tester.getSemantics(find.byType(KunChatLayout))),
      isEmpty,
    );
    handle.dispose();
  });
}
