import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child, {Size size = const Size(480, 800)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: KunMessagesScope(
      messages: KunMessages.en,
      child: KunTheme(
        data: KunThemeData.light(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(width: size.width, child: child),
          ),
        ),
      ),
    ),
  );
}

const KunChatUser haru = KunChatUser(
  id: '1002',
  name: 'Haru',
  avatar: 'https://example.test/haru.webp',
);

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

Finder get backIcon => find.byIcon(KunIcons.arrowLeft);

void main() {
  testWidgets('title defaults to the user name and shows the subtitle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(const KunChatHeader(user: haru, subtitle: 'last seen')),
    );
    expect(find.text('Haru'), findsWidgets);
    expect(find.text('last seen'), findsOneWidget);
    final KunAvatar avatar = tester.widget<KunAvatar>(find.byType(KunAvatar));
    expect(avatar.user!.avatar, haru.avatar);
    expect(avatar.size, KunAvatarSize.lg);
    expect(avatar.isNavigation, isFalse);
  });

  testWidgets('title and avatar props override the user', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const KunChatHeader(
          user: haru,
          title: 'Proofreading',
          avatar: 'https://example.test/group.webp',
          subtitle: '4 members',
        ),
      ),
    );
    expect(find.text('Proofreading'), findsWidgets);
    expect(find.text('Haru'), findsNothing);
    expect(
      tester.widget<KunAvatar>(find.byType(KunAvatar)).user!.avatar,
      'https://example.test/group.webp',
    );
  });

  testWidgets('subtitleWidget replaces the string when nobody is typing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const KunChatHeader(
          user: haru,
          subtitle: 'string line',
          subtitleWidget: Text('slot line'),
        ),
      ),
    );
    expect(find.text('slot line'), findsOneWidget);
    expect(find.text('string line'), findsNothing);
  });

  testWidgets('typing replaces the subtitle and then yields it back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatHeader(
          user: haru,
          subtitle: 'last seen',
          typing: <KunChatTypingEvent>[
            KunChatTypingEvent(userId: haru.id, at: DateTime.now()),
          ],
        ),
      ),
    );
    expect(find.text(KunMessages.en.chatTyping.typing), findsOneWidget);
    expect(find.text('last seen'), findsNothing);

    await tester.pump(kunChatTypingTimeout);
    await tester.pump();
    expect(find.text(KunMessages.en.chatTyping.typing), findsNothing);
    expect(find.text('last seen'), findsOneWidget);
  });

  testWidgets('a group names who is typing', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        KunChatHeader(
          title: 'Group',
          kind: KunChatKind.group,
          users: const <KunChatUser>[haru],
          typing: <KunChatTypingEvent>[
            KunChatTypingEvent(userId: haru.id, at: DateTime.now()),
          ],
        ),
      ),
    );
    expect(
      find.text(KunMessages.en.chatTyping.one(name: 'Haru')),
      findsOneWidget,
    );
  });

  testWidgets('back visibility follows the mode and the viewport', (
    WidgetTester tester,
  ) async {
    Future<void> pump({required KunChatHeaderBack back, required Size size}) {
      return tester.pumpWidget(
        wrap(
          KunChatHeader(user: haru, back: back),
          size: size,
        ),
      );
    }

    const Size phone = Size(390, 844);
    const Size desktop = Size(1000, 700);

    await pump(back: KunChatHeaderBack.mobile, size: phone);
    expect(backIcon, findsOneWidget);
    await pump(back: KunChatHeaderBack.mobile, size: desktop);
    expect(backIcon, findsNothing);

    await pump(back: KunChatHeaderBack.always, size: desktop);
    expect(backIcon, findsOneWidget);
    await pump(back: KunChatHeaderBack.always, size: phone);
    expect(backIcon, findsOneWidget);

    await pump(back: KunChatHeaderBack.never, size: phone);
    expect(backIcon, findsNothing);
    await pump(back: KunChatHeaderBack.never, size: desktop);
    expect(backIcon, findsNothing);
  });

  testWidgets('onBack and onTitleTap fire', (WidgetTester tester) async {
    var backs = 0;
    var titles = 0;
    await tester.pumpWidget(
      wrap(
        KunChatHeader(
          user: haru,
          back: KunChatHeaderBack.always,
          onBack: () => backs += 1,
          onTitleTap: () => titles += 1,
        ),
      ),
    );
    await tester.tap(backIcon);
    await tester.pump();
    expect(backs, 1);
    expect(titles, 0);

    await tester.tap(find.text('Haru').first);
    await tester.pump();
    expect(titles, 1);
  });

  testWidgets('the actions slot is on the right', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        KunChatHeader(
          user: haru,
          actions: KunButton(
            isIconOnly: true,
            semanticLabel: 'Search',
            onPressed: () {},
            child: const Icon(KunIcons.search),
          ),
        ),
      ),
    );
    expect(find.byIcon(KunIcons.search), findsOneWidget);
  });

  testWidgets('has no unnamed actionable node', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        KunChatHeader(
          user: haru,
          back: KunChatHeaderBack.always,
          onBack: () {},
          onTitleTap: () {},
          actions: KunButton(
            isIconOnly: true,
            semanticLabel: 'Search',
            onPressed: () {},
            child: const Icon(KunIcons.search),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel(KunMessages.en.chat.back), findsOneWidget);
    expect(find.bySemanticsLabel('Haru'), findsOneWidget);
    expect(
      unnamedActionable(tester.getSemantics(find.byType(KunChatHeader))),
      isEmpty,
    );
    handle.dispose();
  });
}
