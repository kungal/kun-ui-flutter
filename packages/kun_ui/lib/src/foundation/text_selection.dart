import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../locale/messages.dart';
import '../theme/theme.dart';
import 'design.dart';
import 'motion.dart';
import 'variant_style.dart';

// Material `_kHandleSize` in material/text_selection.dart.
const double _kHandleSize = 22.0;

// Material `_kToolbarContentDistance` in material/text_selection_toolbar.dart.
const double _kToolbarContentDistance = 8.0;

// Material `TextSelectionToolbar.kToolbarContentDistanceBelow` (`_kHandleSize - 2`).
const double _kToolbarContentDistanceBelow = _kHandleSize - 2.0;

// Cupertino `_kSelectionHandleRadius` in cupertino/text_selection.dart.
const double _kSelectionHandleRadius = 6;

// Cupertino `_kSelectionHandleOverlap` in cupertino/text_selection.dart.
const double _kSelectionHandleOverlap = 1.5;

// Cupertino `_CupertinoTextSelectionHandlePainter` `halfStrokeWidth = 1.0`.
const double _kSelectionHandleStroke = 2;

// KunContextMenu `padding` default.
const double _kMenuScreenPadding = 12;

// KunContextMenu `width` default.
const double _kDesktopMenuMinWidth = 192;

// Web `scale-95` / KunDropdown's open Tween begin.
const double _kMenuEnterScale = 0.95;

/// KunUI-drawn text selection handles.
///
/// Instances compare by [handleColor] so rebuilding a field does not dispose
/// [EditableText]'s selection overlay.
class KunTextSelectionControls extends TextSelectionControls
    with TextSelectionHandleControls {
  /// Creates handles painted with [handleColor].
  KunTextSelectionControls({required this.handleColor});

  /// The opaque form of the field's selection tint.
  final Color handleColor;

  bool get _isLollipop {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  @override
  Size getHandleSize(double textLineHeight) {
    if (_isLollipop) {
      return Size(
        _kSelectionHandleRadius * 2,
        textLineHeight + _kSelectionHandleRadius * 2 - _kSelectionHandleOverlap,
      );
    }
    return const Size(_kHandleSize, _kHandleSize);
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    if (_isLollipop) {
      return _buildLollipopHandle(type, textLineHeight);
    }
    return _buildTeardropHandle(type, onTap);
  }

  Widget _buildTeardropHandle(
    TextSelectionHandleType type,
    VoidCallback? onTap,
  ) {
    final Widget handle = SizedBox.square(
      dimension: _kHandleSize,
      child: CustomPaint(
        painter: _KunTeardropHandlePainter(color: handleColor),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.translucent,
        ),
      ),
    );
    return switch (type) {
      TextSelectionHandleType.left => Transform.rotate(
          angle: math.pi / 2.0,
          child: handle,
        ),
      TextSelectionHandleType.right => handle,
      TextSelectionHandleType.collapsed => Transform.rotate(
          angle: math.pi / 4.0,
          child: handle,
        ),
    };
  }

  Widget _buildLollipopHandle(
    TextSelectionHandleType type,
    double textLineHeight,
  ) {
    final Widget customPaint = CustomPaint(
      painter: _KunLollipopHandlePainter(color: handleColor),
    );
    switch (type) {
      case TextSelectionHandleType.left:
        final Size desiredSize = getHandleSize(textLineHeight);
        return SizedBox.fromSize(size: desiredSize, child: customPaint);
      case TextSelectionHandleType.right:
        final Size desiredSize = getHandleSize(textLineHeight);
        final Widget handle =
            SizedBox.fromSize(size: desiredSize, child: customPaint);
        return Transform(
          transform: Matrix4.identity()
            ..translateByDouble(
              desiredSize.width / 2,
              desiredSize.height / 2,
              0,
              1,
            )
            ..rotateZ(math.pi)
            ..translateByDouble(
              -desiredSize.width / 2,
              -desiredSize.height / 2,
              0,
              1,
            ),
          child: handle,
        );
      case TextSelectionHandleType.collapsed:
        return SizedBox.fromSize(size: getHandleSize(textLineHeight));
    }
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    if (_isLollipop) {
      final Size handleSize = getHandleSize(textLineHeight);
      switch (type) {
        case TextSelectionHandleType.left:
          return Offset(handleSize.width / 2, handleSize.height);
        case TextSelectionHandleType.right:
          return Offset(
            handleSize.width / 2,
            handleSize.height -
                2 * _kSelectionHandleRadius +
                _kSelectionHandleOverlap,
          );
        case TextSelectionHandleType.collapsed:
          return Offset(
            handleSize.width / 2,
            textLineHeight + (handleSize.height - textLineHeight) / 2,
          );
      }
    }
    return switch (type) {
      TextSelectionHandleType.collapsed => const Offset(_kHandleSize / 2, -4),
      TextSelectionHandleType.left => const Offset(_kHandleSize, 0),
      TextSelectionHandleType.right => Offset.zero,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is KunTextSelectionControls &&
        other.runtimeType == runtimeType &&
        other.handleColor == handleColor;
  }

  @override
  int get hashCode => Object.hash(runtimeType, handleColor);
}

/// [EditableText.contextMenuBuilder] for KunInput and KunTextarea.
Widget kunTextSelectionContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
) {
  if (SystemContextMenu.isSupportedByField(editableTextState)) {
    return SystemContextMenu.editableText(
      editableTextState: editableTextState,
      items: _systemMenuItems(editableTextState),
    );
  }

  final CapturedThemes themes = InheritedTheme.capture(
    from: editableTextState.context,
    to: Navigator.maybeOf(
      editableTextState.context,
      rootNavigator: true,
    )?.context,
  );
  return themes.wrap(
    Builder(
      builder: (BuildContext capturedContext) {
        final KunThemeData theme = KunTheme.of(capturedContext);
        final KunMessages messages = KunMessagesScope.of(capturedContext);
        final List<_KunTextSelectionMenuEntry> entries = _menuEntries(
          editableTextState.contextMenuButtonItems,
          messages.textSelection,
        );
        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }
        final bool touchBar = switch (defaultTargetPlatform) {
          TargetPlatform.android || TargetPlatform.iOS => true,
          TargetPlatform.fuchsia ||
          TargetPlatform.linux ||
          TargetPlatform.windows ||
          TargetPlatform.macOS =>
            false,
        };
        return _KunTextSelectionMenu(
          theme: theme,
          entries: entries,
          anchors: editableTextState.contextMenuAnchors,
          touchBar: touchBar,
        );
      },
    ),
  );
}

