import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
  KunUIConfig? config,
  bool reducedMotion = false,
  KunMessages messages = KunMessages.en,
}) {
  return MediaQuery(
    data: MediaQueryData(
      disableAnimations: reducedMotion,
      size: const Size(800, 600),
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
              child: Center(child: SizedBox(width: 400, child: child)),
            ),
          ),
        ),
      ),
    ),
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

  testWidgets('a mention navigates to userLinkForId unless prevented',
      (tester) async {
    final List<String> hrefs = <String>[];
    final KunChatFormattedText parsed =
        parseKunChatMarkdown('[@鲲](mention:1001)');
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
          onMention: (KunChatMentionEvent event) {
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

  testWidgets('one reveal uncovers every spoiler and hidden links stay quiet',
      (tester) async {
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
    expect(
      tester.getSemantics(find.byType(KunChatText)),
      isSemantics(
        label: KunMessages.en.spoiler.reveal,
        isButton: true,
      ),
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

  testWidgets('preview flattens breaks, masks spoilers, and is not tappable',
      (tester) async {
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
}
