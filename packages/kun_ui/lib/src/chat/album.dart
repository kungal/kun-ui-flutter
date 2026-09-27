/// Telegram's album mosaic, ported from Telegram Desktop's grouped_layout.cpp
/// by way of tweb's groupedLayout.ts, constant for constant. Not telegram-tt's
/// copy: it passes a maxHeight into the 5+ case, so the 4/3 target height
/// never applies and five photos lay out differently from every other client.
///
/// The output is in layout units; a renderer divides by `width` / `height` and
/// places each tile by percentage, so the mosaic scales to any bubble width
/// with no measuring.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Photo size fed to [layoutKunChatAlbum].
@immutable
class KunChatAlbumSize {
  /// Creates a size. A zero or missing side is treated as square.
  const KunChatAlbumSize({required this.width, required this.height});

  /// Pixel width.
  final double width;

  /// Pixel height.
  final double height;

  @override
  bool operator ==(Object other) =>
      other is KunChatAlbumSize &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'KunChatAlbumSize(${width}x$height)';
}

/// Which outer edges of the mosaic a tile touches — its rounded corners.
abstract final class KunChatAlbumSide {
  /// Top edge.
  static const int top = 1;

  /// Right edge.
  static const int right = 2;

  /// Bottom edge.
  static const int bottom = 4;

  /// Left edge.
  static const int left = 8;
}

/// One tile of a mosaic.
@immutable
class KunChatAlbumTile {
  /// Creates a tile. [sides] is a bitmask of [KunChatAlbumSide].
  const KunChatAlbumTile({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.sides,
  });

  /// Left edge, in layout units.
  final double x;

  /// Top edge, in layout units.
  final double y;

  /// Width, in layout units.
  final double width;

  /// Height, in layout units.
  final double height;

  /// Bitmask of [KunChatAlbumSide].
  final int sides;

  @override
  bool operator ==(Object other) =>
      other is KunChatAlbumTile &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height &&
      other.sides == sides;

  @override
  int get hashCode => Object.hash(x, y, width, height, sides);

  @override
  String toString() => 'KunChatAlbumTile($x,$y ${width}x$height sides:$sides)';
}

/// The mosaic's bounding box and tiles.
@immutable
class KunChatAlbumLayout {
  /// Creates a layout.
  const KunChatAlbumLayout({
    required this.width,
    required this.height,
    required this.tiles,
  });

  /// Bounding width, in layout units.
  final double width;

  /// Bounding height, in layout units.
  final double height;

  /// Tiles, in input order.
  final List<KunChatAlbumTile> tiles;

  @override
  bool operator ==(Object other) =>
      other is KunChatAlbumLayout &&
      other.width == width &&
      other.height == height &&
      listEquals(other.tiles, tiles);

  @override
  int get hashCode => Object.hash(width, height, Object.hashAll(tiles));

  @override
  String toString() =>
      'KunChatAlbumLayout(${width}x$height, ${tiles.length} tiles)';
}

const int _t = KunChatAlbumSide.top;
const int _r = KunChatAlbumSide.right;
const int _b = KunChatAlbumSide.bottom;
const int _l = KunChatAlbumSide.left;

double _sum(List<double> xs) => xs.fold(0.0, (double a, double b) => a + b);

double _clamp(double v, double min, double max) =>
    math.min(math.max(v, min), max);

KunChatAlbumTile _tile(
  double x,
  double y,
  double width,
  double height,
  int sides,
) =>
    KunChatAlbumTile(x: x, y: y, width: width, height: height, sides: sides);

