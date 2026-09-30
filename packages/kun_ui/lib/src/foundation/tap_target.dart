import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// How much room a pressable KunUI control claims beyond what it draws.
///
/// The web has no counterpart: its controls are the size the control scale
/// draws them ([KunControlMetrics]), which clears WCAG 2.2 AA's 24px target
/// minimum but not the platform guidance on phones — Android asks for 48dp,
/// iOS for 44pt. Flutter cannot enlarge a hit area past a widget's layout box
/// (every ancestor rejects a point outside its own size before the widget
/// sees it), so a padded control grows its *layout* box and draws itself,
/// unchanged, in the middle; a tap in the margin reaches the control. Material
/// (`MaterialTapTargetSize.padded`) and Cupertino (`CupertinoButton.minSize`)
/// do the same.
enum KunTapTargetSize {
  /// [padded] on Android, Fuchsia and iOS; [shrinkWrap] on desktop. The
  /// default.
  adaptive,

  /// The layout box is at least 44×44 on iOS and 48×48 everywhere else —
  /// the SDK's `kMinInteractiveDimensionCupertino` and
  /// `kMinInteractiveDimension`; the drawn control keeps its size.
  padded,

  /// The layout box is the drawn control — the web's size.
  shrinkWrap,
}

// The SDK's kMinInteractiveDimension and kMinInteractiveDimensionCupertino,
// which only material.dart and cupertino.dart export; tap_target_test.dart
// holds them equal.
const double _minTapTarget = 48;
const double _minTapTargetIOS = 44;

/// The smallest layout box a pressable claims under the nearest [KunTheme].
///
/// [Size.zero] when [KunThemeData.tapTargetSize] resolves to
/// [KunTapTargetSize.shrinkWrap].
Size kunMinTapTargetSize(BuildContext context) {
  final touch = switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.iOS =>
      true,
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows =>
      false,
  };
  final padded = switch (KunTheme.of(context).tapTargetSize) {
    KunTapTargetSize.adaptive => touch,
    KunTapTargetSize.padded => true,
    KunTapTargetSize.shrinkWrap => false,
  };
  if (!padded) return Size.zero;
  return Size.square(
    defaultTargetPlatform == TargetPlatform.iOS
        ? _minTapTargetIOS
        : _minTapTarget,
  );
}

/// How far a [KunTapTarget] around a control drawn at [drawn] reaches past
/// it on each side under the nearest [KunTheme].
///
/// For a control placed by its drawn edge, such as a close button
/// [Positioned] in a corner: subtract this from the offset and the glyph stays
/// where the web draws it.
EdgeInsets kunTapTargetOutset(BuildContext context, Size drawn) {
  final min = kunMinTapTargetSize(context);
  return EdgeInsets.symmetric(
    horizontal: math.max(0, (min.width - drawn.width) / 2),
    vertical: math.max(0, (min.height - drawn.height) / 2),
  );
}

/// Grows [child]'s layout box to [kunMinTapTargetSize] and centres it there.
///
/// A hit in the margin is delivered to the centre of [child], so the whole
/// box presses the control. Put the control's [Semantics] node *outside* this
/// widget: the node's rect is what a screen reader and the tap-target
/// guidelines measure.
///
/// The layout is transcribed from Material's `_InputPadding`
/// (button_style_button.dart); [child] is laid out under the incoming
/// constraints, so a parent that allows less than the minimum still wins.
class KunTapTarget extends StatelessWidget {
  /// Pads [child] to the theme's minimum tap target.
  const KunTapTarget({required this.child, super.key});

  /// The drawn control.
  final Widget child;

  @override
  Widget build(BuildContext context) => _TapTargetPadding(
        minSize: kunMinTapTargetSize(context),
        child: child,
      );
}

class _TapTargetPadding extends SingleChildRenderObjectWidget {
  const _TapTargetPadding({required this.minSize, super.child});

  final Size minSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTapTargetPadding(minSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTapTargetPadding renderObject,
  ) {
    renderObject.minSize = minSize;
  }
}

class _RenderTapTargetPadding extends RenderShiftedBox {
  _RenderTapTargetPadding(this._minSize) : super(null);

