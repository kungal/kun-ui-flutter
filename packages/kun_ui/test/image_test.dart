import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/components/pulse.dart';

const String _docsHash = 'eBeCA4AmyAaYeIcLy20KVwg3inaCelc=';

Widget wrap(
  Widget child, {
  KunUIConfig? config,
  bool disableAnimations = false,
}) {
  Widget tree = child;
  if (config != null) {
    tree = KunUIConfigScope(config: config, child: tree);
  }
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: tree),
      ),
    ),
  );
}

class _GateImageProvider extends ImageProvider<_GateImageProvider> {
  _GateImageProvider();

  final Completer<ImageInfo> gate = Completer<ImageInfo>();

  @override
  Future<_GateImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_GateImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _GateImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(gate.future);
  }
}

class _UrlGateProvider extends ImageProvider<_UrlGateProvider> {
  _UrlGateProvider(this.url, this.gate);

  final String url;
  final Completer<ImageInfo> gate;

  @override
  Future<_UrlGateProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_UrlGateProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _UrlGateProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(gate.future);
  }

  @override
  bool operator ==(Object other) =>
      other is _UrlGateProvider && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

class _FailingImageProvider extends ImageProvider<_FailingImageProvider> {
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

class _SyncImageProvider extends ImageProvider<_SyncImageProvider> {
  _SyncImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_SyncImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_SyncImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _SyncImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())),
    );
  }
}

Future<ui.Image> pixelImage(WidgetTester tester, [int w = 1, int h = 1]) async {
  late ui.Image image;
  await tester.runAsync(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF000000),
    );
    image = await recorder.endRecording().toImage(w, h);
  });
  return image;
}

