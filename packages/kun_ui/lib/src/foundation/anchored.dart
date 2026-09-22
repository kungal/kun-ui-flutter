import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

/// The gap between a trigger and the panel anchored to it, and the margin an
/// auto-positioned panel keeps from the edge of the view.
///
/// The web's `useKunFloating` passes `offset: 8` and `shift({ padding: 8 })`
/// for every overlay but the dropdown, which offsets by 6.
const double kKunAnchorOffset = 8;

/// The margin [KunAnchoredLayout] keeps between a panel and the view's edge,
/// the web's `shift({ padding })` and `size({ padding })`.
const double kKunAnchorPadding = 8;

/// The side of a square caret, the web's `size-2`.
const double kKunArrowSize = KunSpacing.unit * 2;

/// How close to a panel's corner a caret may sit, the web's `arrowPadding`.
const double kKunArrowPadding = 6;

/// Which edge of its trigger a panel sits against.
enum KunAnchorSide {
  /// Above the trigger.
  top,

  /// To the right of the trigger.
  right,

  /// Below the trigger.
  bottom,

  /// To the left of the trigger.
  left;

  /// The side a flip would move the panel to.
  KunAnchorSide get opposite => switch (this) {
        KunAnchorSide.top => KunAnchorSide.bottom,
        KunAnchorSide.bottom => KunAnchorSide.top,
        KunAnchorSide.left => KunAnchorSide.right,
        KunAnchorSide.right => KunAnchorSide.left,
      };

  /// Whether the panel is stacked above or below the trigger, so the main
  /// axis is vertical and the cross axis horizontal.
  bool get isVertical =>
      this == KunAnchorSide.top || this == KunAnchorSide.bottom;
}

/// Where a panel lines up along the edge it is anchored to.
enum KunAnchorAlign {
  /// Flush with the trigger's leading edge.
  start,

  /// Centred on the trigger.
  center,

  /// Flush with the trigger's trailing edge.
  end,
}

/// The placement [KunAnchoredLayout] actually used, reported back so the panel
/// can grow out of the trigger and point a caret at it.
@immutable
class KunAnchorResolution {
  /// Creates a resolution.
  const KunAnchorResolution({required this.side, required this.arrowCross});

  /// The side the panel was placed on, after any flip.
  final KunAnchorSide side;

  /// The caret's offset along the panel's cross axis, from the panel's own
  /// leading edge.
  final double arrowCross;

  @override
  bool operator ==(Object other) =>
      other is KunAnchorResolution &&
      other.side == side &&
      other.arrowCross == arrowCross;

  @override
  int get hashCode => Object.hash(side, arrowCross);
}

/// The alignment a scale transition grows from, so the panel appears to come
/// out of its trigger.
///
/// Translated entry for entry from the web's `useTransformOrigin`, which maps
/// the *resolved* placement so a panel that flipped above its trigger grows
/// from its bottom edge.
Alignment kunAnchorOrigin(KunAnchorSide side, KunAnchorAlign align) {
  return switch ((side, align)) {
    (KunAnchorSide.bottom, KunAnchorAlign.center) => Alignment.topCenter,
    (KunAnchorSide.bottom, KunAnchorAlign.start) => Alignment.topLeft,
    (KunAnchorSide.bottom, KunAnchorAlign.end) => Alignment.topRight,
    (KunAnchorSide.top, KunAnchorAlign.center) => Alignment.bottomCenter,
    (KunAnchorSide.top, KunAnchorAlign.start) => Alignment.bottomLeft,
    (KunAnchorSide.top, KunAnchorAlign.end) => Alignment.bottomRight,
    (KunAnchorSide.left, KunAnchorAlign.center) => Alignment.centerRight,
    (KunAnchorSide.left, KunAnchorAlign.start) => Alignment.topRight,
    (KunAnchorSide.left, KunAnchorAlign.end) => Alignment.bottomRight,
    (KunAnchorSide.right, KunAnchorAlign.center) => Alignment.centerLeft,
    (KunAnchorSide.right, KunAnchorAlign.start) => Alignment.topLeft,
    (KunAnchorSide.right, KunAnchorAlign.end) => Alignment.bottomLeft,
  };
}

/// The part of the overlay a panel may occupy: its box less the system insets
/// and the soft keyboard.
///
/// Read from the view rather than the ambient [MediaQuery] because a
/// [SafeArea] between the app and the trigger may already have consumed them,
/// while the overlay child is inserted at the root and is not inside it.
Rect kunAnchorViewport(BuildContext context, Size overlaySize) {
  final MediaQueryData view = MediaQueryData.fromView(View.of(context));
  return Rect.fromLTRB(
    math.max(view.viewPadding.left, view.viewInsets.left),
    math.max(view.viewPadding.top, view.viewInsets.top),
    overlaySize.width - math.max(view.viewPadding.right, view.viewInsets.right),
    overlaySize.height -
        math.max(view.viewPadding.bottom, view.viewInsets.bottom),
  );
}