List<KunChatAlbumTile> _layoutComplex(
  List<double> ratios,
  double averageRatio,
  double maxWidth,
  double minWidth,
  double spacing,
) {
  final double maxHeight = (maxWidth * 4) / 3;
  final List<double> cropped = ratios
      .map(
        (double r) =>
            averageRatio > 1.1 ? _clamp(r, 1, 2.75) : _clamp(r, 0.6667, 1),
      )
      .toList();
  final int count = cropped.length;
  final List<({List<int> counts, List<double> heights})> attempts =
      <({List<int> counts, List<double> heights})>[];
  void push(List<int> counts) {
    int offset = 0;
    final List<double> heights = counts.map((int c) {
      final double h = (maxWidth - (c - 1) * spacing) /
          _sum(cropped.sublist(offset, offset + c));
      offset += c;
      return h;
    }).toList();
    attempts.add((counts: counts, heights: heights));
  }

  for (int first = 1; first != count; first++) {
    final int second = count - first;
    if (first <= 3 && second <= 3) push(<int>[first, second]);
  }
  for (int first = 1; first < count - 1; first++) {
    for (int second = 1; second < count - first; second++) {
      final int third = count - first - second;
      if (first <= 3 && second <= (averageRatio < 0.85 ? 4 : 3) && third <= 3) {
        push(<int>[first, second, third]);
      }
    }
  }
  for (int first = 1; first < count - 1; first++) {
    for (int second = 1; second < count - first; second++) {
      for (int third = 1; third < count - first - second; third++) {
        final int fourth = count - first - second - third;
        if (first <= 3 && second <= 3 && third <= 3 && fourth <= 3) {
          push(<int>[first, second, third, fourth]);
        }
      }
    }
  }

  // More than 12 photos leave no split of rows of at most three (tweb throws
  // there). Albums hold 10, but a bad row must render: fall back to rows of
  // three.
  if (attempts.isEmpty) {
    push(
      List<int>.generate(
        (count / 3).ceil(),
        (int i) => math.min(3, count - i * 3),
      ),
    );
  }
  ({List<int> counts, List<double> heights}) best = attempts[0];
  double bestDiff = double.infinity;
  for (final ({List<int> counts, List<double> heights}) attempt in attempts) {
    final List<int> counts = attempt.counts;
    final List<double> heights = attempt.heights;
    final double total = _sum(heights) + spacing * (counts.length - 1);
    final double tooShort = heights.reduce(math.min) < minWidth ? 1.5 : 1;
    final double topHeavy = counts.asMap().entries.any(
              (MapEntry<int, int> e) =>
                  e.key > 0 && counts[e.key - 1] > e.value,
            )
        ? 1.5
        : 1;
    final double diff = (total - maxHeight).abs() * tooShort * topHeavy;
    if (diff < bestDiff) {
      best = attempt;
      bestDiff = diff;
    }
  }

  final List<KunChatAlbumTile> tiles = <KunChatAlbumTile>[];
  int index = 0;
  double y = 0;
  for (int row = 0; row < best.counts.length; row++) {
    final int cols = best.counts[row];
    final double lineHeight = best.heights[row];
    final double height = lineHeight.roundToDouble();
    double x = 0;
    for (int col = 0; col < cols; col++) {
      final int sides = (row == 0 ? _t : 0) |
          (row == best.counts.length - 1 ? _b : 0) |
          (col == 0 ? _l : 0) |
          (col == cols - 1 ? _r : 0);
      final double width = col == cols - 1
          ? maxWidth - x
          : (cropped[index] * lineHeight).roundToDouble();
      tiles.add(_tile(x, y, width, height, sides));
      x += width + spacing;
      index++;
    }
    y += height + spacing;
  }
  return tiles;
}

