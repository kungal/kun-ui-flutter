import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child) => KunTheme(
      data: KunThemeData.light(),
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

Finder teardropHandles() => find.byWidgetPredicate((Widget widget) {
      if (widget is! CustomPaint) {
        return false;
      }
      return '${widget.painter.runtimeType}' == '_KunTeardropHandlePainter';
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

TestDefaultBinaryMessenger testerBindingMessenger() =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

Future<void> pumpMenu(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(KunDurations.base);
}

Future<void> mouseDrag(
  WidgetTester tester, {
  required Offset from,
  required Offset to,
}) async {
  final TestGesture gesture = await tester.startGesture(
    from,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<void> mouseSelectHello(WidgetTester tester) async {
  final RenderParagraph paragraph = paragraphOf(tester, 'hello world');
  final List<TextBox> boxes = paragraph.getBoxesForSelection(
    const TextSelection(baseOffset: 0, extentOffset: 5),
  );
  final Rect hello = boxes.first.toRect();
  await mouseDrag(
    tester,
    from: paragraph.localToGlobal(hello.centerLeft) + const Offset(2, 0),
    to: paragraph.localToGlobal(hello.centerRight) - const Offset(2, 0),
  );
}

Future<void> withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  final TargetPlatform? previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}

Future<void> forBothCallbackModes(
  WidgetTester tester,
  Future<void> Function(ValueChanged<Offset>? callback, List<Offset> seen) body,
) async {
  await body(null, <Offset>[]);
  await tester.pumpWidget(const SizedBox());
  final List<Offset> seen = <Offset>[];
  await body(seen.add, seen);
}

RenderParagraph paragraphOf(WidgetTester tester, String text) {
  return tester.renderObject(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  ) as RenderParagraph;
}

Offset offsetOnFirstWord(WidgetTester tester, String text) {
  final RenderParagraph paragraph = paragraphOf(tester, text);
  final List<TextBox> boxes = paragraph.getBoxesForSelection(
    const TextSelection(baseOffset: 0, extentOffset: 5),
  );
  return paragraph.localToGlobal(boxes.first.toRect().center);
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
    'linux mouse drag reports the selection, Ctrl+C copies, Ctrl+A stays inside',
    (WidgetTester tester) async {
      await withPlatform(TargetPlatform.linux, () async {
        await forBothCallbackModes(tester, (
          ValueChanged<Offset>? callback,
          List<Offset> seen,
        ) async {
          clipboardText = null;
          SelectedContent? last;
          await tester.pumpWidget(
            wrap(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  KunSelectionArea(
                    onSelectionChanged: (SelectedContent? content) {
                      last = content;
                    },
                    onSecondaryTapOutsideSelection: callback,
                    child: const Text('hello world'),
                  ),
                  const Text('outside'),
                ],
              ),
            ),
          );

          await mouseSelectHello(tester);
          expect(last?.plainText, isNotNull);
          expect(last!.plainText, contains('h'));
          expect(last!.plainText.contains('outside'), isFalse);

          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pump();
          expect(clipboardText, last!.plainText);

          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pump();
          expect(last?.plainText, 'hello world');
          expect(last!.plainText.contains('outside'), isFalse);
          expect(seen, isEmpty);
        });
      });
    },
  );

  testWidgets(
    'android long-press selects a word, shows teardrop handles and the touch bar',
    (WidgetTester tester) async {
      await withPlatform(TargetPlatform.android, () async {
        await forBothCallbackModes(tester, (
          ValueChanged<Offset>? callback,
          List<Offset> seen,
        ) async {
          clipboardText = null;
          SelectedContent? last;
          await tester.pumpWidget(
            wrap(
              KunSelectionArea(
                onSelectionChanged: (SelectedContent? content) {
                  last = content;
                },
                onSecondaryTapOutsideSelection: callback,
                child: const Text('hello world'),
              ),
            ),
          );
          await tester.longPressAt(offsetOnFirstWord(tester, 'hello world'));
          await pumpMenu(tester);

          expect(last?.plainText, anyOf('hello', 'world'));
          expect(teardropHandles(), findsNWidgets(2));
          expect(find.text('复制'), findsOneWidget);
          expect(find.text('全选'), findsOneWidget);
          expect(seen, isEmpty);

          await tester.tap(find.text('复制'));
          await tester.pump();
          expect(clipboardText, anyOf('hello', 'world'));
        });
      });
    },
  );

  testWidgets(
    'linux secondary tap on the selection shows the desktop menu and keeps it',
    (WidgetTester tester) async {
      await withPlatform(TargetPlatform.linux, () async {
        await forBothCallbackModes(tester, (
          ValueChanged<Offset>? callback,
          List<Offset> seen,
        ) async {
          SelectedContent? last;
          await tester.pumpWidget(
            wrap(
              KunSelectionArea(
                onSelectionChanged: (SelectedContent? content) {
                  last = content;
                },
                onSecondaryTapOutsideSelection: callback,
                child: const Text('hello world'),
              ),
            ),
          );
          await mouseSelectHello(tester);
          final String selected = last!.plainText;
          expect(selected, isNotEmpty);

          await tester.tapAt(
            offsetOnFirstWord(tester, 'hello world'),
            buttons: kSecondaryMouseButton,
            kind: PointerDeviceKind.mouse,
          );
          await pumpMenu(tester);

          expect(find.text('复制'), findsOneWidget);
          expect(find.text('全选'), findsOneWidget);
          expect(last?.plainText, selected);
          expect(seen, isEmpty);
        });
      });
    },
  );

  testWidgets(
    'secondary tap off the selection with the callback set clears and reports',
    (WidgetTester tester) async {
      Future<void> run(TargetPlatform platform) async {
        await withPlatform(platform, () async {
          final List<Offset> seen = <Offset>[];
          SelectedContent? last;
          await tester.pumpWidget(
            wrap(
              KunSelectionArea(
                onSelectionChanged: (SelectedContent? content) {
                  last = content;
                },
                onSecondaryTapOutsideSelection: seen.add,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('hello world'),
                    SizedBox(height: 24),
                    Text('other line'),
                  ],
                ),
              ),
            ),
          );
          await mouseSelectHello(tester);
          expect(last?.plainText, isNotEmpty);

          final Offset offSelection = tester.getCenter(find.text('other line'));
          await tester.tapAt(
            offSelection,
            buttons: kSecondaryMouseButton,
            kind: PointerDeviceKind.mouse,
          );
          await tester.pump();
          await tester.pump(KunDurations.base);

          expect(seen, <Offset>[offSelection]);
          expect(menuPanel(), findsNothing);
          expect(last?.plainText ?? '', isEmpty);
        });
      }

      await run(TargetPlatform.linux);
      await tester.pumpWidget(const SizedBox());
      await run(TargetPlatform.windows);
      await tester.pumpWidget(const SizedBox());
      await run(TargetPlatform.macOS);
      await tester.pumpWidget(const SizedBox());
      await run(TargetPlatform.iOS);
    },
  );

  testWidgets(
    'linux secondary tap with the callback null still opens the menu',
    (WidgetTester tester) async {
      await withPlatform(TargetPlatform.linux, () async {
        await tester.pumpWidget(
          wrap(const KunSelectionArea(child: Text('hello world'))),
        );
        final Offset at = tester.getCenter(find.text('hello world'));
        await tester.tapAt(
          at,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await pumpMenu(tester);
        expect(find.text('全选'), findsOneWidget);
      });
    },
  );

  testWidgets('setting the callback later keeps the subtree mounted',
      (WidgetTester tester) async {
    Future<void> pump(ValueChanged<Offset>? callback) => tester.pumpWidget(
          wrap(
            KunSelectionArea(
              onSecondaryTapOutsideSelection: callback,
              child: const _Counter(),
            ),
          ),
        );
    await pump(null);
    await tester.tap(find.text('count 0'));
    await tester.pump();
    await pump((Offset _) {});
    expect(find.text('count 1'), findsOneWidget);
    await pump(null);
    expect(find.text('count 1'), findsOneWidget);
  });

  testWidgets('a link still fires after Ctrl+A', (WidgetTester tester) async {
    await withPlatform(TargetPlatform.linux, () async {
      await forBothCallbackModes(tester, (
        ValueChanged<Offset>? callback,
        List<Offset> seen,
      ) async {
        int links = 0;
        SelectedContent? last;
        final TapGestureRecognizer recognizer = TapGestureRecognizer()
          ..onTap = () => links++;
        addTearDown(recognizer.dispose);
        await tester.pumpWidget(
          wrap(
            KunSelectionArea(
              onSelectionChanged: (SelectedContent? content) => last = content,
              onSecondaryTapOutsideSelection: callback,
              child: Text.rich(
                TextSpan(
                  text: 'visit ',
                  children: <InlineSpan>[
                    TextSpan(text: 'link', recognizer: recognizer),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(RichText));
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(last?.plainText, 'visit link');

        final RenderParagraph paragraph = paragraphOf(tester, 'visit link');
        final Offset linkAt = paragraph.localToGlobal(
          paragraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 6, extentOffset: 10),
              )
              .first
              .toRect()
              .center,
        );
        await tester.tapAt(linkAt, kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(links, 1);
        expect(seen, isEmpty);
      });
    });
  });

  testWidgets('a link span and a KunButton inside still fire',
      (WidgetTester tester) async {
    await forBothCallbackModes(tester, (
      ValueChanged<Offset>? callback,
      List<Offset> seen,
    ) async {
      int links = 0;
      int presses = 0;
      final TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () => links++;
      addTearDown(recognizer.dispose);

      await tester.pumpWidget(
        wrap(
          KunSelectionArea(
            onSecondaryTapOutsideSelection: callback,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    text: 'visit ',
                    children: <InlineSpan>[
                      TextSpan(text: 'link', recognizer: recognizer),
                    ],
                  ),
                ),
                KunButton(
                  onPressed: () => presses++,
                  child: const Text('Go'),
                ),
              ],
            ),
          ),
        ),
      );

      final RenderParagraph paragraph = tester.renderObject(
        find.byType(RichText).first,
      ) as RenderParagraph;
      final Offset linkAt = paragraph.localToGlobal(
        paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 6, extentOffset: 10),
            )
            .first
            .toRect()
            .center,
      );
      await tester.tapAt(linkAt);
      await tester.pump();
      expect(links, 1);

      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(presses, 1);
      expect(seen, isEmpty);
    });
  });

  testWidgets(
    'the menu reads a KunTheme placed inside a route',
    (WidgetTester tester) async {
      await withPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          KunTheme(
            data: KunThemeData.light(),
            child: WidgetsApp(
              color: KunColors.black,
              pageRouteBuilder: <T>(
                RouteSettings settings,
                WidgetBuilder builder,
              ) =>
                  PageRouteBuilder<T>(
                settings: settings,
                pageBuilder: (BuildContext context, _, __) => builder(context),
              ),
              home: Builder(
                builder: (BuildContext context) {
                  return KunButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        PageRouteBuilder<void>(
                          pageBuilder: (BuildContext context, _, __) {
                            return KunTheme(
                              data: KunThemeData.dark(),
                              child: const Center(
                                child: SizedBox(
                                  width: 300,
                                  child: KunSelectionArea(
                                    child: Text('hello world'),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.longPressAt(offsetOnFirstWord(tester, 'hello world'));
        await pumpMenu(tester);

        final DecoratedBox panel = tester.widget<DecoratedBox>(menuPanel());
        expect(
          (panel.decoration as BoxDecoration).color,
          KunThemeData.dark().colors.content1,
        );
      });
    },
  );
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => _count++),
        child: Text('count $_count'),
      );
}
