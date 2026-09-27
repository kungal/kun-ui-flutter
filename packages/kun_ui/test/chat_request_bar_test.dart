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
        child: Center(child: SizedBox(width: 480, child: child)),
      ),
    ),
  );
}

const KunChatUser ayase = KunChatUser(
  id: '1003',
  name: 'Ayase',
  avatar: '',
);

void main() {
  testWidgets('renders the title, description and four buttons',
      (tester) async {
    await tester.pumpWidget(wrap(const KunChatRequestBar(user: ayase)));
    expect(find.text(KunMessages.en.chatRequest.title), findsWidgets);
    expect(
      find.text(KunMessages.en.chatRequest.description(name: 'Ayase')),
      findsOneWidget,
    );
    expect(find.byType(KunButton), findsNWidgets(4));
    expect(find.text(KunMessages.en.chatRequest.accept), findsOneWidget);
    expect(find.text(KunMessages.en.chatRequest.delete), findsOneWidget);
    expect(find.text(KunMessages.en.chatRequest.block), findsOneWidget);
    expect(find.text(KunMessages.en.chatRequest.report), findsOneWidget);
  });

  testWidgets('callbacks fire and loading disables the other buttons',
      (tester) async {
    final List<String> log = <String>[];
    await tester.pumpWidget(
      wrap(
        KunChatRequestBar(
          user: ayase,
          onAccept: () => log.add('accept'),
          onDelete: () => log.add('delete'),
          onBlock: () => log.add('block'),
          onReport: () => log.add('report'),
        ),
      ),
    );
    await tester.tap(find.text(KunMessages.en.chatRequest.accept));
    await tester.tap(find.text(KunMessages.en.chatRequest.delete));
    expect(log, <String>['accept', 'delete']);

    await tester.pumpWidget(
      wrap(
        KunChatRequestBar(
          user: ayase,
          loading: KunChatRequestAction.accept,
          onAccept: () => log.add('accept'),
          onDelete: () => log.add('delete'),
        ),
      ),
    );
    log.clear();
    final KunButton accept = tester.widget<KunButton>(
      find.ancestor(
        of: find.text(KunMessages.en.chatRequest.accept),
        matching: find.byType(KunButton),
      ),
    );
    final KunButton delete = tester.widget<KunButton>(
      find.ancestor(
        of: find.text(KunMessages.en.chatRequest.delete),
        matching: find.byType(KunButton),
      ),
    );
    expect(accept.loading, isTrue);
    expect(delete.disabled, isTrue);
    await tester.tap(
      find.text(KunMessages.en.chatRequest.delete),
      warnIfMissed: false,
    );
    expect(log, isEmpty);
  });

  testWidgets('actions order is respected', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunChatRequestBar(
          user: ayase,
          actions: <KunChatRequestAction>[
            KunChatRequestAction.report,
            KunChatRequestAction.accept,
          ],
        ),
      ),
    );
    expect(find.byType(KunButton), findsNWidgets(2));
    final List<String> labels = tester
        .widgetList<KunButton>(find.byType(KunButton))
        .map((KunButton b) => (b.child as Text).data!)
        .toList();
    expect(labels, <String>[
      KunMessages.en.chatRequest.report,
      KunMessages.en.chatRequest.accept,
    ]);
  });

  testWidgets('the region is labelled by the title', (tester) async {
    await tester.pumpWidget(wrap(const KunChatRequestBar(user: ayase)));
    expect(
      tester.getSemantics(find.byType(KunChatRequestBar)),
      matchesSemantics(
        label: KunMessages.en.chatRequest.title,
        isButton: false,
      ),
    );
  });
}
