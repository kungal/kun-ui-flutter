import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
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
      child: KunTheme(
        data: KunThemeData.light(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SizedBox(width: 400, child: child)),
        ),
      ),
    ),
  );
}

const List<KunChatUser> users = <KunChatUser>[
  KunChatUser(id: '1', name: 'Ada', avatar: ''),
  KunChatUser(id: '2', name: 'Bob', avatar: ''),
  KunChatUser(id: '3', name: 'Cyd', avatar: ''),
  KunChatUser(id: '4', name: 'Deb', avatar: ''),
];

void main() {
  testWidgets('draws nothing while nobody is typing', (tester) async {
    await tester.pumpWidget(wrap(const KunChatTyping()));
    expect(find.byType(CustomPaint), findsNothing);
    expect(find.text(KunMessages.en.chatTyping.typing), findsNothing);
  });

  testWidgets('a direct chat says typing without a name', (tester) async {
    await tester.pumpWidget(
      wrap(
        KunChatTyping(
          events: <KunChatTypingEvent>[
            KunChatTypingEvent(userId: '1', at: DateTime.now()),
          ],
        ),
      ),
    );
    expect(find.text(KunMessages.en.chatTyping.typing), findsOneWidget);
  });

  testWidgets('a group names one, several, then many', (tester) async {
    final DateTime at = DateTime.now();
    await tester.pumpWidget(
      wrap(
        KunChatTyping(
          kind: KunChatKind.group,
          users: users,
          events: <KunChatTypingEvent>[
            KunChatTypingEvent(userId: '1', at: at),
          ],
        ),
      ),
    );
    expect(
        find.text(KunMessages.en.chatTyping.one(name: 'Ada')), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        KunChatTyping(
          kind: KunChatKind.group,
          users: users,
          events: <KunChatTypingEvent>[
            KunChatTypingEvent(userId: '1', at: at),
            KunChatTypingEvent(userId: '2', at: at),
            KunChatTypingEvent(userId: '3', at: at),
          ],
        ),
      ),
    );
    expect(
      find.text(
        KunMessages.en.chatTyping.several(names: 'Ada, Bob, and Cyd'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      wrap(
        KunChatTyping(
          kind: KunChatKind.group,
          users: users,
          events: <KunChatTypingEvent>[
            KunChatTypingEvent(userId: '1', at: at),
            KunChatTypingEvent(userId: '2', at: at),
            KunChatTypingEvent(userId: '3', at: at),
            KunChatTypingEvent(userId: '4', at: at),
          ],
        ),
      ),
    );
    expect(
      find.text(KunMessages.en.chatTyping.many(name: 'Ada', count: 3)),
      findsOneWidget,
    );
  });

  testWidgets('an event expires after the timeout', (tester) async {
    await tester.pumpWidget(
      wrap(
        KunChatTyping(
          events: <KunChatTypingEvent>[
            KunChatTypingEvent(userId: '1', at: DateTime.now()),
          ],
        ),
        reducedMotion: true,
      ),
    );
    expect(find.text(KunMessages.en.chatTyping.typing), findsOneWidget);
    await tester.pump(kunChatTypingTimeout + const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text(KunMessages.en.chatTyping.typing), findsNothing);

    await tester.pumpWidget(
      wrap(
        KunChatTyping(
          events: <KunChatTypingEvent>[
            KunChatTypingEvent(
              userId: '1',
              at: DateTime.now().subtract(
                kunChatTypingTimeout + const Duration(seconds: 1),
              ),
            ),
          ],
        ),
        reducedMotion: true,
      ),
    );
    expect(find.text(KunMessages.en.chatTyping.typing), findsNothing);
  });

  testWidgets('showText false keeps the label in semantics only',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        KunChatTyping(
          showText: false,
          events: <KunChatTypingEvent>[
            KunChatTypingEvent(userId: '1', at: DateTime.now()),
          ],
        ),
      ),
    );
    expect(find.text(KunMessages.en.chatTyping.typing), findsNothing);
    expect(
      tester.getSemantics(find.byType(KunChatTyping)),
      matchesSemantics(label: KunMessages.en.chatTyping.typing),
    );
  });

  testWidgets('reduced motion still paints the dots', (tester) async {
    await tester.pumpWidget(
      wrap(
        KunChatTyping(
          events: <KunChatTypingEvent>[
            KunChatTypingEvent(userId: '1', at: DateTime.now()),
          ],
        ),
        reducedMotion: true,
      ),
    );
    expect(find.byType(CustomPaint), findsOneWidget);
  });
}
