import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../theme/theme.dart';

/// Whether the badge shows a number or a plain dot.
enum KunBadgeVariant {
  /// The numeric count (clamped by [KunBadge.max]).
  count,

  /// A filled circle with no text.
  dot,
}

/// The badge's own size scale — sm/md/lg, with no xs/xl.
enum KunBadgeSize {
  /// Small.
  sm,

  /// Medium — the default.
  md,

  /// Large.
  lg,
}

/// Which corner of the anchor the badge sits on.
enum KunBadgePlacement {
  /// Web `top-right`.
  topRight,

  /// Web `top-left`.
  topLeft,

  /// Web `bottom-right`.
  bottomRight,

  /// Web `bottom-left`.
  bottomLeft,
}

class _KunBadgeSize {
  const _KunBadgeSize({
    required this.dotSide,
    required this.countHeight,
    required this.countMinWidth,
    required this.countPadding,
    required this.textStyle,
  });

  final double dotSide;
  final double countHeight;
  final double countMinWidth;
  final double countPadding;
  final TextStyle textStyle;

  static _KunBadgeSize of(KunBadgeSize size) => switch (size) {
        KunBadgeSize.sm => _KunBadgeSize(
            dotSide: KunSpacing.unit * 2,
            countHeight: KunSpacing.unit * 4,
            countMinWidth: KunSpacing.unit * 4,
            countPadding: KunSpacing.unit * 1,
            textStyle: KunText.xs.copyWith(fontSize: 10),
          ),
        KunBadgeSize.md => const _KunBadgeSize(
            dotSide: KunSpacing.unit * 2.5,
            countHeight: KunSpacing.unit * 5,
            countMinWidth: KunSpacing.unit * 5,
            countPadding: KunSpacing.unit * 1.5,
            textStyle: KunText.xs,
          ),
        KunBadgeSize.lg => const _KunBadgeSize(
            dotSide: KunSpacing.unit * 3,
            countHeight: KunSpacing.unit * 6,
            countMinWidth: KunSpacing.unit * 6,
            countPadding: KunSpacing.unit * 2,
            textStyle: KunText.sm,
          ),
      };
}

/// A count or dot on the corner of an anchor widget ([child]), implementing
/// the web `KunBadge` contract.
///
/// Without a [child] it renders standalone (inline) with no ring. For an
/// inline pill use [KunChip].
///
/// A changing count is announced only when [semanticLabel] is set; the
/// caller writes the label to match the count (e.g. "5 条未读").
class KunBadge extends StatelessWidget {
  /// Creates a badge.
  const KunBadge({
    super.key,
    this.child,
    this.variant = KunBadgeVariant.count,
    this.count = 0,
    this.max = 99,
    this.showZero = false,
    this.show = true,
    this.color = KunUIColor.danger,
    this.size = KunBadgeSize.md,
    this.placement = KunBadgePlacement.topRight,
    this.semanticLabel,
  });

  /// The anchor (web slot `default`). Null renders the badge standalone.
  final Widget? child;

  /// Count digits, or a plain dot.
  final KunBadgeVariant variant;

  /// The number shown on a count badge.
  final int count;

  /// Count above this shows as `$max+`.
  final int max;

  /// A count badge hides at `count <= 0` unless this is set.
  final bool showZero;

  /// When false the badge is not painted.
  final bool show;

  /// Fill color. Defaults to [KunUIColor.danger].
  final KunUIColor color;

  /// Dot side and count-box metrics.
  final KunBadgeSize size;

  /// Which corner of [child] the badge sits on. Ignored when standalone.
  final KunBadgePlacement placement;

  /// Web `ariaLabel`, announced as a live region.
  ///
  /// The caller writes the label to match the count (e.g. "5 条未读").
  final String? semanticLabel;

  bool get _visible {
    if (!show) return false;
    if (variant == KunBadgeVariant.count && count <= 0 && !showZero) {
      return false;
    }
    return true;
  }

  String get _displayText {
    if (variant == KunBadgeVariant.dot) return '';
    if (count > max) return '$max+';
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    final bool anchored = child != null;
    if (!anchored) {
      if (!_visible) return const SizedBox.shrink();
      return _buildBadge(context, anchored: false);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child!,
        if (_visible) _positioned(_buildBadge(context, anchored: true)),
      ],
    );
  }

  Widget _positioned(Widget badge) {
    final double inset = -KunSpacing.unit;
    return switch (placement) {
      KunBadgePlacement.topRight =>
        Positioned(top: inset, right: inset, child: badge),
      KunBadgePlacement.topLeft =>
        Positioned(top: inset, left: inset, child: badge),
      KunBadgePlacement.bottomRight =>
        Positioned(bottom: inset, right: inset, child: badge),
      KunBadgePlacement.bottomLeft =>
        Positioned(bottom: inset, left: inset, child: badge),
    };
  }

  Widget _buildBadge(BuildContext context, {required bool anchored}) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunColorScale scale = color.scaleOf(scheme);
    final _KunBadgeSize metrics = _KunBadgeSize.of(size);
    final BoxDecoration decoration = BoxDecoration(
      color: scale.solid,
      borderRadius: BorderRadius.circular(KunRadius.full),
      boxShadow: anchored
          ? [
              BoxShadow(
                color: scheme.background,
                spreadRadius: 2,
                blurRadius: 0,
                offset: Offset.zero,
              ),
            ]
          : null,
    );

    final Widget badge;
    if (variant == KunBadgeVariant.dot) {
      badge = SizedBox.square(
        dimension: metrics.dotSide,
        child: DecoratedBox(decoration: decoration),
      );
    } else {
      // Not Container.alignment: its Align has no size factors, so under a
      // bounded parent a standalone badge laid out 800px wide. The web box
      // shrink-wraps its text.
      badge = Container(
        constraints: BoxConstraints(minWidth: metrics.countMinWidth),
        height: metrics.countHeight,
        padding: EdgeInsets.symmetric(horizontal: metrics.countPadding),
        decoration: decoration,
        child: Align(
          alignment: Alignment.center,
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            _displayText,
            maxLines: 1,
            softWrap: false,
            style: metrics.textStyle.copyWith(
              color: scale.onSolid,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    if (semanticLabel == null) return badge;
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: badge),
    );
  }
}
