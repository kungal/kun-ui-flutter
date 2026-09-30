import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Finder get menu => find.byKey(const ValueKey<String>('KunContextMenu.menu'));

Finder item(String key) =>
    find.byKey(ValueKey<String>('KunContextMenu.item.$key'));

const List<KunContextMenuItem> menuItems = <KunContextMenuItem>[
  KunContextMenuItem(key: 'copy', label: 'Copy link'),
  KunContextMenuItem(key: 'open', label: 'Open'),
];

const Key content = ValueKey<String>('content');

KunLinkMenu testMenu(List<String> log) => KunLinkMenu(
      items: (Uri url) => menuItems,
      onSelected: (KunContextMenuItem item, Uri url) =>
          log.add('${item.key} $url'),
    );

Widget wrap(
  Widget child, {
  KunUIConfig? config,
}) {
  Widget tree = child;
  if (config != null) {
    tree = KunUIConfigScope(config: config, child: tree);
  }
  return KunTheme(
    data: KunThemeData.light(),
    child: WidgetsApp(
      color: KunColors.black,
      debugShowCheckedModeBanner: false,
      home: Center(child: tree),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (BuildContext context, _, __) => builder(context),
      ),
    ),
  );
}

Future<void> pumpMenu(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(KunDurations.base);
}

List<MethodCall> mockPlatform(WidgetTester tester) {
  final List<MethodCall> log = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate' ||
          call.method == 'SystemSound.play') {
        log.add(call);
      }
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  return log;
}

KunPressable pressableRow({
  Uri? linkUrl,
  VoidCallback? onTap,
  ValueChanged<Offset>? onSecondaryTap,
  ValueChanged<Offset>? onLongPress,
  bool disabled = false,
  Widget? trailing,
}) {
  return KunPressable(
    key: content,
    linkUrl: linkUrl,
    onTap: onTap ?? () {},
    onSecondaryTap: onSecondaryTap,
    onLongPress: onLongPress,
    disabled: disabled,
    builder: (BuildContext context, KunPressableState state) {
      return SizedBox(
        width: 240,
        height: 56,
        child: Row(
          children: <Widget>[
            const Expanded(child: Text('Topic title')),
            if (trailing != null) trailing,
          ],
        ),
      );
    },
  );
}

SemanticsData linkData(WidgetTester tester, Finder of) {
  return tester.getSemantics(of).getSemanticsData();
}

