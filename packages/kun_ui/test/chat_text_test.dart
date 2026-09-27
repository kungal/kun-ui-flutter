import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
  KunUIConfig? config,
  bool reducedMotion = false,
  KunMessages messages = KunMessages.en,
  double width = 400,
}) {
  return MediaQuery(
    data: MediaQueryData(
      disableAnimations: reducedMotion,
      size: Size(width < 800 ? 800 : width + 100, 600),
    ),
    child: KunMessagesScope(
      messages: messages,
      child: KunUIConfigScope(
        config: config ?? const KunUIConfig(),
        child: KunTheme(
          data: KunThemeData.light(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: FocusScope(
              child: Center(
                child: SizedBox(width: width, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

(RenderParagraph, String) paragraphContaining(
  WidgetTester tester,
  String needle,
) {
  for (final Element el in tester.elementList(find.byType(RichText))) {
    final RichText rich = el.widget as RichText;
    final String plain = rich.text.toPlainText(
      includeSemanticsLabels: false,
      includePlaceholders: false,
    );
    if (plain.contains(needle)) {
      return (el.renderObject! as RenderParagraph, plain);
    }
  }
  fail('no paragraph contains "$needle"');
}

List<Rect> selectionBoxes(
  RenderParagraph paragraph,
  String plain,
  String needle,
) {
  final int at = plain.indexOf(needle);
  expect(at, greaterThanOrEqualTo(0), reason: '"$needle" in "$plain"');
  return paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: at, extentOffset: at + needle.length),
      )
      .map((TextBox tb) => Rect.fromLTRB(tb.left, tb.top, tb.right, tb.bottom))
      .toList();
}

void expectRectsClose(List<Rect> actual, List<Rect> expected) {
  expect(actual, hasLength(expected.length));
  for (int i = 0; i < expected.length; i++) {
    expect(
      actual[i].left,
      closeTo(expected[i].left, 0.5),
      reason: 'rect $i left',
    );
    expect(actual[i].top, closeTo(expected[i].top, 0.5), reason: 'rect $i top');
    expect(
      actual[i].width,
      closeTo(expected[i].width, 0.5),
      reason: 'rect $i width',
    );
    expect(
      actual[i].height,
      closeTo(expected[i].height, 0.5),
      reason: 'rect $i height',
    );
  }
}

Future<void> expectCodeChipMatches(
  WidgetTester tester,
  String markdown,
  String needle,
) async {
  final KunChatFormattedText parsed = parseKunChatMarkdown(markdown);
  await tester.pumpWidget(
    wrap(KunChatText(text: parsed.text, entities: parsed.entities)),
  );
  await tester.pump();
  await tester.pump();
  final (RenderParagraph paragraph, String plain) = paragraphContaining(
    tester,
    needle,
  );
  expectRectsClose(
    KunChatText.debugCodeChipBoxes(tester.element(find.byType(KunChatText))),
    selectionBoxes(paragraph, plain, needle),
  );
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
    final RichText rich = element.widget as RichText;
    collectRecognizers(rich.text, found);
  }
  for (final TapGestureRecognizer recognizer in found) {
    recognizer.onTap?.call();
  }
}

int recognizerCount(WidgetTester tester) {
  final List<TapGestureRecognizer> found = <TapGestureRecognizer>[];
  for (final Element element in tester.elementList(find.byType(RichText))) {
    final RichText rich = element.widget as RichText;
    collectRecognizers(rich.text, found);
  }
  return found.length;
}

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

void main() {
  testWidgets('plain text renders', (tester) async {
    await tester.pumpWidget(wrap(const KunChatText(text: 'hello')));
    expect(find.text('hello', findRichText: true), findsOneWidget);
  });

  testWidgets('bold uses semibold', (tester) async {
    final KunChatFormattedText parsed = parseKunChatMarkdown('**bold**');
    await tester.pumpWidget(
      wrap(KunChatText(text: parsed.text, entities: parsed.entities)),
    );
    final RichText rich = tester.widget<RichText>(find.byType(RichText));
    FontWeight? weight;
    rich.text.visitChildren((InlineSpan span) {
      if (span is TextSpan && span.text == 'bold') {
        weight = span.style?.fontWeight;
      }
      return true;
    });
    expect(weight, KunFontWeights.semibold);
  });

  testWidgets('a link navigates unless preventDefault', (tester) async {
    final List<String> hrefs = <String>[];
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      '[x](https://www.kungal.com/topic/1)',
    );
    await tester.pumpWidget(
      wrap(
        KunChatText(text: parsed.text, entities: parsed.entities),
        config: KunUIConfig(navigate: (_, String href) => hrefs.add(href)),
      ),
    );
    expect(recognizerCount(tester), 1);
    tapRecognizers(tester);
    expect(hrefs, <String>['https://www.kungal.com/topic/1']);

    hrefs.clear();
    await tester.pumpWidget(
      wrap(
        KunChatText(
          text: parsed.text,
          entities: parsed.entities,
          onLink: (KunChatLinkEvent event) => event.preventDefault(),
        ),
        config: KunUIConfig(navigate: (_, String href) => hrefs.add(href)),
      ),
    );
    tapRecognizers(tester);
    expect(hrefs, isEmpty);
  });

  testWidgets('a mention navigates to userLinkForId unless prevented', (
    tester,
  ) async {
    final List<String> hrefs = <String>[];
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      '[@鲲](mention:1001)',
    );
    await tester.pumpWidget(
      wrap(
        KunChatText(text: parsed.text, entities: parsed.entities),
        config: KunUIConfig(navigate: (_, String href) => hrefs.add(href)),
      ),
    );
    tapRecognizers(tester);
    expect(hrefs, <String>[KunUIConfig.fallback.userLinkForId('1001')]);

    hrefs.clear();
    String? mentioned;
    await tester.pumpWidget(
      wrap(
        KunChatText(
          text: parsed.text,
          entities: parsed.entities,
          onMention: (KunChatUserEvent event) {
            mentioned = event.userId;
            event.preventDefault();
          },
        ),
        config: KunUIConfig(navigate: (_, String href) => hrefs.add(href)),
      ),
    );
    tapRecognizers(tester);
    expect(mentioned, '1001');
    expect(hrefs, isEmpty);
  });

  testWidgets('an unsafe url is plain text', (tester) async {
    const String text = 'nope';
    await tester.pumpWidget(
      wrap(
        const KunChatText(
          text: text,
          entities: <KunChatEntity>[
            KunChatEntity(
              type: KunChatEntityType.textLink,
              offset: 0,
              length: 4,
              url: 'javascript:alert(1)',
            ),
          ],
        ),
      ),
    );
    expect(recognizerCount(tester), 0);
  });

  testWidgets('one reveal uncovers every spoiler and hidden links stay quiet', (
    tester,
  ) async {
    final List<String> hrefs = <String>[];
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      '||secret [link](https://www.kungal.com)|| and ||more||',
    );
    await tester.pumpWidget(
      wrap(
        KunChatText(text: parsed.text, entities: parsed.entities),
        config: KunUIConfig(navigate: (_, String href) => hrefs.add(href)),
      ),
    );
    await tester.pump();
    expect(recognizerCount(tester), 0);
    final Finder text = find.byType(KunChatText);
    expect(tester.getSemantics(text), isSemantics(isButton: true));
    expect(
      tester.getSemantics(text).getSemanticsData().label,
      contains(KunMessages.en.spoiler.reveal),
    );

    tapRecognizers(tester);
    expect(hrefs, isEmpty);

    await tester.tap(find.byType(KunChatText));
    await tester.pump();
    expect(recognizerCount(tester), 1);
    tapRecognizers(tester);
    expect(hrefs, <String>['https://www.kungal.com/']);
    expect(
      find.descendant(
        of: find.byType(KunChatText),
        matching: find.byType(Focus),
      ),
      findsNothing,
    );
  });

  testWidgets('hidden spoilers keep visible words in the label', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      'Beat it! The twist is ||she did it||, and ||level one|| hinted it.',
    );
    await tester.pumpWidget(
      wrap(KunChatText(text: parsed.text, entities: parsed.entities)),
    );
    await tester.pump();
    final Finder text = find.byType(KunChatText);
    String labelOf() => tester.getSemantics(text).getSemanticsData().label;
    final String reveal = KunMessages.en.spoiler.reveal;
    final String label = labelOf();
    expect(tester.getSemantics(text), isSemantics(isButton: true));
    expect(label, contains('Beat it!'));
    expect(label, contains('The twist is'));
    expect(label, contains('hinted it.'));
    expect(reveal.allMatches(label), hasLength(2));
    expect(label, isNot(contains('she did it')));
    expect(label, isNot(contains('level one')));

    await tester.tap(text);
    await tester.pump();
    final String revealed = labelOf();
    expect(revealed, contains('she did it'));
    expect(revealed, contains('level one'));
    expect(revealed, isNot(contains(reveal)));
    handle.dispose();
  });

  testWidgets('reduced motion still reveals on tap', (tester) async {
    final KunChatFormattedText parsed = parseKunChatMarkdown('hide ||secret||');
    await tester.pumpWidget(
      wrap(
        KunChatText(text: parsed.text, entities: parsed.entities),
        reducedMotion: true,
      ),
    );
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.tap(find.byType(KunChatText));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(KunChatText),
        matching: find.byType(Focus),
      ),
      findsNothing,
    );
  });

  testWidgets('preview flattens breaks, masks spoilers, and is not tappable', (
    tester,
  ) async {
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      'a\nb ||secret|| [x](https://www.kungal.com)',
    );
    await tester.pumpWidget(
      wrap(
        KunChatText(
          text: parsed.text,
          entities: parsed.entities,
          preview: true,
        ),
      ),
    );
    expect(recognizerCount(tester), 0);
    expect(find.textContaining('⠿', findRichText: true), findsOneWidget);
    expect(find.textContaining('\n', findRichText: true), findsNothing);
  });

  testWidgets('the pre copy button writes the body', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      handleClipboard,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      clipboardText = null;
    });
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      '```shell\nLANG=ja_JP.UTF-8 wine "Game.exe"\n```',
    );
    await tester.pumpWidget(
      wrap(KunChatText(text: parsed.text, entities: parsed.entities)),
    );
    await tester.tap(find.byIcon(KunIcons.copy));
    await tester.pump();
    expect(clipboardText, contains('wine'));
    expect(find.byIcon(KunIcons.check), findsOneWidget);
  });

  testWidgets('Enter on the spoiler stop reveals', (tester) async {
    final KunChatFormattedText parsed = parseKunChatMarkdown('||secret||');
    await tester.pumpWidget(
      wrap(
        Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
          },
          child: KunChatText(text: parsed.text, entities: parsed.entities),
        ),
      ),
    );
    await tester.pump();
    final Focus focus = tester.widget<Focus>(
      find.descendant(
        of: find.byType(KunChatText),
        matching: find.byType(Focus),
      ),
    );
    focus.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(KunChatText),
        matching: find.byType(Focus),
      ),
      findsNothing,
    );
  });

  testWidgets('spoiler span carries the tint, others do not', (tester) async {
    const String before = 'AAA ';
    const String hidden = 'SECRET';
    const String after = ' BBB';
    await tester.pumpWidget(
      wrap(
        const KunChatText(
          text: '$before$hidden$after',
          entities: <KunChatEntity>[
            KunChatEntity(
              type: KunChatEntityType.spoiler,
              offset: 4,
              length: 6,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    Color? spoilerBg;
    Color? plainBg;
    final RichText rich = tester.widget<RichText>(find.byType(RichText));
    rich.text.visitChildren((InlineSpan span) {
      if (span is TextSpan && span.text == hidden) {
        spoilerBg = span.style?.backgroundColor;
      }
      if (span is TextSpan && span.text == before) {
        plainBg = span.style?.backgroundColor;
      }
      return true;
    });
    expect(spoilerBg, const Color.fromRGBO(150, 150, 150, 0.18));
    expect(plainBg, isNull);
  });

  testWidgets('spoiler tint is on the hidden run only', (tester) async {
    const String before = 'AAA ';
    const String hidden = 'SECRET';
    const String after = ' BBB';
    const String text = '$before$hidden$after';
    final GlobalKey boundaryKey = GlobalKey();
    await tester.pumpWidget(
      wrap(
        RepaintBoundary(
          key: boundaryKey,
          child: const ColoredBox(
            color: Color(0xFFFFFFFF),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: KunChatText(
                text: text,
                entities: <KunChatEntity>[
                  KunChatEntity(
                    type: KunChatEntityType.spoiler,
                    offset: 4,
                    length: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
        reducedMotion: true,
      ),
    );
    await tester.pump();
    await tester.pump();

    final RenderRepaintBoundary boundary = tester.renderObject(
      find.byKey(boundaryKey),
    );
    late ui.Image image;
    late ByteData bytes;
    await tester.runAsync(() async {
      image = await boundary.toImage(pixelRatio: 1);
      bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });

    int redAt(int x, int y) {
      final int ox = x.clamp(0, image.width - 1);
      final int oy = y.clamp(0, image.height - 1);
      return bytes.getUint8((oy * image.width + ox) * 4);
    }

    final int midY = image.height ~/ 2;
    expect(redAt(2, midY), greaterThan(250));

    final RenderParagraph paragraph = tester.renderObject(
      find.byType(RichText),
    );
    final List<TextBox> boxes = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 4, extentOffset: 10),
    );
    expect(boxes, isNotEmpty);
    final TextBox box = boxes.first;
    final Offset global = paragraph.localToGlobal(
      Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2),
    );
    final Offset local = boundary.globalToLocal(global);
    expect(redAt(local.dx.round(), local.dy.round()), lessThan(250));
  });

  testWidgets('particle boxes lie inside spoiler text boxes', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunChatText(
          text: 'hide SECRET now',
          entities: <KunChatEntity>[
            KunChatEntity(
              type: KunChatEntityType.spoiler,
              offset: 5,
              length: 6,
            ),
          ],
        ),
        reducedMotion: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    final BuildContext context = tester.element(find.byType(KunChatText));
    final List<Rect> particles = KunChatText.debugSpoilerParticleBoxes(context);
    final List<Rect> textBoxes = KunChatText.debugSpoilerTextBoxes(context);
    expect(particles, isNotEmpty);
    expect(textBoxes, isNotEmpty);
    for (final Rect particle in particles) {
      expect(
        textBoxes.any(
          (Rect box) =>
              box.inflate(0.5).contains(particle.topLeft) &&
              box
                  .inflate(0.5)
                  .contains(particle.bottomRight - const Offset(0.01, 0.01)),
        ),
        isTrue,
        reason: '$particle outside $textBoxes',
      );
    }
  });

  testWidgets('blockquote spans the available width', (tester) async {
    final KunChatFormattedText parsed = parseKunChatMarkdown('> short');
    await tester.pumpWidget(
      wrap(KunChatText(text: parsed.text, entities: parsed.entities)),
    );
    final Finder quote = find.byWidgetPredicate((Widget w) {
      if (w is! Container) {
        return false;
      }
      final Decoration? decoration = w.decoration;
      if (decoration is! BoxDecoration) {
        return false;
      }
      final BoxBorder? border = decoration.border;
      return border is Border && border.left.width == 3;
    });
    expect(quote, findsOneWidget);
    expect(tester.getSize(quote).width, 400);
  });

  testWidgets('inline code has no backgroundColor and chips get boxes', (
    tester,
  ) async {
    final KunChatFormattedText parsed = parseKunChatMarkdown('see `%APPDATA%`');
    await tester.pumpWidget(
      wrap(KunChatText(text: parsed.text, entities: parsed.entities)),
    );
    await tester.pump();
    await tester.pump();
    Color? codeBg;
    final RichText rich = tester.widget<RichText>(find.byType(RichText));
    rich.text.visitChildren((InlineSpan span) {
      if (span is TextSpan && span.text != null && span.text!.contains('APP')) {
        codeBg = span.style?.backgroundColor;
      }
      return true;
    });
    expect(codeBg, isNull);
    final BuildContext context = tester.element(find.byType(KunChatText));
    expect(KunChatText.debugCodeChipBoxes(context), isNotEmpty);
  });

  testWidgets('code chip after a pre matches the code substring boxes', (
    tester,
  ) async {
    const String code = '%APPDATA%/StarRail';
    await expectCodeChipMatches(
      tester,
      '```shell\nLANG=ja_JP.UTF-8 wine "Game.exe"\n```\n存档在 `$code` 下面。',
      code,
    );
  });

  testWidgets('code chip after a blockquote matches the code substring boxes', (
    tester,
  ) async {
    const String code = '%APPDATA%';
    await expectCodeChipMatches(tester, '> 转区后再启动\n见 `$code` 目录。', code);
  });

  testWidgets('spoiler after a block matches substring boxes', (tester) async {
    const String secret = '列车长就是白本人';
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      '```\nwine Game.exe\n```\n通关了 ||$secret||。',
    );
    await tester.pumpWidget(
      wrap(KunChatText(text: parsed.text, entities: parsed.entities)),
    );
    await tester.pump();
    await tester.pump();
    final BuildContext context = tester.element(find.byType(KunChatText));
    final (RenderParagraph paragraph, String plain) = paragraphContaining(
      tester,
      secret,
    );
    final List<Rect> expected = selectionBoxes(paragraph, plain, secret);
    expectRectsClose(KunChatText.debugSpoilerTextBoxes(context), expected);
    expectRectsClose(KunChatText.debugSpoilerParticleBoxes(context), expected);
  });

  testWidgets('hidden spoiler particles fill each run at web density', (
    tester,
  ) async {
    const String first = '列车长就是白本人';
    const String second = '第三章那封信';
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      '通关了!最后的反转是 ||$first||,而且 ||$second|| 早就暗示过了。',
    );
    await tester.pumpWidget(
      wrap(
        KunChatText(text: parsed.text, entities: parsed.entities),
        width: 800,
      ),
    );
    await tester.pump();
    await tester.pump();
    final BuildContext context = tester.element(find.byType(KunChatText));
    final (RenderParagraph paragraph, String plain) = paragraphContaining(
      tester,
      first,
    );
    final List<(Offset, Rect)> particles = KunChatText.debugSpoilerParticles(
      context,
    );
    expect(particles, isNotEmpty);
    bool hits(List<Rect> boxes, Offset pos, Rect box) {
      return boxes.any(
        (Rect b) =>
            b.inflate(0.5).contains(pos) || b.inflate(0.5).overlaps(box),
      );
    }

    for (final String secret in <String>[first, second]) {
      final List<Rect> boxes = selectionBoxes(paragraph, plain, secret);
      expect(boxes, isNotEmpty, reason: secret);
      double area = 0;
      for (final Rect box in boxes) {
        area += box.width * box.height;
      }
      final int floor = (math.min(2500, area * 0.08) * 0.8).floor();
      final List<(Offset, Rect)> inRun = particles
          .where(((Offset, Rect) p) => hits(boxes, p.$1, p.$2))
          .toList();
      expect(inRun.length, greaterThanOrEqualTo(floor), reason: secret);
      for (final (Offset pos, Rect box) in inRun) {
        expect(hits(boxes, pos, box), isTrue, reason: '$pos outside $boxes');
      }
      for (final Rect box in boxes) {
        if (box.width < 8) {
          continue;
        }
        final List<Offset> inBox = inRun
            .where(
              ((Offset, Rect) p) =>
                  p.$2 == box || box.inflate(0.5).contains(p.$1),
            )
            .map(((Offset, Rect) p) => p.$1)
            .toList();
        if (inBox.length < 4) {
          continue;
        }
        expect(
          inBox.every((Offset p) => p.dx < box.left + box.width * 0.1),
          isFalse,
          reason: '$secret particles all in the first 10% of $box',
        );
      }
    }
  });

  testWidgets('trailing leaves spoiler and chip boxes unchanged', (
    tester,
  ) async {
    const String secret = 'SECRET';
    const String code = '%APPDATA%';
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      'hide ||$secret|| and `$code`',
    );
    final Widget text = KunChatText(
      text: parsed.text,
      entities: parsed.entities,
    );
    await tester.pumpWidget(wrap(text));
    await tester.pump();
    await tester.pump();
    final BuildContext bare = tester.element(find.byType(KunChatText));
    final List<Rect> spoiler = KunChatText.debugSpoilerTextBoxes(bare);
    final List<Rect> chips = KunChatText.debugCodeChipBoxes(bare);
    expect(spoiler, isNotEmpty);
    expect(chips, isNotEmpty);

    await tester.pumpWidget(
      wrap(
        KunChatText(
          text: parsed.text,
          entities: parsed.entities,
          trailing: const SizedBox(width: 48, height: 12),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final BuildContext withTrail = tester.element(find.byType(KunChatText));
    expectRectsClose(KunChatText.debugSpoilerTextBoxes(withTrail), spoiler);
    expectRectsClose(KunChatText.debugCodeChipBoxes(withTrail), chips);
  });

  testWidgets('trailing is ignored in preview and follows a trailing block', (
    tester,
  ) async {
    const Key trail = Key('trail');
    final KunChatFormattedText parsed = parseKunChatMarkdown('```\nwine\n```');
    await tester.pumpWidget(
      wrap(
        KunChatText(
          text: parsed.text,
          entities: parsed.entities,
          preview: true,
          trailing: const SizedBox(key: trail, width: 24, height: 8),
        ),
      ),
    );
    expect(find.byKey(trail), findsNothing);

    await tester.pumpWidget(
      wrap(
        KunChatText(
          text: parsed.text,
          entities: parsed.entities,
          trailing: const SizedBox(key: trail, width: 24, height: 8),
        ),
      ),
    );
    expect(find.byKey(trail), findsOneWidget);
    final RichText last =
        tester.widgetList<RichText>(find.byType(RichText)).last;
    bool found = false;
    last.text.visitChildren((InlineSpan span) {
      if (span is WidgetSpan) {
        found = true;
      }
      return true;
    });
    expect(found, isTrue);
  });
}
