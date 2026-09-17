import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/components/pulse.dart';

const KunUser kun = KunUser(id: 1, name: 'Kun', avatar: 'https://x.test/a.png');

Widget wrap(
  Widget child, {
  KunUIConfig? config,
  KunThemeData? data,
  KunMessages? messages,
  bool disableAnimations = false,
}) {
  Widget tree = child;
  if (config != null) {
    tree = KunUIConfigScope(config: config, child: tree);
  }
  if (messages != null) {
    tree = KunMessagesScope(messages: messages, child: tree);
  }
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: KunTheme(
      data: data ?? KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: tree),
      ),
    ),
  );
}

Widget wrapWebKeys(Widget child, {KunUIConfig? config}) => Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
      },
      child: wrap(child, config: config),
    );

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

// Equal by URL, like NetworkImage, but a new instance per call, as an
// app's imageProvider returns.
class _UrlImageProvider extends ImageProvider<_UrlImageProvider> {
  _UrlImageProvider(this.url, this.gate);

  final String url;
  final Completer<ImageInfo> gate;

  @override
  Future<_UrlImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_UrlImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _UrlImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(gate.future);
  }

  @override
  bool operator ==(Object other) =>
      other is _UrlImageProvider && other.url == url;

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

Future<ui.Image> pixelImage(WidgetTester tester) async {
  late ui.Image image;
  await tester.runAsync(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0xFF000000),
    );
    image = await recorder.endRecording().toImage(1, 1);
  });
  return image;
}

double scaleOf(WidgetTester tester) {
  final Transform transform = tester.widget<Transform>(
    find.descendant(
      of: find.byType(KunAvatar),
      matching: find.byType(Transform),
    ),
  );
  return transform.transform.getMaxScaleOnAxis();
}

void requestFocusOn(WidgetTester tester, Finder of) {
  Focus.of(
    tester.element(
      find.descendant(of: of, matching: find.byType(GestureDetector)).first,
    ),
  ).requestFocus();
}

