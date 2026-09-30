import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/chat/support.dart';

Widget _themeWrap(
  Widget child, {
  required KunThemeData theme,
  Size size = const Size(800, 800),
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: KunMessagesScope(
      messages: KunMessages.en,
      child: KunTheme(
        data: theme,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: child,
        ),
      ),
    ),
  );
}

Widget _overlayWrap(
  Widget child, {
  KunThemeData? theme,
}) {
  return _themeWrap(
    Overlay(
      initialEntries: <OverlayEntry>[
        OverlayEntry(
          builder: (BuildContext context) =>
              Center(child: SizedBox(width: 360, child: child)),
        ),
      ],
    ),
    theme: theme ?? KunThemeData.light(),
  );
}

Widget _appWrap(
  Widget child, {
  KunThemeData? theme,
}) {
  return _themeWrap(
    WidgetsApp(
      color: KunColors.black,
      debugShowCheckedModeBanner: false,
      home: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 480, child: child),
      ),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return builder(context);
          },
        );
      },
    ),
    theme: theme ?? KunThemeData.light(),
  );
}

TextStyle _styleOf(WidgetTester tester, String text, {Finder? of}) {
  Finder rich = find.descendant(
    of: find.text(text),
    matching: find.byType(RichText),
  );
  if (of != null) {
    rich = find.descendant(of: of, matching: rich);
  }
  return (tester.widget<RichText>(rich).text as TextSpan).style!;
}

Color? _spanColor(InlineSpan span, String needle) {
  if (span is TextSpan) {
    if (span.text != null &&
        span.text!.contains(needle) &&
        span.style?.color != null) {
      return span.style!.color;
    }
    if (span.children != null) {
      for (final InlineSpan child in span.children!) {
        final Color? found = _spanColor(child, needle);
        if (found != null) {
          return found;
        }
      }
    }
  }
  return null;
}

Color? _richColor(WidgetTester tester, String needle) {
  for (final Element element in tester.elementList(find.byType(RichText))) {
    final Color? found = _spanColor((element.widget as RichText).text, needle);
    if (found != null) {
      return found;
    }
  }
  return null;
}

const List<KunSelectOption<String>> _frameworks = <KunSelectOption<String>>[
  KunSelectOption<String>(value: 'vue', label: 'Vue'),
  KunSelectOption<String>(value: 'react', label: 'React'),
];

const List<KunAutocompleteOption> _suggestions = <KunAutocompleteOption>[
  KunAutocompleteOption(value: 'vue', label: 'Vue'),
];

const KunChatUser _haru = KunChatUser(id: '1002', name: 'Haru', avatar: '');
const KunChatUser _me = KunChatUser(id: '1001', name: 'Kun', avatar: '');
final DateTime _when = DateTime(2026, 9, 27, 14, 5);

KunChatMessage _msg({
  String senderId = '1002',
  String text = 'hello',
  KunChatReplyTo? replyTo,
  List<KunChatEntity> entities = const <KunChatEntity>[],
}) {
  return KunChatMessage(
    id: '1',
    conversationId: 'c',
    seq: 1,
    senderId: senderId,
    createdAt: _when,
    text: text,
    entities: entities,
    replyTo: replyTo,
  );
}