List<IOSSystemContextMenuItem> _systemMenuItems(
  EditableTextState editableTextState,
) {
  final KunMessages messages = KunMessagesScope.of(editableTextState.context);
  final List<IOSSystemContextMenuItem> items = <IOSSystemContextMenuItem>[];
  for (final IOSSystemContextMenuItem item
      in SystemContextMenu.getDefaultItems(editableTextState)) {
    items.add(switch (item) {
      final IOSSystemContextMenuItemLookUp _ => IOSSystemContextMenuItemLookUp(
          title: messages.textSelection.lookUp,
        ),
      final IOSSystemContextMenuItemSearchWeb _ =>
        IOSSystemContextMenuItemSearchWeb(
          title: messages.textSelection.searchWeb,
        ),
      final IOSSystemContextMenuItemShare _ => IOSSystemContextMenuItemShare(
          title: messages.textSelection.share,
        ),
      _ => item,
    });
  }
  return items;
}

String? _catalogLabel(
  ContextMenuButtonType type,
  KunTextSelectionStrings strings,
) {
  return switch (type) {
    ContextMenuButtonType.cut => strings.cut,
    ContextMenuButtonType.copy => strings.copy,
    ContextMenuButtonType.paste => strings.paste,
    ContextMenuButtonType.selectAll => strings.selectAll,
    ContextMenuButtonType.share => strings.share,
    ContextMenuButtonType.lookUp => strings.lookUp,
    ContextMenuButtonType.searchWeb => strings.searchWeb,
    ContextMenuButtonType.delete ||
    ContextMenuButtonType.liveTextInput ||
    ContextMenuButtonType.custom =>
      null,
  };
}