  Size get minSize => _minSize;
  Size _minSize;
  set minSize(Size value) {
    if (_minSize == value) return;
    _minSize = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => child == null
      ? 0
      : math.max(child!.getMinIntrinsicWidth(height), minSize.width);

  @override
  double computeMinIntrinsicHeight(double width) => child == null
      ? 0
      : math.max(child!.getMinIntrinsicHeight(width), minSize.height);

  @override
  double computeMaxIntrinsicWidth(double height) => child == null
      ? 0
      : math.max(child!.getMaxIntrinsicWidth(height), minSize.width);

  @override
  double computeMaxIntrinsicHeight(double width) => child == null
      ? 0
      : math.max(child!.getMaxIntrinsicHeight(width), minSize.height);

  // A minimum no larger than the padded box is the box's to absorb: in a
  // stretched IntrinsicHeight row (KunScrollShadow) the row is 48 tall
  // because of these boxes, and passing the tight 48 down drew the button
  // 48 tall with its face at the top, beside a centred KunSelect.
  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(
        minWidth: constraints.minWidth <= minSize.width ? 0 : null,
        minHeight: constraints.minHeight <= minSize.height ? 0 : null,
      );

  Size _computeSize(BoxConstraints constraints, ChildLayouter layoutChild) {
    if (child == null) return Size.zero;
    final childSize = layoutChild(child!, _childConstraints(constraints));
    return constraints.constrain(
      Size(
        math.max(childSize.width, minSize.width),
        math.max(childSize.height, minSize.height),
      ),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _computeSize(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    final result =
        child.getDryBaseline(_childConstraints(constraints), baseline);
    if (result == null) return null;
    final childSize = child.getDryLayout(_childConstraints(constraints));
    return result +
        Alignment.center
            .alongOffset(getDryLayout(constraints) - childSize as Offset)
            .dy;
  }

  @override
  void performLayout() {
    size = _computeSize(constraints, ChildLayoutHelper.layoutChild);
    if (child != null) {
      (child!.parentData! as BoxParentData).offset =
          Alignment.center.alongOffset(size - child!.size as Offset);
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTest(result, position: position)) return true;
    if (child == null || !size.contains(position)) return false;
    final center = child!.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (result, position) => child!.hitTest(result, position: center),
    );
  }
}

/// Gives [child] at least [kunMinTapTargetSize]'s height and paints
/// [background] behind it at [child]'s own height, centred.
///
/// For a control with several targets in one drawn box — a field with a
/// clear button, a tab strip, a closable chip — where [KunTapTarget] would
/// send every margin hit to one centre. Here each column of [child] owns the
/// band above and below it, as long as the column fills [child]'s height
/// (`SizedBox(height: double.infinity)`, or a stretched [Row]) and carries
/// no vertical padding of its own: the padding that sets the drawn height
/// belongs inside the column that is not a target, such as a field's text.
///
/// The drawn height is [child]'s minimum intrinsic height at the incoming
/// maximum width, so [child] must answer intrinsics, and it is then laid out
/// once at the padded height. It must centre its content on the cross axis
/// (a [Row]'s default) so the content lands where it was drawn. [background]
/// is laid out at the drawn size and carries the decoration: fill, border,
/// shadow and ring. The width is never padded.
class KunTapBand extends StatelessWidget {
  /// Pads [child]'s height to the theme's minimum tap target.
  const KunTapBand({required this.background, required this.child, super.key});

  /// The drawn box, sized to [child]'s unpadded size.
  final Widget background;

  /// The content, stretched over the padded height.
  final Widget child;

  @override
  Widget build(BuildContext context) => _TapBand(
        minHeight: kunMinTapTargetSize(context).height,
        children: [background, child],
      );
}

class _TapBandParentData extends ContainerBoxParentData<RenderBox> {}

class _TapBand extends MultiChildRenderObjectWidget {
  const _TapBand({required this.minHeight, required super.children});

  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTapBand(minHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderTapBand renderObject) {
    renderObject.minHeight = minHeight;
  }
}

class _RenderTapBand extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TapBandParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TapBandParentData> {
  _RenderTapBand(this._minHeight);

  double get minHeight => _minHeight;
  double _minHeight;
  set minHeight(double value) {
    if (_minHeight == value) return;
    _minHeight = value;
    markNeedsLayout();
  }

  RenderBox get _background => firstChild!;
  RenderBox get _content => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TapBandParentData) {
      child.parentData = _TapBandParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _content.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _content.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(_content.getMinIntrinsicHeight(width), minHeight);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(_content.getMaxIntrinsicHeight(width), minHeight);

  double _drawnHeight(BoxConstraints constraints) => constraints
      .constrainHeight(_content.getMinIntrinsicHeight(constraints.maxWidth));

  BoxConstraints _contentConstraints(BoxConstraints constraints) =>
      constraints.tighten(
        height: constraints.constrainHeight(
          math.max(_drawnHeight(constraints), minHeight),
        ),
      );

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _content.getDryLayout(_contentConstraints(constraints));

  @override
  void performLayout() {
    final drawnHeight = _drawnHeight(constraints);
    _content.layout(_contentConstraints(constraints), parentUsesSize: true);
    size = _content.size;
    (_content.parentData! as BoxParentData).offset = Offset.zero;
    _background.layout(
      BoxConstraints.tight(Size(size.width, drawnHeight)),
    );
    (_background.parentData! as BoxParentData).offset =
        Offset(0, (size.height - drawnHeight) / 2);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
