import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child, {KunMessages messages = KunMessages.en}) {
  return KunMessagesScope(
    messages: messages,
    child: KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          key: UniqueKey(),
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (BuildContext context) => FocusScope(
                child: Center(child: SizedBox(width: 480, child: child)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget wrapWebKeys(Widget child) => Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
      },
      child: wrap(child),
    );

KunChatMessage message({
  String text = 'hello',
  String senderId = '1002',
  List<KunChatEntity> entities = const <KunChatEntity>[],
  KunChatMedia? media,
}) {
  return KunChatMessage(
    id: '1',
    conversationId: 'c',
    seq: 1,
    senderId: senderId,
    createdAt: DateTime.utc(2026, 9, 27, 10),
    text: text,
    entities: entities,
    media: media,
  );
}

final Uint8List _png = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x02,
  0x00,
  0x00,
  0x00,
  0x90,
  0x77,
  0x53,
  0xDE,
  0x00,
  0x00,
  0x00,
  0x0C,
  0x49,
  0x44,
  0x41,
  0x54,
  0x08,
  0xD7,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x00,
  0x03,
  0x00,
  0x01,
  0x18,
  0xDD,
  0x8D,
  0xB0,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _Host extends StatefulWidget {
  const _Host({
    this.initial = '',
    this.replyTo,
    this.quote,
    this.editing,
    this.attachments = const <KunChatAttachment>[],
    this.disabled = false,
    this.disabledText = '',
    this.enterToSend,
    this.maxLength = kunChatTextLimit,
    this.maxRows = 8,
    this.placeholder,
    this.users = const <KunChatUser>[],
    this.prefix,
    this.suffix,
  });

  final String initial;
  final KunChatMessage? replyTo;
  final KunChatReplyQuote? quote;
  final KunChatMessage? editing;
  final List<KunChatAttachment> attachments;
  final bool disabled;
  final String disabledText;
  final bool? enterToSend;
  final int maxLength;
  final int maxRows;
  final String? placeholder;
  final List<KunChatUser> users;
  final Widget? prefix;
  final Widget? suffix;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String value;
  KunChatMessage? replyTo;
  KunChatReplyQuote? quote;
  KunChatMessage? editing;
  final List<KunChatFormattedText> sent = <KunChatFormattedText>[];
  final List<(KunChatFormattedText, KunChatMessage)> edited =
      <(KunChatFormattedText, KunChatMessage)>[];
  int editLast = 0;
  int attach = 0;
  int typing = 0;
  final List<String> removed = <String>[];
  final List<String> retried = <String>[];

  @override
  void initState() {
    super.initState();
    value = widget.initial;
    replyTo = widget.replyTo;
    quote = widget.quote;
    editing = widget.editing;
  }

  @override
  Widget build(BuildContext context) {
    return KunChatComposer(
      value: value,
      onChanged: (String next) => setState(() => value = next),
      replyTo: replyTo,
      onReplyToChanged: (KunChatMessage? next) =>
          setState(() => replyTo = next),
      quote: quote,
      onQuoteChanged: (KunChatReplyQuote? next) => setState(() => quote = next),
      editing: editing,
      onEditingChanged: (KunChatMessage? next) =>
          setState(() => editing = next),
      attachments: widget.attachments,
      disabled: widget.disabled,
      disabledText: widget.disabledText,
      enterToSend: widget.enterToSend,
      maxLength: widget.maxLength,
      maxRows: widget.maxRows,
      placeholder: widget.placeholder,
      users: widget.users,
      prefix: widget.prefix,
      suffix: widget.suffix,
      onSend: (KunChatFormattedText m) => setState(() => sent.add(m)),
      onEdit: (KunChatFormattedText m, KunChatMessage t) {
        setState(() => edited.add((m, t)));
      },
      onEditLast: () => setState(() => editLast++),
      onAttach: () => setState(() => attach++),
      onRemoveAttachment: (String key) => setState(() => removed.add(key)),
      onRetryAttachment: (String key) => setState(() => retried.add(key)),
      onTyping: () => setState(() => typing++),
    );
  }
}

_HostState _hostOf(WidgetTester tester) {
  return tester.state<_HostState>(find.byType(_Host));
}

EditableText editableOf(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

void main() {
  testWidgets('send parses markdown and clears the input and reply', (
    WidgetTester tester,
  ) async {
    final KunChatMessage reply = message(text: 'ping');
    await tester.pumpWidget(
      wrap(
        _Host(
          initial: 'see **bold**',
          replyTo: reply,
          users: const <KunChatUser>[
            KunChatUser(id: '1002', name: 'Haru', avatar: ''),
          ],
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel(KunMessages.en.chatComposer.send));
    await tester.pump();
    final _HostState host = _hostOf(tester);
    expect(host.sent, hasLength(1));
    expect(host.sent.single.text, 'see bold');
    expect(
      host.sent.single.entities.any(
        (KunChatEntity e) => e.type == KunChatEntityType.bold,
      ),
      isTrue,
    );
    expect(host.value, isEmpty);
    expect(host.replyTo, isNull);
  });

  testWidgets('edit round-trips markdown, stashes the draft, and restores it', (
    WidgetTester tester,
  ) async {
    final KunChatFormattedText parsed = parseKunChatMarkdown('**keep** this');
    final KunChatMessage target = message(
      text: parsed.text,
      entities: parsed.entities,
    );
    await tester.pumpWidget(wrap(_Host(initial: 'unsent draft')));
    expect(editableOf(tester).controller.text, 'unsent draft');

    await tester.pumpWidget(
      wrap(_Host(initial: 'unsent draft', editing: target)),
    );
    await tester.pump();
    expect(
      editableOf(tester).controller.text,
      formatKunChatMarkdown(target.text, target.entities),
    );

    await tester.tap(find.bySemanticsLabel(KunMessages.en.chatComposer.save));
    await tester.pump();
    final _HostState host = _hostOf(tester);
    expect(host.edited, hasLength(1));
    expect(host.edited.single.$2, target);
    expect(host.editing, isNull);
    expect(host.value, 'unsent draft');
  });

  testWidgets('cancelling edit restores the stash', (
    WidgetTester tester,
  ) async {
    final KunChatMessage target = message(text: 'keep this');
    await tester.pumpWidget(wrap(_Host(initial: 'draft', editing: target)));
    await tester.tap(
      find.bySemanticsLabel(KunMessages.en.chatComposer.cancelEdit),
    );
    await tester.pump();
    expect(_hostOf(tester).editing, isNull);
    expect(_hostOf(tester).value, 'draft');
  });

  testWidgets('enterToSend true, false and auto on android versus linux', (
    WidgetTester tester,
  ) async {
    Future<void> pump({
      required TargetPlatform platform,
      required bool? enterToSend,
    }) async {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        wrapWebKeys(_Host(initial: 'go', enterToSend: enterToSend)),
      );
    }

    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    try {
      await pump(platform: TargetPlatform.linux, enterToSend: true);
      expect(editableOf(tester).textInputAction, TextInputAction.send);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_hostOf(tester).sent, hasLength(1));

      await pump(platform: TargetPlatform.linux, enterToSend: false);
      expect(editableOf(tester).textInputAction, TextInputAction.newline);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_hostOf(tester).sent, isEmpty);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(_hostOf(tester).sent, hasLength(1));

      await pump(platform: TargetPlatform.android, enterToSend: null);
      expect(editableOf(tester).textInputAction, TextInputAction.newline);

      await pump(platform: TargetPlatform.linux, enterToSend: null);
      expect(editableOf(tester).textInputAction, TextInputAction.send);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('IME composing blocks send', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(_Host(initial: '', enterToSend: true)));
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_hostOf(tester).sent, isEmpty);
  });

  testWidgets('Escape cancels the reply bar and ArrowUp asks to edit last', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapWebKeys(
        _Host(
          replyTo: message(),
          users: const <KunChatUser>[
            KunChatUser(id: '1002', name: 'Haru', avatar: ''),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_hostOf(tester).replyTo, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_hostOf(tester).editLast, 1);
  });

  testWidgets('the quote bar shows the quoted text',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        _Host(
          replyTo: message(text: 'full message'),
          quote: const KunChatReplyQuote(
            text: 'quoted slice',
            offset: 0,
          ),
          users: const <KunChatUser>[
            KunChatUser(id: '1002', name: 'Haru', avatar: ''),
          ],
        ),
      ),
    );
    expect(
      find.text(KunMessages.en.chatComposer.quoteFrom(name: 'Haru')),
      findsOneWidget,
    );
    expect(find.textContaining('quoted slice'), findsOneWidget);
  });

  testWidgets('typing is throttled and skipped while editing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const _Host()));
    await tester.enterText(find.byType(EditableText), 'a');
    await tester.pump();
    expect(_hostOf(tester).typing, 1);
    await tester.enterText(find.byType(EditableText), 'ab');
    await tester.pump();
    expect(_hostOf(tester).typing, 1);
    await tester.pump(kunChatTypingInterval);
    await tester.enterText(find.byType(EditableText), 'abc');
    await tester.pump();
    expect(_hostOf(tester).typing, 2);

    final KunChatMessage target = message(text: 'x');
    await tester.pumpWidget(wrap(_Host(initial: 'abc', editing: target)));
    await tester.enterText(find.byType(EditableText), 'abcd');
    await tester.pump();
    expect(_hostOf(tester).typing, 0);
  });

  testWidgets(
    'the counter appears over the last 200 and turns red past the limit',
    (WidgetTester tester) async {
      const int limit = 500;
      await tester.pumpWidget(
        wrap(_Host(initial: 'a' * 100, maxLength: limit)),
      );
      expect(find.text('${limit - 100}'), findsNothing);

      const int shown = 150;
      await tester.pumpWidget(
        wrap(_Host(initial: 'a' * (limit - shown), maxLength: limit)),
      );
      expect(find.text('$shown'), findsOneWidget);

      await tester.pumpWidget(
        wrap(_Host(initial: 'a' * (limit + 5), maxLength: limit)),
      );
      expect(find.text('-5'), findsOneWidget);
      final Text counter = tester.widget<Text>(find.text('-5'));
      expect(counter.style?.color, KunColors.light.danger.solid);
    },
  );

  testWidgets('attachment strip retries and removes by key', (
    WidgetTester tester,
  ) async {
    final MemoryImage image = MemoryImage(_png);
    await tester.pumpWidget(
      wrap(
        _Host(
          attachments: <KunChatAttachment>[
            KunChatAttachment(
              key: 'up',
              image: image,
              name: 'up.png',
              progress: 0.4,
            ),
            KunChatAttachment(
              key: 'bad',
              image: image,
              name: 'bad.png',
              error: true,
            ),
          ],
        ),
      ),
    );
    await tester.tap(
      find.bySemanticsLabel(KunMessages.en.chatComposer.retryAttachment),
    );
    await tester.pump();
    expect(_hostOf(tester).retried, <String>['bad']);

    await tester.tap(
      find.bySemanticsLabel(KunMessages.en.chatComposer.removeAttachment).first,
    );
    await tester.pump();
    expect(_hostOf(tester).removed, isNotEmpty);
  });

  testWidgets('paperclip fires onAttach', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const _Host()));
    await tester.tap(find.bySemanticsLabel(KunMessages.en.chatComposer.attach));
    await tester.pump();
    expect(_hostOf(tester).attach, 1);
  });

  testWidgets('disabled replaces the input and keeps the bar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        _Host(
          disabled: true,
          disabledText: 'gone',
          replyTo: message(),
          users: const <KunChatUser>[
            KunChatUser(id: '1002', name: 'Haru', avatar: ''),
          ],
        ),
      ),
    );
    expect(find.text('gone'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    expect(
      find.text(KunMessages.en.chatComposer.replyTo(name: 'Haru')),
      findsOneWidget,
    );
    await tester.tap(
      find.bySemanticsLabel(KunMessages.en.chatComposer.cancelReply),
    );
    await tester.pump();
    expect(_hostOf(tester).replyTo, isNull);
  });

  testWidgets('placeholder, prefix, suffix and maxRows are wired', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const _Host(
          placeholder: 'Say hi',
          maxRows: 3,
          prefix: SizedBox(key: Key('prefix')),
          suffix: SizedBox(key: Key('suffix')),
        ),
      ),
    );
    expect(find.text('Say hi'), findsOneWidget);
    expect(find.byKey(const Key('prefix')), findsOneWidget);
    expect(find.byKey(const Key('suffix')), findsOneWidget);
    expect(editableOf(tester).maxLines, 3);
    expect(editableOf(tester).minLines, 1);
  });

  testWidgets('attachments alone can send when not editing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        _Host(
          attachments: <KunChatAttachment>[const KunChatAttachment(key: 'a')],
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel(KunMessages.en.chatComposer.send));
    await tester.pump();
    expect(_hostOf(tester).sent, hasLength(1));
  });
}
