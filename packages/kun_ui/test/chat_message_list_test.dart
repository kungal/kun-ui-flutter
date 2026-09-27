import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

final MemoryImage _memory = MemoryImage(
  Uint8List.fromList(<int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]),
);

const List<KunChatUser> _users = <KunChatUser>[
  KunChatUser(id: 'me', name: 'Kun', avatar: ''),
  KunChatUser(id: 'her', name: 'Haru', avatar: ''),
  KunChatUser(id: 'other', name: 'Ayase', avatar: ''),
];

const List<KunChatReactionOption> _reactions = <KunChatReactionOption>[
  KunChatReactionOption(key: 'heart', emoji: '❤️', label: 'Love'),
  KunChatReactionOption(key: 'fire', emoji: '🔥', label: 'Fire'),
];

final DateTime _day0 = DateTime(2026, 9, 20, 10);
final DateTime _day1 = DateTime(2026, 9, 21, 10);
final DateTime _day2 = DateTime(2026, 9, 22, 10);

KunChatMessage msg({
  required String id,
  required int seq,
  String senderId = 'her',
  String text = 'hello',
  DateTime? at,
  String conversationId = 'c1',
  KunChatMessageKind kind = KunChatMessageKind.message,
  KunChatServiceAction? serviceAction,
  KunChatMedia? media,
  String? mediaGroupId,
  KunChatReplyTo? replyTo,
  List<KunChatReaction> reactions = const <KunChatReaction>[],
  KunChatSendStatus? status,
  String? clientMessageId,
  List<KunChatEntity> entities = const <KunChatEntity>[],
}) {
  return KunChatMessage(
    id: id,
    conversationId: conversationId,
    seq: seq,
    senderId: senderId,
    createdAt: at ?? _day2.add(Duration(minutes: seq)),
    kind: kind,
    text: text,
    entities: entities,
    media: media,
    mediaGroupId: mediaGroupId,
    replyTo: replyTo,
    serviceAction: serviceAction,
    reactions: reactions,
    status: status,
    clientMessageId: clientMessageId,
  );
}

List<KunChatMessage> thread(int count, {String conversationId = 'c1'}) {
  return <KunChatMessage>[
    for (int i = 1; i <= count; i++)
      msg(
        id: '$i',
        seq: i,
        senderId: i.isOdd ? 'her' : 'me',
        text: 'm$i',
        conversationId: conversationId,
        at: _day2.add(Duration(minutes: i)),
      ),
  ];
}

Finder rowOf(KunChatMessage message) =>
    find.byKey(KunChatMessageList.rowKey(kunChatMessageKey(message)));

Finder get menuPanel =>
    find.byKey(const ValueKey<String>('KunChatMessageMenu.panel'));

Finder menuItem(String key) =>
    find.byKey(ValueKey<String>('KunChatMessageMenu.item.$key'));