FadeTransition? imageFadeOf(WidgetTester tester) {
  final Finder fade = find.ancestor(
    of: find.byType(RawImage),
    matching: find.byType(FadeTransition),
  );
  if (fade.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<FadeTransition>(fade);
}

void main() {
  setUp(debugResetKunAvatarWarning);

  testWidgets('each size is the listed square', (tester) async {
    const Map<KunAvatarSize, double> sides = <KunAvatarSize, double>{
      KunAvatarSize.xs: 16,
      KunAvatarSize.sm: 24,
      KunAvatarSize.md: 32,
      KunAvatarSize.lg: 40,
      KunAvatarSize.xl: 48,
      KunAvatarSize.originalSm: 96,
      KunAvatarSize.original: 160,
    };
    const KunUser user = KunUser(id: 1, name: 'Kun');
    for (final MapEntry<KunAvatarSize, double> entry in sides.entries) {
      await tester.pumpWidget(
        wrap(
          KunAvatar(
            user: user,
            size: entry.key,
            isNavigation: false,
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(KunAvatar)),
        Size.square(entry.value),
        reason: entry.key.name,
      );
    }
  });

  testWidgets('the avatar URL reaches imageProvider', (tester) async {
    final List<String> urls = <String>[];
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunAvatar(user: kun, isNavigation: false),
        config: KunUIConfig(
          imageProvider: (String url) {
            urls.add(url);
            return _SyncImageProvider(pixel);
          },
        ),
      ),
    );
    expect(urls, <String>['https://x.test/a.png']);
  });

  testWidgets('an empty avatar with a pool of three picks the hash',
      (tester) async {
    final List<String> urls = <String>[];
    final ui.Image pixel = await pixelImage(tester);
    const List<String> pool = <String>['p0', 'p1', 'p2'];
    await tester.pumpWidget(
      wrap(
        const KunAvatar(
          user: KunUser(id: 1, name: 'Alice'),
          isNavigation: false,
        ),
        config: KunUIConfig(
          avatarFallbackPool: pool,
          imageProvider: (String url) {
            urls.add(url);
            return _SyncImageProvider(pixel);
          },
        ),
      ),
    );
    expect(urls, <String>[kunPickAvatarFallback('Alice', pool)!]);
  });

  testWidgets('an empty pool shows the bundled picture and warns once',
      (tester) async {
    final List<String> printed = <String>[];
    final DebugPrintCallback original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      printed.add(message ?? '');
    };
    try {
      await tester.pumpWidget(
        wrap(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KunAvatar(
                user: KunUser(id: 1, name: 'Alice'),
                isNavigation: false,
              ),
              KunAvatar(
                user: KunUser(id: 2, name: 'Bob'),
                isNavigation: false,
              ),
            ],
          ),
        ),
      );
      expect(printed, hasLength(1));
      expect(printed.single, contains('avatarFallbackPool'));
      expect(printed.single, contains('KunUIConfigScope'));
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .map((Image image) => image.image),
        everyElement(KunImages.avatarFallback),
      );
    } finally {
      debugPrint = original;
    }
  });

  testWidgets('a null user shows the bundled picture and prints nothing',
      (tester) async {
    final List<String> printed = <String>[];
    final DebugPrintCallback original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      printed.add(message ?? '');
    };
    try {
      await tester.pumpWidget(
        wrap(const KunAvatar(user: null, isNavigation: false)),
      );
      expect(printed, isEmpty);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        KunImages.avatarFallback,
      );
    } finally {
      debugPrint = original;
    }
  });

  testWidgets('loading fades the picture in and drops the layer',
      (tester) async {
    final _GateImageProvider provider = _GateImageProvider();
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunAvatar(user: kun, isNavigation: false),
        config: KunUIConfig(imageProvider: (_) => provider),
      ),
    );
    expect(find.byType(KunPulseLayer), findsOneWidget);
    expect(imageFadeOf(tester)!.opacity.value, 0);

    provider.gate.complete(ImageInfo(image: pixel.clone()));
    await tester.pump();
    expect(find.byType(KunPulseLayer), findsNothing);
    expect(imageFadeOf(tester)!.opacity.value, 0);

    await tester.pump(KunDurations.slow ~/ 2);
    final double mid = imageFadeOf(tester)!.opacity.value;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));

    await tester.pump(KunDurations.slow ~/ 2);
    expect(imageFadeOf(tester)!.opacity.value, closeTo(1, 0.001));
  });

  testWidgets('a rebuild with a new but equal provider keeps the picture',
      (tester) async {
    final Completer<ImageInfo> gate = Completer<ImageInfo>();
    int calls = 0;
    await tester.pumpWidget(
      wrap(
        const KunAvatar(user: kun),
        config: KunUIConfig(
          imageProvider: (String url) {
            calls += 1;
            return _UrlImageProvider(url, gate);
          },
        ),
      ),
    );
    final State<Image> before = tester.state(find.byType(Image));
    final TestGesture gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(
        location: tester.getCenter(find.byType(KunAvatar)));
    addTearDown(gesture.removePointer);
    await tester.pump();
    expect(calls, greaterThan(1));
    expect(tester.state<State<Image>>(find.byType(Image)), same(before));
    expect(find.byType(KunPulseLayer), findsOneWidget);
  });

  testWidgets('a synchronously available picture has no layer and no fade',
      (tester) async {
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunAvatar(user: kun, isNavigation: false),
        config: KunUIConfig(
          imageProvider: (_) => _SyncImageProvider(pixel),
        ),
      ),
    );
    expect(find.byType(KunPulseLayer), findsNothing);
    expect(imageFadeOf(tester), isNull);
    expect(find.byType(RawImage), findsOneWidget);
  });

  testWidgets('a failing URL ends on the bundled fallback', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunAvatar(user: kun, isNavigation: false),
        config: KunUIConfig(
          imageProvider: (_) => _FailingImageProvider(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      KunImages.avatarFallback,
    );
  });

  testWidgets('reduced motion makes the fade instant and nothing pulses',
      (tester) async {
    final _GateImageProvider provider = _GateImageProvider();
    final ui.Image pixel = await pixelImage(tester);
    await tester.pumpWidget(
      wrap(
        const KunAvatar(user: kun, isNavigation: false),
        config: KunUIConfig(imageProvider: (_) => provider),
        disableAnimations: true,
      ),
    );
    expect(find.byType(KunPulseLayer), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);

    provider.gate.complete(ImageInfo(image: pixel.clone()));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KunPulseLayer), findsNothing);
    expect(imageFadeOf(tester)!.opacity.value, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a tap with a user calls navigate', (tester) async {
    final List<String> hrefs = <String>[];
    await tester.pumpWidget(
      wrap(
        const KunAvatar(user: KunUser(id: 42, name: 'Kun', avatar: '')),
        config: KunUIConfig(
          navigate: (BuildContext context, String href) => hrefs.add(href),
        ),
      ),
    );
    await tester.tap(find.byType(KunAvatar));
    expect(hrefs, <String>['/user/42/info']);

    hrefs.clear();
    await tester.pumpWidget(
      wrap(
        const KunAvatar(user: KunUser(id: 42, name: 'Kun', avatar: '')),
        config: KunUIConfig(
          userLinkTemplate: '/u/{id}',
          navigate: (BuildContext context, String href) => hrefs.add(href),
        ),
      ),
    );
    await tester.tap(find.byType(KunAvatar));
    expect(hrefs, <String>['/u/42']);
  });

  testWidgets('isNavigation false and a null user never navigate',
      (tester) async {
    final List<String> hrefs = <String>[];
    final KunUIConfig config = KunUIConfig(
      navigate: (BuildContext context, String href) => hrefs.add(href),
    );
    await tester.pumpWidget(
      wrap(
        const KunAvatar(
          user: KunUser(id: 42, name: 'Kun', avatar: ''),
          isNavigation: false,
        ),
        config: config,
      ),
    );
    await tester.tap(find.byType(KunAvatar), warnIfMissed: false);
    expect(hrefs, isEmpty);

    await tester.pumpWidget(
      wrap(const KunAvatar(user: null), config: config),
    );
    await tester.tap(find.byType(KunAvatar), warnIfMissed: false);
    expect(hrefs, isEmpty);
  });

  testWidgets('Space and web-map Enter activate a focused linked avatar',
      (tester) async {
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });

    final List<String> hrefs = <String>[];
    await tester.pumpWidget(
      wrapWebKeys(
        const KunAvatar(user: KunUser(id: 42, name: 'Kun', avatar: '')),
        config: KunUIConfig(
          navigate: (BuildContext context, String href) => hrefs.add(href),
        ),
      ),
    );
    requestFocusOn(tester, find.byType(KunAvatar));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(hrefs, <String>['/user/42/info']);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(hrefs, <String>['/user/42/info', '/user/42/info']);
  });

  testWidgets('only a linked avatar takes focus and shows a click cursor',
      (tester) async {
    Finder inside(Type type) => find.descendant(
        of: find.byType(KunAvatar), matching: find.byType(type));

    await tester.pumpWidget(
      wrap(const KunAvatar(user: KunUser(id: 42, name: 'Kun', avatar: ''))),
    );
    expect(inside(Focus), findsWidgets);
    expect(inside(MouseRegion), findsWidgets);

    for (final KunAvatar avatar in const <KunAvatar>[
      KunAvatar(
        user: KunUser(id: 42, name: 'Kun', avatar: ''),
        isNavigation: false,
      ),
      KunAvatar(user: null),
    ]) {
      await tester.pumpWidget(wrap(avatar));
      expect(inside(Focus), findsNothing);
      expect(inside(MouseRegion), findsNothing);
    }
  });

  testWidgets('hover scales a linked avatar and not an unlinked one',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunAvatar(user: KunUser(id: 42, name: 'Kun', avatar: '')),
      ),
    );
    final TestGesture gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    expect(scaleOf(tester), 1);

    await gesture.moveTo(tester.getCenter(find.byType(KunAvatar)));
    await tester.pump();
    await tester.pump(KunDurations.fast ~/ 2);
    final double mid = scaleOf(tester);
    expect(mid, greaterThan(1));
    expect(mid, lessThan(1.1));

    await tester.pump(KunDurations.fast ~/ 2);
    expect(scaleOf(tester), closeTo(1.1, 0.001));

    await gesture.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(KunDurations.fast);
    expect(scaleOf(tester), closeTo(1, 0.001));

    await tester.pumpWidget(
      wrap(
        const KunAvatar(
          user: KunUser(id: 42, name: 'Kun', avatar: ''),
          isNavigation: false,
        ),
      ),
    );
    expect(find.byType(AnimatedScale), findsNothing);
    await gesture.moveTo(tester.getCenter(find.byType(KunAvatar)));
    await tester.pump();
    await tester.pump(KunDurations.fast);
    expect(find.byType(AnimatedScale), findsNothing);
  });

  testWidgets('semantics: linked is a link, unlinked is an image',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      wrap(const KunAvatar(user: KunUser(id: 42, name: 'Kun', avatar: ''))),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Kun')),
      isSemantics(label: 'Kun', isLink: true, hasTapAction: true),
    );

    await tester.pumpWidget(
      wrap(
        const KunAvatar(
          user: KunUser(id: 42, name: 'Kun', avatar: ''),
          isNavigation: false,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Kun')),
      isSemantics(label: 'Kun', isImage: true),
    );

    await tester.pumpWidget(
      wrap(const KunAvatar(user: null, isNavigation: false)),
    );
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(KunMessages.zhCN.avatar.unknownUser),
      ),
      isSemantics(label: KunMessages.zhCN.avatar.unknownUser, isImage: true),
    );

    await tester.pumpWidget(
      wrap(
        const KunAvatar(user: null, isNavigation: false),
        messages: KunMessages.en,
      ),
    );
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(KunMessages.en.avatar.unknownUser),
      ),
      isSemantics(label: KunMessages.en.avatar.unknownUser, isImage: true),
    );
    handle.dispose();
  });
}
