import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/tap_target.dart';

Widget wrap(
  Widget child, {
  Size size = const Size(480, 800),
  KunUIConfig? config,
  KunTapTargetSize tapTargetSize = KunTapTargetSize.adaptive,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: KunMessagesScope(
      messages: KunMessages.en,
      child: KunUIConfigScope(
        config: config ?? const KunUIConfig(),
        child: KunTheme(
          data: KunThemeData.light(tapTargetSize: tapTargetSize),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: SizedBox(width: 480, child: child)),
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

KunChatMessage message({
  required int seq,
  String text = 'hello',
  String senderId = '1002',
  KunChatMedia? media,
}) {
  return KunChatMessage(
    id: '$seq',
    conversationId: 'c',
    seq: seq,
    senderId: senderId,
    createdAt: DateTime.utc(2026, 9, 27, seq),
    text: text,
    media: media,
  );
}

List<String> unnamedActionable(SemanticsNode root) {
  final List<String> found = <String>[];
  void walk(SemanticsNode node) {
    final SemanticsData data = node.getSemanticsData();
    final bool actionable = data.hasAction(SemanticsAction.tap) ||
        data.hasAction(SemanticsAction.longPress) ||
        data.hasAction(SemanticsAction.customAction);
    if (actionable && data.label.isEmpty) {
      found.add(
        'id=${node.id} tap=${data.hasAction(SemanticsAction.tap)} '
        'label="${data.label}" rect=${node.rect}',
      );
    }
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
  }

  walk(root);
  return found;
}

void main() {
  testWidgets('renders nothing without messages', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(const KunChatPinnedBar(messages: <KunChatMessage>[])),
    );
    expect(find.text(KunMessages.en.chatPinned.label), findsNothing);
    expect(tester.getSize(find.byType(KunChatPinnedBar)).height, 0);
  });

  testWidgets('one pin shows the label and preview text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[message(seq: 1, text: 'keep this')],
        ),
      ),
    );
    expect(find.text(KunMessages.en.chatPinned.label), findsOneWidget);
    expect(find.text('keep this'), findsOneWidget);
  });

  testWidgets('several pins start at the newest and cycle with wrap', (
    WidgetTester tester,
  ) async {
    final List<int> jumps = <int>[];
    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[
            message(seq: 1, text: 'oldest'),
            message(seq: 3, text: 'newest'),
            message(seq: 2, text: 'middle'),
          ],
          onJump: jumps.add,
        ),
      ),
    );
    expect(
      find.text(KunMessages.en.chatPinned.indexed(index: 3)),
      findsOneWidget,
    );
    expect(find.text('newest'), findsOneWidget);

    await tester.tap(find.text('newest'));
    await tester.pump();
    expect(jumps, <int>[3]);
    expect(
      find.text(KunMessages.en.chatPinned.indexed(index: 2)),
      findsOneWidget,
    );
    expect(find.text('middle'), findsOneWidget);

    await tester.tap(find.text('middle'));
    await tester.pump();
    expect(jumps, <int>[3, 2]);
    expect(
      find.text(KunMessages.en.chatPinned.indexed(index: 1)),
      findsOneWidget,
    );
    expect(find.text('oldest'), findsOneWidget);

    await tester.tap(find.text('oldest'));
    await tester.pump();
    expect(jumps, <int>[3, 2, 1]);
    expect(find.text('newest'), findsOneWidget);
  });

  testWidgets('adding a newer pin keeps the shown seq', (
    WidgetTester tester,
  ) async {
    final List<KunChatMessage> pins = <KunChatMessage>[
      message(seq: 1, text: 'one'),
      message(seq: 2, text: 'two'),
    ];
    await tester.pumpWidget(wrap(KunChatPinnedBar(messages: pins)));
    expect(find.text('two'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[
            ...pins,
            message(seq: 3, text: 'three'),
          ],
        ),
      ),
    );
    expect(find.text('two'), findsOneWidget);
    expect(find.text('three'), findsNothing);
    expect(
      find.text(KunMessages.en.chatPinned.indexed(index: 2)),
      findsOneWidget,
    );
  });

  testWidgets('removing the shown pin falls back to the clamped neighbour', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[
            message(seq: 1, text: 'one'),
            message(seq: 2, text: 'two'),
            message(seq: 3, text: 'three'),
          ],
        ),
      ),
    );
    expect(find.text('three'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[
            message(seq: 1, text: 'one'),
            message(seq: 2, text: 'two'),
          ],
        ),
      ),
    );
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('unpin and the actions slot fire', (WidgetTester tester) async {
    final List<int> unpins = <int>[];
    var actions = 0;
    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[message(seq: 7, text: 'pin')],
          unpinnable: true,
          onUnpin: unpins.add,
          actions: GestureDetector(
            excludeFromSemantics: true,
            onTap: () => actions += 1,
            child: const Text('all pins'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('all pins'));
    await tester.pump();
    expect(actions, 1);

    await tester.tap(find.byIcon(KunIcons.x));
    await tester.pump();
    expect(unpins, <int>[7]);
    expect(
      find.bySemanticsLabel(KunMessages.en.chatPinned.unpin),
      findsOneWidget,
    );
  });

  testWidgets('a photo uses resolveMediaUrl and hides a failed load', (
    WidgetTester tester,
  ) async {
    final List<(KunChatMedia, KunChatMediaVariant)> resolved =
        <(KunChatMedia, KunChatMediaVariant)>[];
    final KunChatPhoto photo = KunChatPhoto(
      imageHash: 'bg/bg1',
      width: 32,
      height: 32,
    );
    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[message(seq: 1, text: '', media: photo)],
          resolveMediaUrl: (KunChatMedia media, KunChatMediaVariant variant) {
            resolved.add((media, variant));
            return 'https://example.test/fail.webp';
          },
        ),
        config: KunUIConfig(
          imageProvider: (_) => const _FailingImageProvider(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    tester.takeException();
    expect(resolved, hasLength(1));
    expect(resolved.single.$1, photo);
    expect(resolved.single.$2, KunChatMediaVariant.preview);
    expect(find.byType(KunImage), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.textContaining('EXCEPTION'), findsNothing);
    expect(find.textContaining('load failed'), findsNothing);
    expect(find.textContaining('ERROR'), findsNothing);
  });

  testWidgets('a photo thumbnail falls back to its url, else none', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[
            message(
              seq: 1,
              text: '',
              media: const KunChatPhoto(
                imageHash: 'h',
                width: 32,
                height: 32,
                url: 'https://img.test/h.webp',
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<KunImage>(find.byType(KunImage)).src,
      'https://img.test/h.webp',
    );

    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[
            message(
              seq: 1,
              text: '',
              media: const KunChatPhoto(imageHash: 'h', width: 32, height: 32),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(KunImage), findsNothing);
  });

  testWidgets('a media pin without text shows the media label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[
            message(
              seq: 1,
              text: '',
              media: const KunChatPhoto(
                imageHash: 'bg/bg1',
                width: 32,
                height: 32,
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.text(KunMessages.en.chat.photo), findsOneWidget);
  });

  testWidgets('has no unnamed actionable node', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[
            message(seq: 1, text: 'one'),
            message(seq: 2, text: 'two'),
          ],
          unpinnable: true,
          actions: KunButton(
            isIconOnly: true,
            semanticLabel: 'All pinned',
            onPressed: () {},
            child: const Icon(KunIcons.search),
          ),
        ),
      ),
    );
    expect(
      unnamedActionable(tester.getSemantics(find.byType(KunChatPinnedBar))),
      isEmpty,
    );
    handle.dispose();
  });

  Finder unpinDrawn() => find
      .ancestor(
        of: find.byIcon(KunIcons.x),
        matching: find.byType(AnimatedContainer),
      )
      .first;

  Finder unpinTarget() => find
      .ancestor(
        of: find.byIcon(KunIcons.x),
        matching: find.byType(KunTapTarget),
      )
      .first;

  testWidgets(
    'padded unpin and jump meet the minimum and the bar keeps its height',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<int> unpins = <int>[];
      final List<int> jumps = <int>[];
      await tester.pumpWidget(
        wrap(
          KunChatPinnedBar(
            messages: <KunChatMessage>[message(seq: 7, text: 'pin')],
            unpinnable: true,
            onUnpin: unpins.add,
            onJump: jumps.add,
          ),
          tapTargetSize: KunTapTargetSize.padded,
        ),
      );
      final Size min = kunMinTapTargetSize(
        tester.element(find.byType(KunChatPinnedBar)),
      );
      expect(
        tester.getSize(find.byType(KunChatPinnedBar)).height,
        KunSpacing.unit * 12,
      );
      expect(tester.getSize(unpinDrawn()), Size.square(KunSpacing.unit * 9));
      expect(
        tester.getSize(unpinTarget()).width,
        greaterThanOrEqualTo(min.width),
      );
      expect(
        tester.getSize(unpinTarget()).height,
        greaterThanOrEqualTo(min.height),
      );
      expect(tester.getCenter(unpinDrawn()), tester.getCenter(unpinTarget()));

      final Size jumpNode = tester
          .getSemantics(
            find.bySemanticsLabel(
              '${KunMessages.en.chatPinned.label}, pin',
            ),
          )
          .rect
          .size;
      expect(jumpNode.height, greaterThanOrEqualTo(min.height));

      final Rect drawn = tester.getRect(unpinDrawn());
      await tester.tapAt(Offset(drawn.center.dx, drawn.top - 3));
      await tester.pump();
      expect(unpins, <int>[7]);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    },
  );

  testWidgets(
    'shrinkWrap keeps the pinned bar at the web size',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          KunChatPinnedBar(
            messages: <KunChatMessage>[message(seq: 7, text: 'pin')],
            unpinnable: true,
          ),
          tapTargetSize: KunTapTargetSize.shrinkWrap,
        ),
      );
      expect(
        tester.getSize(find.byType(KunChatPinnedBar)).height,
        KunSpacing.unit * 12,
      );
      expect(tester.getSize(unpinDrawn()), Size.square(KunSpacing.unit * 9));
      expect(tester.getSize(unpinTarget()), Size.square(KunSpacing.unit * 9));
    },
  );

  testWidgets('padded unpin meets the iOS guideline',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        KunChatPinnedBar(
          messages: <KunChatMessage>[message(seq: 7, text: 'pin')],
          unpinnable: true,
        ),
        tapTargetSize: KunTapTargetSize.padded,
      ),
    );
    expect(
      tester.getSize(unpinTarget()).height,
      greaterThanOrEqualTo(
        kunMinTapTargetSize(tester.element(find.byType(KunChatPinnedBar)))
            .height,
      ),
    );
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
