import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/chat/support.dart';

Uint8List _u32(int value) {
  final ByteData data = ByteData(4)..setUint32(0, value);
  return data.buffer.asUint8List();
}

int _crc32(List<int> data) {
  int crc = 0xffffffff;
  for (final int byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      final bool bit = crc & 1 == 1;
      crc >>= 1;
      if (bit) {
        crc ^= 0xEDB88320;
      }
    }
  }
  return crc ^ 0xffffffff;
}

int _adler32(List<int> data) {
  int a = 1;
  int b = 0;
  for (final int byte in data) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  return (b << 16) | a;
}

Uint8List _chunk(List<int> type, List<int> payload) {
  final BytesBuilder body = BytesBuilder()
    ..add(type)
    ..add(payload);
  final Uint8List bytes = body.toBytes();
  return Uint8List.fromList(<int>[
    ..._u32(payload.length),
    ...bytes,
    ..._u32(_crc32(bytes)),
  ]);
}

Uint8List _solidPng({int width = 16, int height = 16}) {
  final BytesBuilder raw = BytesBuilder(copy: false);
  for (int y = 0; y < height; y++) {
    raw.addByte(0);
    for (int x = 0; x < width; x++) {
      raw
        ..addByte(0x7C)
        ..addByte(0x3A)
        ..addByte(0xED);
    }
  }
  final Uint8List pixels = raw.toBytes();
  final BytesBuilder zlib = BytesBuilder()
    ..addByte(0x78)
    ..addByte(0x01);
  zlib
    ..addByte(1)
    ..addByte(pixels.length & 0xff)
    ..addByte((pixels.length >> 8) & 0xff)
    ..addByte((~pixels.length) & 0xff)
    ..addByte(((~pixels.length) >> 8) & 0xff)
    ..add(pixels)
    ..add(_u32(_adler32(pixels)));
  final ByteData ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  return Uint8List.fromList(<int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    ..._chunk(<int>[0x49, 0x48, 0x44, 0x52], ihdr.buffer.asUint8List()),
    ..._chunk(<int>[0x49, 0x44, 0x41, 0x54], zlib.toBytes()),
    ..._chunk(<int>[0x49, 0x45, 0x4E, 0x44], const <int>[]),
  ]);
}

final MemoryImage _memory = MemoryImage(_solidPng());

ImageProvider _resolveImage(String url) => _memory;

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

final DateTime _when = DateTime(2026, 9, 27, 14, 5);

const List<KunChatUser> _users = <KunChatUser>[
  KunChatUser(id: '1001', name: 'Kun', avatar: ''),
  KunChatUser(id: '1002', name: 'Haru', avatar: ''),
  KunChatUser(id: '1005', name: '', avatar: '', deleted: true),
];

KunChatMessage _msg({
  String id = '1',
  int seq = 1,
  String senderId = '1002',
  String text = 'hello',
  List<KunChatEntity> entities = const <KunChatEntity>[],
  KunChatMedia? media,
  String? mediaGroupId,
  KunChatReplyTo? replyTo,
  KunChatReplyQuote? replyQuote,
  KunChatContext? context,
  List<KunChatReaction> reactions = const <KunChatReaction>[],
  DateTime? editedAt,
  KunChatMessageKind kind = KunChatMessageKind.message,
  KunChatServiceAction? serviceAction,
}) {
  return KunChatMessage(
    id: id,
    conversationId: '77',
    seq: seq,
    senderId: senderId,
    createdAt: _when,
    kind: kind,
    text: text,
    entities: entities,
    media: media,
    mediaGroupId: mediaGroupId,
    replyTo: replyTo,
    replyQuote: replyQuote,
    context: context,
    reactions: reactions,
    editedAt: editedAt,
    serviceAction: serviceAction,
  );
}

