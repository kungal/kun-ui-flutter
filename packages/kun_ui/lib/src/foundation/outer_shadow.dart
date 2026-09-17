import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Paints [shadows] around a box and never under it, as CSS paints
/// `box-shadow`.
///
/// `BoxDecoration` paints each shadow under the box as well, where a
/// translucent fill lets it show: a tinted `KunCard` came out about 6%
/// darker than the web's, with a lighter rim where its inset shadow ended.
/// Put this outside a `BoxDecoration` that has the fill and no shadows.
class KunOuterShadowDecoration extends Decoration {
  /// Creates the decoration for a box of [shape], rounded by [borderRadius]
  /// when it is a rectangle.
  const KunOuterShadowDecoration({
    required this.shadows,
    this.borderRadius = BorderRadius.zero,
    this.shape = BoxShape.rectangle,
  });

  /// The shadows, painted in order, the first at the bottom.
  final List<BoxShadow> shadows;

  /// The corners of a [BoxShape.rectangle] box.
  final BorderRadius borderRadius;

  /// The box's shape.
  final BoxShape shape;

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) {
    return switch (shape) {
      BoxShape.rectangle =>
        borderRadius.toRRect(Offset.zero & size).contains(position),
      BoxShape.circle =>
        (position - size.center(Offset.zero)).distance <= size.shortestSide / 2,
    };
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _OuterShadowPainter(this, onChanged);
  }

  @override
  bool operator ==(Object other) {
    return other is KunOuterShadowDecoration &&
        other.borderRadius == borderRadius &&
        other.shape == shape &&
        listEquals(other.shadows, shadows);
  }

  @override
  int get hashCode => Object.hash(borderRadius, shape, Object.hashAll(shadows));
}

class _OuterShadowPainter extends BoxPainter {
  _OuterShadowPainter(this._decoration, super.onChanged);

  final KunOuterShadowDecoration _decoration;

  Path _shapeOf(Rect rect) {
    return switch (_decoration.shape) {
      BoxShape.rectangle => Path()
        ..addRRect(_decoration.borderRadius.toRRect(rect)),
      BoxShape.circle => Path()
        ..addOval(
          Rect.fromCircle(center: rect.center, radius: rect.shortestSide / 2),
        ),
    };
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & configuration.size!;
    double reach = 0;
    for (final BoxShadow shadow in _decoration.shadows) {
      final double extent = shadow.offset.distance +
          shadow.spreadRadius +
          Shadow.convertRadiusToSigma(shadow.blurRadius) * 3;
      if (extent > reach) {
        reach = extent;
      }
    }
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(reach + 1))
        ..addPath(_shapeOf(rect), Offset.zero),
    );
    for (final BoxShadow shadow in _decoration.shadows) {
      final Rect bounds =
          rect.shift(shadow.offset).inflate(shadow.spreadRadius);
      canvas.drawPath(_shapeOf(bounds), shadow.toPaint());
    }
    canvas.restore();
  }
}
