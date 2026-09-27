import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/chat/support.dart';

Widget wrap(Widget child, {KunMessages messages = KunMessages.en}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(400, 800)),
    child: KunMessagesScope(
      messages: messages,
      child: KunTheme(
        data: KunThemeData.light(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SizedBox(width: 360, child: child)),
        ),
      ),
    ),
  );
}

Widget wrapWebKeys(Widget child) => Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
      },
      child: wrap(child),
    );

const KunChatUser haru = KunChatUser(id: '1002', name: 'Haru', avatar: '');
const KunChatUser me = KunChatUser(id: '1001', name: 'Kun', avatar: '');

KunChatMessage message({
  String text = 'hello',
  String senderId = '1002',
  DateTime? createdAt,
  KunChatMessageKind kind = KunChatMessageKind.message,
  KunChatMedia? media,
  KunChatServiceAction? serviceAction,
  List<KunChatEntity>? entities,
}) {
  return KunChatMessage(
    id: '1',
    conversationId: 'c',
    seq: 1,
    senderId: senderId,
    createdAt: createdAt ?? DateTime.now(),
    kind: kind,
    text: text,
    entities: entities ?? const <KunChatEntity>[],
    media: media,
    serviceAction: serviceAction,
  );
}

void main() {
  testWidgets('title defaults to the user name and shows the list time', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime at = DateTime(now.year, now.month, now.day, 9, 14);
    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(createdAt: at),
        ),
      ),
    );
    expect(find.text('Haru'), findsWidgets);
    expect(
      find.text(formatKunChatListTime(at, KunMessages.en.code)),
      findsOneWidget,
    );
  });

  testWidgets('preview precedence is typing, then draft, then last message', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(text: 'last'),
          draft: const KunChatFormattedText(text: 'unsent'),
          typing: <KunChatTypingEvent>[
            KunChatTypingEvent(userId: '1002', at: now),
          ],
        ),
      ),
    );
    expect(find.text(KunMessages.en.chatTyping.typing), findsOneWidget);
    expect(find.textContaining('unsent'), findsNothing);
    expect(find.textContaining('last'), findsNothing);

    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(text: 'last'),
          draft: const KunChatFormattedText(text: 'unsent'),
        ),
      ),
    );
    expect(find.text(KunMessages.en.chat.draft), findsOneWidget);
    expect(find.textContaining('last'), findsNothing);

    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(text: 'last'),
        ),
      ),
    );
    expect(find.textContaining('last'), findsOneWidget);
  });

  testWidgets('service sentence, sender prefix and media label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          currentUserId: me.id,
          users: const <KunChatUser>[haru, me],
          lastMessage: message(
            kind: KunChatMessageKind.service,
            senderId: me.id,
            serviceAction: const KunChatGroupCreatedAction(title: 'Room'),
          ),
        ),
      ),
    );
    expect(
      find.text(
        KunMessages.en.chatService.groupCreatedTitled(
          actor: KunMessages.en.chat.you,
          title: 'Room',
        ),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(text: 'file'),
          lastMessageSender: 'You',
        ),
      ),
    );
    expect(
      find.text(KunMessages.en.chat.senderPrefix(name: 'You')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(
            text: '',
            media: const KunChatPhoto(imageHash: 'h', width: 10, height: 10),
          ),
        ),
      ),
    );
    expect(find.text(KunMessages.en.chat.photo), findsOneWidget);
    expect(find.byIcon(KunIcons.image), findsOneWidget);
  });

  testWidgets('badges: mention, unread cap, muted, marked unread, pin', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const KunChatConversationItem(
          user: haru,
          mentionCount: 2,
          unreadCount: 1200,
        ),
      ),
    );
    expect(find.byIcon(KunIcons.atSign), findsOneWidget);
    expect(find.text('999+'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        const KunChatConversationItem(user: haru, unreadCount: 3, muted: true),
      ),
    );
    expect(find.byIcon(KunIcons.bellOff), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const KunChatConversationItem(user: haru, markedUnread: true)),
    );
    expect(find.text('0'), findsNothing);
    expect(find.byIcon(KunIcons.pin), findsNothing);

    await tester.pumpWidget(
      wrap(const KunChatConversationItem(user: haru, pinned: true)),
    );
    expect(find.byIcon(KunIcons.pin), findsOneWidget);
  });

  testWidgets('unread badge digit is not read after the unread label', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final DateTime at = DateTime(2026, 9, 27, 9, 14);
    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(createdAt: at, text: 'hello'),
          unreadCount: 1,
        ),
      ),
    );
    final String unread = KunMessages.en.chat.unreadCount(count: 1);
    final List<String> parts = <String>[];
    void walk(SemanticsNode node) {
      final String part = node.getSemanticsData().label;
      if (part.isNotEmpty) {
        parts.add(part);
      }
      node.visitChildren((SemanticsNode child) {
        walk(child);
        return true;
      });
    }

    walk(tester.getSemantics(find.byType(KunChatConversationItem)));
    final String label = parts.join(' | ');
    expect(unread.allMatches(label), hasLength(1));
    final String after = label.substring(label.indexOf(unread) + unread.length);
    expect(RegExp(r'(^|[\s|])1(\s|$|\|)').hasMatch(after), isFalse);
    semantics.dispose();
  });

  testWidgets('status icons', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(),
          status: KunChatSendStatus.sending,
        ),
      ),
    );
    expect(find.byIcon(KunIcons.clock), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(),
          status: KunChatSendStatus.read,
        ),
      ),
    );
    expect(find.byIcon(KunIcons.checkCheck), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(),
          status: KunChatSendStatus.failed,
        ),
      ),
    );
    expect(find.byIcon(KunIcons.circleAlert), findsOneWidget);
  });

  testWidgets('selected maps to the semantic selected state', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(),
          selected: true,
          onTap: () {},
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(KunChatConversationItem)),
      isSemantics(
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('custom semantics actions fire onAction', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final List<String> log = <String>[];
    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(),
          leadingActions: const <KunChatSwipeAction>[
            KunChatSwipeAction(key: 'read', label: 'Read'),
          ],
          trailingActions: const <KunChatSwipeAction>[
            KunChatSwipeAction(key: 'mute', label: 'Mute'),
          ],
          onAction: log.add,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(KunChatConversationItem)),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
        customActions: <CustomSemanticsAction>[
          CustomSemanticsAction(label: 'Read'),
          CustomSemanticsAction(label: 'Mute'),
        ],
      ),
    );
    tester.semantics.customAction(
      find.semantics.byPredicate(
        (SemanticsNode node) =>
            node.getSemanticsData().hasAction(SemanticsAction.customAction),
      ),
      const CustomSemanticsAction(label: 'Read'),
    );
    await tester.pump();
    expect(log, <String>['read']);
    semantics.dispose();
  });

  testWidgets('a touch swipe opens, a tap closes, an action fires', (
    WidgetTester tester,
  ) async {
    final List<String> taps = <String>[];
    final List<String> actions = <String>[];
    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(text: 'hello'),
          leadingActions: const <KunChatSwipeAction>[
            KunChatSwipeAction(key: 'read', label: 'Read'),
          ],
          trailingActions: const <KunChatSwipeAction>[
            KunChatSwipeAction(key: 'mute', label: 'Mute'),
          ],
          onTap: () => taps.add('tap'),
          onAction: actions.add,
        ),
      ),
    );
    final Finder title = find.text('Haru').first;
    final double origin = tester.getTopLeft(title).dx;
    final Offset center = tester.getCenter(
      find.byType(KunChatConversationItem),
    );
    final TestGesture gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(tester.getTopLeft(title).dx, greaterThan(origin + 20));
    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dx, closeTo(origin + 72, 2));

    await tester.tap(find.byType(KunChatConversationItem));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(taps, isEmpty);
    expect(tester.getTopLeft(title).dx, closeTo(origin, 2));

    final TestGesture open = await tester.startGesture(
      center,
      kind: PointerDeviceKind.touch,
    );
    await open.moveBy(const Offset(80, 0));
    await open.up();
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pump();
    expect(actions, <String>['read']);
  });

  testWidgets('a mouse drag does not swipe', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(text: 'hello'),
          leadingActions: const <KunChatSwipeAction>[
            KunChatSwipeAction(key: 'read', label: 'Read'),
          ],
        ),
      ),
    );
    final Finder title = find.text('Haru').first;
    final double origin = tester.getTopLeft(title).dx;
    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 100,
    );
    await gesture.addPointer(
      location: tester.getCenter(find.byType(KunChatConversationItem)),
    );
    addTearDown(gesture.removePointer);
    await gesture.down(
      tester.getCenter(find.byType(KunChatConversationItem)),
    );
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(tester.getTopLeft(title).dx, closeTo(origin, 1));
    await gesture.up();
  });

  testWidgets('onTap fires when the row is closed', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      wrapWebKeys(
        KunChatConversationItem(
          user: haru,
          lastMessage: message(),
          onTap: () => taps++,
        ),
      ),
    );
    await tester.tap(find.byType(KunChatConversationItem));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('title override, avatar, and group kind typing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatConversationItem(
          title: '校对组',
          kind: KunChatKind.group,
          avatar: 'https://example.com/g.png',
          users: const <KunChatUser>[haru],
          typing: <KunChatTypingEvent>[
            KunChatTypingEvent(userId: '1002', at: DateTime.now()),
          ],
        ),
      ),
    );
    expect(find.text('校对组'), findsOneWidget);
    expect(
      find.text(KunMessages.en.chatTyping.one(name: 'Haru')),
      findsOneWidget,
    );
  });
}