List<_KunTextSelectionMenuEntry> _menuEntries(
  List<ContextMenuButtonItem> items,
  KunTextSelectionStrings strings,
) {
  final List<_KunTextSelectionMenuEntry> entries =
      <_KunTextSelectionMenuEntry>[];
  for (final ContextMenuButtonItem item in items) {
    final String? label = item.label ?? _catalogLabel(item.type, strings);
    if (label == null) {
      continue;
    }
    entries.add(
      _KunTextSelectionMenuEntry(label: label, onPressed: item.onPressed),
    );
  }
  return entries;
}

class _KunTextSelectionMenuEntry {
  const _KunTextSelectionMenuEntry({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;
}

class _KunTextSelectionMenu extends StatefulWidget {
  const _KunTextSelectionMenu({
    required this.theme,
    required this.entries,
    required this.anchors,
    required this.touchBar,
  });

  final KunThemeData theme;
  final List<_KunTextSelectionMenuEntry> entries;
  final TextSelectionToolbarAnchors anchors;
  final bool touchBar;

  @override
  State<_KunTextSelectionMenu> createState() => _KunTextSelectionMenuState();
}

class _KunTextSelectionMenuState extends State<_KunTextSelectionMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _open = AnimationController(
      vsync: this,
      duration: KunDurations.base,
    );
    _curve = CurvedAnimation(
      parent: _open,
      curve: KunEasing.enter,
    );
    _scale = Tween<double>(begin: _kMenuEnterScale, end: 1).animate(_curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _open.duration = kunMotion(context, KunDurations.base);
    if (_open.isDismissed) {
      _open.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _open.dispose();
    super.dispose();
  }

  Widget _panel(Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.theme.colors.content1,
        borderRadius: BorderRadius.circular(KunRadius.lg),
        boxShadow: KunShadows.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(KunSpacing.unit),
        child: child,
      ),
    );
  }

  List<Widget> _rows({required bool asMenuItem}) {
    return <Widget>[
      for (int i = 0; i < widget.entries.length; i++)
        _KunTextSelectionMenuRow(
          label: widget.entries[i].label,
          onPressed: widget.entries[i].onPressed,
          theme: widget.theme,
          asMenuItem: asMenuItem,
          order: i,
        ),
    ];
  }