double opacityOf(WidgetTester tester, Key key) {
  return tester
      .widget<FadeTransition>(
        find
            .descendant(
              of: find.byKey(key),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;
}

bool hasThumbHashImage(WidgetTester tester) {
  return tester.widgetList<Image>(find.byType(Image)).any(
        (Image image) => image.image is KunThumbHashImage,
      );
}

void main() {
  testWidgets('src reaches imageProvider', (tester) async {
    final List<String> urls = <String>[];
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunImage(src: 'https://x.test/a.png', alt: 'A'),
        config: KunUIConfig(
          imageProvider: (String url) {
            urls.add(url);
            return _SyncImageProvider(pixel);
          },
        ),
      ),
    );
    expect(urls, isNotEmpty);
    expect(urls.first, 'https://x.test/a.png');
    expect(urls, everyElement('https://x.test/a.png'));
  });

  testWidgets('loading keeps the placeholder at 1 until the picture fades in',
      (tester) async {
    final _GateImageProvider provider = _GateImageProvider();
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunImage(
          src: 'https://x.test/a.png',
          width: 80,
          height: 80,
        ),
        config: KunUIConfig(imageProvider: (_) => provider),
      ),
    );
    expect(find.byType(KunPulseLayer), findsOneWidget);
    expect(opacityOf(tester, KunImage.placeholderKey), 1);
    expect(opacityOf(tester, KunImage.pictureFadeKey), 0);

    provider.gate.complete(ImageInfo(image: pixel.clone()));
    await tester.pump();
    expect(find.byType(KunPulseLayer), findsNothing);
    expect(opacityOf(tester, KunImage.placeholderKey), 1);
    expect(opacityOf(tester, KunImage.pictureFadeKey), 0);

    await tester.pump(KunDurations.slow);
    expect(opacityOf(tester, KunImage.pictureFadeKey), closeTo(1, 0.001));
    expect(opacityOf(tester, KunImage.placeholderKey), 1);

    await tester.pump(KunDurations.slow);
    expect(opacityOf(tester, KunImage.placeholderKey), 0);
  });

  testWidgets('error fades the placeholder with no hold and reports once',
      (tester) async {
    final List<String> errors = <String>[];
    await tester.pumpWidget(
      wrap(
        KunImage(
          src: 'https://x.test/bad.png',
          width: 80,
          height: 80,
          onError: errors.add,
        ),
        config: KunUIConfig(imageProvider: (_) => _FailingImageProvider()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(errors, <String>['https://x.test/bad.png']);
    expect(find.byType(KunPulseLayer), findsNothing);
    expect(opacityOf(tester, KunImage.placeholderKey), 1);

    await tester.pump(KunDurations.slow ~/ 2);
    final double mid = opacityOf(tester, KunImage.placeholderKey);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));

    await tester.pump(KunDurations.slow ~/ 2);
    expect(opacityOf(tester, KunImage.placeholderKey), closeTo(0, 0.001));

    await tester.pump();
    expect(errors, <String>['https://x.test/bad.png']);
  });

  testWidgets('fallback swaps and reports error then load, each once',
      (tester) async {
    final List<String> errors = <String>[];
    final List<String> loads = <String>[];
    final Completer<ImageInfo> ok = Completer<ImageInfo>();
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        KunImage(
          src: 'https://x.test/bad.png',
          fallbackSrc: 'https://x.test/ok.png',
          width: 80,
          height: 80,
          onError: errors.add,
          onLoad: loads.add,
        ),
        config: KunUIConfig(
          imageProvider: (String url) {
            if (url.contains('bad')) {
              return _FailingImageProvider();
            }
            return _UrlGateProvider(url, ok);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(errors, <String>['https://x.test/bad.png']);
    expect(loads, isEmpty);

    ok.complete(ImageInfo(image: pixel.clone()));
    await tester.pump();
    await tester.pump();
    expect(loads, <String>['https://x.test/ok.png']);
    expect(errors, <String>['https://x.test/bad.png']);
  });

  testWidgets('a new src brings the placeholder back at 1 in the same frame',
      (tester) async {
    final Completer<ImageInfo> first = Completer<ImageInfo>();
    final Completer<ImageInfo> second = Completer<ImageInfo>();
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunImage(src: 'https://x.test/a.png', width: 80, height: 80),
        config: KunUIConfig(
          imageProvider: (String url) => _UrlGateProvider(url, first),
        ),
      ),
    );
    first.complete(ImageInfo(image: pixel.clone()));
    await tester.pump();
    await tester.pump(KunDurations.slow);
    await tester.pump(KunDurations.slow);

    await tester.pumpWidget(
      wrap(
        const KunImage(src: 'https://x.test/b.png', width: 80, height: 80),
        config: KunUIConfig(
          imageProvider: (String url) => _UrlGateProvider(url, second),
        ),
      ),
    );
    expect(opacityOf(tester, KunImage.placeholderKey), 1);
    expect(find.byType(KunPulseLayer), findsOneWidget);
  });

  testWidgets('the skeleton pulses only while loading', (tester) async {
    final _GateImageProvider provider = _GateImageProvider();
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunImage(src: 'https://x.test/a.png', width: 80, height: 80),
        config: KunUIConfig(imageProvider: (_) => provider),
      ),
    );
    expect(find.byType(KunPulseLayer), findsOneWidget);

    provider.gate.complete(ImageInfo(image: pixel.clone()));
    await tester.pump();
    expect(find.byType(KunPulseLayer), findsNothing);
  });

  testWidgets('an undecodable thumbhash falls back to the skeleton',
      (tester) async {
    final _GateImageProvider provider = _GateImageProvider();
    await tester.pumpWidget(
      wrap(
        const KunImage(
          src: 'https://x.test/a.png',
          width: 80,
          height: 80,
          thumbhash: 'not-base64!!!',
        ),
        config: KunUIConfig(imageProvider: (_) => provider),
      ),
    );
    expect(hasThumbHashImage(tester), isFalse);
    expect(find.byType(KunPulseLayer), findsOneWidget);
  });

  testWidgets('a decodable thumbhash is the placeholder, not the pulse',
      (tester) async {
    final _GateImageProvider provider = _GateImageProvider();
    await tester.pumpWidget(
      wrap(
        const KunImage(
          src: 'https://x.test/a.png',
          width: 80,
          height: 80,
          thumbhash: _docsHash,
        ),
        config: KunUIConfig(imageProvider: (_) => provider),
      ),
    );
    expect(hasThumbHashImage(tester), isTrue);
    expect(find.byType(KunPulseLayer), findsNothing);
  });

  testWidgets('no wrapper when skeleton is false and there is no hash',
      (tester) async {
    final _GateImageProvider provider = _GateImageProvider();
    await tester.pumpWidget(
      wrap(
        const KunImage(
          src: 'https://x.test/a.png',
          skeleton: false,
          aspectRatio: 16 / 9,
        ),
        config: KunUIConfig(imageProvider: (_) => provider),
      ),
    );
    expect(find.byType(AspectRatio), findsNothing);
    expect(find.byKey(KunImage.placeholderKey), findsNothing);
    expect(find.byType(KunPulseLayer), findsNothing);
  });

  testWidgets('aspectRatio 16/9 in a 320-wide parent is 320x180',
      (tester) async {
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 320,
          child: KunImage(
            src: 'https://x.test/a.png',
            aspectRatio: 16 / 9,
          ),
        ),
        config: KunUIConfig(
          imageProvider: (_) => _SyncImageProvider(pixel),
        ),
      ),
    );
    expect(tester.getSize(find.byType(KunImage)), const Size(320, 180));
  });

  group('a parent that sizes the wrapper', () {
    for (final (String name, KunImage image) in <(String, KunImage)>[
      (
        'skeleton',
        const KunImage(src: 'https://x.test/a.png'),
      ),
      (
        'thumbhash',
        const KunImage(src: 'https://x.test/a.png', thumbhash: _docsHash),
      ),
      (
        'contain',
        const KunImage(src: 'https://x.test/a.png', fit: BoxFit.contain),
      ),
    ]) {
      testWidgets('$name: the picture fills a tight box', (tester) async {
        final ui.Image picture = await pixelImage(tester, 79, 100);
        await tester.pumpWidget(
          wrap(
            SizedBox(width: 150, height: 214, child: image),
            config: KunUIConfig(
              imageProvider: (_) => _SyncImageProvider(picture),
            ),
          ),
        );
        final Finder raw = find
            .descendant(
              of: find.byType(KunImage),
              matching: find.byType(RawImage),
            )
            .last;
        expect(tester.getSize(raw), const Size(150, 214));
        expect(
          tester.getTopLeft(raw),
          tester.getTopLeft(find.byType(KunImage)),
        );
        expect(tester.widget<RawImage>(raw).fit, image.fit);
      });
    }

    testWidgets('a loose parent keeps the intrinsic size', (tester) async {
      final ui.Image picture = await pixelImage(tester, 79, 100);
      await tester.pumpWidget(
        wrap(
          const KunImage(src: 'https://x.test/a.png', thumbhash: _docsHash),
          config: KunUIConfig(
            imageProvider: (_) => _SyncImageProvider(picture),
          ),
        ),
      );
      expect(tester.getSize(find.byType(KunImage)), const Size(79, 100));
    });

    testWidgets('the placeholder fills a tight box while loading',
        (tester) async {
      final _GateImageProvider provider = _GateImageProvider();
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 150,
            height: 214,
            child: KunImage(src: 'https://x.test/a.png'),
          ),
          config: KunUIConfig(imageProvider: (_) => provider),
        ),
      );
      expect(
        tester.getSize(find.byKey(KunImage.placeholderKey)),
        const Size(150, 214),
      );
    });
  });

  testWidgets('cacheWidth wraps the provider in ResizeImage', (tester) async {
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunImage(
          src: 'https://x.test/a.png',
          skeleton: false,
          cacheWidth: 64,
        ),
        config: KunUIConfig(
          imageProvider: (_) => _SyncImageProvider(pixel),
        ),
      ),
    );
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      isA<ResizeImage>(),
    );
  });

  testWidgets('reduced motion drops the placeholder in the load frame',
      (tester) async {
    final _GateImageProvider provider = _GateImageProvider();
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunImage(src: 'https://x.test/a.png', width: 80, height: 80),
        config: KunUIConfig(imageProvider: (_) => provider),
        disableAnimations: true,
      ),
    );
    expect(find.byKey(KunImage.placeholderKey), findsOneWidget);

    provider.gate.complete(ImageInfo(image: pixel.clone()));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(KunImage.placeholderKey), findsNothing);
  });

  testWidgets('semantics: label is semanticLabel ?? alt', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ui.Image pixel = await pixelImage(tester);
    final KunUIConfig config = KunUIConfig(
      imageProvider: (_) => _SyncImageProvider(pixel),
    );

    await tester.pumpWidget(
      wrap(
        const KunImage(src: 'https://x.test/a.png', alt: 'Alt text'),
        config: config,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Alt text')),
      isSemantics(label: 'Alt text', isImage: true),
    );

    await tester.pumpWidget(
      wrap(
        const KunImage(
          src: 'https://x.test/a.png',
          alt: 'Alt text',
          semanticLabel: 'Accessible',
        ),
        config: config,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Accessible')),
      isSemantics(label: 'Accessible', isImage: true),
    );
    handle.dispose();
  });

  testWidgets('alt empty excludes the node from semantics', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunImage(src: 'https://x.test/a.png', alt: ''),
        config: KunUIConfig(
          imageProvider: (_) => _SyncImageProvider(pixel),
        ),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
    expect(
      tester.getSemantics(find.byType(KunImage)),
      isSemantics(),
    );
    handle.dispose();
  });

  testWidgets(
      'a synchronously available picture has no placeholder and no fade',
      (tester) async {
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunImage(src: 'https://x.test/a.png', width: 80, height: 80),
        config: KunUIConfig(
          imageProvider: (_) => _SyncImageProvider(pixel),
        ),
      ),
    );
    expect(find.byKey(KunImage.placeholderKey), findsNothing);
    expect(find.byKey(KunImage.pictureFadeKey), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);
  });
}
