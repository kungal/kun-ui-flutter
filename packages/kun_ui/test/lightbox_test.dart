import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

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

Uint8List _solidPng({int width = 640, int height = 480}) {
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
  const int maxBlock = 65535;
  int offset = 0;
  while (offset < pixels.length) {
    final int remaining = pixels.length - offset;
    final int n = remaining > maxBlock ? maxBlock : remaining;
    final bool last = offset + n >= pixels.length;
    zlib
      ..addByte(last ? 1 : 0)
      ..addByte(n & 0xff)
      ..addByte((n >> 8) & 0xff)
      ..addByte((~n) & 0xff)
      ..addByte(((~n) >> 8) & 0xff)
      ..add(pixels.sublist(offset, offset + n));
    offset += n;
  }
  zlib.add(_u32(_adler32(pixels)));
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

const List<KunLightboxImage> _three = <KunLightboxImage>[
  KunLightboxImage(src: 'a', alt: 'Alpha'),
  KunLightboxImage(src: 'b', alt: 'Beta'),
  KunLightboxImage(src: 'c', alt: 'Gamma'),
];

final Map<String, int> _resolverHits = <String, int>{};

ImageProvider _resolve(String src) {
  _resolverHits[src] = (_resolverHits[src] ?? 0) + 1;
  return _memory;
}

Finder get layer => find.byKey(KunLightbox.layerKey);
Finder get backdrop => find.byKey(KunLightbox.backdropKey);
Finder get stage => find.byKey(KunLightbox.stageKey);
Finder get imageTransform => find.byKey(KunLightbox.imageTransformKey);
Finder get counter => find.byKey(KunLightbox.counterKey);
Finder get toolbar => find.byKey(KunLightbox.toolbarKey);

Finder get zoomIn => find.byIcon(KunIcons.zoomIn);
Finder get zoomOut => find.byIcon(KunIcons.zoomOut);
Finder get rotateLeft => find.byIcon(KunIcons.rotateCcw);
Finder get rotateRight => find.byIcon(KunIcons.rotateCw);
Finder get reset => find.byIcon(KunIcons.refreshCcw);
Finder get close => find.byIcon(KunIcons.x);
Finder get next => find.byIcon(KunIcons.chevronRight);
Finder get prev => find.byIcon(KunIcons.chevronLeft);

Widget wrap(
  Widget child, {
  KunUIConfig? config,
  KunMessages? messages,
  Size size = const Size(1024, 768),
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: KunTheme(
      data: KunThemeData.light(),
      child: KunMessagesScope(
        messages: messages ?? KunMessages.en,
        child: KunUIConfigScope(
          config: config ?? KunUIConfig(imageProvider: _resolve),
          child: WidgetsApp(
            color: KunColors.black,
            debugShowCheckedModeBanner: false,
            home: child,
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

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.initial = false,
    this.images = _three,
    this.initialIndex = 0,
    this.behind,
  });

  final bool initial;
  final List<KunLightboxImage> images;
  final int initialIndex;
  final Widget? behind;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool isOpen = widget.initial;
  late int initialIndex = widget.initialIndex;
  final List<bool> events = <bool>[];

  void open({int? at}) {
    setState(() {
      if (at != null) {
        initialIndex = at;
      }
      isOpen = true;
    });
  }

  void close() => setState(() => isOpen = false);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.behind != null) widget.behind!,
        KunButton(onPressed: open, child: const Text('Open')),
        KunLightbox(
          images: widget.images,
          isOpen: isOpen,
          initialIndex: initialIndex,
          onOpenChanged: (bool next) {
            events.add(next);
            setState(() => isOpen = next);
          },
        ),
      ],
    );
  }
}