  Widget _animated({required Alignment alignment, required Widget child}) {
    return FadeTransition(
      opacity: _curve,
      child: ScaleTransition(
        scale: _scale,
        alignment: alignment,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.touchBar) {
      final double paddingAbove =
          MediaQuery.paddingOf(context).top + _kMenuScreenPadding;
      final Offset localAdjustment = Offset(_kMenuScreenPadding, paddingAbove);
      final Offset anchorAbove = widget.anchors.primaryAnchor -
          const Offset(0, _kToolbarContentDistance);
      final Offset anchorBelow =
          (widget.anchors.secondaryAnchor ?? widget.anchors.primaryAnchor) +
              const Offset(0, _kToolbarContentDistanceBelow);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          _kMenuScreenPadding,
          paddingAbove,
          _kMenuScreenPadding,
          _kMenuScreenPadding,
        ),
        child: CustomSingleChildLayout(
          delegate: TextSelectionToolbarLayoutDelegate(
            anchorAbove: anchorAbove - localAdjustment,
            anchorBelow: anchorBelow - localAdjustment,
          ),
          child: _animated(
            alignment: Alignment.center,
            // Ungrouped, the rows were ordered among the page's nodes:
            // uiautomator on a Pixel 10 Pro listed a wrapped bar's last
            // first-line item after the whole second line.
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              child: _panel(
                Wrap(
                  children: _rows(asMenuItem: false),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return CustomSingleChildLayout(
      delegate: _KunDesktopMenuLayoutDelegate(
        anchor: widget.anchors.primaryAnchor,
      ),
      child: _animated(
        alignment: Alignment.topLeft,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          role: SemanticsRole.menu,
          child: _panel(
            ConstrainedBox(
              constraints:
                  const BoxConstraints(minWidth: _kDesktopMenuMinWidth),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _rows(asMenuItem: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KunTextSelectionMenuRow extends StatefulWidget {
  const _KunTextSelectionMenuRow({
    required this.label,
    required this.onPressed,
    required this.theme,
    required this.asMenuItem,
    required this.order,
  });

  final String label;
  final VoidCallback? onPressed;
  final KunThemeData theme;
  final bool asMenuItem;
  final int order;

  @override
  State<_KunTextSelectionMenuRow> createState() =>
      _KunTextSelectionMenuRowState();
}

class _KunTextSelectionMenuRowState extends State<_KunTextSelectionMenuRow> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final KunVariantStyle style = KunVariantStyle.resolve(
      scheme: widget.theme.colors,
      brightness: widget.theme.brightness,
      variant: KunUIVariant.light,
      color: KunUIColor.neutral,
    );
    final bool lit = _hovered || _pressed;
    final Widget visuals = Container(
      decoration: BoxDecoration(
        color: lit ? style.hoverOverlay : null,
        borderRadius: BorderRadius.circular(KunRadius.md),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: KunSpacing.unit * 3,
        vertical: KunSpacing.unit * 1.5,
      ),
      child: Text(
        widget.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: KunText.sm.copyWith(
          color: style.foreground,
          fontWeight: KunFontWeights.medium,
        ),
      ),
    );

    final Widget interactive = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: visuals,
      ),
    );

    if (widget.asMenuItem) {
      return Semantics(
        role: SemanticsRole.menuItem,
        label: widget.label,
        onTap: widget.onPressed,
        child: ExcludeSemantics(child: interactive),
      );
    }
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onPressed,
      sortKey: OrdinalSortKey(widget.order.toDouble()),
      child: ExcludeSemantics(child: interactive),
    );
  }
}

class _KunDesktopMenuLayoutDelegate extends SingleChildLayoutDelegate {
  _KunDesktopMenuLayoutDelegate({required this.anchor});

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return Offset(
      _clampMenu(
        anchor.dx,
        _kMenuScreenPadding,
        size.width - childSize.width - _kMenuScreenPadding,
      ),
      _clampMenu(
        anchor.dy,
        _kMenuScreenPadding,
        size.height - childSize.height - _kMenuScreenPadding,
      ),
    );
  }

  @override
  bool shouldRelayout(_KunDesktopMenuLayoutDelegate oldDelegate) {
    return anchor != oldDelegate.anchor;
  }
}

double _clampMenu(double value, double min, double max) {
  return math.min(math.max(value, min), math.max(max, min));
}

class _KunTeardropHandlePainter extends CustomPainter {
  _KunTeardropHandlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double radius = size.width / 2.0;
    final Rect circle =
        Rect.fromCircle(center: Offset(radius, radius), radius: radius);
    final Rect point = Rect.fromLTWH(0.0, 0.0, radius, radius);
    final Path path = Path()
      ..addOval(circle)
      ..addRect(point);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_KunTeardropHandlePainter oldPainter) {
    return color != oldPainter.color;
  }
}

class _KunLollipopHandlePainter extends CustomPainter {
  _KunLollipopHandlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double halfStrokeWidth = _kSelectionHandleStroke / 2;
    final Paint paint = Paint()..color = color;
    final Rect circle = Rect.fromCircle(
      center: const Offset(_kSelectionHandleRadius, _kSelectionHandleRadius),
      radius: _kSelectionHandleRadius,
    );
    final Rect line = Rect.fromPoints(
      const Offset(
        _kSelectionHandleRadius - halfStrokeWidth,
        2 * _kSelectionHandleRadius - _kSelectionHandleOverlap,
      ),
      Offset(_kSelectionHandleRadius + halfStrokeWidth, size.height),
    );
    final Path path = Path()
      ..addOval(circle)
      ..addRect(line);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_KunLollipopHandlePainter oldPainter) {
    return color != oldPainter.color;
  }
}
