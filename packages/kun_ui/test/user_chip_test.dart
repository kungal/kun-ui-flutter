import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/focus_outline.dart';

const KunUser kun = KunUser(id: 1, name: 'Kun', avatar: '');

Widget wrap(Widget child, {KunUIConfig? config, KunMessages? messages}) {
  Widget tree = child;
  if (config != null) {
    tree = KunUIConfigScope(config: config, child: tree);
  }
  if (messages != null) {
    tree = KunMessagesScope(messages: messages, child: tree);
  }
  return KunTheme(
    data: KunThemeData.light(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: tree),
    ),
  );
}

Widget wrapWebKeys(Widget child, {KunUIConfig? config}) => Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
      },
      child: wrap(child, config: config),
    );

void requestFocusOn(WidgetTester tester, Finder of) {
  Focus.of(
    tester.element(
      find.descendant(of: of, matching: find.byType(GestureDetector)).first,
    ),
  ).requestFocus();
}

TextStyle styleOf(WidgetTester tester, String text) => (tester
        .widget<RichText>(find.descendant(
          of: find.text(text),
          matching: find.byType(RichText),
        ))
        .text as TextSpan)
    .style!;

void main() {
  testWidgets('layout: avatar then text, 8 apart, centred', (tester) async {
    await tester.pumpWidget(
      wrap(const KunUserChip(user: kun, isNavigation: false)),
    );
    final Rect avatar = tester.getRect(find.byType(KunAvatar));
    final Rect name = tester.getRect(find.text('Kun'));
    expect(name.left - avatar.right, KunSpacing.unit * 2);
    expect(avatar.center.dy, closeTo(name.center.dy, 1));
  });

  testWidgets('size changes only the avatar', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunUserChip(
          user: kun,
          size: KunAvatarSize.md,
          isNavigation: false,
        ),
      ),
    );
    expect(tester.getSize(find.byType(KunAvatar)), const Size.square(32));
    expect(styleOf(tester, 'Kun').fontSize, KunText.sm.fontSize);

    await tester.pumpWidget(
      wrap(
        const KunUserChip(
          user: kun,
          size: KunAvatarSize.lg,
          isNavigation: false,
        ),
      ),
    );
    expect(tester.getSize(find.byType(KunAvatar)), const Size.square(40));
    expect(styleOf(tester, 'Kun').fontSize, KunText.sm.fontSize);
  });

  testWidgets('a 224-wide box truncates a long name and description',
      (tester) async {
    const String longName = '这是一个非常非常长的用户名会被自动截断显示省略号';
    const String longDescription = '同样很长的一段个人简介也会被截断而不会撑破布局';
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 224,
          child: KunUserChip(
            user: KunUser(id: 1, name: longName, avatar: ''),
            description: longDescription,
            isNavigation: false,
          ),
        ),
      ),
    );
    final RenderParagraph name = tester.renderObject<RenderParagraph>(
      find.text(longName),
    );
    final RenderParagraph description = tester.renderObject<RenderParagraph>(
      find.text(longDescription),
    );
    expect(name.maxLines, 1);
    expect(description.maxLines, 1);
    expect(name.didExceedMaxLines, isTrue);
    expect(description.didExceedMaxLines, isTrue);
    expect(tester.getSize(find.text(longName)).width, lessThan(224));
    expect(tester.getSize(find.text(longDescription)).width, lessThan(224));
  });

  testWidgets('name uses text-sm and the ambient colour', (tester) async {
    await tester.pumpWidget(
      wrap(const KunUserChip(user: kun, isNavigation: false)),
    );
    final TextStyle style = styleOf(tester, 'Kun');
    expect(style.fontSize, KunText.sm.fontSize);
    expect(style.color, KunColors.light.foreground);
  });

  testWidgets('description uses text-sm and neutral 500', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunUserChip(
          user: kun,
          description: 'admin',
          isNavigation: false,
        ),
      ),
    );
    final TextStyle style = styleOf(tester, 'admin');
    expect(style.fontSize, KunText.sm.fontSize);
    expect(style.color, KunColors.light.neutral.shade500);
  });

  testWidgets('empty name and null user both read unknownUser', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunUserChip(
          user: KunUser(id: 1, name: '', avatar: ''),
          isNavigation: false,
        ),
      ),
    );
    expect(find.text(KunMessages.zhCN.avatar.unknownUser), findsOneWidget);

    await tester.pumpWidget(
      wrap(const KunUserChip(user: null, isNavigation: false)),
    );
    expect(find.text(KunMessages.zhCN.avatar.unknownUser), findsOneWidget);
  });

  testWidgets('an empty description draws no second line', (tester) async {
    await tester.pumpWidget(
      wrap(const KunUserChip(user: kun, isNavigation: false)),
    );
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('the whole chip is one link that navigates once', (tester) async {
    final List<String> hrefs = <String>[];
    await tester.pumpWidget(
      wrap(
        const KunUserChip(
          user: KunUser(id: 42, name: 'Kun', avatar: ''),
          description: 'click',
        ),
        config: KunUIConfig(
          navigate: (BuildContext context, String href) => hrefs.add(href),
        ),
      ),
    );
    await tester.tap(find.byType(KunUserChip));
    expect(hrefs, <String>['/user/42/info']);
  });

  testWidgets('the inner avatar is not a link and does not scale on hover',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunUserChip(user: KunUser(id: 42, name: 'Kun', avatar: '')),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(KunAvatar),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is Semantics && widget.properties.link == true,
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(KunAvatar),
        matching: find.byType(AnimatedScale),
      ),
      findsNothing,
    );

    final TestGesture gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(KunAvatar)));
    await tester.pump();
    await tester.pump(KunDurations.fast);
    expect(
      find.descendant(
        of: find.byType(KunAvatar),
        matching: find.byType(AnimatedScale),
      ),
      findsNothing,
    );
  });

  testWidgets('Space and web-map Enter activate a focused chip',
      (tester) async {
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });

    final List<String> hrefs = <String>[];
    await tester.pumpWidget(
      wrapWebKeys(
        const KunUserChip(user: KunUser(id: 42, name: 'Kun', avatar: '')),
        config: KunUIConfig(
          navigate: (BuildContext context, String href) => hrefs.add(href),
        ),
      ),
    );
    requestFocusOn(tester, find.byType(KunUserChip));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(hrefs, <String>['/user/42/info']);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(hrefs, <String>['/user/42/info', '/user/42/info']);
  });

  testWidgets('one semantics node with name and description, name not repeated',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        const KunUserChip(
          user: kun,
          description: 'admin',
          isNavigation: false,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Kun\nadmin')),
      isSemantics(label: 'Kun\nadmin'),
    );
    expect(find.bySemanticsLabel(RegExp(r'^Kun$')), findsNothing);
    handle.dispose();
  });

  testWidgets('id 0 is not a link and does not navigate', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<String> hrefs = <String>[];
    await tester.pumpWidget(
      wrap(
        const KunUserChip(user: KunUser(id: 0, name: 'Kun', avatar: '')),
        config: KunUIConfig(
          navigate: (BuildContext context, String href) => hrefs.add(href),
        ),
      ),
    );
    expect(find.byType(FocusableActionDetector), findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Kun')),
      isSemantics(label: 'Kun'),
    );
    await tester.tap(find.byType(KunUserChip), warnIfMissed: false);
    expect(hrefs, isEmpty);
    handle.dispose();
  });

  testWidgets(
      'keyboard focus shows a rectangular primary outline; a tap does not',
      (tester) async {
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });

    await tester.pumpWidget(
      wrapWebKeys(
        const KunUserChip(user: KunUser(id: 42, name: 'Kun', avatar: '')),
      ),
    );
    await tester.pump();
    requestFocusOn(tester, find.byType(KunUserChip));
    await tester.pump();
    await tester.pump();
    final KunFocusOutline outline = tester.widget<KunFocusOutline>(
      find.byType(KunFocusOutline),
    );
    expect(outline.visible, isTrue);
    expect(outline.circle, isFalse);
    expect(outline.color, KunColors.light.primary.solid.withValues(alpha: 0.5));

    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pumpWidget(
      wrapWebKeys(
        const KunUserChip(user: KunUser(id: 42, name: 'Kun', avatar: '')),
      ),
    );
    await tester.tap(find.byType(KunUserChip));
    await tester.pump();
    expect(
      tester.widget<KunFocusOutline>(find.byType(KunFocusOutline)).visible,
      isFalse,
    );
  });
}