Future<_HostState> _pumpOpen(
  WidgetTester tester, {
  List<KunLightboxImage> images = _three,
  int initialIndex = 0,
  Size size = const Size(1024, 768),
  Widget? behind,
  KunUIConfig? config,
}) async {
  setView(tester, size);
  _resolverHits.clear();
  final GlobalKey<_HostState> key = GlobalKey<_HostState>();
  await tester.pumpWidget(
    wrap(
      _Host(
        key: key,
        initial: true,
        images: images,
        initialIndex: initialIndex,
        behind: behind,
      ),
      config: config,
      size: size,
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  await _loadImages(tester);
  return key.currentState!;
}

Future<void> _loadImages(WidgetTester tester) async {
  final Element element = tester.element(find.byType(WidgetsApp));
  await tester.runAsync(() async {
    await precacheImage(_memory, element);
  });
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  final Offset center = tester.getCenter(finder);
  final TestGesture first = await tester.startGesture(center);
  await first.up();
  await tester.pump(const Duration(milliseconds: 40));
  final TestGesture second = await tester.startGesture(center);
  await second.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Transform _imageTransform(WidgetTester tester) {
  return tester.widget<Transform>(
    find.descendant(of: imageTransform, matching: find.byType(Transform)),
  );
}

void main() {
  testWidgets('opens and closes through isOpen', (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(wrap(_Host(key: key)));
    expect(layer, findsNothing);

    key.currentState!.open();
    await tester.pump();
    await tester.pumpAndSettle();
    await _loadImages(tester);
    expect(layer, findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    key.currentState!.close();
    await tester.pumpAndSettle();
    expect(layer, findsNothing);
    expect(key.currentState!.events, isEmpty);
  });

  testWidgets('onOpenChanged(false) on back, Escape and backdrop click', (
    WidgetTester tester,
  ) async {
    _HostState host = await _pumpOpen(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(layer, findsNothing);
    expect(host.events, <bool>[false]);

    host = await _pumpOpen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(layer, findsNothing);
    expect(host.events, <bool>[false]);

    host = await _pumpOpen(tester);
    await tester.tapAt(const Offset(8, 400));
    await tester.pumpAndSettle();
    expect(layer, findsNothing);
    expect(host.events, <bool>[false]);
  });

  testWidgets('no dismissal after a drag', (WidgetTester tester) async {
    final _HostState host = await _pumpOpen(tester);
    final TestGesture gesture = await tester.startGesture(const Offset(8, 400));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(layer, findsOneWidget);
    expect(host.events, isEmpty);
  });

  testWidgets('arrow keys and buttons wrap', (WidgetTester tester) async {
    await _pumpOpen(tester);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.tap(prev);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('initialIndex', (WidgetTester tester) async {
    await _pumpOpen(tester, initialIndex: 2);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Gamma'), findsWidgets);
  });

  testWidgets('double tap zooms and a second one resets', (
    WidgetTester tester,
  ) async {
    await _pumpOpen(tester);
    expect(find.text('100%'), findsOneWidget);
    await _doubleTap(tester, imageTransform);
    await tester.pumpAndSettle();
    expect(find.text('200%'), findsOneWidget);
    await _doubleTap(tester, imageTransform);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets(
    'while zoomed a horizontal drag pans and does not turn the page',
    (WidgetTester tester) async {
      await _pumpOpen(tester);
      await _doubleTap(tester, imageTransform);
      await tester.pumpAndSettle();
      expect(find.text('200%'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);

      final Matrix4 before = _imageTransform(tester).transform.clone();
      await tester.timedDrag(
        imageTransform,
        const Offset(-80, 0),
        const Duration(milliseconds: 80),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('200%'), findsOneWidget);
      final Matrix4 after = _imageTransform(tester).transform.clone();
      expect(after.getTranslation().x, isNot(before.getTranslation().x));
    },
  );

  testWidgets('rotate, zoom and reset buttons', (WidgetTester tester) async {
    await _pumpOpen(tester);
    expect(
      find.descendant(of: toolbar, matching: find.byType(KunButton)),
      findsNWidgets(5),
    );

    await tester.tap(zoomIn);
    await tester.pumpAndSettle();
    expect(find.text('150%'), findsOneWidget);
    await tester.tap(zoomIn);
    await tester.pumpAndSettle();
    expect(find.text('200%'), findsOneWidget);

    await tester.tap(zoomOut);
    await tester.pumpAndSettle();
    expect(find.text('150%'), findsOneWidget);

    await tester.tap(rotateRight);
    await tester.pumpAndSettle();
    expect(_imageTransform(tester).transform.storage[0], closeTo(0, 0.001));

    await tester.tap(rotateLeft);
    await tester.pumpAndSettle();
    expect(_imageTransform(tester).transform.storage[0], closeTo(1.5, 0.001));

    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(_imageTransform(tester).transform.storage[0], closeTo(1, 0.001));
  });

  testWidgets('accessible names', (WidgetTester tester) async {
    await _pumpOpen(tester);
    final KunLightboxStrings strings = KunMessages.en.lightbox;
    expect(find.bySemanticsLabel(strings.label), findsOneWidget);
    expect(find.bySemanticsLabel(strings.close), findsOneWidget);
    expect(find.bySemanticsLabel(strings.prev), findsOneWidget);
    expect(find.bySemanticsLabel(strings.next), findsOneWidget);
    expect(find.bySemanticsLabel(strings.zoomIn), findsOneWidget);
    expect(find.bySemanticsLabel(strings.zoomOut), findsOneWidget);
    expect(find.bySemanticsLabel(strings.rotateLeft), findsOneWidget);
    expect(find.bySemanticsLabel(strings.rotateRight), findsOneWidget);
    expect(find.bySemanticsLabel(strings.reset), findsOneWidget);
    expect(find.bySemanticsLabel(strings.goto(index: 1)), findsOneWidget);
    expect(find.bySemanticsLabel('Alpha'), findsWidgets);
    expect(find.byIcon(KunIcons.download), findsNothing);
  });

  testWidgets('focus is trapped and restored', (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    final FocusNode behind = FocusNode();
    addTearDown(behind.dispose);
    final GlobalKey<_HostState> key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      wrap(
        _Host(
          key: key,
          behind: Focus(
            focusNode: behind,
            child: const KunButton(onPressed: null, child: Text('behind')),
          ),
        ),
      ),
    );
    behind.requestFocus();
    await tester.pump();
    expect(behind.hasFocus, isTrue);

    key.currentState!.open();
    await tester.pump();
    await tester.pumpAndSettle();
    await _loadImages(tester);
    expect(layer, findsOneWidget);
    expect(behind.hasFocus, isFalse);

    for (int i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(behind.hasFocus, isFalse);
    }

    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(layer, findsNothing);
    expect(behind.hasFocus, isTrue);
  });

  testWidgets('showKunLightbox completes on close', (
    WidgetTester tester,
  ) async {
    setView(tester, const Size(1024, 768));
    late Future<void> closed;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (BuildContext context) {
            return KunButton(
              onPressed: () {
                closed = showKunLightbox(context, images: _three);
              },
              child: const Text('Show'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pumpAndSettle();
    await _loadImages(tester);
    expect(layer, findsOneWidget);

    bool done = false;
    closed.then((_) => done = true);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(layer, findsNothing);
    expect(done, isTrue);
  });

  testWidgets('custom imageProvider is used', (WidgetTester tester) async {
    final List<String> seen = <String>[];
    await _pumpOpen(
      tester,
      config: KunUIConfig(
        imageProvider: (String src) {
          seen.add(src);
          return _memory;
        },
      ),
    );
    expect(seen, containsAll(<String>['a', 'b', 'c']));
    expect(
      tester
          .widget<Image>(
            find
                .descendant(
                  of: find.byKey(KunLightbox.thumbsKey),
                  matching: find.byType(Image),
                )
                .first,
          )
          .image,
      isA<ResizeImage>(),
    );
  });

  testWidgets('swipe when not zoomed turns the page', (
    WidgetTester tester,
  ) async {
    await _pumpOpen(tester);
    await tester.timedDrag(
      imageTransform,
      const Offset(-80, 0),
      const Duration(milliseconds: 80),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('close button dismisses', (WidgetTester tester) async {
    final _HostState host = await _pumpOpen(tester);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(layer, findsNothing);
    expect(host.events, <bool>[false]);
  });
}
