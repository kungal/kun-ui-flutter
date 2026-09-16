import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child) => KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

TextStyle resolvedStyle(WidgetTester tester) => (tester
        .widget<RichText>(
          find.descendant(
            of: find.byType(KunNull),
            matching: find.byType(RichText),
          ),
        )
        .text as TextSpan)
    .style!;

void main() {
  testWidgets('defaults to the bundled mascot and the zh-CN description',
      (tester) async {
    await tester.pumpWidget(wrap(const KunNull()));

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, KunImages.nullImage);
    expect(image.width, KunSpacing.unit * 72);
    expect(image.excludeFromSemantics, isTrue);

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(KunRadius.lg));

    expect(
      find.text(KunMessages.zhCN.nullState.description),
      findsOneWidget,
    );
  });

  testWidgets('the nearest messages scope supplies the description',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunMessagesScope(
          messages: KunMessages.en,
          child: KunNull(),
        ),
      ),
    );
    expect(
      find.text(KunMessages.en.nullState.description),
      findsOneWidget,
    );
    expect(
      find.text(KunMessages.zhCN.nullState.description),
      findsNothing,
    );
  });

  testWidgets('description replaces the locale text; empty stays empty',
      (tester) async {
    await tester.pumpWidget(
      wrap(const KunNull(description: 'nothing here')),
    );
    expect(find.text('nothing here'), findsOneWidget);
    expect(
      find.text(KunMessages.zhCN.nullState.description),
      findsNothing,
    );

    await tester.pumpWidget(wrap(const KunNull(description: '')));
    expect(tester.widget<Text>(find.byType(Text)).data, '');
    expect(
      find.text(KunMessages.zhCN.nullState.description),
      findsNothing,
    );
  });

  testWidgets('isShowSticker hides the image; a custom image is passed through',
      (tester) async {
    await tester.pumpWidget(
      wrap(const KunNull(isShowSticker: false)),
    );
    expect(find.byType(Image), findsNothing);
    expect(
      find.text(KunMessages.zhCN.nullState.description),
      findsOneWidget,
    );

    await tester.pumpWidget(
      wrap(const KunNull(image: KunImages.avatarFallback)),
    );
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      KunImages.avatarFallback,
    );
  });

  testWidgets('the description is the light-scheme neutral 500',
      (tester) async {
    await tester.pumpWidget(wrap(const KunNull()));
    expect(
      resolvedStyle(tester).color,
      KunColors.light.neutral.shade500,
    );
  });
}
