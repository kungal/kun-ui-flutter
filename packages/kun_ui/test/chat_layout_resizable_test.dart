import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

const Size desktop = Size(1000, 400);
const Key listKey = Key('list-pane');
const ValueKey<String> handleKey = ValueKey<String>('KunSplitPane.handle');

Widget wrap(
  Widget child, {
  Size size = desktop,
}) {
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
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

const List<KunChatUser> _users = <KunChatUser>[
  KunChatUser(id: 'me', name: 'Kun', avatar: ''),
  KunChatUser(id: 'her', name: 'Haru', avatar: ''),
];

KunChatMessage _msg(int seq) {
  return KunChatMessage(
    id: '$seq',
    conversationId: 'c1',
    seq: seq,
    senderId: 'her',
    createdAt: DateTime(2026, 9, 21, 10),
    text: 'hello $seq',
  );
}

void main() {
  testWidgets('the list drags between 280 and 480',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const KunChatLayout(
          resizable: true,
          showConversation: true,
          sidebar: SizedBox.expand(key: listKey, child: Text('list')),
          child: Text('conversation'),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(listKey)).width, 352);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(handleKey)),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(tester.getSize(find.byKey(listKey)).width, 480);
    await gesture.moveBy(const Offset(-400, 0));
    await tester.pump();
    expect(tester.getSize(find.byKey(listKey)).width, 280);
    await gesture.up();
  });

  testWidgets('narrowOf and the stacking agree at 767 and 768', (
    WidgetTester tester,
  ) async {
    bool? narrow;
    Widget layout() {
      return KunChatLayout(
        resizable: true,
        showConversation: true,
        sidebar: const Text('list'),
        child: Builder(
          builder: (BuildContext context) {
            narrow = KunChatLayout.narrowOf(context);
            return const Text('conversation');
          },
        ),
      );
    }

    await tester.pumpWidget(wrap(layout(), size: const Size(767, 400)));
    expect(narrow, isTrue);
    expect(find.text('list'), findsNothing);
    expect(find.text('conversation'), findsOneWidget);
    expect(find.byKey(handleKey), findsNothing);

    await tester.pumpWidget(wrap(layout(), size: const Size(768, 400)));
    expect(narrow, isFalse);
    expect(find.text('list'), findsOneWidget);
    expect(find.text('conversation'), findsOneWidget);
    expect(find.byKey(handleKey), findsOneWidget);
  });

  testWidgets('showConversation picks the stacked pane', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const KunChatLayout(
          resizable: true,
          sidebar: Text('list'),
          empty: Text('empty'),
          child: Text('conversation'),
        ),
        size: const Size(700, 400),
      ),
    );
    expect(find.text('list'), findsOneWidget);
    expect(find.text('conversation'), findsNothing);
    expect(find.text('empty'), findsNothing);

    await tester.pumpWidget(
      wrap(
        const KunChatLayout(
          resizable: true,
          showConversation: true,
          sidebar: Text('list'),
          empty: Text('empty'),
          child: Text('conversation'),
        ),
        size: const Size(700, 400),
      ),
    );
    expect(find.text('conversation'), findsOneWidget);
    expect(find.text('list'), findsNothing);
    expect(find.text('list', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the empty pane shows when the conversation is closed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const KunChatLayout(
          resizable: true,
          sidebar: Text('list'),
          empty: Text('empty'),
          child: Text('conversation'),
        ),
      ),
    );
    expect(find.text('list'), findsOneWidget);
    expect(find.text('empty'), findsOneWidget);
    expect(find.text('conversation'), findsNothing);
    expect(find.text('conversation', skipOffstage: false), findsOneWidget);
  });

  testWidgets(
    'a KunChatMessageList in the hidden pane gets TickerMode off',
    (WidgetTester tester) async {
      bool? tickers;
      await tester.pumpWidget(
        wrap(
          KunChatLayout(
            resizable: true,
            sidebar: const Text('list'),
            child: Builder(
              builder: (BuildContext context) {
                tickers = TickerMode.valuesOf(context).enabled;
                return KunChatMessageList(
                  messages: <KunChatMessage>[_msg(1)],
                  users: _users,
                  currentUserId: 'me',
                );
              },
            ),
          ),
          size: const Size(700, 400),
        ),
      );
      expect(find.text('list'), findsOneWidget);
      expect(tickers, isFalse);
    },
  );
}