/// Places a panel against its trigger, the Flutter translation of the web's
/// floating-ui recipe (`offset` + `flip` + `shift` + `size`).
///
/// One pass of Flutter layout cannot measure the panel, decide the side from
/// that measurement and then constrain it again the way floating-ui's
/// middleware chain does. So the constraints cap the panel to the *better* of
/// the two candidate sides and the side itself is chosen in
/// [getPositionForChild], once the measurement exists. A panel that fits on
/// either side is therefore positioned exactly as the web positions it, and
/// one that fits on neither is capped to the room the winning side has.
class KunAnchoredLayout extends SingleChildLayoutDelegate {
  /// Creates a delegate.
  KunAnchoredLayout({
    required this.anchor,
    required this.viewport,
    required this.side,
    required this.align,
    required this.onResolved,
    this.offset = kKunAnchorOffset,
    this.padding = kKunAnchorPadding,
    this.constrain = true,
    this.capSize = true,
    this.minWidth = 0,
    this.arrowSize = 0,
  });

  /// The trigger's box, in the overlay's coordinates.
  final Rect anchor;

  /// The box the panel must stay inside while [constrain] holds.
  final Rect viewport;

  /// The side asked for, before any flip.
  final KunAnchorSide side;

  /// How the panel lines up along [side].
  final KunAnchorAlign align;

  /// The gap between the trigger and the panel.
  final double offset;

  /// The margin kept from [viewport]'s edges.
  final double padding;

  /// Whether to flip to the opposite side and shift along the edge to stay
  /// inside [viewport]. The web's `autoPosition`.
  final bool constrain;

  /// Whether to cap the panel to the room [viewport] offers, so tall content
  /// scrolls instead of overflowing. The web's `size` middleware.
  final bool capSize;

  /// A floor for the panel's width, the dropdown's `minWidth`.
  final double minWidth;

  /// The side of the caret, or zero when there is none.
  final double arrowSize;

  /// Called during layout with the placement that was used.
  final ValueChanged<KunAnchorResolution> onResolved;

  double get _roomBefore => side.isVertical
      ? anchor.top - viewport.top - offset
      : anchor.left - viewport.left - offset;

  double get _roomAfter => side.isVertical
      ? viewport.bottom - anchor.bottom - offset
      : viewport.right - anchor.right - offset;

  bool get _preferBefore =>
      side == KunAnchorSide.top || side == KunAnchorSide.left;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final bool vertical = side.isVertical;
    final double maxMain = capSize
        ? math.max(0, math.max(_roomBefore, _roomAfter) - padding)
        : (vertical ? viewport.height : viewport.width);
    final double maxCross = constrain
        ? math.max(
            0, (vertical ? viewport.width : viewport.height) - padding * 2)
        : (vertical ? constraints.maxWidth : constraints.maxHeight);
    final double maxWidth = vertical ? maxCross : maxMain;
    return BoxConstraints(
      minWidth: minWidth.clamp(0, maxWidth),
      maxWidth: maxWidth,
      maxHeight: vertical ? maxMain : maxCross,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final bool vertical = side.isVertical;
    final double childMain = vertical ? childSize.height : childSize.width;
    final double roomPreferred = _preferBefore ? _roomBefore : _roomAfter;
    final double roomOpposite = _preferBefore ? _roomAfter : _roomBefore;

    KunAnchorSide resolved = side;
    if (constrain && childMain > roomPreferred - padding) {
      // floating-ui's flip() with its default `bestFit` fallback: take the
      // opposite side when the panel fits there, and otherwise the side with
      // more room rather than the one that was asked for.
      resolved =
          childMain <= roomOpposite - padding || roomOpposite > roomPreferred
              ? side.opposite
              : side;
    }

    final double main = switch (resolved) {
      KunAnchorSide.top => anchor.top - offset - childSize.height,
      KunAnchorSide.bottom => anchor.bottom + offset,
      KunAnchorSide.left => anchor.left - offset - childSize.width,
      KunAnchorSide.right => anchor.right + offset,
    };

    final double anchorCrossStart = vertical ? anchor.left : anchor.top;
    final double anchorCrossEnd = vertical ? anchor.right : anchor.bottom;
    final double childCross = vertical ? childSize.width : childSize.height;
    double cross = switch (align) {
      KunAnchorAlign.start => anchorCrossStart,
      KunAnchorAlign.center =>
        (anchorCrossStart + anchorCrossEnd) / 2 - childCross / 2,
      KunAnchorAlign.end => anchorCrossEnd - childCross,
    };
    if (constrain) {
      final double lowest = (vertical ? viewport.left : viewport.top) + padding;
      final double highest =
          (vertical ? viewport.right : viewport.bottom) - padding - childCross;
      if (highest >= lowest) {
        cross = cross.clamp(lowest, highest);
      }
    }

    onResolved(
      KunAnchorResolution(
        side: resolved,
        arrowCross: _arrowCross(cross, childCross, vertical),
      ),
    );
    return vertical ? Offset(cross, main) : Offset(main, cross);
  }

