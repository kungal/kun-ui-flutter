import 'package:flutter/cupertino.dart' show kMinInteractiveDimensionCupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show kMinInteractiveDimension;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/tap_target.dart';

Widget wrap(
  Widget child, {
  KunTapTargetSize tapTargetSize = KunTapTargetSize.adaptive,
}) =>
    KunTheme(
      data: KunThemeData.light(tapTargetSize: tapTargetSize),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

Finder drawnBox() => find
    .descendant(of: find.byType(KunButton), matching: find.byType(Stack))
    .first;

KunButton iconButton(KunUISize size, VoidCallback onPressed) => KunButton(
      size: size,
      isIconOnly: true,
      semanticLabel: 'close',
      onPressed: onPressed,
      child: const Icon(KunIcons.x),
    );

void main() {
  testWidgets('the minimums are the SDK constants', (tester) async {
    late Size size;
    Future<void> measure(TargetPlatform platform) async {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              size = kunMinTapTargetSize(context);
              return const SizedBox();
            },
          ),
        ),
      );
    }

    await measure(TargetPlatform.android);
    expect(size, const Size.square(kMinInteractiveDimension));
    await measure(TargetPlatform.fuchsia);
    expect(size, const Size.square(kMinInteractiveDimension));
    await measure(TargetPlatform.iOS);
    expect(size, const Size.square(kMinInteractiveDimensionCupertino));
    for (final desktop in [
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      await measure(desktop);
      expect(size, Size.zero, reason: '$desktop');
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'adaptive pads on touch platforms and keeps the drawn size',
    (tester) async {
      final touch = defaultTargetPlatform != TargetPlatform.linux &&
          defaultTargetPlatform != TargetPlatform.macOS &&
          defaultTargetPlatform != TargetPlatform.windows;
      final min = defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 48.0;
      for (final size in KunUISize.values) {
        final square = KunControlMetrics.of(size).square;
        await tester.pumpWidget(wrap(iconButton(size, () {})));
        expect(tester.getSize(drawnBox()), Size.square(square));
        final box = touch && square < min ? min : square;
        expect(
          tester.getSize(find.byType(KunButton)),
          Size.square(box),
          reason: '$size',
        );
        expect(
          tester.getCenter(drawnBox()),
          tester.getCenter(find.byType(KunButton)),
        );
      }
    },
    variant: TargetPlatformVariant.all(),
  );

  testWidgets('padded and shrinkWrap override the platform', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(
      wrap(
        iconButton(KunUISize.md, () {}),
        tapTargetSize: KunTapTargetSize.padded,
      ),
    );
    expect(tester.getSize(find.byType(KunButton)), const Size.square(48));

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      wrap(
        iconButton(KunUISize.md, () {}),
        tapTargetSize: KunTapTargetSize.shrinkWrap,
      ),
    );
    expect(tester.getSize(find.byType(KunButton)), const Size.square(38));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a tap in the margin presses, a tap past it does not',
      (tester) async {
    var presses = 0;
    await tester.pumpWidget(wrap(iconButton(KunUISize.md, () => presses++)));
    final drawn = tester.getRect(drawnBox());
    final box = tester.getRect(find.byType(KunButton));
    expect(box, drawn.inflate(5));

    await tester.tapAt(Offset(drawn.center.dx, drawn.top - 3));
    await tester.tapAt(Offset(drawn.right + 3, drawn.bottom + 3));
    expect(presses, 2);

    await tester.tapAt(Offset(box.center.dx, box.top - 1));
    await tester.tapAt(Offset(box.right + 1, box.center.dy));
    expect(presses, 2);
  });

  testWidgets('a margin tap on a text button presses it', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      wrap(KunButton(onPressed: () => presses++, child: const Text('Save'))),
    );
    final drawn = tester.getRect(drawnBox());
    expect(tester.getSize(find.byType(KunButton)).height, 48);
    await tester.tapAt(Offset(drawn.left + 2, drawn.bottom + 4));
    expect(presses, 1);
  });

  testWidgets('a parent that allows less than the minimum wins',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [iconButton(KunUISize.md, () {})],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(KunButton)), const Size(48, 40));
    expect(tester.getSize(drawnBox()), const Size.square(38));
    expect(tester.takeException(), isNull);
  });

  testWidgets('every button size meets the Android guideline', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final size in KunUISize.values) ...[
              iconButton(size, () {}),
              KunButton(
                size: size,
                onPressed: () {},
                child: Text('Save ${size.name}'),
              ),
            ],
          ],
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('every button size meets the iOS guideline', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final size in KunUISize.values) iconButton(size, () {}),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byType(KunButton).first), const Size.square(44));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  Widget band({
    required VoidCallback onLeft,
    required VoidCallback onRight,
    KunTapTargetSize tapTargetSize = KunTapTargetSize.adaptive,
  }) =>
      wrap(
        SizedBox(
          width: 200,
          child: GestureDetector(
            onTap: onLeft,
            behavior: HitTestBehavior.opaque,
            child: KunTapBand(
              background: const DecoratedBox(
                key: ValueKey('background'),
                decoration: BoxDecoration(color: Color(0xFF000000)),
              ),
              child: Row(
                key: const ValueKey('content'),
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(9),
                      child: SizedBox(height: 20),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: double.infinity,
                    child: GestureDetector(
                      onTap: onRight,
                      behavior: HitTestBehavior.opaque,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        tapTargetSize: tapTargetSize,
      );

  testWidgets('a band paints the drawn box centred in the padded height',
      (tester) async {
    await tester.pumpWidget(band(onLeft: () {}, onRight: () {}));
    final box = tester.getRect(find.byType(KunTapBand));
    expect(box.size, const Size(200, 48));
    expect(
      tester.getRect(find.byKey(const ValueKey('background'))),
      Rect.fromCenter(center: box.center, width: 200, height: 38),
    );
    expect(tester.getSize(find.byKey(const ValueKey('content'))).height, 48);

    await tester.pumpWidget(
      band(
        onLeft: () {},
        onRight: () {},
        tapTargetSize: KunTapTargetSize.shrinkWrap,
      ),
    );
    expect(tester.getSize(find.byType(KunTapBand)), const Size(200, 38));
    expect(
      tester.getRect(find.byKey(const ValueKey('background'))),
      tester.getRect(find.byType(KunTapBand)),
    );
  });

  testWidgets('a fill column owns the band beside it, the rest falls through',
      (tester) async {
    var left = 0;
    var right = 0;
    await tester.pumpWidget(
      band(onLeft: () => left++, onRight: () => right++),
    );
    final drawn = tester.getRect(find.byKey(const ValueKey('background')));
    await tester.tapAt(Offset(drawn.right - 20, drawn.top - 2));
    await tester.tapAt(Offset(drawn.right - 20, drawn.bottom + 2));
    expect(right, 2);
    await tester.tapAt(Offset(drawn.left + 40, drawn.top - 2));
    expect(left, 1);
  });

  testWidgets('a stretched row keeps each drawn control centred in its box',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 600,
            child: KunScrollShadow(
              children: <Widget>[
                KunSelect<String, KunSelectOption<String>>(
                  size: KunUISize.sm,
                  fullWidth: false,
                  options: const <KunSelectOption<String>>[
                    KunSelectOption<String>(value: 'pc', label: 'PC'),
                  ],
                  value: 'pc',
                  onChanged: (String? value) {},
                ),
                iconButton(KunUISize.sm, () {}),
                KunButton(
                  size: KunUISize.sm,
                  onPressed: () {},
                  child: const Text('More filters'),
                ),
              ],
            ),
          ),
        ),
      );
      final Finder drawn = find.descendant(
        of: find.byType(KunButton),
        matching: find.byType(Stack),
      );
      final double square = KunControlMetrics.of(KunUISize.sm).square;
      for (final Element button in find.byType(KunButton).evaluate()) {
        final Rect box = tester.getRect(find.byWidget(button.widget));
        final Rect paint = tester.getRect(
          find
              .descendant(
                of: find.byWidget(button.widget),
                matching: find.byType(Stack),
              )
              .first,
        );
        expect(box.height, 48);
        expect(paint.height, square);
        expect(paint.center.dy, closeTo(box.center.dy, 0.5));
      }
      expect(drawn, findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
