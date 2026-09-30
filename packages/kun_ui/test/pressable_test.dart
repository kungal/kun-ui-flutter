import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/focus_outline.dart';

Widget wrap(
  Widget child, {
  KunTapTargetSize tapTargetSize = KunTapTargetSize.adaptive,
}) =>
    KunTheme(
      data: KunThemeData.light(tapTargetSize: tapTargetSize),
      child: WidgetsApp(
        color: KunColors.black,
        home: Center(child: child),
        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
            PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (BuildContext context, _, __) => builder(context),
        ),
      ),
    );

const Key content = ValueKey<String>('content');

KunPressable row({
  VoidCallback? onTap,
  ValueChanged<Offset>? onSecondaryTap,
  ValueChanged<Offset>? onLongPress,
  bool disabled = false,
  String? semanticLabel,
  List<KunPressableState>? states,
  double height = 56,
  Widget? trailing,
}) =>
    KunPressable(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      onLongPress: onLongPress,
      disabled: disabled,
      semanticLabel: semanticLabel,
      builder: (BuildContext context, KunPressableState state) {
        states?.add(state);
        return SizedBox(
          key: content,
          width: 240,
          height: height,
          child: Row(
            children: <Widget>[
              const Expanded(child: Text('Topic title')),
              if (trailing != null) trailing,
            ],
          ),
        );
      },
    );