void main() {
  test('bordered, light and flat foregrounds are scale.text', () {
    for (final Brightness brightness in <Brightness>[
      Brightness.light,
      Brightness.dark,
    ]) {
      final KunColorScheme scheme =
          brightness == Brightness.light ? KunColors.light : KunColors.dark;
      for (final KunUIColor color in KunUIColor.values) {
        final KunColorScale scale = color.scaleOf(scheme);
        final Color tinted =
            color == KunUIColor.neutral ? scheme.foreground : scale.text;
        for (final KunUIVariant variant in <KunUIVariant>[
          KunUIVariant.bordered,
          KunUIVariant.light,
          KunUIVariant.flat,
        ]) {
          final KunVariantStyle style = KunVariantStyle.resolve(
            scheme: scheme,
            brightness: brightness,
            variant: variant,
            color: color,
          );
          final Color expected =
              variant == KunUIVariant.flat ? scale.text : tinted;
          expect(
            style.foreground,
            expected,
            reason: '${brightness.name} ${color.name} ${variant.name}',
          );
        }
      }
    }
  });

  testWidgets('KunInput error, asterisk and placeholder', (tester) async {
    await tester.pumpWidget(
      _overlayWrap(
        const KunInput(
          label: 'Name',
          required: true,
          error: 'Required',
          placeholder: 'Type',
        ),
      ),
    );
    expect(_styleOf(tester, 'Required').color, KunColors.light.danger.text);
    expect(_styleOf(tester, 'Type').color, KunColors.light.foregroundMuted);
    final TextSpan root = tester
        .widget<RichText>(
          find
              .descendant(
                of: find.byType(KunInput),
                matching: find.byType(RichText),
              )
              .first,
        )
        .text as TextSpan;
    Color? star;
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text != null && span.text!.contains('*')) {
          star = span.style?.color;
        }
        span.children?.forEach(walk);
      }
    }

    walk(root);
    expect(star, KunColors.light.danger.text);
  });

  testWidgets('KunTextarea error, asterisk and placeholder', (tester) async {
    await tester.pumpWidget(
      _overlayWrap(
        const KunTextarea(
          label: 'Bio',
          required: true,
          error: 'Required',
          placeholder: 'Write',
        ),
      ),
    );
    expect(_styleOf(tester, 'Required').color, KunColors.light.danger.text);
    expect(_styleOf(tester, 'Write').color, KunColors.light.foregroundMuted);
    expect(_richColor(tester, '*'), KunColors.light.danger.text);
  });

  testWidgets('KunAutocomplete error comes through KunInput', (tester) async {
    await tester.pumpWidget(
      _overlayWrap(
        const KunAutocomplete(
          options: _suggestions,
          error: 'Required',
        ),
      ),
    );
    expect(_styleOf(tester, 'Required').color, KunColors.light.danger.text);
  });

  testWidgets('KunSelect empty trigger, error and search placeholder',
      (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _appWrap(
        const KunSelect<String, KunSelectOption<String>>(
          options: _frameworks,
          value: null,
          placeholder: 'Pick one',
          error: 'Required',
          searchable: true,
          searchPlaceholder: 'Search…',
        ),
      ),
    );
    expect(_styleOf(tester, 'Pick one').color, KunColors.light.foregroundMuted);
    expect(_styleOf(tester, 'Required').color, KunColors.light.danger.text);

    await tester.tap(find.byKey(const ValueKey<String>('KunSelect.trigger')));
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(_styleOf(tester, 'Search…').color, KunColors.light.foregroundMuted);
  });

  testWidgets('KunDatePicker empty trigger and error', (tester) async {
    await tester.pumpWidget(
      _appWrap(
        const KunDatePicker(
          placeholder: 'Pick a date',
          error: 'Required',
        ),
      ),
    );
    expect(
      _styleOf(tester, 'Pick a date').color,
      KunColors.light.foregroundMuted,
    );
    expect(_styleOf(tester, 'Required').color, KunColors.light.danger.text);
  });

  testWidgets('KunCheckBox error', (tester) async {
    await tester.pumpWidget(
      _themeWrap(
        const Center(child: KunCheckBox(error: 'Required')),
        theme: KunThemeData.light(),
      ),
    );
    expect(
      tester.widget<Text>(find.text('Required')).style!.color,
      KunColors.light.danger.text,
    );
  });

  testWidgets('KunCheckBoxGroup error', (tester) async {
    await tester.pumpWidget(
      _themeWrap(
        const Center(
          child: SizedBox(
            width: 360,
            child: KunCheckBoxGroup<String>(
              options: <KunCheckBoxGroupOption<String>>[
                KunCheckBoxGroupOption<String>(value: 'a', label: 'A'),
              ],
              values: <String>[],
              error: 'Required',
            ),
          ),
        ),
        theme: KunThemeData.light(),
      ),
    );
    expect(_styleOf(tester, 'Required').color, KunColors.light.danger.text);
  });

  testWidgets('KunRadioGroup error', (tester) async {
    await tester.pumpWidget(
      _themeWrap(
        const Center(
          child: SizedBox(
            width: 360,
            child: KunRadioGroup<String>(
              options: <KunRadioOption<String>>[
                KunRadioOption<String>(value: 'a', label: 'A'),
              ],
              value: null,
              error: 'Required',
            ),
          ),
        ),
        theme: KunThemeData.light(),
      ),
    );
    expect(_styleOf(tester, 'Required').color, KunColors.light.danger.text);
  });

  testWidgets('KunSwitch error', (tester) async {
    await tester.pumpWidget(
      _themeWrap(
        const Center(child: KunSwitch(value: false, error: 'Required')),
        theme: KunThemeData.light(),
      ),
    );
    expect(_styleOf(tester, 'Required').color, KunColors.light.danger.text);
  });

  testWidgets('selected Tab text is scale.text', (tester) async {
    await tester.pumpWidget(
      _themeWrap(
        Center(
          child: KunTab(
            items: const <KunTabItem>[
              KunTabItem(value: 'home', textValue: 'Home'),
              KunTabItem(value: 'docs', textValue: 'Docs'),
            ],
            value: 'home',
            onChanged: (_) {},
          ),
        ),
        theme: KunThemeData.light(),
      ),
    );
    await tester.pumpAndSettle();
    expect(_styleOf(tester, 'Home').color, KunColors.light.primary.text);
  });

  testWidgets('active Reaction uses scale.text', (tester) async {
    await tester.pumpWidget(
      _themeWrap(
        const Center(
          child: KunReaction(value: true, color: KunUIColor.danger),
        ),
        theme: KunThemeData.light(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      IconTheme.of(tester.element(find.byType(Icon))).color,
      KunColors.light.danger.text,
    );
  });

  testWidgets('KunChatBubble sender, reply and own timestamp', (tester) async {
    await tester.pumpWidget(
      _appWrap(
        KunChatBubble(
          message: _msg(),
          users: const <KunChatUser>[_haru, _me],
          showSender: true,
        ),
      ),
    );
    expect(_styleOf(tester, 'Haru').color, KunColors.light.primary.text);

    await tester.pumpWidget(
      _appWrap(
        KunChatBubble(
          message: _msg(
            replyTo: const KunChatReplyTo(
              seq: 1,
              senderId: '1002',
              text: 'orig',
              deleted: false,
            ),
          ),
          users: const <KunChatUser>[_haru, _me],
        ),
      ),
    );
    expect(_styleOf(tester, 'Haru').color, KunColors.light.primary.text);

    await tester.pumpWidget(
      _appWrap(
        KunChatBubble(
          message: _msg(senderId: '1001'),
          users: const <KunChatUser>[_haru, _me],
          own: true,
        ),
      ),
    );
    expect(
      _styleOf(
        tester,
        formatKunChatTime(_when, KunMessages.en.code),
        of: find.byKey(KunChatBubble.metaKey),
      ).color,
      KunColors.light.primary.text,
    );
  });

  testWidgets('KunChatComposer placeholder and reply title', (tester) async {
    await tester.pumpWidget(
      _appWrap(
        const KunChatComposer(placeholder: 'Write a message'),
      ),
    );
    expect(
      _styleOf(tester, 'Write a message').color,
      KunColors.light.foregroundMuted,
    );

    await tester.pumpWidget(
      _appWrap(
        KunChatComposer(
          replyTo: _msg(),
          users: const <KunChatUser>[_haru, _me],
        ),
      ),
    );
    expect(
      _styleOf(
        tester,
        KunMessages.en.chatComposer.replyTo(name: 'Haru'),
      ).color,
      KunColors.light.primary.text,
    );
  });

  testWidgets('KunChatConversationItem typing, draft and status',
      (tester) async {
    await tester.pumpWidget(
      _themeWrap(
        Center(
          child: SizedBox(
            width: 360,
            child: KunChatConversationItem(
              user: _haru,
              typing: <KunChatTypingEvent>[
                KunChatTypingEvent(userId: '1002', at: DateTime.now()),
              ],
            ),
          ),
        ),
        theme: KunThemeData.light(),
      ),
    );
    expect(
      _styleOf(tester, KunMessages.en.chatTyping.typing).color,
      KunColors.light.primary.text,
    );

    await tester.pumpWidget(
      _themeWrap(
        const Center(
          child: SizedBox(
            width: 360,
            child: KunChatConversationItem(
              user: _haru,
              draft: KunChatFormattedText(text: 'unsent'),
            ),
          ),
        ),
        theme: KunThemeData.light(),
      ),
    );
    expect(
      _styleOf(tester, KunMessages.en.chat.draft).color,
      KunColors.light.danger.text,
    );

    await tester.pumpWidget(
      _themeWrap(
        Center(
          child: SizedBox(
            width: 360,
            child: KunChatConversationItem(
              user: _haru,
              lastMessage: _msg(),
              status: KunChatSendStatus.sending,
            ),
          ),
        ),
        theme: KunThemeData.light(),
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(KunIcons.clock)).color,
      KunColors.light.primary.text,
    );

    await tester.pumpWidget(
      _themeWrap(
        Center(
          child: SizedBox(
            width: 360,
            child: KunChatConversationItem(
              user: _haru,
              lastMessage: _msg(),
              status: KunChatSendStatus.failed,
            ),
          ),
        ),
        theme: KunThemeData.light(),
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(KunIcons.circleAlert)).color,
      KunColors.light.danger.text,
    );
  });

  testWidgets('KunChatHeader typing', (tester) async {
    await tester.pumpWidget(
      _themeWrap(
        Center(
          child: SizedBox(
            width: 480,
            child: KunChatHeader(
              user: _haru,
              typing: <KunChatTypingEvent>[
                KunChatTypingEvent(userId: '1002', at: DateTime.now()),
              ],
            ),
          ),
        ),
        theme: KunThemeData.light(),
      ),
    );
    expect(
      _styleOf(tester, KunMessages.en.chatTyping.typing).color,
      KunColors.light.primary.text,
    );
  });

  testWidgets('KunChatPinnedBar title', (tester) async {
    await tester.pumpWidget(
      _themeWrap(
        Center(
          child: SizedBox(
            width: 480,
            child: KunChatPinnedBar(
              messages: <KunChatMessage>[_msg(text: 'keep this')],
            ),
          ),
        ),
        theme: KunThemeData.light(),
      ),
    );
    expect(
      _styleOf(tester, KunMessages.en.chatPinned.label).color,
      KunColors.light.primary.text,
    );
  });

  testWidgets('KunChatText link and mention', (tester) async {
    final KunChatFormattedText link = parseKunChatMarkdown(
      '[here](https://example.com)',
    );
    await tester.pumpWidget(
      _themeWrap(
        Center(
          child: KunChatText(text: link.text, entities: link.entities),
        ),
        theme: KunThemeData.light(),
      ),
    );
    expect(_richColor(tester, 'here'), KunColors.light.primary.text);

    final KunChatFormattedText mention = parseKunChatMarkdown(
      '[@鲲](mention:1001)',
    );
    await tester.pumpWidget(
      _themeWrap(
        Center(
          child: KunChatText(text: mention.text, entities: mention.entities),
        ),
        theme: KunThemeData.light(),
      ),
    );
    expect(_richColor(tester, '鲲'), KunColors.light.primary.text);
  });
}