  double _arrowCross(double cross, double childCross, bool vertical) {
    if (arrowSize <= 0) {
      return 0;
    }
    final double center = vertical ? anchor.center.dx : anchor.center.dy;
    final double highest = childCross - kKunArrowPadding - arrowSize;
    if (highest <= kKunArrowPadding) {
      return math.max(0, (childCross - arrowSize) / 2);
    }
    return (center - cross - arrowSize / 2).clamp(kKunArrowPadding, highest);
  }

  @override
  bool shouldRelayout(covariant KunAnchoredLayout oldDelegate) {
    return anchor != oldDelegate.anchor ||
        viewport != oldDelegate.viewport ||
        side != oldDelegate.side ||
        align != oldDelegate.align ||
        offset != oldDelegate.offset ||
        padding != oldDelegate.padding ||
        constrain != oldDelegate.constrain ||
        capSize != oldDelegate.capSize ||
        minWidth != oldDelegate.minWidth ||
        arrowSize != oldDelegate.arrowSize;
  }
}

/// The caret pointing at the trigger: the web's `size-2 rotate-45` square,
/// half outside the panel's edge.
class KunAnchorArrow extends StatelessWidget {
  /// Creates a caret for a panel placed on [side].
  const KunAnchorArrow({
    required this.side,
    required this.cross,
    required this.color,
    super.key,
  });

  /// The side the panel was placed on.
  final KunAnchorSide side;

  /// The caret's offset along the panel's cross axis.
  final double cross;

  /// The panel's own fill, so the caret reads as part of it.
  final Color color;

  @override
  Widget build(BuildContext context) {
    // The square is rotated, so its diagonal — not its side — is what pokes
    // out of the panel. The web gets the same result from `rotate-45` on a
    // box whose static side is offset by half its (unrotated) size.
    const double half = kKunArrowSize / 2;
    final Widget square = Transform.rotate(
      angle: math.pi / 4,
      child: SizedBox(
        width: kKunArrowSize,
        height: kKunArrowSize,
        child: ColoredBox(color: color),
      ),
    );
    return switch (side) {
      KunAnchorSide.top =>
        Positioned(bottom: -half, left: cross, child: square),
      KunAnchorSide.bottom =>
        Positioned(top: -half, left: cross, child: square),
      KunAnchorSide.left => Positioned(right: -half, top: cross, child: square),
      KunAnchorSide.right => Positioned(left: -half, top: cross, child: square),
    };
  }
}

/// A tap on a trigger that still fires when the trigger handles its own taps.
///
/// A nested [GestureDetector] wins the gesture arena outright, so wrapping a
/// [GestureDetector] around a widget that already has one — a `KunButton`
/// passed as a popover's or a dropdown's trigger — never fires: the button's
/// recognizer takes the tap and the wrapper hears nothing. The web has no
/// such rule, where a click on the slotted trigger bubbles to the wrapper
/// that opens the panel. So the wrapper stays out of the arena and watches
/// raw pointers, calling [onTap] when one goes down and comes up in the same
/// place — a DOM click, not a Flutter tap.
class KunTriggerTap extends StatefulWidget {
  /// Creates a trigger tap region around [child].
  const KunTriggerTap({
    required this.child,
    required this.onTap,
    super.key,
  });

  /// The trigger.
  final Widget child;

  /// Called on a tap, or null to ignore taps entirely.
  final VoidCallback? onTap;

  @override
  State<KunTriggerTap> createState() => _KunTriggerTapState();
}

class _KunTriggerTapState extends State<KunTriggerTap> {
  Offset? _downAt;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) {
      return widget.child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) => _downAt = event.position,
      onPointerCancel: (PointerCancelEvent event) => _downAt = null,
      onPointerUp: (PointerUpEvent event) {
        final Offset? down = _downAt;
        _downAt = null;
        if (down != null && (event.position - down).distance <= kTouchSlop) {
          widget.onTap!();
        }
      },
      child: widget.child,
    );
  }
}
