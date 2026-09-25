import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/text_selection.dart';

Widget wrap(
  Widget child, {
  Alignment alignment = Alignment.center,
  Key? overlayKey,
}) =>
    KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          key: overlayKey ?? UniqueKey(),
          initialEntries: [
            OverlayEntry(
              builder: (context) => Align(
                  alignment: alignment,
                  child: SizedBox(width: 300, child: child)),
            ),
          ],
        ),
      ),
    );

Finder teardropHandles() => find.byWidgetPredicate((Widget widget) {
      if (widget is! CustomPaint) {
        return false;
      }
      return '${widget.painter.runtimeType}' == '_KunTeardropHandlePainter';
    });

Finder lollipopHandles() => find.byWidgetPredicate((Widget widget) {
      if (widget is! CustomPaint) {
        return false;
      }
      return '${widget.painter.runtimeType}' == '_KunLollipopHandlePainter';
    });

Finder menuPanel() => find.byWidgetPredicate((Widget widget) {
      if (widget is! DecoratedBox) {
        return false;
      }
      final Decoration decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.boxShadow == KunShadows.md;
    });

String? clipboardText;

Future<Object?> handleClipboard(MethodCall call) async {
  switch (call.method) {
    case 'Clipboard.getData':
      if (clipboardText == null) {
        return null;
      }
      return <String, dynamic>{'text': clipboardText};
    case 'Clipboard.hasStrings':
      return <String, dynamic>{
        'value': clipboardText != null && clipboardText!.isNotEmpty,
      };
    case 'Clipboard.setData':
      final Map<dynamic, dynamic> arguments =
          call.arguments as Map<dynamic, dynamic>;
      clipboardText = arguments['text'] as String?;
  }
  return null;
}

