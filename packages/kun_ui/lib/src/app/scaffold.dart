import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// A page frame: a [body] and an optional [bottomBar].
///
/// The subset of Material's `Scaffold` an app needs once the chrome is
/// KunUI's — no app bar, FAB, drawers, snack bars or bottom sheets, and no
/// `Material` or `ScaffoldMessenger`. Inset arithmetic is transcribed from
/// `material/scaffold.dart`.
class KunScaffold extends StatelessWidget {
  /// Creates a page frame around [body].
  const KunScaffold({
    super.key,
    required this.body,
    this.bottomBar,
    this.extendBody = false,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  /// The primary content of the page.
  final Widget body;

  /// A bar laid out at the bottom at full width.
  ///
  /// It sees the ambient [MediaQuery] without its top padding, as `Scaffold`'s
  /// `bottomNavigationBar` does, so a bar can wrap itself in a [SafeArea] and
  /// pad only for the bottom inset. With [extendBody] false the [body] ends at
  /// this bar's top; with it true the body runs behind the bar and its
  /// `padding.bottom` becomes the bar's height.
  final Widget? bottomBar;

  /// Whether [body] extends behind [bottomBar].
  final bool extendBody;

  /// The page fill. Defaults to the theme's `background` — the web's
  /// `body { background-color: var(--background) }`.
  final Color? backgroundColor;

  /// Whether [body] shrinks above `viewInsets.bottom` (the keyboard).
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData metrics = MediaQuery.of(context);
    final List<LayoutId> children = <LayoutId>[
      LayoutId(
        id: _Slot.body,
        child: MediaQuery(
          data: _bodyMetrics(metrics),
          child: _Body(extendBody: extendBody, body: body),
        ),
      ),
    ];
    if (bottomBar != null) {
      children.add(
        LayoutId(
          id: _Slot.bottomBar,
          child: MediaQuery(data: _barMetrics(metrics), child: bottomBar!),
        ),
      );
    }

    final EdgeInsets minInsets = metrics.padding.copyWith(
      bottom: resizeToAvoidBottomInset ? metrics.viewInsets.bottom : 0,
    );

    return ColoredBox(
      color: backgroundColor ?? KunTheme.of(context).colors.background,
      child: CustomMultiChildLayout(
        delegate: _Layout(extendBody: extendBody, minInsets: minInsets),
        children: children,
      ),
    );
  }

  MediaQueryData _barMetrics(MediaQueryData metrics) {
    final MediaQueryData data = metrics.removePadding(removeTop: true);
    if (!resizeToAvoidBottomInset && data.viewInsets.bottom != 0) {
      return data.copyWith(
        padding: data.padding.copyWith(bottom: data.viewPadding.bottom),
      );
    }
    return data;
  }

  MediaQueryData _bodyMetrics(MediaQueryData metrics) {
    MediaQueryData data = metrics.removePadding(
      removeBottom: bottomBar != null,
    );
    if (resizeToAvoidBottomInset) {
      data = data.removeViewInsets(removeBottom: true);
    }
    return data;
  }
}

enum _Slot { body, bottomBar }

class _BodyConstraints extends BoxConstraints {
  const _BodyConstraints({
    super.maxWidth,
    super.maxHeight,
    required this.bottomBarHeight,
  }) : assert(bottomBarHeight >= 0);

  final double bottomBarHeight;

  @override
  bool operator ==(Object other) {
    if (super != other) {
      return false;
    }
    return other is _BodyConstraints &&
        other.bottomBarHeight == bottomBarHeight;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, bottomBarHeight);
}

class _Body extends StatelessWidget {
  const _Body({required this.extendBody, required this.body});

  final bool extendBody;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    if (!extendBody) {
      return body;
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _BodyConstraints bodyConstraints =
            constraints as _BodyConstraints;
        final MediaQueryData metrics = MediaQuery.of(context);
        final double bottom = math.max(
          metrics.padding.bottom,
          bodyConstraints.bottomBarHeight,
        );
        return MediaQuery(
          data: metrics.copyWith(
            padding: metrics.padding.copyWith(bottom: bottom),
          ),
          child: body,
        );
      },
    );
  }
}

class _Layout extends MultiChildLayoutDelegate {
  _Layout({required this.extendBody, required this.minInsets});

  final bool extendBody;
  final EdgeInsets minInsets;

  @override
  void performLayout(Size size) {
    final BoxConstraints loose = BoxConstraints.loose(size);
    final BoxConstraints fullWidth = loose.tighten(width: size.width);
    var barHeight = 0.0;
    if (hasChild(_Slot.bottomBar)) {
      barHeight = layoutChild(_Slot.bottomBar, fullWidth).height;
      positionChild(
        _Slot.bottomBar,
        Offset(0, math.max(0, size.height - barHeight)),
      );
    }
    if (hasChild(_Slot.body)) {
      final double contentBottom = math.max(
        0,
        size.height - math.max(minInsets.bottom, barHeight),
      );
      double bodyMaxHeight = math.max(0, contentBottom);
      var reportedBarHeight = barHeight;
      if (extendBody && minInsets.bottom <= barHeight) {
        bodyMaxHeight += barHeight;
        bodyMaxHeight = clampDouble(bodyMaxHeight, 0, loose.maxHeight);
      } else {
        reportedBarHeight = 0;
      }
      layoutChild(
        _Slot.body,
        _BodyConstraints(
          maxWidth: fullWidth.maxWidth,
          maxHeight: bodyMaxHeight,
          bottomBarHeight: reportedBarHeight,
        ),
      );
      positionChild(_Slot.body, Offset.zero);
    }
  }

  @override
  bool shouldRelayout(_Layout oldDelegate) =>
      oldDelegate.extendBody != extendBody ||
      oldDelegate.minInsets != minInsets;
}