void main() {
  group('KunPressable', () {
    testWidgets('a right-click opens at the pointer and a row calls onSelected',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      await tester.pumpWidget(
        wrap(
          pressableRow(linkUrl: Uri.parse('/topic/1')),
          config: KunUIConfig(linkMenu: testMenu(log)),
        ),
      );
      final Offset at =
          tester.getTopLeft(find.byKey(content)) + const Offset(12, 8);
      await tester.tapAt(at, buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      await tester.tap(item('copy'));
      await tester.pumpAndSettle();
      expect(log, <String>['copy /topic/1']);
      expect(menu, findsNothing);
    });

    testWidgets(
      'a long press opens at the finger and vibrates',
      (WidgetTester tester) async {
        final List<MethodCall> haptic = mockPlatform(tester);
        final List<String> log = <String>[];
        await tester.pumpWidget(
          wrap(
            pressableRow(linkUrl: Uri.parse('/topic/1')),
            config: KunUIConfig(linkMenu: testMenu(log)),
          ),
        );
        final Offset at =
            tester.getTopLeft(find.byKey(content)) + const Offset(20, 10);
        await tester.longPressAt(at);
        await pumpMenu(tester);
        expect(menu, findsOneWidget);
        expect(
          haptic,
          <Matcher>[
            isMethodCall('HapticFeedback.vibrate', arguments: null),
          ],
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('Shift+F10 and the Menu key open at the centre',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      await tester.pumpWidget(
        wrap(
          pressableRow(linkUrl: Uri.parse('/topic/1')),
          config: KunUIConfig(linkMenu: testMenu(log)),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(menu, findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
    });

    testWidgets(
        'semantics long-press is the link node, at its centre, with linkUrl',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<String> log = <String>[];
      final Uri url = Uri.parse('/topic/1');
      await tester.pumpWidget(
        wrap(
          pressableRow(linkUrl: url),
          config: KunUIConfig(linkMenu: testMenu(log)),
        ),
      );
      final SemanticsNode node = tester.getSemantics(find.byKey(content));
      final SemanticsData data = node.getSemanticsData();
      expect(data.flagsCollection.isLink, isTrue);
      expect(data.linkUrl, url);
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.longPress);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      handle.dispose();
    });

    testWidgets('onSecondaryTap replaces the link menu for that gesture',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      final List<Offset> own = <Offset>[];
      await tester.pumpWidget(
        wrap(
          pressableRow(
            linkUrl: Uri.parse('/topic/1'),
            onSecondaryTap: own.add,
          ),
          config: KunUIConfig(linkMenu: testMenu(log)),
        ),
      );
      await tester.tap(find.byKey(content), buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(own, isNotEmpty);
      expect(menu, findsNothing);
      expect(log, isEmpty);

      await tester.longPress(find.byKey(content));
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
    });

    testWidgets('onLongPress replaces the link menu for that gesture',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      final List<Offset> own = <Offset>[];
      await tester.pumpWidget(
        wrap(
          pressableRow(
            linkUrl: Uri.parse('/topic/1'),
            onLongPress: own.add,
          ),
          config: KunUIConfig(linkMenu: testMenu(log)),
        ),
      );
      await tester.longPress(find.byKey(content));
      await pumpMenu(tester);
      expect(own, isNotEmpty);
      expect(menu, findsNothing);

      await tester.tap(find.byKey(content), buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
    });

    testWidgets(
        'null linkMenu claims nothing; an ancestor long-press still wins',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int outer = 0;
      await tester.pumpWidget(
        wrap(
          GestureDetector(
            onLongPress: () => outer++,
            child: pressableRow(linkUrl: Uri.parse('/topic/1')),
          ),
        ),
      );
      final SemanticsData data = linkData(tester, find.byKey(content));
      expect(data.hasAction(SemanticsAction.longPress), isFalse);
      await tester.longPress(find.byKey(content));
      await pumpMenu(tester);
      expect(menu, findsNothing);
      expect(outer, 1);
      handle.dispose();
    });

    testWidgets('empty items claim nothing', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          pressableRow(linkUrl: Uri.parse('/topic/1')),
          config: KunUIConfig(
            linkMenu: KunLinkMenu(
              items: (Uri url) => const <KunMenuEntry>[],
              onSelected: (KunContextMenuItem item, Uri url) {},
            ),
          ),
        ),
      );
      expect(
        linkData(tester, find.byKey(content))
            .hasAction(SemanticsAction.longPress),
        isFalse,
      );
      await tester.tap(find.byKey(content), buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsNothing);
      handle.dispose();
    });

    testWidgets('a stateful child keeps its state when linkMenu is set',
        (WidgetTester tester) async {
      Widget tree(KunUIConfig config) => wrap(
            KunPressable(
              key: const ValueKey<String>('row'),
              linkUrl: Uri.parse('/topic/1'),
              onTap: () {},
              builder: (BuildContext context, KunPressableState state) {
                return const SizedBox(
                  width: 240,
                  height: 56,
                  child: _Tally(),
                );
              },
            ),
            config: config,
          );
      await tester.pumpWidget(tree(const KunUIConfig()));
      final _TallyState tally = tester.state(find.byType(_Tally));
      tally.bump();
      await tester.pump();
      expect(find.text('tally 1'), findsOneWidget);
      await tester.pumpWidget(
        tree(KunUIConfig(linkMenu: testMenu(<String>[]))),
      );
      expect(find.text('tally 1'), findsOneWidget);
      expect(tester.state(find.byType(_Tally)), same(tally));
    });

    testWidgets(
        'a nested KunButton keeps its press; the row still has the menu',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      int likes = 0;
      await tester.pumpWidget(
        wrap(
          pressableRow(
            linkUrl: Uri.parse('/topic/1'),
            trailing: KunButton(
              size: KunUISize.sm,
              onPressed: () => likes++,
              child: const Text('Like'),
            ),
          ),
          config: KunUIConfig(linkMenu: testMenu(log)),
        ),
      );
      await tester.tap(find.text('Like'));
      expect(likes, 1);
      await tester.tap(find.text('Topic title'),
          buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
    });

    testWidgets('link: true without a URL has no menu',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          KunPressable(
            link: true,
            onTap: () {},
            builder: (BuildContext context, KunPressableState state) =>
                const SizedBox(key: content, width: 240, height: 56),
          ),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      await tester.tapAt(
        tester.getTopLeft(find.byType(KunPressable)) + const Offset(12, 8),
        buttons: kSecondaryMouseButton,
      );
      await pumpMenu(tester);
      expect(menu, findsNothing);
    });

    testWidgets('disabled claims nothing', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          pressableRow(linkUrl: Uri.parse('/topic/1'), disabled: true),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      await tester.tap(find.byKey(content), buttons: kSecondaryMouseButton);
      await tester.longPress(find.byKey(content));
      await pumpMenu(tester);
      expect(menu, findsNothing);
    });

    testWidgets(
        'inside a region, a right-click on the link opens the link menu',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      final List<String> region = <String>[];
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 320,
            child: KunContextMenuRegion(
              items: const <KunMenuEntry>[
                KunContextMenuItem(key: 'reply', label: 'Reply'),
              ],
              semanticActionLabel: 'Open actions',
              onSelected: (KunContextMenuItem item) => region.add(item.key),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(
                    key: ValueKey<String>('blank'),
                    width: 320,
                    height: 48,
                    child: DecoratedBox(decoration: BoxDecoration()),
                  ),
                  pressableRow(linkUrl: Uri.parse('/topic/1')),
                ],
              ),
            ),
          ),
          config: KunUIConfig(linkMenu: testMenu(log)),
        ),
      );
      await tester.tap(find.byKey(content), buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(item('copy'), findsOneWidget);
      expect(item('reply'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('blank')),
        buttons: kSecondaryMouseButton,
      );
      await pumpMenu(tester);
      expect(item('reply'), findsOneWidget);
      expect(log, isEmpty);
    });
  });

  group('KunAvatar', () {
    testWidgets('a linked avatar opens the menu at the pointer',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      const KunUser user = KunUser(id: 42, name: 'Kun', avatar: '');
      await tester.pumpWidget(
        wrap(
          const KunAvatar(user: user),
          config: KunUIConfig(linkMenu: testMenu(log)),
        ),
      );
      await tester.tap(find.byType(KunAvatar), buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      await tester.tap(item('open'));
      await tester.pump();
      expect(log, <String>['open /user/42/info']);
    });

    testWidgets(
      'a long press opens at the finger and vibrates',
      (WidgetTester tester) async {
        final List<MethodCall> haptic = mockPlatform(tester);
        await tester.pumpWidget(
          wrap(
            const KunAvatar(user: KunUser(id: 42, name: 'Kun', avatar: '')),
            config: KunUIConfig(linkMenu: testMenu(<String>[])),
          ),
        );
        await tester.longPress(find.byType(KunAvatar));
        await pumpMenu(tester);
        expect(menu, findsOneWidget);
        expect(
          haptic,
          <Matcher>[
            isMethodCall('HapticFeedback.vibrate', arguments: null),
          ],
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('Shift+F10 opens at the avatar while focused',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const KunAvatar(user: KunUser(id: 42, name: 'Kun', avatar: '')),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      Focus.of(
        tester.element(
          find
              .descendant(
                of: find.byType(KunAvatar),
                matching: find.byType(GestureDetector),
              )
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
    });

    testWidgets('semantics long-press is the avatar link node',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          const KunAvatar(user: KunUser(id: 42, name: 'Kun', avatar: '')),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      final SemanticsNode node =
          tester.getSemantics(find.bySemanticsLabel('Kun'));
      final SemanticsData data = node.getSemanticsData();
      expect(data.flagsCollection.isLink, isTrue);
      expect(data.linkUrl, isNull);
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.longPress);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      handle.dispose();
    });

    testWidgets('id 0 is not a link and has no menu',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const KunAvatar(user: KunUser(id: 0, name: 'Kun', avatar: '')),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      await tester.tap(find.byType(KunAvatar), buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsNothing);
    });
  });

  group('KunUserChip', () {
    testWidgets('a linked chip opens the menu and keeps one link node',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<String> log = <String>[];
      await tester.pumpWidget(
        wrap(
          const KunUserChip(
            user: KunUser(id: 7, name: 'Kun', avatar: ''),
          ),
          config: KunUIConfig(linkMenu: testMenu(log)),
        ),
      );
      final SemanticsData data =
          tester.getSemantics(find.byType(KunUserChip)).getSemanticsData();
      expect(data.flagsCollection.isLink, isTrue);
      expect(data.linkUrl, isNull);
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
      await tester.tap(find.byType(KunUserChip),
          buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      handle.dispose();
    });

    testWidgets(
      'a long press opens at the finger and vibrates',
      (WidgetTester tester) async {
        final List<MethodCall> haptic = mockPlatform(tester);
        await tester.pumpWidget(
          wrap(
            const KunUserChip(
              user: KunUser(id: 7, name: 'Kun', avatar: ''),
            ),
            config: KunUIConfig(linkMenu: testMenu(<String>[])),
          ),
        );
        await tester.longPress(find.byType(KunUserChip));
        await pumpMenu(tester);
        expect(menu, findsOneWidget);
        expect(
          haptic,
          <Matcher>[
            isMethodCall('HapticFeedback.vibrate', arguments: null),
          ],
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('Shift+F10 opens at the chip while focused',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const KunUserChip(
            user: KunUser(id: 7, name: 'Kun', avatar: ''),
          ),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      Focus.of(
        tester.element(
          find
              .descendant(
                of: find.byType(KunUserChip),
                matching: find.byType(GestureDetector),
              )
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
    });
  });

  group('KunNavItem', () {
    testWidgets('an href item opens the menu', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 240,
            child: KunNavItem(label: 'Search', href: '/search'),
          ),
          config: KunUIConfig(linkMenu: testMenu(log)),
        ),
      );
      await tester.tap(find.text('Search'), buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      await tester.tap(item('copy'));
      await tester.pumpAndSettle();
      expect(log, <String>['copy /search']);
    });

    testWidgets('Shift+F10 opens at the item while focused',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 240,
            child: KunNavItem(label: 'Search', href: '/search'),
          ),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
    });

    testWidgets('without href there is no menu', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 240,
            child: KunNavItem(label: 'Search', onPressed: null),
          ),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      await tester.tap(find.text('Search'), buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsNothing);
    });

    testWidgets('semantics long-press is the item node',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 240,
            child: KunNavItem(label: 'Search', href: '/search'),
          ),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      final SemanticsNode node =
          tester.getSemantics(find.bySemanticsLabel('Search'));
      expect(
          node.getSemanticsData().hasAction(SemanticsAction.longPress), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.longPress);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      handle.dispose();
    });

    testWidgets('the semantics long-press follows a linkMenu set later',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      Widget tree(KunUIConfig config) => wrap(
            const SizedBox(
              width: 240,
              child: KunNavItem(label: 'Search', href: '/search'),
            ),
            config: config,
          );
      await tester.pumpWidget(tree(const KunUIConfig()));
      SemanticsData data() => tester
          .getSemantics(find.bySemanticsLabel('Search'))
          .getSemanticsData();
      expect(data().hasAction(SemanticsAction.longPress), isFalse);
      await tester.pumpWidget(
        tree(KunUIConfig(linkMenu: testMenu(<String>[]))),
      );
      expect(data().hasAction(SemanticsAction.longPress), isTrue);
      await tester.pumpWidget(tree(const KunUIConfig()));
      expect(data().hasAction(SemanticsAction.longPress), isFalse);
      handle.dispose();
    });

    testWidgets('an href that does not parse builds and claims nothing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 240,
            child: KunNavItem(label: 'Search', href: 'http://[bad'),
          ),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Search'), buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsNothing);
    });
  });

  group('KunTab', () {
    testWidgets('an href tab opens the menu', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await tester.pumpWidget(
        wrap(
          KunTab(
            items: const <KunTabItem>[
              KunTabItem(value: 'home', textValue: 'Home', href: '/'),
              KunTabItem(value: 'docs', textValue: 'Docs', href: '/docs'),
            ],
            value: 'home',
            onChanged: (_) {},
          ),
          config: KunUIConfig(linkMenu: testMenu(log)),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Docs'), buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      await tester.tap(item('open'));
      await tester.pumpAndSettle();
      expect(log, <String>['open /docs']);
    });

    testWidgets('Shift+F10 opens at the tab while focused',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          KunTab(
            items: const <KunTabItem>[
              KunTabItem(value: 'home', textValue: 'Home', href: '/'),
              KunTabItem(value: 'docs', textValue: 'Docs', href: '/docs'),
            ],
            value: 'home',
            onChanged: (_) {},
          ),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
    });

    testWidgets('a tab without href has no menu', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          KunTab(
            items: const <KunTabItem>[
              KunTabItem(value: 'home', textValue: 'Home'),
              KunTabItem(value: 'docs', textValue: 'Docs'),
            ],
            value: 'home',
            onChanged: (_) {},
          ),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Docs'), buttons: kSecondaryMouseButton);
      await pumpMenu(tester);
      expect(menu, findsNothing);
    });

    testWidgets('semantics long-press is the tab node',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          KunTab(
            items: const <KunTabItem>[
              KunTabItem(value: 'home', textValue: 'Home', href: '/'),
              KunTabItem(value: 'docs', textValue: 'Docs', href: '/docs'),
            ],
            value: 'home',
            onChanged: (_) {},
          ),
          config: KunUIConfig(linkMenu: testMenu(<String>[])),
        ),
      );
      await tester.pump();
      final SemanticsNode node =
          tester.getSemantics(find.bySemanticsLabel('Docs'));
      final SemanticsData data = node.getSemanticsData();
      expect(data.flagsCollection.isLink, isFalse);
      expect(data.linkUrl, isNull);
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.longPress);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      handle.dispose();
    });
  });
}

class _Tally extends StatefulWidget {
  const _Tally();

  @override
  State<_Tally> createState() => _TallyState();
}

class _TallyState extends State<_Tally> {
  int _count = 0;

  void bump() => setState(() => _count++);

  @override
  Widget build(BuildContext context) => Center(child: Text('tally $_count'));
}