Future<void> pumpMenu(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(KunDurations.base);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    clipboardText = null;
    testerBindingMessenger().setMockMethodCallHandler(
      SystemChannels.platform,
      handleClipboard,
    );
  });

  tearDown(() {
    testerBindingMessenger().setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets(
    'android long-press selects a word, shows teardrop handles and the touch bar',
    (tester) async {
      await tester.pumpWidget(wrap(const KunInput(value: 'hello world')));
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);

      final TextEditingController controller =
          tester.widget<EditableText>(find.byType(EditableText)).controller;
      expect(controller.selection.isCollapsed, isFalse);
      expect(
        controller.selection.textInside(controller.text),
        anyOf('hello', 'world'),
      );
      expect(teardropHandles(), findsNWidgets(2));
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('剪切'), findsOneWidget);
      expect(find.text('全选'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'android paste copies the selection and inserts at a collapsed caret',
    (tester) async {
      clipboardText = 'hello';
      final List<String> seen = <String>[];
      await tester.pumpWidget(
        wrap(KunInput(value: 'hello world', onChanged: seen.add)),
      );
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);
      expect(find.text('粘贴'), findsOneWidget);

      await tester.tap(find.text('复制'));
      await tester.pump();
      expect(clipboardText, anyOf('hello', 'world'));

      final EditableTextState state =
          tester.state<EditableTextState>(find.byType(EditableText));
      state.widget.controller.selection = TextSelection.collapsed(
        offset: state.widget.controller.text.length,
      );
      await tester.pump();
      expect(state.showToolbar(), isTrue);
      await pumpMenu(tester);

      await tester.tap(find.text('粘贴'));
      await tester.pump();
      await tester.pump();
      expect(seen, isNotEmpty);
      expect(seen.last, contains(clipboardText!));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'android touch bar sits above the selection when there is room, below when there is not',
    (tester) async {
      await tester.pumpWidget(wrap(const KunInput(value: 'hello world')));
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);
      final Rect fieldCenter = tester.getRect(find.byType(KunInput));
      final Rect barAbove = tester.getRect(menuPanel());
      expect(barAbove.bottom, lessThanOrEqualTo(fieldCenter.center.dy));

      await tester.pumpWidget(
        wrap(
          const KunInput(value: 'hello world'),
          alignment: Alignment.topCenter,
        ),
      );
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);
      final Rect fieldTop = tester.getRect(find.byType(KunInput));
      final Rect barBelow = tester.getRect(menuPanel());
      expect(barBelow.top, greaterThanOrEqualTo(fieldTop.center.dy));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'android touch bar items are buttons with labels and tap actions',
    (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(wrap(const KunInput(value: 'hello world')));
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);

      for (final String label in <String>['复制', '剪切', '全选']) {
        expect(
          tester.getSemantics(find.text(label)),
          isSemantics(
            label: label,
            isButton: true,
            hasTapAction: true,
          ),
        );
      }
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'linux secondary tap opens a desktop menu at the click point',
    (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(wrap(const KunInput(value: 'hello world')));
      final Offset click = tester.getCenter(find.byType(EditableText));
      await tester.tapAt(
        click,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await pumpMenu(tester);

      expect(find.text('全选'), findsOneWidget);
      final Rect panel = tester.getRect(menuPanel());
      expect(panel.topLeft, click);
      expect(panel.width, greaterThanOrEqualTo(192));

      final Rect copy = tester.getRect(find.text('全选'));
      expect(copy.top, greaterThan(panel.top));

      expect(
        tester.getSemantics(find.text('全选')).getSemanticsData().role,
        SemanticsRole.menuItem,
      );
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'linux right-click near the bottom-right corner keeps the menu 12px inside the view',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          const KunInput(value: 'hello world'),
          alignment: Alignment.bottomRight,
        ),
      );
      final Rect field = tester.getRect(find.byType(EditableText));
      final Offset click = Offset(field.right - 4, field.bottom - 4);
      await tester.tapAt(
        click,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await pumpMenu(tester);

      final Rect panel = tester.getRect(menuPanel());
      final Size view = tester.view.physicalSize;
      expect(panel.left, greaterThanOrEqualTo(12));
      expect(panel.top, greaterThanOrEqualTo(12));
      expect(panel.right, lessThanOrEqualTo(view.width - 12));
      expect(panel.bottom, lessThanOrEqualTo(view.height - 12));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'android handle colour follows the field and a rebuild leaves the bar open',
    (tester) async {
      late StateSetter setHarness;
      await tester.pumpWidget(
        KunTheme(
          data: KunThemeData.light(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (BuildContext context) {
                    return StatefulBuilder(
                      builder: (BuildContext context, StateSetter setState) {
                        setHarness = setState;
                        return const Center(
                          child: SizedBox(
                            width: 300,
                            child: KunInput(
                              value: 'hello world',
                              color: KunUIColor.danger,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      final EditableText editable =
          tester.widget<EditableText>(find.byType(EditableText));
      final KunTextSelectionControls controls =
          editable.selectionControls! as KunTextSelectionControls;
      expect(
        controls.handleColor,
        KunUIColor.danger.scaleOf(KunThemeData.light().colors).solid,
      );

      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);
      expect(find.text('复制'), findsOneWidget);

      setHarness(() {});
      await tester.pump();
      expect(find.text('复制'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'android theme and messages inside the overlay entry still reach the menu',
    (tester) async {
      await tester.pumpWidget(
        KunTheme(
          data: KunThemeData.light(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Overlay(
              key: UniqueKey(),
              initialEntries: [
                OverlayEntry(
                  builder: (BuildContext context) {
                    return KunTheme(
                      data: KunThemeData.dark(),
                      child: const KunMessagesScope(
                        messages: KunMessages.en,
                        child: Center(
                          child: SizedBox(
                            width: 300,
                            child: KunInput(value: 'hello world'),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);

      expect(find.text('Copy'), findsOneWidget);
      final DecoratedBox panel = tester.widget<DecoratedBox>(menuPanel());
      expect(
        (panel.decoration as BoxDecoration).color,
        KunThemeData.dark().colors.content1,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS uses SystemContextMenu when supported and the KunUI bar otherwise',
    (tester) async {
      Future<void> pumpField({required bool systemMenu}) async {
        await tester.pumpWidget(
          Localizations(
            locale: const Locale('zh', 'CN'),
            delegates: const <LocalizationsDelegate<dynamic>>[
              DefaultWidgetsLocalizations.delegate,
            ],
            child: KunTheme(
              data: KunThemeData.light(),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Builder(
                  builder: (BuildContext context) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        supportsShowingSystemContextMenu: systemMenu,
                      ),
                      child: Overlay(
                        key: UniqueKey(),
                        initialEntries: [
                          OverlayEntry(
                            builder: (BuildContext context) => const Center(
                              child: SizedBox(
                                width: 300,
                                child: KunInput(value: 'hello world'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }

      await pumpField(systemMenu: true);
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);

      expect(find.byType(SystemContextMenu), findsOneWidget);
      expect(menuPanel(), findsNothing);
      final SystemContextMenu system =
          tester.widget<SystemContextMenu>(find.byType(SystemContextMenu));
      for (final IOSSystemContextMenuItem item in system.items) {
        switch (item) {
          case IOSSystemContextMenuItemLookUp():
            expect(item.title, KunMessages.zhCN.textSelection.lookUp);
          case IOSSystemContextMenuItemSearchWeb():
            expect(item.title, KunMessages.zhCN.textSelection.searchWeb);
          case IOSSystemContextMenuItemShare():
            expect(item.title, KunMessages.zhCN.textSelection.share);
          default:
            break;
        }
      }
      final EditableText editable =
          tester.widget<EditableText>(find.byType(EditableText));
      final KunTextSelectionControls controls =
          editable.selectionControls! as KunTextSelectionControls;
      expect(controls.getHandleSize(20).width, 12);
      expect(lollipopHandles(), findsWidgets);

      await pumpField(systemMenu: false);
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);
      expect(find.byType(SystemContextMenu), findsNothing);
      expect(find.text('复制'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'android KunTextarea long-press shows the bar; readOnly drops cut',
    (tester) async {
      await tester.pumpWidget(wrap(const KunTextarea(value: 'hello world')));
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('剪切'), findsOneWidget);

      await tester.pumpWidget(
        wrap(const KunTextarea(value: 'hello world', readOnly: true)),
      );
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('全选'), findsOneWidget);
      expect(find.text('剪切'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a disabled field has no selectionControls',
    (tester) async {
      await tester.pumpWidget(wrap(const KunInput(disabled: true)));
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .selectionControls,
        isNull,
      );

      await tester.pumpWidget(
        wrap(const KunTextarea(disabled: true)),
      );
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .selectionControls,
        isNull,
      );
    },
  );

  testWidgets(
    'reduced motion shows the menu fully in its first frame',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: wrap(const KunInput(value: 'hello world')),
        ),
      );
      await tester.longPress(find.byType(EditableText));
      await tester.pump();

      final FadeTransition fade = tester.widget<FadeTransition>(
        find
            .ancestor(of: menuPanel(), matching: find.byType(FadeTransition))
            .first,
      );
      expect(fade.opacity.value, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'fuchsia gets the desktop menu, as Material\'s adaptive toolbar does',
    (tester) async {
      await tester.pumpWidget(wrap(const KunInput(value: 'hello world')));
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);
      expect(
        find.ancestor(
          of: find.text('复制'),
          matching: find.byType(IntrinsicWidth),
        ),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.fuchsia),
  );

  testWidgets(
    'a wrapped touch bar is its own semantics group, ordered by list',
    (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(700, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      clipboardText = 'x';
      testerBindingMessenger().setMockMethodCallHandler(
        SystemChannels.processText,
        (MethodCall call) async => call.method == 'ProcessText.queryTextActions'
            ? <String, String>{
                'a': 'Translate',
                'b': 'Read aloud',
                'c': 'Ask Gemini',
              }
            : null,
      );
      addTearDown(
        () => testerBindingMessenger()
            .setMockMethodCallHandler(SystemChannels.processText, null),
      );
      // A page node spanning the screen, as every app has, is what puts the
      // bar's rows into one geometric group with the page.
      await tester.pumpWidget(
        KunTheme(
          data: KunThemeData.light(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Overlay(
              initialEntries: <OverlayEntry>[
                OverlayEntry(
                  builder: (BuildContext context) => Semantics(
                    container: true,
                    label: 'page',
                    child: const SizedBox.expand(
                      child: Center(
                        child: SizedBox(
                          width: 300,
                          child: KunMessagesScope(
                            messages: KunMessages.en,
                            child: KunInput(value: 'hello world again'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.longPress(find.byType(EditableText));
      await pumpMenu(tester);

      final EditableTextState state =
          tester.state<EditableTextState>(find.byType(EditableText));
      final List<String> shown = <String>[
        for (final ContextMenuButtonItem item in state.contextMenuButtonItems)
          switch (item.type) {
            ContextMenuButtonType.cut => 'Cut',
            ContextMenuButtonType.copy => 'Copy',
            ContextMenuButtonType.paste => 'Paste',
            ContextMenuButtonType.share => 'Share',
            ContextMenuButtonType.selectAll => 'Select all',
            _ => item.label ?? '',
          },
      ];
      final Set<double> lines = <double>{
        for (final String label in shown)
          tester.getTopLeft(find.text(label)).dy,
      };
      expect(lines.length, greaterThan(1),
          reason: 'the bar has to wrap for this test to mean anything');

      final SemanticsNode first = tester.semantics.find(find.text('Cut'));
      final List<SemanticsNode> siblings = <SemanticsNode>[];
      first.parent!.visitChildren((SemanticsNode node) {
        siblings.add(node);
        return true;
      });
      expect(
        siblings.map((SemanticsNode node) => node.label).toSet(),
        shown.toSet(),
      );
      for (final SemanticsNode node in siblings) {
        expect(
          (node.sortKey! as OrdinalSortKey).order,
          shown.indexOf(node.label),
          reason: node.label,
        );
      }
      handle.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

TestDefaultBinaryMessenger testerBindingMessenger() =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
