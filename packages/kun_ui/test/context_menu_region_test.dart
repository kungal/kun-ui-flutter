import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Finder get menu => find.byKey(const ValueKey<String>('KunContextMenu.menu'));

const List<KunContextMenuItem> items = <KunContextMenuItem>[
  KunContextMenuItem(key: 'copy', label: 'Copy'),
  KunContextMenuItem(key: 'reply', label: 'Reply'),
];

const Key blank = ValueKey<String>('blank');
const Key likeKey = ValueKey<String>('like');

Widget wrap(Widget child) => KunTheme(
      data: KunThemeData.light(),
      child: WidgetsApp(
        color: KunColors.black,
        debugShowCheckedModeBanner: false,
        home: Center(child: child),
        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
            PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (BuildContext context, _, __) => builder(context),
        ),
      ),
    );

Future<void> pumpMenu(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(KunDurations.base);
}

void expectNear(Offset a, Offset b) {
  expect((a - b).distance, lessThan(1.5), reason: '$a vs $b');
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

Widget card({
  Key? key,
  bool longPress = true,
  ValueChanged<KunContextMenuItem>? onSelected,
  Widget? trailing,
  TapGestureRecognizer? link,
}) {
  return SizedBox(
    width: 320,
    child: KunContextMenuRegion(
      key: key,
      items: items,
      semanticActionLabel: 'Open actions',
      longPress: longPress,
      onSelected: onSelected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(
            key: blank,
            width: 320,
            height: 48,
            child: DecoratedBox(decoration: BoxDecoration()),
          ),
          KunButton(
            key: likeKey,
            size: KunUISize.sm,
            onPressed: () {},
            child: const Text('Like'),
          ),
          if (trailing != null) trailing,
          KunPressable(
            link: true,
            semanticLabel: 'permalink',
            onTap: () {},
            builder: (BuildContext context, KunPressableState state) =>
                const Text('permalink'),
          ),
          if (link != null)
            Text.rich(
              TextSpan(text: 'source', recognizer: link),
            ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('a right-click on blank space opens at the pointer',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(card()));
    final Offset at =
        tester.getTopLeft(find.byKey(blank)) + const Offset(12, 8);
    await tester.tapAt(at, buttons: kSecondaryMouseButton);
    await pumpMenu(tester);
    expect(menu, findsOneWidget);
    expectNear(tester.getTopLeft(menu), at);
  });

  testWidgets('a right-click on an inner KunButton opens too',
      (WidgetTester tester) async {
    int likes = 0;
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: KunContextMenuRegion(
            items: items,
            semanticActionLabel: 'Open actions',
            child: KunButton(
              key: likeKey,
              onPressed: () => likes++,
              child: const Text('Like'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(likeKey), buttons: kSecondaryMouseButton);
    await pumpMenu(tester);
    expect(menu, findsOneWidget);
    expect(likes, 0);
  });

  testWidgets(
    'a primary tap on the inner KunButton presses it and does not open',
    (WidgetTester tester) async {
      int likes = 0;
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 320,
            child: KunContextMenuRegion(
              items: items,
              semanticActionLabel: 'Open actions',
              child: KunButton(
                onPressed: () => likes++,
                child: const Text('Like'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Like'));
      await tester.pump();
      expect(likes, 1);
      expect(menu, findsNothing);
    },
  );

  testWidgets(
    'on Android a long press opens at the finger and vibrates',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      await tester.pumpWidget(wrap(card()));
      final Offset at =
          tester.getTopLeft(find.byKey(blank)) + const Offset(20, 10);
      await tester.longPressAt(at);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      expectNear(tester.getTopLeft(menu), at);
      expect(
        log,
        <Matcher>[
          isMethodCall('HapticFeedback.vibrate', arguments: null),
        ],
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'longPress: false does not open or vibrate',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      await tester.pumpWidget(wrap(card(longPress: false)));
      final Offset at =
          tester.getTopLeft(find.byKey(blank)) + const Offset(20, 10);
      await tester.longPressAt(at);
      await pumpMenu(tester);
      expect(menu, findsNothing);
      expect(log, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Shift+F10 with focus on the inner button opens at the button centre',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 320,
            child: KunContextMenuRegion(
              items: items,
              semanticActionLabel: 'Open actions',
              child: KunButton(
                onPressed: () {},
                child: const Text('Like'),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final Offset centre = tester.getCenter(find.byType(KunButton));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      expectNear(tester.getTopLeft(menu), centre);
    },
  );

  testWidgets(
    'an inner KunPressable with onSecondaryTap keeps Shift+F10 and Menu',
    (WidgetTester tester) async {
      final List<Offset> seen = <Offset>[];
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 320,
            child: KunContextMenuRegion(
              items: items,
              semanticActionLabel: 'Open actions',
              child: KunPressable(
                onSecondaryTap: seen.add,
                builder: (BuildContext context, KunPressableState state) =>
                    const SizedBox(width: 240, height: 56, child: Text('Row')),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await pumpMenu(tester);
      expect(seen, hasLength(2));
      expect(menu, findsNothing);
    },
  );

  testWidgets('openAt through a GlobalKey opens at that point',
      (WidgetTester tester) async {
    final GlobalKey<KunContextMenuRegionState> key =
        GlobalKey<KunContextMenuRegionState>();
    await tester.pumpWidget(wrap(card(key: key)));
    const Offset at = Offset(140, 90);
    key.currentState!.openAt(at);
    await pumpMenu(tester);
    expect(menu, findsOneWidget);
    expectNear(tester.getTopLeft(menu), at);
  });

  testWidgets('selecting an item calls onSelected and closes',
      (WidgetTester tester) async {
    final List<String> selected = <String>[];
    await tester.pumpWidget(
      wrap(card(
          onSelected: (KunContextMenuItem item) => selected.add(item.key))),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(blank)),
      buttons: kSecondaryMouseButton,
    );
    await pumpMenu(tester);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(selected, <String>['copy']);
    expect(menu, findsNothing);
  });

  testWidgets(
    'the region node has a custom action and no button flag; children stay',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final TapGestureRecognizer permalink = TapGestureRecognizer()
        ..onTap = () {};
      addTearDown(permalink.dispose);
      await tester.pumpWidget(wrap(card(link: permalink)));

      final SemanticsData region = tester
          .getSemantics(
              find.byKey(const ValueKey<String>('KunContextMenuRegion')))
          .getSemanticsData();
      expect(region.flagsCollection.isButton, isFalse);
      expect(region.hasAction(SemanticsAction.tap), isFalse);
      expect(region.hasAction(SemanticsAction.longPress), isFalse);
      expect(
        region,
        isSemantics(
          customActions: <CustomSemanticsAction>[
            CustomSemanticsAction(label: 'Open actions'),
          ],
        ),
      );

      expect(find.bySemanticsLabel('Like'), findsOneWidget);
      expect(find.bySemanticsLabel('permalink'), findsOneWidget);
      expect(find.text('source'), findsOneWidget);
      final SemanticsData like =
          tester.getSemantics(find.bySemanticsLabel('Like')).getSemanticsData();
      expect(like.flagsCollection.isButton, isTrue);
      expect(like.hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    },
  );

  testWidgets('invoking the custom action opens the menu',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(card()));
    tester.semantics.customAction(
      find.semantics.byPredicate(
        (SemanticsNode node) =>
            !node.getSemanticsData().flagsCollection.isButton &&
            node.getSemanticsData().hasAction(SemanticsAction.customAction),
      ),
      const CustomSemanticsAction(label: 'Open actions'),
    );
    await pumpMenu(tester);
    expect(menu, findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'a right-click off a KunSelectionArea selection opens through openAt',
    (WidgetTester tester) async {
      final GlobalKey<KunContextMenuRegionState> key =
          GlobalKey<KunContextMenuRegionState>();
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 320,
            child: KunContextMenuRegion(
              key: key,
              items: items,
              semanticActionLabel: 'Open actions',
              child: KunSelectionArea(
                onSecondaryTapOutsideSelection: (Offset p) =>
                    key.currentState!.openAt(p),
                child: const Text('hello world'),
              ),
            ),
          ),
        ),
      );
      final Offset at = tester.getCenter(find.text('hello world'));
      await tester.tapAt(at, buttons: kSecondaryMouseButton);
      await tester.pump();
      await pumpMenu(tester);
      expect(menu, findsOneWidget);
      expectNear(tester.getTopLeft(menu), at);
    },
  );

  testWidgets(
    'a long press on selectable text selects it; on blank space it opens',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        SelectedContent? selected;
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 320,
              child: KunContextMenuRegion(
                items: items,
                semanticActionLabel: 'Open actions',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    KunSelectionArea(
                      onSelectionChanged: (SelectedContent? c) => selected = c,
                      child: const Text('hello world'),
                    ),
                    const SizedBox(key: blank, height: 160),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.longPressAt(
          tester.getTopLeft(find.text('hello world')) + const Offset(8, 8),
        );
        await tester.pumpAndSettle();
        expect(selected?.plainText, isNotEmpty);
        expect(menu, findsNothing);

        await tester.longPressAt(
          tester.getBottomLeft(find.byKey(blank)) + const Offset(40, -12),
        );
        await tester.pumpAndSettle();
        expect(menu, findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
