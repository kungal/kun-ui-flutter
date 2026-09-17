import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/src/foundation/outer_shadow.dart';

const BoxShadow shadow = BoxShadow(
  color: Color(0x80000000),
  offset: Offset(0, 4),
  blurRadius: 8,
  spreadRadius: -2,
);

Widget box(Decoration decoration, Size size) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(decoration: decoration),
      ),
    ),
  );
}

void main() {
  testWidgets('a rounded box clips its shadows to outside the box',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      box(
        KunOuterShadowDecoration(
          shadows: const <BoxShadow>[shadow, shadow],
          borderRadius: BorderRadius.circular(16),
        ),
        const Size(100, 60),
      ),
    );
    expect(
      tester.renderObject(find.byType(DecoratedBox)),
      paints
        ..clipPath(
          pathMatcher: isPathThat(
            includes: const <Offset>[
              Offset(-4, 30),
              Offset(50, 70),
              Offset(1, 1),
              Offset(99, 59),
            ],
            excludes: const <Offset>[
              Offset(50, 30),
              Offset(20, 2),
              Offset(98, 30),
            ],
          ),
        )
        // BoxDecoration's geometry: the box shifted by the offset and
        // inflated by the spread, with the same corners.
        ..path(
          color: shadow.color,
          includes: const <Offset>[Offset(50, 30), Offset(50, 60)],
          excludes: const <Offset>[Offset(50, 5), Offset(1, 30)],
        )
        ..path(color: shadow.color),
    );
  });

  testWidgets('a circle clips its shadows to outside the circle',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      box(
        const KunOuterShadowDecoration(
          shadows: <BoxShadow>[shadow],
          shape: BoxShape.circle,
        ),
        const Size(40, 40),
      ),
    );
    expect(
      tester.renderObject(find.byType(DecoratedBox)),
      paints
        ..clipPath(
          pathMatcher: isPathThat(
            includes: const <Offset>[Offset(2, 2), Offset(20, 45)],
            excludes: const <Offset>[Offset(20, 20), Offset(20, 1)],
          ),
        )
        ..path(
          color: shadow.color,
          includes: const <Offset>[Offset(20, 24)],
          excludes: const <Offset>[Offset(1, 24)],
        ),
    );
  });

  test('hit testing follows the shape', () {
    final KunOuterShadowDecoration rounded = KunOuterShadowDecoration(
      shadows: const <BoxShadow>[shadow],
      borderRadius: BorderRadius.circular(16),
    );
    const Size size = Size(100, 60);
    expect(rounded.hitTest(size, const Offset(50, 30)), isTrue);
    expect(rounded.hitTest(size, const Offset(1, 1)), isFalse);
    const KunOuterShadowDecoration circle = KunOuterShadowDecoration(
      shadows: <BoxShadow>[shadow],
      shape: BoxShape.circle,
    );
    expect(circle.hitTest(const Size(40, 40), const Offset(20, 20)), isTrue);
    expect(circle.hitTest(const Size(40, 40), const Offset(2, 2)), isFalse);
  });

  test('equality compares the shadows by value', () {
    expect(
      KunOuterShadowDecoration(
        shadows: const <BoxShadow>[shadow],
        borderRadius: BorderRadius.circular(8),
      ),
      KunOuterShadowDecoration(
        shadows: <BoxShadow>[shadow.copyWith()],
        borderRadius: BorderRadius.circular(8),
      ),
    );
    expect(
      const KunOuterShadowDecoration(shadows: <BoxShadow>[shadow]),
      isNot(const KunOuterShadowDecoration(shadows: <BoxShadow>[])),
    );
  });
}