Future<void> openRowMenu(WidgetTester tester, Finder row) async {
  final Rect box = tester.getRect(row);
  await tester.tapAt(
    Offset(box.left + 8, box.center.dy),
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await tester.pump();
}

ScrollableState scrollOf(WidgetTester tester) {
  return tester.state<ScrollableState>(
    find.descendant(
      of: find.byKey(KunChatMessageList.scrollKey),
      matching: find.byType(Scrollable),
    ),
  );
}

Future<void> settleList(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Widget wrap(
  Widget child, {
  bool reducedMotion = false,
  double width = 400,
  double height = 400,
  List<String>? navigated,
  KunMessages messages = KunMessages.en,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: Size(width, height),
      disableAnimations: reducedMotion,
    ),
    child: KunTheme(
      data: KunThemeData.light(),
      child: KunMessagesScope(
        messages: messages,
        child: KunUIConfigScope(
          config: KunUIConfig(
            imageProvider: (_) => _memory,
            navigate: (_, String href) => navigated?.add(href),
          ),
          child: WidgetsApp(
            color: KunColors.black,
            debugShowCheckedModeBanner: false,
            shortcuts: <ShortcutActivator, Intent>{
              ...WidgetsApp.defaultShortcuts,
              const SingleActivator(LogicalKeyboardKey.enter):
                  const ButtonActivateIntent(),
            },
            builder: (BuildContext context, Widget? navigator) {
              return KunMessageProvider(child: navigator!);
            },
            home: Center(
              child: SizedBox(width: width, height: height, child: child),
            ),
            pageRouteBuilder:
                <T>(RouteSettings settings, WidgetBuilder builder) {
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
      ),
    ),
  );
}

Future<void> pumpList(
  WidgetTester tester, {
  required List<KunChatMessage> messages,
  KunChatMessageListController? controller,
  String currentUserId = 'me',
  KunChatKind kind = KunChatKind.direct,
  int? lastReadSeq,
  int? peerReadSeq,
  int? unreadCount,
  bool hasOlder = false,
  bool hasNewer = false,
  bool loadingOlder = false,
  bool loadingNewer = false,
  bool swipeToReply = true,
  String? semanticLabel,
  Widget? empty,
  Widget? footer,
  Widget? start,
  List<KunChatMessageAction> Function(KunChatMessage, bool)? actions,
  void Function(String, KunChatMessage, KunChatReplyQuote?)? onAction,
  ValueChanged<int>? onJump,
  VoidCallback? onLatest,
  KunChatLinkCallback? onLink,
  VoidCallback? onLoadNewer,
  VoidCallback? onLoadOlder,
  KunChatUserCallback? onMention,
  void Function(KunChatMessage, String?)? onReact,
  ValueChanged<int>? onRead,
  ValueChanged<KunChatMessage>? onRetry,
  KunChatUserCallback? onUserTap,
  List<String>? navigated,
  bool reducedMotion = false,
  double height = 400,
  Duration groupWindow = const Duration(minutes: 10),
}) async {
  await tester.pumpWidget(
    wrap(
      KunChatMessageList(
        key: const ValueKey<String>('KunChatMessageList.host'),
        controller: controller,
        currentUserId: currentUserId,
        messages: messages,
        users: _users,
        kind: kind,
        lastReadSeq: lastReadSeq,
        peerReadSeq: peerReadSeq,
        unreadCount: unreadCount,
        hasOlder: hasOlder,
        hasNewer: hasNewer,
        loadingOlder: loadingOlder,
        loadingNewer: loadingNewer,
        swipeToReply: swipeToReply,
        semanticLabel: semanticLabel,
        empty: empty,
        footer: footer,
        start: start,
        actions: actions,
        groupWindow: groupWindow,
        reactionOptions: _reactions,
        resolveMediaUrl: (KunChatMedia _, KunChatMediaVariant __) => 'mem',
        onAction: onAction,
        onJump: onJump,
        onLatest: onLatest,
        onLink: onLink,
        onLoadNewer: onLoadNewer,
        onLoadOlder: onLoadOlder,
        onMention: onMention,
        onReact: onReact,
        onRead: onRead,
        onRetry: onRetry,
        onUserTap: onUserTap,
      ),
      navigated: navigated,
      reducedMotion: reducedMotion,
      height: height,
    ),
  );
  await settleList(tester);
}

void collectRecognizers(InlineSpan span, List<TapGestureRecognizer> found) {
  if (span is TextSpan) {
    if (span.recognizer is TapGestureRecognizer) {
      found.add(span.recognizer! as TapGestureRecognizer);
    }
    final List<InlineSpan>? children = span.children;
    if (children != null) {
      for (final InlineSpan child in children) {
        collectRecognizers(child, found);
      }
    }
  }
}

void tapRecognizers(WidgetTester tester) {
  final List<TapGestureRecognizer> found = <TapGestureRecognizer>[];
  for (final Element element in tester.elementList(find.byType(RichText))) {
    collectRecognizers((element.widget as RichText).text, found);
  }
  for (final TapGestureRecognizer recognizer in found) {
    recognizer.onTap?.call();
  }
}

SemanticsNode listSemantics(WidgetTester tester) {
  return tester.getSemantics(find.byType(KunChatMessageList));
}

SemanticsNode? nodeWithLabel(SemanticsNode root, String needle) {
  SemanticsNode? found;
  void walk(SemanticsNode node) {
    if (found != null) {
      return;
    }
    if (node.getSemanticsData().label.contains(needle)) {
      found = node;
      return;
    }
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return found == null;
    });
  }

  walk(root);
  return found;
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
        'longPress=${data.hasAction(SemanticsAction.longPress)} '
        'custom=${data.hasAction(SemanticsAction.customAction)} '
        'rect=${node.rect}',
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

CustomSemanticsAction menuAction() => CustomSemanticsAction(
      label: KunMessages.en.chatMenu.label,
    );

void main() {
  testWidgets('1 bottom origin puts the newest row on the bottom edge', (
    WidgetTester tester,
  ) async {
    final List<KunChatMessage> messages = thread(4);
    await pumpList(tester, messages: messages);
    final Rect view = tester.getRect(
      find.byKey(KunChatMessageList.scrollKey),
    );
    final Rect newest = tester.getRect(rowOf(messages.last));
    expect(newest.bottom, closeTo(view.bottom, 8));
    expect(newest.bottom, greaterThan(view.center.dy));
  });

  testWidgets('2 prepending older messages leaves the visible row in place', (
    WidgetTester tester,
  ) async {
    final List<KunChatMessage> later = thread(30).sublist(20);
    await pumpList(tester, messages: later, height: 360);
    scrollOf(tester).position.jumpTo(180);
    await tester.pump();
    final KunChatMessage anchor = later[later.length ~/ 2];
    final Rect before = tester.getRect(rowOf(anchor));
    final List<KunChatMessage> older = <KunChatMessage>[
      for (int i = 1; i <= 50; i++)
        msg(
          id: 'old$i',
          seq: i,
          text: 'old$i',
          at: _day0.add(Duration(minutes: i)),
        ),
      ...later,
    ];
    await pumpList(tester, messages: older, height: 360);
    expect(tester.getRect(rowOf(anchor)).top, closeTo(before.top, 1.5));
  });

  testWidgets('3a a new message pins when the viewer is at the bottom', (
    WidgetTester tester,
  ) async {
    List<KunChatMessage> messages = thread(6);
    await pumpList(tester, messages: messages);
    expect(scrollOf(tester).position.pixels, closeTo(0, 0.5));
    messages = <KunChatMessage>[
      ...messages,
      msg(id: '7', seq: 7, text: 'fresh', senderId: 'her'),
    ];
    await pumpList(tester, messages: messages);
    expect(scrollOf(tester).position.pixels, closeTo(0, 0.5));
    expect(find.textContaining('fresh'), findsWidgets);
    final Rect view = tester.getRect(
      find.byKey(KunChatMessageList.scrollKey),
    );
    expect(
      tester.getRect(rowOf(messages.last)).bottom,
      closeTo(view.bottom, 12),
    );
  });

  testWidgets('3b a new message does not move the screen when scrolled up', (
    WidgetTester tester,
  ) async {
    List<KunChatMessage> messages = thread(24);
    await pumpList(tester, messages: messages);
    scrollOf(tester).position.jumpTo(220);
    await tester.pump();
    final Rect before = tester.getRect(rowOf(messages[10]));
    messages = <KunChatMessage>[
      ...messages,
      msg(id: '25', seq: 25, text: 'unseen-new', senderId: 'her'),
    ];
    await pumpList(tester, messages: messages);
    expect(tester.getRect(rowOf(messages[10])).top, closeTo(before.top, 1.5));
  });

  testWidgets('3c an own sending message always scrolls to the bottom', (
    WidgetTester tester,
  ) async {
    List<KunChatMessage> messages = thread(20);
    await pumpList(tester, messages: messages);
    scrollOf(tester).position.jumpTo(240);
    await tester.pump();
    expect(scrollOf(tester).position.pixels, greaterThan(50));
    messages = <KunChatMessage>[
      ...messages,
      msg(
        id: '21',
        seq: 21,
        senderId: 'me',
        text: 'sending now',
        status: KunChatSendStatus.sending,
        clientMessageId: 'pending-21',
      ),
    ];
    await pumpList(tester, messages: messages);
    expect(scrollOf(tester).position.pixels, closeTo(0, 2));
    expect(find.textContaining('sending now'), findsWidgets);
  });

  testWidgets('4 an off-screen height change keeps the anchor', (
    WidgetTester tester,
  ) async {
    List<KunChatMessage> messages = thread(18);
    await pumpList(tester, messages: messages);
    scrollOf(tester).position.jumpTo(200);
    await tester.pump();
    final Rect before = tester.getRect(rowOf(messages[8]));
    messages = <KunChatMessage>[
      ...messages.sublist(0, messages.length - 1),
      messages.last.copyWith(
        text: '${messages.last.text}\n${'tall\n' * 12}',
      ),
    ];
    await pumpList(tester, messages: messages);
    expect(tester.getRect(rowOf(messages[8])).top, closeTo(before.top, 2));
  });

  testWidgets('5a opens with the unread divider 10px under the top', (
    WidgetTester tester,
  ) async {
    final List<KunChatMessage> messages = <KunChatMessage>[
      for (int i = 1; i <= 20; i++)
        msg(id: '$i', seq: i, senderId: 'her', text: 'unread-$i'),
    ];
    await pumpList(tester, messages: messages, lastReadSeq: 2, height: 280);
    final Rect view = tester.getRect(
      find.byKey(KunChatMessageList.scrollKey),
    );
    final Rect unread = tester.getRect(
      find.byKey(KunChatMessageList.unreadKey),
    );
    expect(unread.top, closeTo(view.top + 10, 3));
    expect(find.text(KunMessages.en.chat.unreadDivider), findsOneWidget);
  });

  testWidgets('5b opens at the bottom when unread fits or is absent', (
    WidgetTester tester,
  ) async {
    final List<KunChatMessage> messages = thread(3);
    await pumpList(tester, messages: messages, lastReadSeq: 1);
    expect(scrollOf(tester).position.pixels, closeTo(0, 0.5));
    final Rect view = tester.getRect(
      find.byKey(KunChatMessageList.scrollKey),
    );
    expect(
      tester.getRect(rowOf(messages.last)).bottom,
      closeTo(view.bottom, 8),
    );
  });

  testWidgets('6 scrollToSeq centres, flashes, jumps unbuilt, and misses', (
    WidgetTester tester,
  ) async {
    final KunChatMessageListController controller =
        KunChatMessageListController();
    addTearDown(controller.dispose);
    final List<KunChatMessage> messages = thread(80);
    await pumpList(
      tester,
      messages: messages,
      controller: controller,
      height: 320,
    );
    expect(controller.scrollToSeq(999), isFalse);
    expect(controller.scrollToSeq(2, animate: false), isTrue);
    await settleList(tester);
    await tester.pump();
    expect(rowOf(messages[1]), findsOneWidget);
    final Rect view = tester.getRect(
      find.byKey(KunChatMessageList.scrollKey),
    );
    final Rect row = tester.getRect(rowOf(messages[1]));
    expect(row.center.dy, closeTo(view.center.dy, view.height / 2));
    expect(controller.atBottom.value, isFalse);
  });

  testWidgets('6b a reply tap jumps or fires onJump', (
    WidgetTester tester,
  ) async {
    final List<int> jumps = <int>[];
    final KunChatMessageListController controller =
        KunChatMessageListController();
    addTearDown(controller.dispose);
    final KunChatMessage original = msg(id: '1', seq: 1, text: 'source');
    final KunChatMessage reply = msg(
      id: '2',
      seq: 2,
      senderId: 'me',
      text: 'replying',
      replyTo: KunChatReplyTo(
        seq: 1,
        senderId: 'her',
        text: 'source',
        deleted: false,
      ),
    );
    await pumpList(
      tester,
      messages: <KunChatMessage>[original, reply],
      controller: controller,
      onJump: jumps.add,
    );
    await tester.tap(find.byKey(KunChatBubble.replyKey));
    await tester.pump();
    expect(jumps, isEmpty);

    final KunChatMessage missing = msg(
      id: '3',
      seq: 3,
      senderId: 'me',
      text: 'gone-target',
      replyTo: const KunChatReplyTo(
        seq: 99,
        senderId: 'her',
        text: 'missing',
        deleted: false,
      ),
    );
    await pumpList(
      tester,
      messages: <KunChatMessage>[original, reply, missing],
      controller: controller,
      onJump: jumps.add,
    );
    await tester.tap(
      find.descendant(
        of: rowOf(missing),
        matching: find.byKey(KunChatBubble.replyKey),
      ),
    );
    await tester.pump();
    expect(jumps, <int>[99]);
  });

  testWidgets('7 edge paging fires once until the edge flips', (
    WidgetTester tester,
  ) async {
    int older = 0;
    int newer = 0;
    final List<KunChatMessage> messages = thread(40);
    await pumpList(
      tester,
      messages: messages,
      hasOlder: true,
      hasNewer: true,
      onLoadOlder: () => older++,
      onLoadNewer: () => newer++,
      height: 280,
    );
    expect(newer, 1);
    expect(older, 0);
    scrollOf(tester).position.jumpTo(
          scrollOf(tester).position.maxScrollExtent,
        );
    await tester.pump();
    await tester.pump();
    expect(older, 1);
    await tester.pump();
    expect(older, 1);
    expect(newer, 1);

    await pumpList(
      tester,
      messages: messages,
      hasOlder: true,
      hasNewer: true,
      loadingOlder: true,
      loadingNewer: true,
      onLoadOlder: () => older++,
      onLoadNewer: () => newer++,
      height: 280,
    );
    await tester.pump();
    scrollOf(tester).position.jumpTo(0);
    await tester.pump();
    expect(find.byKey(KunChatMessageList.newerSpinnerKey), findsOneWidget);
    scrollOf(tester).position.jumpTo(
          scrollOf(tester).position.maxScrollExtent,
        );
    await tester.pump();
    expect(find.byKey(KunChatMessageList.olderSpinnerKey), findsOneWidget);

    older = 0;
    newer = 0;
    await pumpList(
      tester,
      messages: messages,
      hasOlder: true,
      hasNewer: true,
      onLoadOlder: () => older++,
      onLoadNewer: () => newer++,
      height: 280,
    );
    scrollOf(tester).position.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(newer, 1);
  });

  testWidgets('8 the sticky day pill pins and is pushed out', (
    WidgetTester tester,
  ) async {
    final List<KunChatMessage> messages = <KunChatMessage>[
      for (int i = 1; i <= 12; i++)
        msg(
          id: 'a$i',
          seq: i,
          text: 'dayA-$i',
          at: _day0.add(Duration(minutes: i)),
        ),
      for (int i = 1; i <= 12; i++)
        msg(
          id: 'b$i',
          seq: 12 + i,
          text: 'dayB-$i',
          at: _day1.add(Duration(minutes: i)),
        ),
    ];
    await pumpList(tester, messages: messages, height: 300);
    scrollOf(tester).position.jumpTo(
          scrollOf(tester).position.maxScrollExtent * 0.55,
        );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(KunChatMessageList.stickyDayKey), findsOneWidget);
    final Rect view = tester.getRect(
      find.byKey(KunChatMessageList.scrollKey),
    );
    final Rect pill = tester.getRect(
      find.byKey(KunChatMessageList.stickyDayKey),
    );
    expect(pill.top, closeTo(view.top + KunSpacing.unit * 2, 4));

    scrollOf(tester).position.jumpTo(
          scrollOf(tester).position.maxScrollExtent * 0.72,
        );
    await tester.pump();
    await tester.pump();
    if (find.byKey(KunChatMessageList.stickyDayKey).evaluate().isNotEmpty) {
      final Rect pushed = tester.getRect(
        find.byKey(KunChatMessageList.stickyDayKey),
      );
      expect(pushed.top, lessThan(pill.top + 0.5));
    }
  });

  testWidgets('8b the pinned day pill matches the in-flow pill', (
    WidgetTester tester,
  ) async {
    final List<KunChatMessage> messages = <KunChatMessage>[
      for (int i = 1; i <= 12; i++)
        msg(
          id: 'a$i',
          seq: i,
          text: 'dayA-$i',
          at: _day0.add(Duration(minutes: i)),
        ),
      for (int i = 1; i <= 12; i++)
        msg(
          id: 'b$i',
          seq: 12 + i,
          text: 'dayB-$i',
          at: _day1.add(Duration(minutes: i)),
        ),
    ];
    await pumpList(tester, messages: messages, height: 300);
    scrollOf(tester).position.jumpTo(
          scrollOf(tester).position.maxScrollExtent * 0.55,
        );
    await tester.pump();
    await tester.pump();
    final Finder sticky = find.byKey(KunChatMessageList.stickyDayKey);
    expect(sticky, findsOneWidget);
    final Rect view = tester.getRect(
      find.byKey(KunChatMessageList.scrollKey),
    );
    final Rect pill = tester.getRect(sticky);
    final String stickyLabel = tester
        .widget<Text>(
          find.descendant(of: sticky, matching: find.byType(Text)),
        )
        .data!;
    Finder? inFlowPill;
    for (final DateTime day in <DateTime>[_day0, _day1]) {
      final Finder dayFinder = find.byKey(
        KunChatMessageList.dayKey(kunChatDayKey(day)),
      );
      if (dayFinder.evaluate().isEmpty) {
        continue;
      }
      if (find
          .descendant(of: dayFinder, matching: find.text(stickyLabel))
          .evaluate()
          .isEmpty) {
        continue;
      }
      inFlowPill = find.descendant(
        of: dayFinder,
        matching: find.byType(DecoratedBox),
      );
      break;
    }
    expect(inFlowPill, isNotNull, reason: 'in-flow pill for "$stickyLabel"');
    final Size inFlowSize = tester.getSize(inFlowPill!);
    expect(pill.width, closeTo(inFlowSize.width, 1));
    expect(pill.height, closeTo(inFlowSize.height, 1));
    expect(pill.center.dx, closeTo(view.center.dx, 1));
    expect(pill.top, closeTo(view.top + KunSpacing.unit * 2, 1));
    expect(pill.width, lessThan(view.width - 8));
  });

  testWidgets('9 read tracking increases once per frame while resumed', (
    WidgetTester tester,
  ) async {
    final List<int> reads = <int>[];
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await pumpList(
      tester,
      messages: const <KunChatMessage>[],
      lastReadSeq: 0,
      onRead: reads.add,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await pumpList(
      tester,
      messages: <KunChatMessage>[
        for (int i = 1; i <= 8; i++)
          msg(id: '$i', seq: i, senderId: i == 8 ? 'me' : 'her', text: 'r$i'),
      ],
      lastReadSeq: 0,
      onRead: reads.add,
    );
    expect(reads, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(reads, isNotEmpty);
    expect(reads.last, greaterThan(0));
    final int first = reads.last;
    await tester.pump();
    expect(reads.last, first);
  });

  testWidgets('10 unread, service, group avatar and bubble wiring', (
    WidgetTester tester,
  ) async {
    final List<String> users = <String>[];
    final KunChatMessage created = msg(
      id: 's1',
      seq: 1,
      senderId: 'me',
      text: '',
      kind: KunChatMessageKind.service,
      serviceAction: const KunChatGroupCreatedAction(title: 'Room'),
      at: _day2,
    );
    final KunChatMessage first = msg(
      id: '2',
      seq: 2,
      senderId: 'her',
      text: 'hi group',
      at: _day2.add(const Duration(minutes: 1)),
    );
    final KunChatMessage second = msg(
      id: '3',
      seq: 3,
      senderId: 'her',
      text: 'still me',
      at: _day2.add(const Duration(minutes: 2)),
    );
    final KunChatMessage own = msg(
      id: '4',
      seq: 4,
      senderId: 'me',
      text: 'mine',
      at: _day2.add(const Duration(minutes: 3)),
    );
    await pumpList(
      tester,
      messages: <KunChatMessage>[created, first, second, own],
      kind: KunChatKind.group,
      lastReadSeq: 1,
      peerReadSeq: 4,
      onUserTap: (KunChatUserEvent e) {
        users.add(e.userId);
        e.preventDefault();
      },
    );
    expect(find.byKey(KunChatBubble.serviceKey), findsOneWidget);
    expect(find.text(KunMessages.en.chat.unreadDivider), findsOneWidget);
    expect(find.byType(KunAvatar), findsOneWidget);
    expect(
      tester.widgetList<SizedBox>(find.byType(SizedBox)).any(
            (SizedBox box) => box.width == KunSpacing.unit * 8,
          ),
      isTrue,
    );
    expect(find.byKey(KunChatBubble.senderKey), findsOneWidget);
    await tester.tap(find.byType(KunAvatar));
    await tester.pump();
    expect(users, <String>['her']);
    expect(find.byIcon(KunIcons.checkCheck), findsWidgets);
  });

  testWidgets('11 lightbox index uses the photo-filtered album', (
    WidgetTester tester,
  ) async {
    const String album = 'g1';
    final List<KunChatMessage> messages = <KunChatMessage>[
      msg(
        id: '1',
        seq: 1,
        text: '',
        media: const KunChatUnknownMedia(type: 'file'),
        mediaGroupId: album,
      ),
      msg(
        id: '2',
        seq: 2,
        text: '',
        media: const KunChatPhoto(imageHash: 'a', width: 120, height: 80),
        mediaGroupId: album,
      ),
      msg(
        id: '3',
        seq: 3,
        text: 'cap',
        media: const KunChatPhoto(imageHash: 'b', width: 120, height: 80),
        mediaGroupId: album,
      ),
    ];
    await pumpList(tester, messages: messages);
    await tester.tap(find.byKey(KunChatBubble.photoKey(0)));
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(find.byKey(KunLightbox.layerKey), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets(
      '12 the menu opens, copies, retries, reacts, and closes on scroll',
      (WidgetTester tester) async {
    String? action;
    KunChatMessage? acted;
    KunChatMessage? retried;
    (KunChatMessage, String?)? reacted;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final KunChatMessage failed = msg(
      id: '21',
      seq: 21,
      senderId: 'me',
      text: 'copy-me',
      status: KunChatSendStatus.failed,
    );
    await pumpList(
      tester,
      messages: <KunChatMessage>[...thread(20), failed],
      actions: (KunChatMessage _, bool __) => const <KunChatMessageAction>[
        KunChatMessageAction.copy,
        KunChatMessageAction.retry,
        KunChatMessageAction.quote,
        KunChatMessageAction.reply,
      ],
      onAction: (String a, KunChatMessage m, KunChatReplyQuote? q) {
        action = a;
        acted = m;
        expect(q, isNull);
      },
      onRetry: (KunChatMessage m) => retried = m,
      onReact: (KunChatMessage m, String? r) => reacted = (m, r),
    );

    await openRowMenu(tester, rowOf(failed));
    expect(menuPanel, findsOneWidget);

    await tester.tap(menuItem('copy'));
    await tester.pump();
    await tester.pump();
    expect(copied, 'copy-me');
    expect(action, 'copy');
    expect(acted, failed);
    expect(find.text(KunMessages.en.chatMenu.copied), findsOneWidget);

    await openRowMenu(tester, rowOf(failed));
    await tester.tap(menuItem('retry'));
    await tester.pump();
    expect(retried, failed);

    await openRowMenu(tester, rowOf(failed));
    await tester.tap(menuItem('reply'));
    await tester.pump();
    expect(action, 'reply');

    await openRowMenu(tester, rowOf(failed));
    await tester.tap(
      find.byKey(const ValueKey<String>('KunChatMessageMenu.quick.heart')),
    );
    await tester.pump();
    expect(reacted?.$1, failed);
    expect(reacted?.$2, 'heart');

    await openRowMenu(tester, rowOf(failed));
    expect(menuPanel, findsOneWidget);
    final ScrollPosition position = scrollOf(tester).position;
    final double next =
        position.maxScrollExtent < 80 ? position.maxScrollExtent : 80;
    position.jumpTo(next);
    await tester.pump();
    expect(
      tester
          .widget<KunChatMessageMenu>(find.byType(KunChatMessageMenu))
          .visible,
      isFalse,
    );
  });

  testWidgets('12b long-press opens after 450ms and cancels past 8px', (
    WidgetTester tester,
  ) async {
    final KunChatMessage message = msg(id: '1', seq: 1, text: 'hold');
    await pumpList(tester, messages: <KunChatMessage>[message]);
    final Offset center = tester.getCenter(rowOf(message));
    final TestGesture cancelled = await tester.startGesture(
      center,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await cancelled.moveBy(const Offset(9, 0));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await tester.pump();
    expect(menuPanel, findsNothing);
    await cancelled.up();
    await tester.pump();
  });

  testWidgets('12c a still touch of 450ms opens the menu', (
    WidgetTester tester,
  ) async {
    final List<KunChatMessage> messages = thread(20);
    await pumpList(tester, messages: messages, height: 280);
    final Offset center = tester.getCenter(rowOf(messages.last));
    final TestGesture held = await tester.startGesture(
      center,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(menuPanel, findsOneWidget);
    await held.up();
    await tester.pump();
    await tester.pump();
    await tester.pump(KunDurations.exit);
    expect(
      tester
          .widget<KunChatMessageMenu>(find.byType(KunChatMessageMenu))
          .visible,
      isTrue,
    );
    expect(menuPanel, findsOneWidget);
  });

  testWidgets('12d a real list scroll after the menu opens closes it', (
    WidgetTester tester,
  ) async {
    final List<KunChatMessage> messages = thread(20);
    await pumpList(tester, messages: messages, height: 280);
    final Offset center = tester.getCenter(rowOf(messages.last));
    final TestGesture held = await tester.startGesture(
      center,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(
      tester
          .widget<KunChatMessageMenu>(find.byType(KunChatMessageMenu))
          .visible,
      isTrue,
    );
    await held.moveBy(const Offset(0, 80));
    await tester.pump();
    await held.up();
    await tester.pump();
    expect(
      tester
          .widget<KunChatMessageMenu>(find.byType(KunChatMessageMenu))
          .visible,
      isFalse,
    );
  });

  testWidgets('13 quote is not offered without a selection, as on the web', (
    WidgetTester tester,
  ) async {
    final KunChatMessage message = msg(id: '1', seq: 1, text: 'selectable');
    await pumpList(
      tester,
      messages: <KunChatMessage>[message],
      actions: (KunChatMessage _, bool __) => const <KunChatMessageAction>[
        KunChatMessageAction.reply,
        KunChatMessageAction.quote,
      ],
    );
    await openRowMenu(tester, rowOf(message));
    expect(menuItem('reply'), findsOneWidget);
    expect(menuItem('quote'), findsNothing);
  });

  testWidgets('14 swipe to reply on touch, not on a vertical drag', (
    WidgetTester tester,
  ) async {
    final List<String> actions = <String>[];
    final KunChatMessage message = msg(id: '1', seq: 1, text: 'swipe me');
    await pumpList(
      tester,
      messages: <KunChatMessage>[message],
      onAction: (String a, KunChatMessage _, KunChatReplyQuote? __) =>
          actions.add(a),
    );
    final Offset start = tester.getCenter(rowOf(message));
    expect(start.dx, greaterThan(30));

    final TestGesture vertical = await tester.startGesture(
      start,
      kind: PointerDeviceKind.touch,
    );
    await vertical.moveBy(const Offset(0, 28));
    await vertical.up();
    await tester.pump();
    expect(actions, isEmpty);

    final TestGesture swipe = await tester.startGesture(
      start,
      kind: PointerDeviceKind.touch,
    );
    await swipe.moveBy(const Offset(-52, 0));
    await tester.pump();
    final Transform translated = tester.widget<Transform>(
      find
          .descendant(
            of: rowOf(message),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(translated.transform.getTranslation().x, lessThan(0));
    await swipe.up();
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(actions, <String>['reply']);
  });

  testWidgets('14b swipeToReply false never emits reply', (
    WidgetTester tester,
  ) async {
    final List<String> actions = <String>[];
    final KunChatMessage message = msg(id: '1', seq: 1, text: 'no swipe');
    await pumpList(
      tester,
      messages: <KunChatMessage>[message],
      swipeToReply: false,
      onAction: (String a, KunChatMessage _, KunChatReplyQuote? __) =>
          actions.add(a),
    );
    final TestGesture swipe = await tester.startGesture(
      tester.getCenter(rowOf(message)),
      kind: PointerDeviceKind.touch,
    );
    await swipe.moveBy(const Offset(-60, 0));
    await swipe.up();
    await tester.pump();
    expect(actions, isEmpty);
  });

  testWidgets('15 the scroll-to-bottom button, badge, and latest', (
    WidgetTester tester,
  ) async {
    int latest = 0;
    final KunChatMessageListController controller =
        KunChatMessageListController();
    addTearDown(controller.dispose);
    final List<KunChatMessage> messages = thread(20);
    await pumpList(
      tester,
      messages: messages,
      controller: controller,
      unreadCount: 12,
      onLatest: () => latest++,
    );
    final IgnorePointer atBottom = tester
        .widgetList<IgnorePointer>(
          find.ancestor(
            of: find.byKey(KunChatMessageList.fabKey),
            matching: find.byType(IgnorePointer),
          ),
        )
        .first;
    expect(atBottom.ignoring, isTrue);

    scrollOf(tester).position.jumpTo(180);
    await tester.pump();
    await tester.pump(KunDurations.base);
    await tester.pump();
    expect(find.text('12'), findsOneWidget);
    final Semantics fabSemantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(KunChatMessageList.fabKey),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(
      fabSemantics.properties.label,
      KunMessages.en.chat.scrollToBottomUnread(count: 12),
    );
    await tester.tap(find.byKey(KunChatMessageList.fabKey));
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(controller.atBottom.value, isTrue);
    expect(latest, 0);

    await pumpList(
      tester,
      messages: messages,
      controller: controller,
      hasNewer: true,
      unreadCount: 1200,
      onLatest: () => latest++,
    );
    await tester.pump(KunDurations.base);
    expect(find.text('999+'), findsOneWidget);
    await tester.tap(find.byKey(KunChatMessageList.fabKey));
    await tester.pump();
    expect(latest, 1);
  });

  testWidgets('16 roving focus tints and opens the menu from the web key map', (
    WidgetTester tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });
    final List<KunChatMessage> messages = thread(4);
    await pumpList(tester, messages: messages);
    final Color tint =
        KunThemeData.light().colors.primary.solid.withValues(alpha: 0.1);
    Finder tinted() => find.byWidgetPredicate(
          (Widget w) => w is ColoredBox && w.color == tint,
        );
    expect(tinted(), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tinted(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(menuPanel, findsOneWidget);
  });

  testWidgets('17 announces incoming others and names the region', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<Map<dynamic, dynamic>> events = <Map<dynamic, dynamic>>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (dynamic message) async {
        if (message is Map) {
          events.add(Map<dynamic, dynamic>.from(message));
        }
        return null;
      },
    );
    try {
      List<KunChatMessage> messages = thread(2);
      await pumpList(
        tester,
        messages: messages,
        semanticLabel: 'Conversation',
      );
      expect(find.bySemanticsLabel('Conversation'), findsWidgets);

      messages = <KunChatMessage>[
        ...messages,
        msg(id: '3', seq: 3, senderId: 'her', text: 'ping one'),
        msg(id: '4', seq: 4, senderId: 'her', text: 'ping two'),
        msg(id: '5', seq: 5, senderId: 'her', text: 'ping three'),
        msg(id: '6', seq: 6, senderId: 'her', text: 'ping four'),
      ];
      await pumpList(tester, messages: messages);
      final List<String> announced = events
          .where((Map<dynamic, dynamic> e) => e['type'] == 'announce')
          .map((Map<dynamic, dynamic> e) =>
              (e['data'] as Map)['message'] as String)
          .toList();
      expect(announced.where((String m) => m.contains('ping')).length, 3);
      expect(announced.last, contains('ping four'));
      expect(
        announced.where((String m) => m.contains('ping one')),
        isEmpty,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('18 reduced motion flashes as an outline', (
    WidgetTester tester,
  ) async {
    final KunChatMessageListController controller =
        KunChatMessageListController();
    addTearDown(controller.dispose);
    final List<KunChatMessage> messages = thread(3);
    await pumpList(
      tester,
      messages: messages,
      controller: controller,
      reducedMotion: true,
    );
    expect(controller.scrollToSeq(1, animate: false), isTrue);
    await tester.pump();
    final DecoratedBox outline = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: rowOf(messages.first),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final BoxDecoration decoration = outline.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.border!.top.width, 2);
  });

  testWidgets('19 switching conversation repositions and resets reads', (
    WidgetTester tester,
  ) async {
    final List<int> reads = <int>[];
    final List<KunChatMessage> first = thread(6, conversationId: 'a');
    await pumpList(
      tester,
      messages: first,
      lastReadSeq: 0,
      onRead: reads.add,
    );
    expect(reads, isNotEmpty);
    final int before = reads.length;
    final List<KunChatMessage> second = thread(4, conversationId: 'b');
    await pumpList(
      tester,
      messages: second,
      lastReadSeq: 0,
      onRead: reads.add,
    );
    expect(scrollOf(tester).position.pixels, closeTo(0, 1));
    expect(reads.length, greaterThan(before));
  });

  testWidgets('20 grouping is skipped when the list identity is unchanged', (
    WidgetTester tester,
  ) async {
    final List<KunChatMessage> messages = thread(80);
    KunChatMessageList.debugGroupComputations = 0;
    await pumpList(tester, messages: messages);
    final int afterFirst = KunChatMessageList.debugGroupComputations;
    expect(afterFirst, greaterThan(0));
    await pumpList(tester, messages: messages);
    expect(KunChatMessageList.debugGroupComputations, afterFirst);
    scrollOf(tester).position.jumpTo(120);
    await tester.pump();
    await tester.pump();
    expect(KunChatMessageList.debugGroupComputations, afterFirst);
  });

  testWidgets('slots empty footer and start', (WidgetTester tester) async {
    await pumpList(
      tester,
      messages: const <KunChatMessage>[],
      empty: const Text('no-mail'),
    );
    expect(find.text('no-mail'), findsOneWidget);

    await pumpList(
      tester,
      messages: thread(2),
      footer: const Text('typing-slot'),
      start: const Text('beginning'),
    );
    expect(find.text('typing-slot'), findsOneWidget);
    expect(find.text('beginning'), findsOneWidget);
  });

  testWidgets('controller scrollToBottom and atBottom', (
    WidgetTester tester,
  ) async {
    final KunChatMessageListController controller =
        KunChatMessageListController();
    addTearDown(controller.dispose);
    await pumpList(
      tester,
      messages: thread(20),
      controller: controller,
    );
    expect(controller.atBottom.value, isTrue);
    scrollOf(tester).position.jumpTo(150);
    await tester.pump();
    expect(controller.atBottom.value, isFalse);
    controller.scrollToBottom();
    await tester.pump();
    expect(controller.atBottom.value, isTrue);
    expect(scrollOf(tester).position.pixels, closeTo(0, 0.5));
  });

  testWidgets('fallback actions are reply and copy', (
    WidgetTester tester,
  ) async {
    final KunChatMessage message = msg(id: '1', seq: 1, text: 'menu');
    await pumpList(tester, messages: <KunChatMessage>[message]);
    await openRowMenu(tester, rowOf(message));
    expect(menuItem('reply'), findsOneWidget);
    expect(menuItem('copy'), findsOneWidget);
  });

  testWidgets('onMention and onLink fire from bubble text', (
    WidgetTester tester,
  ) async {
    String? mentioned;
    String? link;
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      'hi [@鲲](mention:1002) and [site](https://example.com)',
    );
    final KunChatMessage message = msg(
      id: '1',
      seq: 1,
      text: parsed.text,
      entities: parsed.entities,
    );
    await pumpList(
      tester,
      messages: <KunChatMessage>[message],
      onMention: (KunChatUserEvent e) {
        mentioned = e.userId;
        e.preventDefault();
      },
      onLink: (KunChatLinkEvent e) {
        link = e.url;
        e.preventDefault();
      },
    );
    tapRecognizers(tester);
    expect(mentioned, '1002');
    expect(link, anyOf('https://example.com', 'https://example.com/'));
  });

  testWidgets('edge spinners show while a page is in flight', (
    WidgetTester tester,
  ) async {
    await pumpList(
      tester,
      messages: thread(3),
      loadingOlder: true,
      loadingNewer: true,
    );
    expect(find.byKey(KunChatMessageList.olderSpinnerKey), findsOneWidget);
    expect(find.byKey(KunChatMessageList.newerSpinnerKey), findsOneWidget);
    expect(find.byType(KunSpinner), findsNWidgets(2));
  });

  testWidgets('local unread count feeds the badge when unreadCount is null', (
    WidgetTester tester,
  ) async {
    final List<KunChatMessage> messages = <KunChatMessage>[
      for (int i = 1; i <= 12; i++)
        msg(id: '$i', seq: i, senderId: 'her', text: 'u$i'),
    ];
    await pumpList(
      tester,
      messages: messages,
      lastReadSeq: 10,
      unreadCount: 2,
      hasNewer: true,
      height: 240,
    );
    await tester.pump(KunDurations.base);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('a text row and a service row expose no tap action', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      'plain text and [site-link](https://example.com)',
    );
    final KunChatMessage text = msg(
      id: 't',
      seq: 1,
      text: parsed.text,
      entities: parsed.entities,
    );
    final KunChatMessage service = msg(
      id: 's',
      seq: 2,
      text: '',
      kind: KunChatMessageKind.service,
      serviceAction: const KunChatGroupCreatedAction(title: 'Room'),
    );
    await pumpList(
      tester,
      messages: <KunChatMessage>[text, service],
    );
    final SemanticsData textRow =
        tester.getSemantics(rowOf(text)).getSemanticsData();
    expect(textRow.hasAction(SemanticsAction.tap), isFalse);
    expect(textRow.hasAction(SemanticsAction.focus), isTrue);
    final SemanticsNode? link =
        nodeWithLabel(listSemantics(tester), 'site-link');
    expect(link, isNotNull);
    expect(link!.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(
      tester.getSemantics(rowOf(service)).getSemanticsData().hasAction(
            SemanticsAction.tap,
          ),
      isFalse,
    );
    handle.dispose();
  });

  testWidgets('the list has no unnamed actionable node', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final KunChatMessageListController controller =
        KunChatMessageListController();
    addTearDown(controller.dispose);
    const String album = 'g1';
    final KunChatMessage dayText = msg(
      id: 'd',
      seq: 1,
      text: 'day-a-text',
      at: _day0,
    );
    final KunChatMessage service = msg(
      id: 's',
      seq: 2,
      text: '',
      kind: KunChatMessageKind.service,
      serviceAction: const KunChatGroupCreatedAction(title: 'Room'),
      at: _day2,
    );
    final KunChatMessage groupText = msg(
      id: 'g',
      seq: 3,
      text: 'group-hi',
      at: _day2.add(const Duration(minutes: 1)),
    );
    final KunChatMessage photo = msg(
      id: 'p',
      seq: 4,
      text: 'caption',
      media: const KunChatPhoto(imageHash: 'p', width: 120, height: 80),
      at: _day2.add(const Duration(minutes: 2)),
    );
    final KunChatMessage albumA = msg(
      id: 'a1',
      seq: 5,
      text: '',
      media: const KunChatPhoto(imageHash: 'a', width: 120, height: 80),
      mediaGroupId: album,
      at: _day2.add(const Duration(minutes: 3)),
    );
    final KunChatMessage albumB = msg(
      id: 'a2',
      seq: 6,
      text: '',
      media: const KunChatPhoto(imageHash: 'b', width: 120, height: 80),
      mediaGroupId: album,
      at: _day2.add(const Duration(minutes: 3, seconds: 1)),
    );
    final KunChatMessage reply = msg(
      id: 'r',
      seq: 7,
      senderId: 'me',
      text: 'reply-body',
      replyTo: const KunChatReplyTo(
        seq: 3,
        senderId: 'her',
        text: 'group-hi',
        deleted: false,
      ),
      at: _day2.add(const Duration(minutes: 4)),
    );
    await pumpList(
      tester,
      controller: controller,
      messages: <KunChatMessage>[
        dayText,
        service,
        groupText,
        photo,
        albumA,
        albumB,
        reply,
      ],
      kind: KunChatKind.group,
      lastReadSeq: 2,
      height: 800,
    );
    final List<String> unnamed = <String>[];
    Future<void> collectAt(int seq) async {
      expect(
        controller.scrollToSeq(seq, highlight: false, animate: false),
        isTrue,
      );
      await tester.pump();
      unnamed.addAll(unnamedActionable(listSemantics(tester)));
    }

    await collectAt(7);
    expect(find.byKey(KunChatBubble.replyKey), findsOneWidget);
    await collectAt(5);
    expect(find.byKey(KunChatBubble.photoKey(0)), findsWidgets);
    await collectAt(4);
    expect(rowOf(photo), findsOneWidget);
    await collectAt(3);
    expect(find.byType(KunAvatar), findsWidgets);
    expect(find.text(KunMessages.en.chat.unreadDivider), findsOneWidget);
    await collectAt(2);
    expect(find.byKey(KunChatBubble.serviceKey), findsOneWidget);
    await collectAt(1);
    expect(rowOf(dayText), findsOneWidget);
    expect(unnamed, isEmpty);
    handle.dispose();
  });

  testWidgets('a screen reader opens the menu from the labelled row node',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final KunChatMessage text = msg(id: 't', seq: 1, text: 'plain text');
    final KunChatMessage photo = msg(
      id: 'p',
      seq: 2,
      text: 'caption',
      media: const KunChatPhoto(imageHash: 'p', width: 120, height: 80),
    );
    await pumpList(
      tester,
      messages: <KunChatMessage>[text, photo],
      height: 800,
    );
    final SemanticsNode root = listSemantics(tester);
    final SemanticsNode? textNode = nodeWithLabel(root, 'plain text');
    expect(textNode, isNotNull);
    expect(textNode!.getSemanticsData().label, isNotEmpty);
    final CustomSemanticsAction menu = menuAction();
    expect(
      textNode,
      isSemantics(
        customActions: <CustomSemanticsAction>[menu],
      ),
    );
    final SemanticsNode? photoNode = nodeWithLabel(root, 'Photo from Haru');
    expect(photoNode, isNotNull);
    expect(photoNode!.getSemanticsData().label, isNotEmpty);
    expect(
      photoNode,
      isSemantics(
        isButton: true,
        customActions: <CustomSemanticsAction>[menu],
      ),
    );

    tester.semantics.customAction(
      find.semantics.byPredicate(
        (SemanticsNode node) =>
            node.getSemanticsData().label.contains('plain text') &&
            node.getSemanticsData().hasAction(SemanticsAction.customAction),
      ),
      menu,
    );
    await tester.pump();
    await tester.pump();
    expect(menuPanel, findsOneWidget);

    await pumpList(
      tester,
      messages: <KunChatMessage>[text, photo],
      height: 800,
    );
    tester.semantics.customAction(
      find.semantics.byPredicate(
        (SemanticsNode node) =>
            node.getSemanticsData().label.contains('Photo from Haru') &&
            node.getSemanticsData().hasAction(SemanticsAction.customAction),
      ),
      menu,
    );
    await tester.pump();
    await tester.pump();
    expect(menuPanel, findsOneWidget);
    handle.dispose();
  });
}
