import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrapInput(Widget child) => KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (BuildContext context) =>
                  Center(child: SizedBox(width: 300, child: child)),
            ),
          ],
        ),
      ),
    );

Widget wrapComposer(Widget child) => KunMessagesScope(
      messages: KunMessages.en,
      child: wrapInput(child),
    );

/// Same payload the SDK sends in `editable_text_test.dart` (lines 833–846).
Future<void> simulateCommitContent(WidgetTester tester) async {
  const String uri =
      'content://com.google.android.inputmethod.latin.fileprovider/test.gif';
  final ByteData? messageBytes =
      const JSONMessageCodec().encodeMessage(<String, dynamic>{
    'args': <dynamic>[
      -1,
      'TextInputAction.commitContent',
      jsonDecode(
        '{"mimeType": "image/gif", "data": [0,1,0,1,0,1,0,0,0], "uri": "$uri"}',
      ),
    ],
    'method': 'TextInputClient.performAction',
  });
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/textinput',
    messageBytes,
    (ByteData? _) {},
  );
}

void main() {
  testWidgets('KunInput passes contentInsertionConfiguration and fires it',
      (WidgetTester tester) async {
    KeyboardInsertedContent? seen;
    final ContentInsertionConfiguration config = ContentInsertionConfiguration(
      onContentInserted: (KeyboardInsertedContent content) => seen = content,
      allowedMimeTypes: const <String>['image/gif'],
    );
    await tester.pumpWidget(
      wrapInput(KunInput(contentInsertionConfiguration: config)),
    );
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText))
          .contentInsertionConfiguration,
      same(config),
    );
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'test');
    await tester.idle();
    await simulateCommitContent(tester);
    expect(
      seen?.uri,
      'content://com.google.android.inputmethod.latin.fileprovider/test.gif',
    );
  });

  testWidgets('KunTextarea passes contentInsertionConfiguration and fires it',
      (WidgetTester tester) async {
    KeyboardInsertedContent? seen;
    final ContentInsertionConfiguration config = ContentInsertionConfiguration(
      onContentInserted: (KeyboardInsertedContent content) => seen = content,
      allowedMimeTypes: const <String>['image/gif'],
    );
    await tester.pumpWidget(
      wrapInput(KunTextarea(contentInsertionConfiguration: config)),
    );
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText))
          .contentInsertionConfiguration,
      same(config),
    );
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'test');
    await tester.idle();
    await simulateCommitContent(tester);
    expect(
      seen?.uri,
      'content://com.google.android.inputmethod.latin.fileprovider/test.gif',
    );
  });

  testWidgets(
      'KunChatComposer passes contentInsertionConfiguration and fires it',
      (WidgetTester tester) async {
    KeyboardInsertedContent? seen;
    final ContentInsertionConfiguration config = ContentInsertionConfiguration(
      onContentInserted: (KeyboardInsertedContent content) => seen = content,
      allowedMimeTypes: const <String>['image/gif'],
    );
    await tester.pumpWidget(
      wrapComposer(KunChatComposer(contentInsertionConfiguration: config)),
    );
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText))
          .contentInsertionConfiguration,
      same(config),
    );
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'test');
    await tester.idle();
    await simulateCommitContent(tester);
    expect(
      seen?.uri,
      'content://com.google.android.inputmethod.latin.fileprovider/test.gif',
    );
  });
}
