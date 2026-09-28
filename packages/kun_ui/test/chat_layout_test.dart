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
          child: SizedBox(width: size.width, height: 400, child: child),
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
          child: SizedBox(width: size.width, height: 400, child: child),
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