/// Lay out an album of 1–10 photos as Telegram does. Sizes with a zero or
/// missing side are treated as square.
KunChatAlbumLayout layoutKunChatAlbum(
  List<KunChatAlbumSize> sizes, {
  double maxWidth = 420,
  double minWidth = 100,
  double spacing = 2,
}) {
  final double maxHeight = maxWidth;
  final List<double> r = sizes
      .map(
        (KunChatAlbumSize z) =>
            z.width > 0 && z.height > 0 ? z.width / z.height : 1.0,
      )
      .toList();
  final int n = r.length;
  final String shape =
      r.map((double x) => x > 1.2 ? 'w' : (x < 0.8 ? 'n' : 'q')).join();
  // The `+ 1` is in Telegram Desktop too.
  final double averageRatio = (1 + _sum(r)) / n;
  final double maxSizeRatio = maxWidth / maxHeight;
  final double s = spacing;

  late final List<KunChatAlbumTile> tiles;
  if (n == 0) {
    tiles = <KunChatAlbumTile>[];
  } else if (n == 1) {
    tiles = <KunChatAlbumTile>[
      _tile(0, 0, maxWidth, maxWidth / r[0], _t | _r | _b | _l),
    ];
  } else if (n >= 5 || r.any((double x) => x > 2)) {
    tiles = _layoutComplex(r, averageRatio, maxWidth, minWidth, s);
  } else if (n == 2) {
    final double r0 = r[0];
    final double r1 = r[1];
    if (shape == 'ww' && averageRatio > 1.4 * maxSizeRatio && r1 - r0 < 0.2) {
      final double h = math
          .min(maxWidth / r0, math.min(maxWidth / r1, (maxHeight - s) / 2))
          .roundToDouble();
      tiles = <KunChatAlbumTile>[
        _tile(0, 0, maxWidth, h, _l | _t | _r),
        _tile(0, h + s, maxWidth, h, _l | _b | _r),
      ];
    } else if (shape == 'ww' || shape == 'qq') {
      final double w = (maxWidth - s) / 2;
      final double h =
          math.min(w / r0, math.min(w / r1, maxHeight)).roundToDouble();
      tiles = <KunChatAlbumTile>[
        _tile(0, 0, w, h, _t | _l | _b),
        _tile(w + s, 0, w, h, _t | _r | _b),
      ];
    } else {
      final double w2 = math.min(
        math
            .max(
              0.4 * (maxWidth - s),
              (maxWidth - s) / r0 / (1 / r0 + 1 / r1),
            )
            .roundToDouble(),
        maxWidth - s - (minWidth * 1.5).roundToDouble(),
      );
      final double w1 = maxWidth - w2 - s;
      final double h = math.min(
        maxHeight,
        math.min(w1 / r0, w2 / r1).roundToDouble(),
      );
      tiles = <KunChatAlbumTile>[
        _tile(0, 0, w1, h, _t | _l | _b),
        _tile(w1 + s, 0, w2, h, _t | _r | _b),
      ];
    }
  } else if (n == 3) {
    final double r0 = r[0];
    final double r1 = r[1];
    final double r2 = r[2];
    if (shape[0] == 'n') {
      final double h0 = maxHeight;
      final double h2 = math
          .min((maxHeight - s) / 2, (r1 * (maxWidth - s)) / (r2 + r1))
          .roundToDouble();
      final double h1 = h0 - h2 - s;
      final double wR = math.max(
        minWidth,
        math
            .min((maxWidth - s) / 2, math.min(h2 * r2, h1 * r1))
            .roundToDouble(),
      );
      final double wL = math.min(
        (h0 * r0).roundToDouble(),
        maxWidth - s - wR,
      );
      tiles = <KunChatAlbumTile>[
        _tile(0, 0, wL, h0, _t | _l | _b),
        _tile(wL + s, 0, wR, h1, _t | _r),
        _tile(wL + s, h1 + s, wR, h2, _b | _r),
      ];
    } else {
      final double h0 =
          math.min(maxWidth / r0, (maxHeight - s) * 0.66).roundToDouble();
      final double w1 = (maxWidth - s) / 2;
      final double h1 = math.min(
        maxHeight - h0 - s,
        math.min(w1 / r1, w1 / r2).roundToDouble(),
      );
      final double w2 = maxWidth - w1 - s;
      tiles = <KunChatAlbumTile>[
        _tile(0, 0, maxWidth, h0, _l | _t | _r),
        _tile(0, h0 + s, w1, h1, _b | _l),
        _tile(w1 + s, h0 + s, w2, h1, _b | _r),
      ];
    }
  } else {
    final double r0 = r[0];
    final double r1 = r[1];
    final double r2 = r[2];
    final double r3 = r[3];
    if (shape[0] == 'w') {
      final double h0 =
          math.min(maxWidth / r0, (maxHeight - s) * 0.66).roundToDouble();
      final double h = ((maxWidth - 2 * s) / (r1 + r2 + r3)).roundToDouble();
      final double w0 = math.max(
        minWidth,
        math.min((maxWidth - 2 * s) * 0.4, h * r1).roundToDouble(),
      );
      final double w2 = math
          .max(
            minWidth,
            math.max((maxWidth - 2 * s) * 0.33, h * r3),
          )
          .roundToDouble();
      final double w1 = maxWidth - w0 - w2 - 2 * s;
      final double h1 = math.min(maxHeight - h0 - s, h);
      tiles = <KunChatAlbumTile>[
        _tile(0, 0, maxWidth, h0, _l | _t | _r),
        _tile(0, h0 + s, w0, h1, _b | _l),
        _tile(w0 + s, h0 + s, w1, h1, _b),
        _tile(w0 + s + w1 + s, h0 + s, w2, h1, _r | _b),
      ];
    } else {
      final double h = maxHeight;
      final double w0 = math.min(h * r0, (maxWidth - s) * 0.6).roundToDouble();
      final double w =
          ((maxHeight - 2 * s) / (1 / r1 + 1 / r2 + 1 / r3)).roundToDouble();
      final double h0 = (w / r1).roundToDouble();
      final double h1 = (w / r2).roundToDouble();
      final double h2 = h - h0 - h1 - 2 * s;
      final double w1 = math.max(minWidth, math.min(maxWidth - w0 - s, w));
      tiles = <KunChatAlbumTile>[
        _tile(0, 0, w0, h, _t | _l | _b),
        _tile(w0 + s, 0, w1, h0, _t | _r),
        _tile(w0 + s, h0 + s, w1, h1, _r),
        _tile(w0 + s, h0 + h1 + 2 * s, w1, h2, _b | _r),
      ];
    }
  }

  return KunChatAlbumLayout(
    width: tiles.fold<double>(
      0,
      (double m, KunChatAlbumTile t) => math.max(m, t.x + t.width),
    ),
    height: tiles.fold<double>(
      0,
      (double m, KunChatAlbumTile t) => math.max(m, t.y + t.height),
    ),
    tiles: tiles,
  );
}
