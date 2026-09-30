/// Options for [resolveKunSplitSize], mirroring `KunSplitSizeOptions`.
class KunSplitSizeOptions {
  /// Creates the options.
  const KunSplitSizeOptions({
    required this.min,
    required this.max,
    this.snapPoints = const <double>[],
    this.snapThreshold = 8,
    this.from,
  });

  /// Inclusive lower bound of the allowed width.
  final double min;

  /// Inclusive upper bound of the allowed width.
  final double max;

  /// Widths the divider is pulled to when it comes within [snapThreshold].
  final List<double> snapPoints;

  /// How close, in px, the divider must come to a snap point to be pulled
  /// to it.
  final double snapThreshold;

  /// The width a keyboard step starts from. A snap may not cancel or reverse
  /// that step. A drag leaves it unset, so the divider sticks to a snap
  /// point until the pointer pulls clear.
  final double? from;
}

/// Clamp a requested width into `[min, max]`, pull it to the nearest snap
/// point within the threshold, and round it to a whole pixel.
///
/// Port of `resolveKunSplitSize` in `packages/ui-core/src/splitPane.ts`.
double resolveKunSplitSize(double raw, KunSplitSizeOptions options) {
  final double lo = options.min < options.max ? options.min : options.max;
  final double hi = options.min > options.max ? options.min : options.max;
  final double clamped = raw < lo ? lo : (raw > hi ? hi : raw);
  double best = clamped;
  double bestDistance = double.infinity;
  for (final double point in options.snapPoints) {
    if (point < lo || point > hi) {
      continue;
    }
    final double distance = (point - clamped).abs();
    if (distance <= options.snapThreshold && distance < bestDistance) {
      best = point;
      bestDistance = distance;
    }
  }
  final double? from = options.from;
  if (from != null && _sign(best - from) != _sign(clamped - from)) {
    best = clamped;
  }
  return best.roundToDouble();
}

double _sign(double value) {
  if (value > 0) {
    return 1;
  }
  if (value < 0) {
    return -1;
  }
  return 0;
}