void main() {
  testWidgets('a tap, Enter and the web Enter all press it', (tester) async {
    int taps = 0;
    await tester.pumpWidget(wrap(row(onTap: () => taps++)));
    await tester.tap(find.byKey(content));
    expect(taps, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 3);

    final FocusNode focus = Focus.of(tester.element(find.byKey(content)));
    expect(focus.hasFocus, isTrue);
    Actions.invoke(
        tester.element(find.byKey(content)), const ButtonActivateIntent());
    expect(taps, 4);
  });

  testWidgets('a link takes Enter and leaves Space to the page',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int taps = 0;
    int fallthrough = 0;
    await tester.pumpWidget(
      wrap(
        Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) => fallthrough++,
              ),
            },
            child: KunPressable(
              link: true,
              onTap: () => taps++,
              builder: (BuildContext context, KunPressableState state) =>
                  const SizedBox(key: content, width: 240, height: 56),
            ),
          ),
        ),
      ),
    );
    final SemanticsData data =
        tester.getSemantics(find.byType(KunPressable)).getSemanticsData();
    expect(data.flagsCollection.isLink, isTrue);
    expect(data.flagsCollection.isButton, isFalse);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(find.byKey(content));
    expect(taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    expect(taps, 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 3);
    expect(fallthrough, 1);
    handle.dispose();
  });

  testWidgets('linkUrl makes a link and carries the URL', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int taps = 0;
    await tester.pumpWidget(
      wrap(
        KunPressable(
          linkUrl: Uri.parse('/topic/42'),
          onTap: () => taps++,
          builder: (BuildContext context, KunPressableState state) =>
              const SizedBox(key: content, width: 240, height: 56),
        ),
      ),
    );
    final SemanticsData data =
        tester.getSemantics(find.byType(KunPressable)).getSemanticsData();
    expect(data.flagsCollection.isLink, isTrue);
    expect(data.flagsCollection.isButton, isFalse);
    expect(data.linkUrl, Uri.parse('/topic/42'));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('selected and expanded reach the node, named or not',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    Future<SemanticsFlags> flags({
      bool? selected,
      bool? expanded,
      String? semanticLabel,
    }) async {
      await tester.pumpWidget(
        wrap(
          KunPressable(
            onTap: () {},
            selected: selected,
            expanded: expanded,
            semanticLabel: semanticLabel,
            builder: (BuildContext context, KunPressableState state) =>
                const SizedBox(width: 240, height: 56, child: Text('Rules')),
          ),
        ),
      );
      return tester
          .getSemantics(find.byType(KunPressable))
          .getSemanticsData()
          .flagsCollection;
    }

    SemanticsFlags f = await flags();
    expect(f.isSelected, Tristate.none);
    expect(f.isExpanded, Tristate.none);
    expect(f.isButton, isTrue);

    f = await flags(selected: true, expanded: false);
    expect(f.isSelected, Tristate.isTrue);
    expect(f.isExpanded, Tristate.isFalse);

    f = await flags(
      selected: false,
      expanded: true,
      semanticLabel: 'Entry rules',
    );
    expect(f.isSelected, Tristate.isFalse);
    expect(f.isExpanded, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('the builder sees hover, press and keyboard focus',
      (tester) async {
    final List<KunPressableState> states = <KunPressableState>[];
    await tester.pumpWidget(wrap(row(onTap: () {}, states: states)));
    expect(states.last, const KunPressableState());

    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(content)));
    await tester.pump();
    expect(states.last.hovered, isTrue);
    await mouse.down(tester.getCenter(find.byKey(content)));
    await tester.pump();
    expect(states.last.pressed, isTrue);
    await mouse.up();
    await tester.pump();
    expect(states.last.pressed, isFalse);
    expect(states.last.focused, isFalse,
        reason: 'a click is not focus-visible');
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(states.last.hovered, isFalse);

    final TestGesture touch = await tester.startGesture(
      tester.getCenter(find.byKey(content)),
    );
    await tester.pump();
    expect(states.last.hovered, isFalse, reason: 'a touch never hovers');
    expect(states.last.pressed, isTrue);
    await touch.up();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(states.last.focused, isTrue);
    expect(
      tester.widget<KunFocusOutline>(find.byType(KunFocusOutline)).visible,
      isTrue,
    );
  });

  testWidgets('a right-click, Shift+F10 and the Menu key open a menu',
      (tester) async {
    final List<Offset> menus = <Offset>[];
    await tester.pumpWidget(wrap(row(onSecondaryTap: menus.add)));
    final Rect box = tester.getRect(find.byType(KunPressable));
    final Offset at =
        tester.getTopLeft(find.byKey(content)) + const Offset(9, 7);
    await tester.tapAt(at, buttons: kSecondaryMouseButton);
    expect(menus, <Offset>[at]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    expect(menus.skip(1), <Offset>[box.center, box.center]);
  });

  testWidgets(
      'a long press hands over the finger, and a screen reader the '
      'centre', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<Offset> presses = <Offset>[];
    int taps = 0;
    await tester.pumpWidget(
      wrap(row(onTap: () => taps++, onLongPress: presses.add)),
    );
    final Offset at =
        tester.getTopLeft(find.byKey(content)) + const Offset(20, 10);
    await tester.longPressAt(at);
    expect(presses, <Offset>[at]);
    expect(taps, 0);

    final SemanticsNode node = tester.getSemantics(find.byType(KunPressable));
    node.owner!.performAction(node.id, SemanticsAction.longPress);
    expect(presses.last, tester.getCenter(find.byType(KunPressable)));
    handle.dispose();
  });

  testWidgets(
      'disabled blocks everything and says so, a null callback does '
      'neither', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int calls = 0;
    final List<KunPressableState> states = <KunPressableState>[];
    await tester.pumpWidget(
      wrap(
        row(
          onTap: () => calls++,
          onSecondaryTap: (_) => calls++,
          onLongPress: (_) => calls++,
          disabled: true,
          states: states,
        ),
      ),
    );
    await tester.tap(find.byKey(content));
    await tester.tapAt(tester.getCenter(find.byKey(content)),
        buttons: kSecondaryMouseButton);
    await tester.longPress(find.byKey(content));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 0);
    expect(states.last.disabled, isTrue);
    expect(states.last.focused, isFalse);
    final SemanticsData disabled =
        tester.getSemantics(find.byType(KunPressable)).getSemanticsData();
    expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
    expect(disabled.hasAction(SemanticsAction.tap), isFalse);

    await tester.pumpWidget(wrap(row()));
    final SemanticsData inert =
        tester.getSemantics(find.byType(KunPressable)).getSemanticsData();
    expect(inert.flagsCollection.isEnabled, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('the cursor follows what a click would do', (tester) async {
    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    Future<MouseCursor> cursorOver(KunPressable pressable) async {
      await tester.pumpWidget(wrap(pressable));
      await mouse.moveTo(tester.getCenter(find.byKey(content)));
      await tester.pump();
      return RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1)!;
    }

    expect(await cursorOver(row(onTap: () {})), SystemMouseCursors.click);
    expect(
      await cursorOver(row(onTap: () {}, disabled: true)),
      SystemMouseCursors.forbidden,
    );
    expect(await cursorOver(row()), SystemMouseCursors.basic);
  });

  testWidgets('one button node, named by its text or by semanticLabel',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        row(
          onTap: () {},
          trailing: KunButton(
            isIconOnly: true,
            size: KunUISize.sm,
            semanticLabel: 'Favourite',
            onPressed: () {},
            child: const Icon(KunIcons.x),
          ),
        ),
      ),
    );
    final SemanticsData data =
        tester.getSemantics(find.byType(KunPressable)).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.label, 'Topic title');
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(find.bySemanticsLabel('Favourite'), findsOneWidget);

    await tester.pumpWidget(
      wrap(row(onTap: () {}, semanticLabel: 'Open the topic')),
    );
    expect(
      tester.getSemantics(find.byType(KunPressable)).getSemanticsData().label,
      'Open the topic',
    );
    expect(find.bySemanticsLabel('Topic title'), findsNothing);
    handle.dispose();
  });

  testWidgets('a nested KunButton keeps its own press', (tester) async {
    int rows = 0;
    int buttons = 0;
    await tester.pumpWidget(
      wrap(
        row(
          onTap: () => rows++,
          trailing: KunButton(
            size: KunUISize.sm,
            onPressed: () => buttons++,
            child: const Text('Like'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Like'));
    expect((rows, buttons), (0, 1));
    await tester.tap(find.text('Topic title'));
    expect((rows, buttons), (1, 1));
  });

  testWidgets('a short one is padded on phones and draws unchanged',
      (tester) async {
    int taps = 0;
    await tester.pumpWidget(wrap(row(onTap: () => taps++, height: 32)));
    expect(tester.getSize(find.byKey(content)), const Size(240, 32));
    expect(tester.getSize(find.byType(KunPressable)), const Size(240, 48));
    await tester
        .tapAt(tester.getTopLeft(find.byKey(content)) - const Offset(-4, 5));
    expect(taps, 1);

    await tester.pumpWidget(
      wrap(
        row(onTap: () {}, height: 32),
        tapTargetSize: KunTapTargetSize.shrinkWrap,
      ),
    );
    expect(tester.getSize(find.byType(KunPressable)), const Size(240, 32));
  });

  testWidgets('it meets the Android guideline', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(row(onTap: () {}, height: 24)));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the focus ring hugs the drawn content at the theme radius',
      (tester) async {
    await tester.pumpWidget(wrap(row(onTap: () {}, height: 32)));
    final KunFocusOutline ring =
        tester.widget<KunFocusOutline>(find.byType(KunFocusOutline));
    expect(ring.borderRadius, BorderRadius.circular(KunUIRounded.md.radius));
    expect(
      tester.getSize(find.byType(KunFocusOutline)),
      tester.getSize(find.byKey(content)),
    );
    expect(debugDefaultTargetPlatformOverride, isNull);
  });
}
