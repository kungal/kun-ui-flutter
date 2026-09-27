import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
  bool reducedMotion = false,
  KunMessages messages = KunMessages.en,
  KunUIConfig? config,
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
              child: Center(
                child: SizedBox(width: 320, height: 320, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FailingImageProvider extends ImageProvider<_FailingImageProvider> {
  const _FailingImageProvider();

  @override
  Future<_FailingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_FailingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _FailingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(Exception('load failed')),
    );
  }
}

const List<KunChatReactionOption> options = <KunChatReactionOption>[
  KunChatReactionOption(key: 'heart', emoji: '❤️', label: 'Love'),
  KunChatReactionOption(key: 'fire', emoji: '🔥', label: 'Fire'),
  KunChatReactionOption(key: 'party', emoji: '🎉', label: 'Party'),
  KunChatReactionOption(key: 'clap', emoji: '👏', label: 'Clap'),
];

bool focused(WidgetTester tester, String label) {
  return tester
      .widget<FocusableActionDetector>(
        find.descendant(
          of: find.bySemanticsLabel(label),
          matching: find.byType(FocusableActionDetector),
        ),
      )
      .focusNode!
      .hasPrimaryFocus;
}

void main() {
  testWidgets('choosing toggles the current key to null', (tester) async {
    String? value = 'heart';
    await tester.pumpWidget(
      wrap(
        KunChatReactionPicker(
          options: options,
          value: value,
          onChanged: (String? next) => value = next,
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Love'));
    expect(value, isNull);

    await tester.pumpWidget(
      wrap(
        KunChatReactionPicker(
          options: options,
          value: value,
          onChanged: (String? next) => value = next,
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Fire'));
    expect(value, 'fire');
  });

  testWidgets('arrows wrap and Home/End jump', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunChatReactionPicker(
          options: options,
          columns: 2,
        ),
      ),
    );
    tester
        .widget<FocusableActionDetector>(
          find.descendant(
            of: find.bySemanticsLabel('Love'),
            matching: find.byType(FocusableActionDetector),
          ),
        )
        .focusNode!
        .requestFocus();
    await tester.pump();
    expect(focused(tester, 'Love'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focused(tester, 'Fire'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'Clap'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(focused(tester, 'Love'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(focused(tester, 'Clap'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(focused(tester, 'Party'), isTrue);
  });

  testWidgets('each option is a named toggle', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunChatReactionPicker(
          options: options,
          value: 'heart',
          semanticLabel: 'Pick a reaction',
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Love')),
      isSemantics(
        label: 'Love',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Fire')),
      isSemantics(
        label: 'Fire',
        isButton: true,
        hasToggledState: true,
        isToggled: false,
      ),
    );
    expect(
      tester.getSemantics(find.byType(KunChatReactionPicker)),
      isSemantics(label: 'Pick a reaction'),
    );
  });

  testWidgets('autofocus lands on the first cell', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunChatReactionPicker(
          options: options,
          autofocus: true,
        ),
      ),
    );
    await tester.pump();
    expect(focused(tester, 'Love'), isTrue);
  });

  testWidgets('a failed reaction image falls back to the emoji', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    const List<KunChatReactionOption> art = <KunChatReactionOption>[
      KunChatReactionOption(
        key: 'heart',
        emoji: '❤️',
        label: 'Love',
        imageUrl: 'https://example.test/heart.webp',
      ),
      KunChatReactionOption(key: 'fire', emoji: '🔥', label: 'Fire'),
    ];
    await tester.pumpWidget(
      wrap(
        const KunChatReactionPicker(options: art, columns: 2),
        config: KunUIConfig(
          imageProvider: (_) => const _FailingImageProvider(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    tester.takeException();
    expect(find.text('❤️'), findsOneWidget);
    expect(find.textContaining('load failed'), findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Love')),
      isSemantics(
        label: 'Love',
        isButton: true,
        hasToggledState: true,
        isToggled: false,
      ),
    );
    expect(
      tester.getSize(find.byType(Image)),
      Size.square(KunSpacing.unit * 8),
    );
    handle.dispose();
  });
}