Widget wrap(
  Widget child, {
  KunUIConfig? config,
  KunMessages messages = KunMessages.en,
  Size size = const Size(800, 800),
  double width = 400,
  KunTapTargetSize tapTargetSize = KunTapTargetSize.adaptive,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: KunTheme(
      data: KunThemeData.light(tapTargetSize: tapTargetSize),
      child: KunMessagesScope(
        messages: messages,
        child: KunUIConfigScope(
          config: config ??
              KunUIConfig(imageProvider: _resolveImage, navigate: (_, __) {}),
          child: WidgetsApp(
            color: KunColors.black,
            debugShowCheckedModeBanner: false,
            home: Center(
              child: SizedBox(width: width, child: child),
            ),
            pageRouteBuilder:
                <T>(RouteSettings settings, WidgetBuilder builder) {
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
        ),
      ),
    ),
  );
}

BorderRadius surfaceRadius(WidgetTester tester) {
  final DecoratedBox box = tester.widget(find.byKey(KunChatBubble.surfaceKey));
  return (box.decoration as BoxDecoration).borderRadius! as BorderRadius;
}

const double _kCapFraction = 0.85;

const double _kCapMax = 34 * 16;

double _capOf(double parent) {
  final double fraction = parent * _kCapFraction;
  return fraction < _kCapMax ? fraction : _kCapMax;
}

KunChatContext _contextWithTitle(String title) {
  return KunChatContext(
    site: 'moyu',
    kind: 'patch',
    id: '3021',
    title: title,
    url: 'https://www.moyu.moe/patch/3021/introduction',
  );
}

(RenderParagraph, String) messageParagraph(WidgetTester tester, String needle) {
  for (final Element el in tester.elementList(find.byType(RichText))) {
    final RichText rich = el.widget as RichText;
    final String value = rich.text.toPlainText(
      includeSemanticsLabels: false,
      includePlaceholders: false,
    );
    if (value.contains(needle)) {
      return (el.renderObject! as RenderParagraph, value);
    }
  }
  fail('no paragraph contains "$needle"');
}

void main() {
  testWidgets('link and user events navigate unless prevented', (
    WidgetTester tester,
  ) async {
    final List<String> hrefs = <String>[];
    const String text = 'see x and y';
    const List<KunChatEntity> entities = <KunChatEntity>[
      KunChatEntity(
        type: KunChatEntityType.textLink,
        offset: 4,
        length: 1,
        url: 'https://www.kungal.com/topic/1',
      ),
      KunChatEntity(
        type: KunChatEntityType.mention,
        offset: 10,
        length: 1,
        userId: '1001',
      ),
    ];
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(text: text, entities: entities),
          users: _users,
        ),
        config: KunUIConfig(
          imageProvider: _resolveImage,
          navigate: (_, String href) => hrefs.add(href),
        ),
      ),
    );
    void collect(InlineSpan span, List<TapGestureRecognizer> found) {
      if (span is TextSpan) {
        if (span.recognizer is TapGestureRecognizer) {
          found.add(span.recognizer! as TapGestureRecognizer);
        }
        final List<InlineSpan>? children = span.children;
        if (children != null) {
          for (final InlineSpan child in children) {
            collect(child, found);
          }
        }
      }
    }

    final List<TapGestureRecognizer> found = <TapGestureRecognizer>[];
    for (final Element element in tester.elementList(find.byType(RichText))) {
      collect((element.widget as RichText).text, found);
    }
    expect(found, hasLength(2));
    found[0].onTap?.call();
    found[1].onTap?.call();
    expect(hrefs, <String>[
      'https://www.kungal.com/topic/1',
      KunUIConfig.fallback.userLinkForId('1001'),
    ]);

    hrefs.clear();
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(text: text, entities: entities),
          users: _users,
          onLink: (KunChatLinkEvent event) => event.preventDefault(),
          onMention: (KunChatUserEvent event) => event.preventDefault(),
        ),
        config: KunUIConfig(
          imageProvider: _resolveImage,
          navigate: (_, String href) => hrefs.add(href),
        ),
      ),
    );
    found.clear();
    for (final Element element in tester.elementList(find.byType(RichText))) {
      collect((element.widget as RichText).text, found);
    }
    found[0].onTap?.call();
    found[1].onTap?.call();
    expect(hrefs, isEmpty);
  });

  testWidgets('sender name navigates unless prevented; deleted is plain', (
    WidgetTester tester,
  ) async {
    final List<String> hrefs = <String>[];
    await tester.pumpWidget(
      wrap(
        KunChatBubble(message: _msg(), users: _users, showSender: true),
        config: KunUIConfig(
          imageProvider: _resolveImage,
          navigate: (_, String href) => hrefs.add(href),
        ),
      ),
    );
    expect(find.text('Haru'), findsOneWidget);
    await tester.tap(find.byKey(KunChatBubble.senderKey));
    await tester.pump();
    expect(hrefs, <String>[KunUIConfig.fallback.userLinkForId('1002')]);

    hrefs.clear();
    String? tapped;
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(),
          users: _users,
          showSender: true,
          onUserTap: (KunChatUserEvent event) {
            tapped = event.userId;
            event.preventDefault();
          },
        ),
        config: KunUIConfig(
          imageProvider: _resolveImage,
          navigate: (_, String href) => hrefs.add(href),
        ),
      ),
    );
    await tester.tap(find.byKey(KunChatBubble.senderKey));
    await tester.pump();
    expect(tapped, '1002');
    expect(hrefs, isEmpty);

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(senderId: '1005'),
          users: _users,
          showSender: true,
        ),
        config: KunUIConfig(
          imageProvider: _resolveImage,
          navigate: (_, String href) => hrefs.add(href),
        ),
      ),
    );
    expect(find.text(KunMessages.en.chat.deletedUser), findsOneWidget);
    await tester.tap(find.byKey(KunChatBubble.senderKey));
    await tester.pump();
    expect(hrefs, isEmpty);
  });

  testWidgets('reply states: text, quote, deleted, media', (
    WidgetTester tester,
  ) async {
    final List<int> seqs = <int>[];
    final KunChatReplyTo textReply = KunChatReplyTo(
      seq: 3,
      senderId: '1002',
      text: 'original line',
      deleted: false,
    );
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(text: 'answer', replyTo: textReply),
          users: _users,
          onReplyTap: seqs.add,
        ),
      ),
    );
    expect(find.text('original line', findRichText: true), findsOneWidget);
    await tester.tap(find.byKey(KunChatBubble.replyKey));
    await tester.pump();
    expect(seqs, <int>[3]);

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(
            text: 'quoted',
            replyTo: textReply,
            replyQuote: const KunChatReplyQuote(text: 'slice', offset: 0),
          ),
          users: _users,
        ),
      ),
    );
    expect(find.byIcon(KunIcons.quote), findsOneWidget);
    expect(find.text('slice', findRichText: true), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(
            text: 'gone',
            replyTo: const KunChatReplyTo(
              seq: 4,
              senderId: '1002',
              text: '',
              deleted: true,
            ),
          ),
          users: _users,
        ),
      ),
    );
    expect(find.text(KunMessages.en.chat.deletedMessage), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(
            text: 'pic',
            replyTo: const KunChatReplyTo(
              seq: 5,
              senderId: '1002',
              text: '',
              mediaType: 'photo',
              deleted: false,
            ),
          ),
          users: _users,
        ),
      ),
    );
    expect(find.byIcon(KunIcons.image), findsOneWidget);
    expect(find.text(KunMessages.en.chat.photo), findsOneWidget);
  });

  testWidgets('single-photo clamp sizes', (WidgetTester tester) async {
    const KunChatPhoto wide = KunChatPhoto(
      imageHash: 'wide',
      width: 1920,
      height: 1080,
    );
    expect(KunChatBubble.debugSinglePhotoSize(wide).width, 320);
    expect(
      KunChatBubble.debugSinglePhotoSize(wide).height,
      closeTo(320 / (1920 / 1080), 0.01),
    );

    const KunChatPhoto tall = KunChatPhoto(
      imageHash: 'tall',
      width: 290,
      height: 599,
    );
    final Size tallSize = KunChatBubble.debugSinglePhotoSize(tall);
    expect(tallSize.width, 210);
    expect(tallSize.height, 420);

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(text: '', media: wide),
          users: _users,
          lightbox: false,
          resolveMediaUrl: (KunChatMedia _, KunChatMediaVariant __) => 'p',
        ),
        width: 500,
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byKey(KunChatBubble.photoKey(0))).width, 320);
  });

  testWidgets('a photo falls back to its url, and a resolver still wins', (
    WidgetTester tester,
  ) async {
    const KunChatPhoto photo = KunChatPhoto(
      imageHash: 'h',
      width: 400,
      height: 300,
      url: 'https://img.test/h.webp',
    );
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(text: '', media: photo),
          users: _users,
          lightbox: false,
        ),
        width: 500,
      ),
    );
    await tester.pump();
    expect(
      tester.widget<KunImage>(find.byType(KunImage)).src,
      'https://img.test/h.webp',
    );

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(text: '', media: photo),
          users: _users,
          lightbox: false,
          resolveMediaUrl: (KunChatMedia _, KunChatMediaVariant __) =>
              'https://small.test/h',
        ),
        width: 500,
      ),
    );
    await tester.pump();
    expect(
      tester.widget<KunImage>(find.byType(KunImage)).src,
      'https://small.test/h',
    );
  });

  testWidgets('album tiles match layoutKunChatAlbum', (
    WidgetTester tester,
  ) async {
    final List<KunChatPhoto> photos = <KunChatPhoto>[
      const KunChatPhoto(imageHash: 'a', width: 1920, height: 1080),
      const KunChatPhoto(imageHash: 'b', width: 367, height: 602),
      const KunChatPhoto(imageHash: 'c', width: 1920, height: 1239),
      const KunChatPhoto(imageHash: 'd', width: 1920, height: 1200),
      const KunChatPhoto(imageHash: 'e', width: 1920, height: 1268),
    ];
    final List<KunChatMessage> album = <KunChatMessage>[
      for (int i = 0; i < photos.length; i++)
        _msg(
          id: '$i',
          seq: i + 1,
          text: i == 4 ? 'caption' : '',
          media: photos[i],
          mediaGroupId: 'g',
        ),
    ];
    final KunChatAlbumLayout layout = layoutKunChatAlbum(<KunChatAlbumSize>[
      for (final KunChatPhoto photo in photos)
        KunChatAlbumSize(
          width: photo.width.toDouble(),
          height: photo.height.toDouble(),
        ),
    ]);

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: album.last,
          album: album,
          users: _users,
          lightbox: false,
          resolveMediaUrl: (KunChatMedia _, KunChatMediaVariant __) => 'p',
        ),
        width: 500,
      ),
    );
    await tester.pump();

    final List<Rect> tiles = <Rect>[
      for (int i = 0; i < photos.length; i++)
        tester.getRect(find.byKey(KunChatBubble.photoKey(i))),
    ];
    final double mosaicLeft = tiles
        .map((Rect r) => r.left)
        .reduce((double a, double b) => a < b ? a : b);
    final double mosaicTop = tiles
        .map((Rect r) => r.top)
        .reduce((double a, double b) => a < b ? a : b);
    final double mosaicW = tiles
            .map((Rect r) => r.right)
            .reduce((double a, double b) => a > b ? a : b) -
        mosaicLeft;
    expect(mosaicW, closeTo(320, 1));

    for (int i = 0; i < layout.tiles.length; i++) {
      final KunChatAlbumTile tile = layout.tiles[i];
      expect(
        tiles[i].left,
        closeTo(mosaicLeft + tile.x / layout.width * mosaicW, 1.5),
        reason: 'tile $i left',
      );
      expect(
        tiles[i].top,
        closeTo(
          mosaicTop +
              tile.y / layout.height * (mosaicW * layout.height / layout.width),
          1.5,
        ),
        reason: 'tile $i top',
      );
    }
  });

  testWidgets('photo tap fires with and without the lightbox', (
    WidgetTester tester,
  ) async {
    final List<int> taps = <int>[];
    const KunChatPhoto photo = KunChatPhoto(
      imageHash: 'wide',
      width: 1920,
      height: 1080,
    );
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(text: '', media: photo),
          users: _users,
          lightbox: false,
          resolveMediaUrl: (KunChatMedia _, KunChatMediaVariant __) => 'mem',
          onPhotoTap: taps.add,
        ),
      ),
    );
    await tester.tap(find.byKey(KunChatBubble.photoKey(0)));
    await tester.pump();
    expect(taps, <int>[0]);
    expect(find.byKey(KunLightbox.layerKey), findsNothing);

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(text: '', media: photo),
          users: _users,
          resolveMediaUrl: (KunChatMedia _, KunChatMediaVariant variant) =>
              variant == KunChatMediaVariant.original ? 'orig' : 'prev',
          onPhotoTap: taps.add,
        ),
      ),
    );
    await tester.tap(find.byKey(KunChatBubble.photoKey(0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, <int>[0, 0]);
    expect(find.byKey(KunLightbox.layerKey), findsOneWidget);
  });

  testWidgets('meta shows time, edited, and each status icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(senderId: '1001', editedAt: _when),
          users: _users,
          own: true,
          status: KunChatSendStatus.sending,
        ),
      ),
    );
    expect(
      find.text(formatKunChatTime(_when, KunMessages.en.code)),
      findsWidgets,
    );
    expect(find.text(KunMessages.en.chat.edited), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(KunChatBubble.metaKey),
        matching: find.byIcon(KunIcons.clock),
      ),
      findsOneWidget,
    );
    final KunTooltip tip = tester.widget(find.byType(KunTooltip).first);
    expect(tip.text, formatKunChatFullTime(_when, KunMessages.en.code));

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(senderId: '1001'),
          users: _users,
          own: true,
          status: KunChatSendStatus.sent,
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(KunChatBubble.metaKey),
        matching: find.byIcon(KunIcons.check),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(senderId: '1001'),
          users: _users,
          own: true,
          status: KunChatSendStatus.read,
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(KunChatBubble.metaKey),
        matching: find.byIcon(KunIcons.checkCheck),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byKey(KunChatBubble.metaKey),
          matching: find.byIcon(KunIcons.checkCheck),
        ),
      ),
      isSemantics(label: KunMessages.en.chatStatus.read),
    );

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(senderId: '1001'),
          users: _users,
          own: true,
          status: KunChatSendStatus.failed,
        ),
      ),
    );
    expect(find.byIcon(KunIcons.check), findsNothing);
    expect(find.byIcon(KunIcons.checkCheck), findsNothing);
    expect(find.byIcon(KunIcons.clock), findsNothing);
    expect(find.byKey(KunChatBubble.retryKey), findsOneWidget);
  });

  testWidgets('twin keeps the last line clear of the real meta', (
    WidgetTester tester,
  ) async {
    Future<void> expectClear(String text, {required double width}) async {
      await tester.pumpWidget(
        wrap(
          KunChatBubble(
            message: _msg(text: text),
            users: _users,
          ),
          width: width,
        ),
      );
      await tester.pump();
      final (RenderParagraph paragraph, String plain) = messageParagraph(
        tester,
        text.split(' ').first,
      );
      final int last = plain.length - 1;
      final List<TextBox> boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: last, extentOffset: last + 1),
      );
      expect(boxes, isNotEmpty);
      final TextBox box = boxes.last;
      final Rect glyph = Rect.fromLTRB(
        box.left,
        box.top,
        box.right,
        box.bottom,
      );
      final Rect glyphGlobal = glyph.shift(
        paragraph.localToGlobal(Offset.zero),
      );
      final Rect meta = tester.getRect(find.byKey(KunChatBubble.metaKey));
      expect(
        meta.deflate(0.5).overlaps(glyphGlobal.deflate(0.5)),
        isFalse,
        reason: 'meta $meta overlaps glyph $glyphGlobal for "$text"',
      );
    }

    await expectClear('Hi', width: 400);
    await expectClear(
      'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
      width: 220,
    );
  });

  testWidgets('reaction toggle payloads and semantics', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<String?> keys = <String?>[];
    final KunChatMessage message = _msg(
      text: 'hi',
      reactions: const <KunChatReaction>[
        KunChatReaction(reaction: 'heart', count: 3, reacted: true),
        KunChatReaction(reaction: 'party', count: 1, reacted: false),
      ],
    );
    const List<KunChatReactionOption> options = <KunChatReactionOption>[
      KunChatReactionOption(key: 'heart', emoji: '❤️', label: 'Love'),
      KunChatReactionOption(key: 'party', emoji: '🎉', label: 'Party'),
    ];
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: message,
          users: _users,
          reactionOptions: options,
          onReact: keys.add,
        ),
      ),
    );
    final Finder heart = find.byWidgetPredicate((Widget w) {
      return w is Semantics &&
          w.properties.label ==
              KunMessages.en.chat.reactionCount(label: 'Love', count: 3);
    });
    final Finder party = find.byWidgetPredicate((Widget w) {
      return w is Semantics &&
          w.properties.label ==
              KunMessages.en.chat.reactionCount(label: 'Party', count: 1);
    });
    expect(
      tester.getSemantics(heart),
      isSemantics(
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        label: KunMessages.en.chat.reactionCount(label: 'Love', count: 3),
      ),
    );
    expect(
      tester.getSemantics(party),
      isSemantics(
        isButton: true,
        hasToggledState: true,
        isToggled: false,
        label: KunMessages.en.chat.reactionCount(label: 'Party', count: 1),
      ),
    );
    expect(
      tester.getSemantics(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Semantics &&
              w.properties.label == KunMessages.en.chat.reactions,
        ),
      ),
      isSemantics(label: KunMessages.en.chat.reactions),
    );

    await tester.tap(heart);
    await tester.tap(party);
    expect(keys, <String?>[null, 'party']);
    handle.dispose();
  });

  testWidgets('retry fires and its gutter is hittable', (
    WidgetTester tester,
  ) async {
    int retries = 0;
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(senderId: '1001'),
          users: _users,
          own: true,
          status: KunChatSendStatus.failed,
          onRetry: () => retries++,
        ),
        width: 400,
      ),
    );
    final Rect retry = tester.getRect(find.byKey(KunChatBubble.retryKey));
    final Rect surface = tester.getRect(find.byKey(KunChatBubble.surfaceKey));
    expect(retry.right, lessThanOrEqualTo(surface.left + 0.5));
    expect(surface.left - retry.left, closeTo(32, 1));
    await tester.tap(find.byKey(KunChatBubble.retryKey));
    await tester.pump();
    expect(retries, 1);
    await tester.tapAt(retry.center);
    await tester.pump();
    expect(retries, 2);
  });

  testWidgets('disabled swallows sender, reply, reactions and photos', (
    WidgetTester tester,
  ) async {
    final List<String> log = <String>[];
    const KunChatPhoto photo = KunChatPhoto(
      imageHash: 'wide',
      width: 1920,
      height: 1080,
    );
    await tester.pumpWidget(
      wrap(
        Column(
          children: <Widget>[
            KunChatBubble(
              message: _msg(
                text: 'cap',
                media: photo,
                replyTo: const KunChatReplyTo(
                  seq: 9,
                  senderId: '1002',
                  text: 'earlier',
                  deleted: false,
                ),
                reactions: const <KunChatReaction>[
                  KunChatReaction(reaction: 'heart', count: 1, reacted: false),
                ],
              ),
              users: _users,
              showSender: true,
              disabled: true,
              lightbox: false,
              reactionOptions: const <KunChatReactionOption>[
                KunChatReactionOption(key: 'heart', emoji: '❤️', label: 'Love'),
              ],
              resolveMediaUrl: (KunChatMedia _, KunChatMediaVariant __) => 'p',
              onUserTap: (_) => log.add('user'),
              onReplyTap: (_) => log.add('reply'),
              onReact: (_) => log.add('react'),
              onPhotoTap: (_) => log.add('photo'),
            ),
            KunChatBubble(
              message: _msg(
                senderId: '1001',
                context: const KunChatContext(
                  site: 'moyu',
                  kind: 'patch',
                  id: '1',
                  title: 'Patch',
                  url: 'https://www.moyu.moe/patch/1',
                ),
              ),
              users: _users,
              own: true,
              status: KunChatSendStatus.failed,
              disabled: true,
              onRetry: () => log.add('retry'),
              onLink: (KunChatLinkEvent event) {
                event.preventDefault();
                log.add('link');
              },
            ),
          ],
        ),
        config: KunUIConfig(
          imageProvider: _resolveImage,
          navigate: (_, __) => log.add('nav'),
        ),
      ),
    );
    await tester.tap(find.byKey(KunChatBubble.senderKey));
    await tester.tap(find.byKey(KunChatBubble.replyKey));
    await tester.tap(find.byKey(KunChatBubble.photoKey(0)));
    await tester.tap(
      find.byWidgetPredicate(
        (Widget w) =>
            w is Semantics &&
            w.properties.label ==
                KunMessages.en.chat.reactionCount(label: 'Love', count: 1),
      ),
    );
    await tester.tap(find.byKey(KunChatBubble.retryKey));
    await tester.tap(find.text('Patch'));
    await tester.pump();
    expect(log, <String>['retry', 'link']);
  });

  testWidgets('service pill uses kunChatServiceText', (
    WidgetTester tester,
  ) async {
    final KunChatMessage created = _msg(
      senderId: '1001',
      text: '',
      kind: KunChatMessageKind.service,
      serviceAction: const KunChatGroupCreatedAction(title: 'Room'),
    );
    await tester.pumpWidget(
      wrap(
        KunChatBubble(message: created, users: _users, currentUserId: '1001'),
      ),
    );
    final String expected = kunChatServiceText(
      created,
      KunChatServiceContext(
        users: kunChatUserMap(_users),
        currentUserId: '1001',
        messages: KunMessages.en,
      ),
    );
    expect(find.text(expected), findsOneWidget);
    expect(find.byKey(KunChatBubble.serviceKey), findsOneWidget);
    expect(find.byKey(KunChatBubble.surfaceKey), findsNothing);
  });

  testWidgets('corner radii follow position and own', (
    WidgetTester tester,
  ) async {
    Future<BorderRadius> pump(
      KunChatBubblePosition position, {
      required bool own,
    }) async {
      await tester.pumpWidget(
        wrap(
          KunChatBubble(
            message: _msg(senderId: own ? '1001' : '1002'),
            users: _users,
            own: own,
            position: position,
            status: own ? KunChatSendStatus.sent : null,
          ),
        ),
      );
      return surfaceRadius(tester);
    }

    const Radius lg = Radius.circular(KunRadius.lg);
    const Radius sm = Radius.circular(KunRadius.sm);

    final BorderRadius ownSingle = await pump(
      KunChatBubblePosition.single,
      own: true,
    );
    expect(ownSingle.bottomRight, Radius.zero);
    expect(ownSingle.topRight, lg);

    final BorderRadius ownFirst = await pump(
      KunChatBubblePosition.first,
      own: true,
    );
    expect(ownFirst.bottomRight, sm);
    expect(ownFirst.topRight, lg);

    final BorderRadius ownMiddle = await pump(
      KunChatBubblePosition.middle,
      own: true,
    );
    expect(ownMiddle.topRight, sm);
    expect(ownMiddle.bottomRight, sm);

    final BorderRadius ownLast = await pump(
      KunChatBubblePosition.last,
      own: true,
    );
    expect(ownLast.topRight, sm);
    expect(ownLast.bottomRight, Radius.zero);

    final BorderRadius otherSingle = await pump(
      KunChatBubblePosition.single,
      own: false,
    );
    expect(otherSingle.bottomLeft, Radius.zero);
    expect(otherSingle.topLeft, lg);
    expect(find.byKey(KunChatBubble.tailKey), findsOneWidget);
  });

  testWidgets('context card host includes the port', (
    WidgetTester tester,
  ) async {
    final List<String> hrefs = <String>[];
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(
            context: const KunChatContext(
              site: 'moyu',
              kind: 'patch',
              id: '1',
              title: 'Patch',
              url: 'https://www.moyu.moe:8443/patch/1',
            ),
          ),
          users: _users,
        ),
        config: KunUIConfig(
          imageProvider: _resolveImage,
          navigate: (_, String href) => hrefs.add(href),
        ),
      ),
    );
    expect(find.text('www.moyu.moe:8443'), findsOneWidget);
    await tester.tap(find.text('Patch'));
    await tester.pump();
    expect(hrefs.single, contains('www.moyu.moe:8443'));
  });

  testWidgets('short own message keeps meta on the text line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(senderId: '1001', text: 'ok', editedAt: _when),
          users: _users,
          own: true,
          status: KunChatSendStatus.read,
        ),
        width: 600,
      ),
    );
    await tester.pump();
    final (RenderParagraph paragraph, String plain) = messageParagraph(
      tester,
      'ok',
    );
    expect(plain, 'ok');
    expect(
      paragraph.size.height,
      closeTo(paragraph.preferredLineHeight, 0.5),
    );
    final Size surface = tester.getSize(find.byKey(KunChatBubble.surfaceKey));
    expect(
      surface.height,
      closeTo(
        paragraph.preferredLineHeight + KunSpacing.unit * 1.5 * 2,
        1,
      ),
    );
    final List<TextBox> boxes = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    expect(boxes, isNotEmpty);
    final Offset origin = paragraph.localToGlobal(Offset.zero);
    final Rect textBand = Rect.fromLTRB(
      boxes.first.left,
      boxes.map((TextBox b) => b.top).reduce(
            (double a, double b) => a < b ? a : b,
          ),
      boxes.last.right,
      boxes.map((TextBox b) => b.bottom).reduce(
            (double a, double b) => a > b ? a : b,
          ),
    ).shift(origin);
    final Rect meta = tester.getRect(find.byKey(KunChatBubble.metaKey));
    expect(meta.top, lessThan(textBand.bottom - 0.5));
    expect(meta.bottom, greaterThan(textBand.top + 0.5));
    for (final TextBox box in boxes) {
      final Rect glyph = Rect.fromLTRB(
        box.left,
        box.top,
        box.right,
        box.bottom,
      ).shift(origin);
      expect(
        meta.deflate(0.5).overlaps(glyph.deflate(0.5)),
        isFalse,
        reason: 'meta $meta overlaps glyph $glyph',
      );
    }
  });

  testWidgets('text plus meta longer than the cap wraps the meta', (
    WidgetTester tester,
  ) async {
    const double parent = 600;
    final double cap = _capOf(parent);
    const String text = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxx';
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(senderId: '1001', text: text, editedAt: _when),
          users: _users,
          own: true,
          status: KunChatSendStatus.read,
        ),
        width: parent,
      ),
    );
    await tester.pump();
    final (RenderParagraph paragraph, String plain) = messageParagraph(
      tester,
      text.substring(0, 8),
    );
    expect(plain, text);
    expect(
        paragraph.size.height, greaterThan(paragraph.preferredLineHeight + 4));
    expect(
      tester.getSize(find.byKey(KunChatBubble.surfaceKey)).width,
      closeTo(cap, 0.5),
    );
    final List<TextBox> boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: plain.length),
    );
    final Offset origin = paragraph.localToGlobal(Offset.zero);
    final double textBottom = boxes
        .map((TextBox b) => b.bottom)
        .reduce((double a, double b) => a > b ? a : b);
    final Rect meta = tester.getRect(find.byKey(KunChatBubble.metaKey));
    expect(
      meta.top,
      greaterThanOrEqualTo(origin.dy + textBottom - 1),
      reason:
          'meta $meta should sit on its own line below text at ${origin.dy + textBottom}',
    );
  });

  testWidgets('a long context title widens the bubble and is not truncated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(text: 'ok', context: _contextWithTitle('Hi')),
          users: _users,
        ),
        width: 800,
      ),
    );
    final Size shortSize = tester.getSize(find.byKey(KunChatBubble.surfaceKey));
    const String longTitle = '《星空鉄道とシロの旅》汉化补丁 v0.9';
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(text: 'ok', context: _contextWithTitle(longTitle)),
          users: _users,
        ),
        width: 800,
      ),
    );
    final Size longSize = tester.getSize(find.byKey(KunChatBubble.surfaceKey));
    expect(longSize.width, greaterThan(shortSize.width + 8));
    final RenderParagraph title = tester.renderObject<RenderParagraph>(
      find.text(longTitle),
    );
    expect(title.didExceedMaxLines, isFalse);
  });

  testWidgets('twelve reaction chips wrap and keep meta on the last row', (
    WidgetTester tester,
  ) async {
    const double parent = 400;
    final double cap = _capOf(parent);
    final List<KunChatReaction> reactions = <KunChatReaction>[
      for (int i = 0; i < 12; i++)
        KunChatReaction(reaction: 'r$i', count: i + 1, reacted: false),
    ];
    final List<KunChatReactionOption> options = <KunChatReactionOption>[
      for (int i = 0; i < 12; i++)
        KunChatReactionOption(key: 'r$i', emoji: '😀', label: 'R$i'),
    ];
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(text: 'hi', reactions: reactions),
          users: _users,
          reactionOptions: options,
        ),
        width: parent,
      ),
    );
    await tester.pump();
    final Size surface = tester.getSize(find.byKey(KunChatBubble.surfaceKey));
    expect(surface.width, lessThanOrEqualTo(cap + 0.5));
    final List<Rect> chips = <Rect>[
      for (int i = 0; i < 12; i++)
        tester.getRect(
          find.byWidgetPredicate((Widget w) {
            return w is Semantics &&
                w.properties.label ==
                    KunMessages.en.chat.reactionCount(
                      label: 'R$i',
                      count: i + 1,
                    );
          }),
        ),
    ];
    final double firstTop = chips.first.top;
    expect(
      chips.any((Rect r) => (r.top - firstTop).abs() > 8),
      isTrue,
      reason: 'chips should wrap onto a second row, tops=$chips',
    );
    final double lastRowTop = chips
        .map((Rect r) => r.top)
        .reduce((double a, double b) => a > b ? a : b);
    final Rect meta = tester.getRect(find.byKey(KunChatBubble.metaKey));
    expect(
      (meta.top - lastRowTop).abs(),
      lessThan(8),
      reason: 'meta $meta not on last chip row (top $lastRowTop)',
    );
  });

  testWidgets('absent resolveMediaUrl passes an empty src', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(
            text: '',
            media: const KunChatPhoto(
              imageHash: 'wide',
              width: 1920,
              height: 1080,
            ),
          ),
          users: _users,
          lightbox: false,
        ),
      ),
    );
    final KunImage image = tester.widget(find.byType(KunImage));
    expect(image.src, isEmpty);
  });

  testWidgets('a reaction key with no option is unboxed text, not clipped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(
            text: 'hi',
            reactions: const <KunChatReaction>[
              KunChatReaction(reaction: 'heart', count: 2, reacted: false),
            ],
          ),
          users: _users,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('heart'), findsOneWidget);
    final RenderParagraph para = tester.renderObject<RenderParagraph>(
      find.text('heart'),
    );
    expect(para.didExceedMaxLines, isFalse);
    expect(para.size.width, greaterThan(KunSpacing.unit * 5));
    expect(
      para.size.width,
      greaterThanOrEqualTo(para.textSize.width - 0.5),
    );
    expect(
      para.size.width,
      greaterThanOrEqualTo(
        para.getMaxIntrinsicWidth(double.infinity) - 0.5,
      ),
    );
    final String chipLabel = KunMessages.en.chat.reactionCount(
      label: 'heart',
      count: 2,
    );
    final Size chip = tester.getSize(
      find.byWidgetPredicate((Widget w) {
        return w is Semantics && w.properties.label == chipLabel;
      }),
    );
    expect(chip.width, greaterThan(KunSpacing.unit * 5 + 8));
  });

  testWidgets('a failed reaction image falls back to the emoji', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    const List<KunChatReactionOption> options = <KunChatReactionOption>[
      KunChatReactionOption(
        key: 'heart',
        emoji: '❤️',
        label: 'Love',
        imageUrl: 'https://example.test/heart.webp',
      ),
    ];
    final KunChatMessage message = _msg(
      text: 'hi',
      reactions: const <KunChatReaction>[
        KunChatReaction(reaction: 'heart', count: 3, reacted: true),
      ],
    );
    final String chipLabel = KunMessages.en.chat.reactionCount(
      label: 'Love',
      count: 3,
    );
    final Finder chip = find.byWidgetPredicate((Widget w) {
      return w is Semantics && w.properties.label == chipLabel;
    });

    Future<Size> pumpChip(ImageProvider Function(String) resolver) async {
      await tester.pumpWidget(
        wrap(
          KunChatBubble(
            message: message,
            users: _users,
            reactionOptions: options,
          ),
          config: KunUIConfig(
            imageProvider: resolver,
            navigate: (_, __) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return tester.getSize(chip);
    }

    final Size ok = await pumpChip((_) => _memory);
    final Size failed = await pumpChip((_) => const _FailingImageProvider());
    tester.takeException();
    expect(find.text('❤️'), findsOneWidget);
    expect(find.textContaining('load failed'), findsNothing);
    expect(failed, ok);
    expect(
      tester.getSemantics(chip).getSemanticsData().label,
      allOf(contains(chipLabel), isNot(contains('load failed'))),
    );
    handle.dispose();
  });

  testWidgets('sender prefix lands on the message text node', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    const String text = 'see x here';
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(
            text: text,
            entities: const <KunChatEntity>[
              KunChatEntity(
                type: KunChatEntityType.textLink,
                offset: 4,
                length: 1,
                url: 'https://www.kungal.com/topic/1',
              ),
            ],
          ),
          users: _users,
        ),
      ),
    );
    final String prefix = KunMessages.en.chat.senderPrefix(name: 'Haru');
    SemanticsNode? prefixNode;
    SemanticsNode? textNode;
    SemanticsNode? linkNode;
    void walk(SemanticsNode node) {
      final SemanticsData data = node.getSemanticsData();
      if (data.label.isNotEmpty) {
        expect(
          node.rect.size,
          isNot(Size.zero),
          reason: 'labelled zero-size node "${data.label}"',
        );
      }
      if (data.label.startsWith(prefix)) {
        prefixNode = node;
      }
      if (data.label.contains('see')) {
        textNode = node;
      }
      if (data.hasAction(SemanticsAction.tap) && data.label.contains('x')) {
        linkNode = node;
      }
      node.visitChildren((SemanticsNode child) {
        walk(child);
        return true;
      });
    }

    walk(tester.getSemantics(find.byType(KunChatBubble)));
    expect(prefixNode, isNotNull);
    expect(prefixNode!.rect.size, isNot(Size.zero));
    expect(prefixNode!.getSemanticsData().label, startsWith(prefix));
    expect(textNode, isNotNull);
    expect(linkNode, isNotNull);
    expect(linkNode!.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('retry is one labelled actionable node and keeps its size', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int retries = 0;
    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(senderId: '1001'),
          users: _users,
          own: true,
          status: KunChatSendStatus.failed,
          onRetry: () => retries++,
        ),
        width: 400,
        tapTargetSize: KunTapTargetSize.padded,
      ),
    );
    final String label = KunMessages.en.chatStatus.failed;
    final List<SemanticsNode> retryNodes = <SemanticsNode>[];
    void walk(SemanticsNode node) {
      final SemanticsData data = node.getSemanticsData();
      final bool actionable = data.hasAction(SemanticsAction.tap) ||
          data.hasAction(SemanticsAction.longPress);
      if (data.label == label || (actionable && data.label.contains(label))) {
        retryNodes.add(node);
      }
      node.visitChildren((SemanticsNode child) {
        walk(child);
        return true;
      });
    }

    walk(tester.getSemantics(find.byType(KunChatBubble)));
    final List<SemanticsNode> actionable = retryNodes
        .where(
          (SemanticsNode n) =>
              n.getSemanticsData().hasAction(SemanticsAction.tap),
        )
        .toList();
    expect(actionable, hasLength(1));
    expect(actionable.single.getSemanticsData().label, label);
    expect(
      actionable.single.getSemanticsData().flagsCollection.isButton,
      isTrue,
    );
    expect(
      tester.getSize(find.byKey(KunChatBubble.retryKey)),
      Size.square(KunSpacing.unit * 6),
    );

    await tester.pumpWidget(
      wrap(
        KunChatBubble(
          message: _msg(senderId: '1001'),
          users: _users,
          own: true,
          status: KunChatSendStatus.failed,
          onRetry: () => retries++,
        ),
        width: 400,
        tapTargetSize: KunTapTargetSize.shrinkWrap,
      ),
    );
    expect(
      tester.getSize(find.byKey(KunChatBubble.retryKey)),
      Size.square(KunSpacing.unit * 6),
    );
    handle.dispose();
  });
}
