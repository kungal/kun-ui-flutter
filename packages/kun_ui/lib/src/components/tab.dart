import 'dart:math' as math;
import 'dart:ui' show ImageFilter, SemanticsRole;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/design.dart';
import '../theme/theme.dart';

/// Visual style of a [KunTab] strip.
enum KunTabVariant {
  /// A sliding underline under the selected tab.
  underlined,

  /// A filled chip behind the selected tab, inside a padded frame.
  solid,

  /// A 1px outline that slides onto the selected tab, inside a padded frame.
  bordered,

  /// A soft tint behind the selected tab, inside a padded frame.
  light,

  /// Independent pills; the selected tab fills with the semantic color.
  pills,
}

/// The tab strip's own size scale — sm/md/lg, with no xs/xl.
enum KunTabSize {
  /// Small padding and `text-sm`.
  sm,

  /// Medium padding and `text-sm` — the default.
  md,

  /// Large padding and `text-base`.
  lg,
}

/// Axis of a [KunTab] strip.
enum KunTabOrientation {
  /// A row that scrolls horizontally when it outgrows its parent.
  horizontal,

  /// A column. Vertical overflow scrolls only when [KunTab.scrollable] is set.
  vertical,
}

/// Horizontal alignment of a tab's icon and label inside its box.
enum KunTabAlign {
  /// Pack content to the start.
  start,

  /// Center content.
  center,

  /// Pack content to the end.
  end,
}

/// Web type `KunTabItem`. Not final: an app subclasses it to carry its own
/// fields (an unread count, a dirty flag) and reads them back in
/// [KunTab.tabBuilder], as the web's generic item type allows.
@immutable
class KunTabItem {
  /// Creates a tab item.
  const KunTabItem({
    required this.value,
    this.textValue,
    this.icon,
    this.disabled = false,
    this.href,
  });

  /// The selection key, matched against [KunTab.value].
  final String value;

  /// The label.
  final String? textValue;

  /// The glyph. The web takes a registered icon name; here the glyph itself.
  final IconData? icon;

  /// Dims this tab and blocks selecting or focusing it.
  final bool disabled;

  /// Navigated to through [KunUIConfig] on every selection of this tab.
  final String? href;
}

/// Builds custom content for one tab (web slot `tab`).
typedef KunTabBuilder<T extends KunTabItem> = Widget Function(
  BuildContext context,
  T item,
  int index,
  bool active,
);

class _KunTabMetrics {
  const _KunTabMetrics({
    required this.labelStyle,
    required this.paddingH,
    required this.paddingV,
    required this.gap,
  });

  final TextStyle labelStyle;
  final double paddingH;
  final double paddingV;
  final double gap;

  static _KunTabMetrics of(KunTabSize size) => switch (size) {
        KunTabSize.sm => const _KunTabMetrics(
            labelStyle: KunText.sm,
            paddingH: KunSpacing.unit * 2.5,
            paddingV: KunSpacing.unit * 1.5,
            gap: KunSpacing.unit * 1,
          ),
        KunTabSize.md => const _KunTabMetrics(
            labelStyle: KunText.sm,
            paddingH: KunSpacing.unit * 3,
            paddingV: KunSpacing.unit * 2,
            gap: KunSpacing.unit * 1.5,
          ),
        KunTabSize.lg => const _KunTabMetrics(
            labelStyle: KunText.base,
            paddingH: KunSpacing.unit * 4,
            paddingV: KunSpacing.unit * 2.5,
            gap: KunSpacing.unit * 2,
          ),
      };
}

/// A tab strip implementing the web `KunTab` contract.
///
/// The value is controlled: pass [value], rebuild with what [onChanged]
/// gives. Items with an [KunTabItem.href] navigate through
/// [KunUIConfigScope] on every selection, changed or not. Arrow keys move
/// the selection (focus follows); Home and End jump to the first and last
/// enabled tab. A horizontal strip that outgrows its parent scrolls inside
/// it. `KunTabPanels` is not ported — switch content on [value] yourself.
class KunTab<T extends KunTabItem> extends StatefulWidget {
  /// Creates a tab strip.
  const KunTab({
    super.key,
    required this.items,
    required this.value,
    this.onChanged,
    this.tabBuilder,
    this.variant = KunTabVariant.underlined,
    this.color = KunUIColor.primary,
    this.size = KunTabSize.md,
    this.orientation = KunTabOrientation.horizontal,
    this.fullWidth = false,
    this.align,
    this.disabled = false,
    this.disableAnimation = false,
    this.scrollable = false,
    this.scrollButtons = true,
    this.iconSize,
  });

  /// The tabs to show.
  final List<T> items;

  /// The current selection (web `modelValue`). Matching no item selects
  /// nothing.
  final String value;

  /// Called when the selection should change (web `update:modelValue`, and
  /// `change` — both fire on the same selections).
  final ValueChanged<String>? onChanged;

  /// Replaces the default icon + label (web slot `tab`).
  final KunTabBuilder<T>? tabBuilder;

  /// Visual style of the strip and the sliding indicator.
  final KunTabVariant variant;

  /// Semantic color the indicator and selected text are painted in.
  final KunUIColor color;

  /// Padding, type size and gap.
  final KunTabSize size;

  /// Row or column.
  final KunTabOrientation orientation;

  /// Stretch the strip (and a vertical list) to the parent's width. Horizontal
  /// tabs still pack at the start.
  final bool fullWidth;

  /// Alignment of each tab's content inside its box. Null: [KunTabAlign.center]
  /// when horizontal, [KunTabAlign.start] when vertical.
  final KunTabAlign? align;

  /// Dims the whole strip and blocks selection, focus and keyboard.
  final bool disabled;

  /// Jump the indicator instead of sliding it. Text colour still eases.
  final bool disableAnimation;

  /// Vertical only: scroll when the column outgrows a bounded height.
  final bool scrollable;

  /// Horizontal overflow chevrons. The edge fade stays either way.
  final bool scrollButtons;

  /// Glyph size. Null is the tab's font size (web `'1em'`).
  final double? iconSize;

  @override
  State<KunTab<T>> createState() => _KunTabState<T>();
}

class _KunTabState<T extends KunTabItem> extends State<KunTab<T>>
    with SingleTickerProviderStateMixin<KunTab<T>> {
  static const double _underlineThickness = 2;
  static const double _scrollPad = 44;
  static const double _scrollSlack = 1;

  final GlobalKey _listKey = GlobalKey();
  // The fade's ShaderMask comes and goes above the scroll view; remounted,
  // it restarted at offset 0 and dropped the initial scroll into view.
  final GlobalKey _viewportKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _tabKeys = <GlobalKey>[];
  final List<FocusNode> _focusNodes = <FocusNode>[];

  Rect? _indicatorFrom;
  Rect? _indicatorTo;
  late final AnimationController _indicatorMotion;
  bool _hasMeasured = false;
  bool _selectionChanged = false;
  bool _didInitialScroll = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _layoutScheduled = false;
  bool _reduceMotion = false;
  final Set<int> _hovered = <int>{};
  final Set<int> _chevronHovered = <int>{};

  bool get _isVertical => widget.orientation == KunTabOrientation.vertical;

  KunTabAlign get _align =>
      widget.align ?? (_isVertical ? KunTabAlign.start : KunTabAlign.center);

  @override
  void initState() {
    super.initState();
    _indicatorMotion = AnimationController(
      vsync: this,
      duration: KunDurations.base,
    );
    _syncKeys();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(KunTab<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _selectionChanged = true;
    }
    if (oldWidget.orientation != widget.orientation &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _syncKeys();
  }

  @override
  void dispose() {
    _indicatorMotion.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    for (final FocusNode node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncKeys() {
    while (_tabKeys.length < widget.items.length) {
      _tabKeys.add(GlobalKey());
    }
    if (_tabKeys.length > widget.items.length) {
      _tabKeys.removeRange(widget.items.length, _tabKeys.length);
    }
    while (_focusNodes.length < widget.items.length) {
      _focusNodes.add(FocusNode(debugLabel: 'KunTab'));
    }
    while (_focusNodes.length > widget.items.length) {
      _focusNodes.removeLast().dispose();
    }
  }

  void _scheduleAfterLayout() {
    if (_layoutScheduled) return;
    _layoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutScheduled = false;
      if (mounted) _afterLayout();
    });
  }

  void _handleScroll() {
    if (!mounted) return;
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      _scheduleAfterLayout();
      return;
    }
    _updateOverflow(notify: true);
  }

  bool _sameRect(Rect? a, Rect? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return (a.left - b.left).abs() < 0.5 &&
        (a.top - b.top).abs() < 0.5 &&
        (a.width - b.width).abs() < 0.5 &&
        (a.height - b.height).abs() < 0.5;
  }

  Rect? get _indicatorRect {
    final Rect? from = _indicatorFrom;
    final Rect? to = _indicatorTo;
    if (from == null || to == null) return to;
    return Rect.lerp(
      from,
      to,
      KunEasing.standard.transform(_indicatorMotion.value),
    );
  }

  void _jumpIndicator(Rect? rect) {
    _indicatorMotion.stop();
    _indicatorFrom = rect;
    _indicatorTo = rect;
  }

  Duration _motion(Duration duration) =>
      _reduceMotion ? Duration.zero : duration;

  void _afterLayout() {
    final bool selectionChanged = _selectionChanged;
    _selectionChanged = false;
    final Rect? rect = _computeIndicatorRect();
    final ({bool left, bool right}) overflow = _computeOverflow();
    final bool rectChanged = !_sameRect(rect, _indicatorTo);
    final bool overflowChanged =
        overflow.left != _canScrollLeft || overflow.right != _canScrollRight;

    if (rectChanged || overflowChanged || !_hasMeasured) {
      final Rect? origin = _indicatorRect;
      final bool slide = rectChanged &&
          selectionChanged &&
          _hasMeasured &&
          rect != null &&
          origin != null &&
          !widget.disableAnimation &&
          !_reduceMotion;
      setState(() {
        if (slide) {
          _indicatorFrom = origin;
          _indicatorTo = rect;
        } else if (rectChanged) {
          _jumpIndicator(rect);
        }
        _canScrollLeft = overflow.left;
        _canScrollRight = overflow.right;
        _hasMeasured = true;
      });
      if (slide) {
        _indicatorMotion.forward(from: 0);
      }
    }

    if (!_didInitialScroll) {
      _didInitialScroll = true;
      _scrollActiveIntoView(smooth: false);
    } else if (selectionChanged) {
      _scrollActiveIntoView(smooth: true);
    }
  }

  Rect? _computeIndicatorRect() {
    final int index =
        widget.items.indexWhere((T item) => item.value == widget.value);
    if (index < 0) return null;
    final BuildContext? listContext = _listKey.currentContext;
    final BuildContext? tabContext = _tabKeys[index].currentContext;
    if (listContext == null || tabContext == null) return null;
    final RenderObject? listObject = listContext.findRenderObject();
    final RenderObject? tabObject = tabContext.findRenderObject();
    if (listObject is! RenderBox || tabObject is! RenderBox) return null;
    if (!listObject.hasSize || !tabObject.hasSize) return null;
    final Offset origin =
        tabObject.localToGlobal(Offset.zero, ancestor: listObject);
    final Size tabSize = tabObject.size;
    if (widget.variant == KunTabVariant.underlined) {
      if (_isVertical) {
        return Rect.fromLTWH(0, origin.dy, _underlineThickness, tabSize.height);
      }
      return Rect.fromLTWH(
        origin.dx,
        listObject.size.height - _underlineThickness,
        tabSize.width,
        _underlineThickness,
      );
    }
    return origin & tabSize;
  }

  ({bool left, bool right}) _computeOverflow() {
    if (_isVertical || !_scrollController.hasClients) {
      return (left: false, right: false);
    }
    final ScrollPosition position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      return (left: false, right: false);
    }
    return (
      left: position.pixels > _scrollSlack,
      right: position.pixels < position.maxScrollExtent - _scrollSlack,
    );
  }

  void _updateOverflow({required bool notify}) {
    final ({bool left, bool right}) overflow = _computeOverflow();
    if (overflow.left == _canScrollLeft && overflow.right == _canScrollRight) {
      return;
    }
    if (notify) {
      setState(() {
        _canScrollLeft = overflow.left;
        _canScrollRight = overflow.right;
      });
    } else {
      _canScrollLeft = overflow.left;
      _canScrollRight = overflow.right;
    }
  }

  void _scrollActiveIntoView({required bool smooth}) {
    if (_isVertical || !_scrollController.hasClients) return;
    final int index =
        widget.items.indexWhere((T item) => item.value == widget.value);
    if (index < 0) return;
    final BuildContext? tabContext = _tabKeys[index].currentContext;
    final BuildContext? listContext = _listKey.currentContext;
    if (tabContext == null || listContext == null) return;
    final RenderObject? tabObject = tabContext.findRenderObject();
    final RenderObject? listObject = listContext.findRenderObject();
    if (tabObject is! RenderBox || listObject is! RenderBox) return;
    final ScrollPosition position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final double left =
        tabObject.localToGlobal(Offset.zero, ancestor: listObject).dx;
    final double right = left + tabObject.size.width;
    final double viewLeft = position.pixels;
    final double viewRight = viewLeft + position.viewportDimension;
    double? target;
    if (left < viewLeft + _scrollPad) {
      target = math.max(0, left - _scrollPad);
    } else if (right > viewRight - _scrollPad) {
      target = right - position.viewportDimension + _scrollPad;
    }
    if (target == null) return;
    target = target.clamp(0, position.maxScrollExtent);
    _animateScrollTo(target, smooth: smooth);
  }

  void _animateScrollTo(double target, {required bool smooth}) {
    if (!_scrollController.hasClients) return;
    final Duration duration =
        smooth ? _motion(KunDurations.slow) : Duration.zero;
    if (duration == Duration.zero) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(
      target,
      duration: duration,
      curve: KunEasing.standard,
    );
  }

  void _scrollByStep(int direction) {
    if (!_scrollController.hasClients) return;
    final ScrollPosition position = _scrollController.position;
    final double delta = direction * position.viewportDimension * 0.8;
    final double target =
        (position.pixels + delta).clamp(0, position.maxScrollExtent);
    _animateScrollTo(target, smooth: true);
  }

  void _select(T item) {
    if (widget.disabled || item.disabled) return;
    if (item.value != widget.value) {
      widget.onChanged?.call(item.value);
    }
    if (item.href != null) {
      KunUIConfigScope.of(context).navigateTo(context, item.href!);
    }
  }

  List<int> _enabledIndices() {
    final List<int> enabled = <int>[];
    for (int i = 0; i < widget.items.length; i++) {
      if (!widget.items[i].disabled) enabled.add(i);
    }
    return enabled;
  }

  void _moveSelection(int delta) {
    final List<int> enabled = _enabledIndices();
    if (enabled.isEmpty) return;
    final int current =
        widget.items.indexWhere((T item) => item.value == widget.value);
    final int curInEnabled = enabled.indexOf(current);
    final int next;
    if (curInEnabled < 0) {
      next = enabled[delta > 0 ? 0 : enabled.length - 1];
    } else {
      next = enabled[(curInEnabled + delta + enabled.length) % enabled.length];
    }
    _select(widget.items[next]);
    _focusNodes[next].requestFocus();
  }

  void _moveToEdge({required bool first}) {
    final List<int> enabled = _enabledIndices();
    if (enabled.isEmpty) return;
    final int index = first ? enabled.first : enabled.last;
    _select(widget.items[index]);
    _focusNodes[index].requestFocus();
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (widget.disabled) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      final int focused = _focusNodes.indexWhere((FocusNode n) => n.hasFocus);
      if (focused >= 0) {
        _select(widget.items[focused]);
        return KeyEventResult.handled;
      }
    }
    if (!_isVertical && key == LogicalKeyboardKey.arrowRight) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (!_isVertical && key == LogicalKeyboardKey.arrowLeft) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (_isVertical && key == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (_isVertical && key == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _moveToEdge(first: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _moveToEdge(first: false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Color _selectedTextColor(KunColorScheme scheme, KunColorScale scale) {
    switch (widget.variant) {
      case KunTabVariant.solid:
      case KunTabVariant.pills:
        return scale.onSolid;
      case KunTabVariant.underlined:
      case KunTabVariant.light:
      case KunTabVariant.bordered:
        return widget.color == KunUIColor.neutral
            ? scheme.foreground
            : scale.solid;
    }
  }

  Color _unselectedTextColor(KunColorScheme scheme, {required bool hovered}) {
    // CSS `:hover` matches a disabled button; the web does not exclude it.
    return hovered ? scheme.foreground : scheme.neutral.shade500;
  }

  BorderRadius? _tabRadius() {
    switch (widget.variant) {
      case KunTabVariant.underlined:
        return null;
      case KunTabVariant.solid:
      case KunTabVariant.light:
      case KunTabVariant.bordered:
        return BorderRadius.circular(KunRadius.md);
      case KunTabVariant.pills:
        return BorderRadius.circular(KunRadius.full);
    }
  }

  BoxDecoration _indicatorDecoration(
    KunColorScheme scheme,
    KunColorScale scale,
  ) {
    switch (widget.variant) {
      case KunTabVariant.underlined:
        return BoxDecoration(
          color: scale.solid,
          borderRadius: BorderRadius.circular(KunRadius.full),
        );
      case KunTabVariant.solid:
        return BoxDecoration(
          color: scale.solid,
          borderRadius: BorderRadius.circular(KunRadius.md),
        );
      case KunTabVariant.light:
        return BoxDecoration(
          color: scale.solid.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(KunRadius.md),
        );
      case KunTabVariant.bordered:
        return BoxDecoration(
          border: Border.all(color: scale.solid),
          borderRadius: BorderRadius.circular(KunRadius.md),
        );
      case KunTabVariant.pills:
        return BoxDecoration(
          color: scale.solid,
          borderRadius: BorderRadius.circular(KunRadius.full),
        );
    }
  }

  MainAxisAlignment _contentAlignment() {
    switch (_align) {
      case KunTabAlign.start:
        return MainAxisAlignment.start;
      case KunTabAlign.center:
        return MainAxisAlignment.center;
      case KunTabAlign.end:
        return MainAxisAlignment.end;
    }
  }

  Widget _wrapScroll(Widget child, Axis axis) {
    return NotificationListener<ScrollMetricsNotification>(
      key: _viewportKey,
      onNotification: (ScrollMetricsNotification notification) {
        if (notification.depth == 0) _handleScroll();
        return false;
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          overscroll: false,
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: axis,
          child: child,
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    KunColorScheme scheme,
    KunColorScale scale,
    _KunTabMetrics metrics,
  ) {
    final bool framed = widget.variant == KunTabVariant.solid ||
        widget.variant == KunTabVariant.light ||
        widget.variant == KunTabVariant.bordered;
    final bool filled = widget.variant == KunTabVariant.solid ||
        widget.variant == KunTabVariant.light;

    final List<Widget> tabs = <Widget>[
      for (int i = 0; i < widget.items.length; i++)
        _buildTab(i, scheme, scale, metrics),
    ];

    Widget body = _isVertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: metrics.gap,
            children: tabs,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: metrics.gap,
            children: tabs,
          );

    body = Stack(
      key: _listKey,
      children: <Widget>[
        if (_hasMeasured && _indicatorTo != null)
          AnimatedBuilder(
            animation: _indicatorMotion,
            builder: (BuildContext context, Widget? child) =>
                Positioned.fromRect(rect: _indicatorRect!, child: child!),
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: DecoratedBox(
                  key: const ValueKey<String>('KunTab.indicator'),
                  decoration: _indicatorDecoration(scheme, scale),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        // The web re-measures on a ResizeObserver: a relayout that never
        // rebuilds this state (a parent resize, a text scale change) still
        // moves the tabs, so a rebuild alone left the indicator stale.
        _LayoutProbe(onLayout: _scheduleAfterLayout, child: body),
      ],
    );

    if (widget.items.isNotEmpty) {
      body = Semantics(
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.tabBar,
        child: body,
      );
    }

    if (framed) {
      body = Container(
        padding: const EdgeInsets.all(KunSpacing.unit * 1),
        decoration: BoxDecoration(
          color: filled ? scheme.content2.withValues(alpha: 0.3) : null,
          border: Border.all(color: scheme.neutral.shade100),
          borderRadius: BorderRadius.circular(KunRadius.lg),
        ),
        child: body,
      );
    }

    if (_isVertical && !widget.fullWidth) {
      body = IntrinsicWidth(child: body);
    }
    return body;
  }

  Widget _buildTab(
    int index,
    KunColorScheme scheme,
    KunColorScale scale,
    _KunTabMetrics metrics,
  ) {
    final T item = widget.items[index];
    final bool selected = item.value == widget.value;
    final bool itemEnabled = !widget.disabled && !item.disabled;
    final bool hovered = _hovered.contains(index);
    final Color targetColor = selected
        ? _selectedTextColor(scheme, scale)
        : _unselectedTextColor(scheme, hovered: hovered);
    final bool showFallback = !_hasMeasured && selected;
    final BorderRadius? radius = _tabRadius();

    Color? fill;
    Border? border;
    Decoration? underlineFallback;
    if (widget.variant == KunTabVariant.bordered) {
      border = Border.all(
        color:
            showFallback ? scale.solid : KunColors.black.withValues(alpha: 0),
      );
    }
    if (showFallback) {
      switch (widget.variant) {
        case KunTabVariant.solid:
        case KunTabVariant.pills:
          fill = scale.solid;
        case KunTabVariant.light:
          fill = scale.solid.withValues(alpha: 0.15);
        case KunTabVariant.bordered:
          break;
        case KunTabVariant.underlined:
          underlineFallback = const BoxDecoration();
      }
    }

    final bool stretch = _isVertical;
    Widget content;
    if (widget.tabBuilder != null) {
      content = widget.tabBuilder!(context, item, index, selected);
      if (stretch) {
        content = SizedBox(
          width: double.infinity,
          child: Align(
            alignment: switch (_align) {
              KunTabAlign.start => Alignment.centerLeft,
              KunTabAlign.center => Alignment.center,
              KunTabAlign.end => Alignment.centerRight,
            },
            child: content,
          ),
        );
      }
    } else {
      content = Row(
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: _contentAlignment(),
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: metrics.gap,
        children: <Widget>[
          if (item.icon != null)
            Icon(
              item.icon,
              size: widget.iconSize ?? metrics.labelStyle.fontSize,
            ),
          if (item.textValue != null)
            Text(
              item.textValue!,
              maxLines: 1,
              softWrap: false,
            ),
        ],
      );
    }

    Widget tab = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: targetColor),
      duration: _motion(KunDurations.base),
      curve: KunEasing.standard,
      builder: (BuildContext context, Color? color, Widget? child) {
        final Color resolved = color ?? targetColor;
        final Decoration? foreground = underlineFallback == null
            ? null
            : BoxDecoration(
                border: _isVertical
                    ? Border(
                        left: BorderSide(
                          width: _underlineThickness,
                          color: resolved,
                        ),
                      )
                    : Border(
                        bottom: BorderSide(
                          width: _underlineThickness,
                          color: resolved,
                        ),
                      ),
              );
        return Container(
          key: showFallback ? const ValueKey<String>('KunTab.fallback') : null,
          padding: EdgeInsets.symmetric(
            horizontal: metrics.paddingH,
            vertical: metrics.paddingV,
          ),
          decoration: BoxDecoration(
            color: fill,
            border: border,
            borderRadius: radius,
          ),
          foregroundDecoration: foreground,
          child: DefaultTextStyle(
            style: metrics.labelStyle.copyWith(color: resolved),
            maxLines: 1,
            softWrap: false,
            child: IconTheme.merge(
              data: IconThemeData(
                color: resolved,
                size: widget.iconSize ?? metrics.labelStyle.fontSize,
              ),
              child: child!,
            ),
          ),
        );
      },
      child: content,
    );

    if (item.disabled) {
      tab = Opacity(opacity: 0.5, child: tab);
    }

    tab = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: itemEnabled
          ? () {
              _focusNodes[index].requestFocus();
              _select(item);
            }
          : null,
      child: tab,
    );

    tab = MouseRegion(
      // The web's root `cursor-not-allowed` on a disabled group is overridden
      // by each tab's own `cursor-pointer`.
      cursor: item.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered.add(index)),
      onExit: (_) => setState(() => _hovered.remove(index)),
      child: tab,
    );

    tab = Focus(
      focusNode: _focusNodes[index],
      canRequestFocus: itemEnabled,
      skipTraversal: !itemEnabled || !selected,
      includeSemantics: false,
      onKeyEvent: (FocusNode node, KeyEvent event) => _onKey(event),
      child: tab,
    );

    tab = Semantics(
      container: true,
      role: SemanticsRole.tab,
      selected: selected,
      enabled: itemEnabled,
      onTap: itemEnabled ? () => _select(item) : null,
      child: tab,
    );

    return KeyedSubtree(
      key: ValueKey<String>('KunTab.${item.value}'),
      child: KeyedSubtree(
        key: _tabKeys[index],
        child: tab,
      ),
    );
  }

  Widget _buildChevron({
    required bool left,
    required KunColorScheme scheme,
  }) {
    final bool hovered = _chevronHovered.contains(left ? 0 : 1);
    final double iconSize =
        DefaultTextStyle.of(context).style.fontSize ?? KunText.base.fontSize!;
    return Positioned(
      left: left ? KunSpacing.unit * 0.5 : null,
      right: left ? null : KunSpacing.unit * 0.5,
      top: 0,
      bottom: 0,
      child: ExcludeSemantics(
        child: Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _chevronHovered.add(left ? 0 : 1)),
            onExit: (_) => setState(() => _chevronHovered.remove(left ? 0 : 1)),
            child: GestureDetector(
              key: ValueKey<String>(
                left ? 'KunTab.chevron.left' : 'KunTab.chevron.right',
              ),
              behavior: HitTestBehavior.opaque,
              onTap: () => _scrollByStep(left ? -1 : 1),
              child: AnimatedOpacity(
                opacity: hovered ? 1 : 0.8,
                duration: _motion(KunDefaultTransition.duration),
                curve: KunDefaultTransition.curve,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: KunShadows.sm,
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: KunBlur.sm,
                        sigmaY: KunBlur.sm,
                      ),
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(
                          end: hovered
                              ? scheme.foreground
                              : scheme.neutral.shade600,
                        ),
                        duration: _motion(KunDefaultTransition.duration),
                        curve: KunDefaultTransition.curve,
                        builder: (BuildContext context, Color? color,
                            Widget? child) {
                          return Container(
                            width: KunSpacing.unit * 7,
                            height: KunSpacing.unit * 7,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.background.withValues(alpha: 0.8),
                              border:
                                  Border.all(color: scheme.neutral.shade100),
                            ),
                            child: Icon(
                              left
                                  ? KunIcons.chevronLeft
                                  : KunIcons.chevronRight,
                              size: iconSize,
                              color: color ?? scheme.neutral.shade600,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _maybeFade(Widget child) {
    if (_isVertical || (!_canScrollLeft && !_canScrollRight)) {
      return child;
    }
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect rect) {
        final double fadePx = KunSpacing.unit * 7;
        final double fadeFrac = rect.width <= 0
            ? 0
            : math.min(
                fadePx / rect.width,
                _canScrollLeft && _canScrollRight ? 0.5 : 1,
              );
        final List<Color> colors = <Color>[];
        final List<double> stops = <double>[];
        if (_canScrollLeft) {
          colors.add(KunColors.black.withValues(alpha: 0));
          stops.add(0);
          colors.add(KunColors.black);
          stops.add(fadeFrac);
        } else {
          colors.add(KunColors.black);
          stops.add(0);
        }
        if (_canScrollRight) {
          colors.add(KunColors.black);
          stops.add(1 - fadeFrac);
          colors.add(KunColors.black.withValues(alpha: 0));
          stops.add(1);
        } else {
          colors.add(KunColors.black);
          stops.add(1);
        }
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: colors,
          stops: stops,
        ).createShader(rect);
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    _scheduleAfterLayout();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunColorScale scale = widget.color.scaleOf(scheme);
    final _KunTabMetrics metrics = _KunTabMetrics.of(widget.size);

    Widget strip = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        Widget list = _buildList(context, scheme, scale, metrics);
        if (_isVertical) {
          if (widget.fullWidth && constraints.maxWidth.isFinite) {
            list = SizedBox(width: constraints.maxWidth, child: list);
          }
          if (widget.scrollable) {
            list = _wrapScroll(list, Axis.vertical);
          }
          return list;
        }

        final bool fill = widget.fullWidth && constraints.hasBoundedWidth;
        final Widget viewport = _maybeFade(
          _wrapScroll(
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: fill ? constraints.maxWidth : 0,
              ),
              child: list,
            ),
            Axis.horizontal,
          ),
        );
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            viewport,
            if (widget.scrollButtons && _canScrollLeft)
              _buildChevron(left: true, scheme: scheme),
            if (widget.scrollButtons && _canScrollRight)
              _buildChevron(left: false, scheme: scheme),
          ],
        );
      },
    );

    if (widget.disabled) {
      strip = Opacity(opacity: 0.5, child: strip);
    }
    return strip;
  }
}

class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({required this.onLayout, super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutProbe(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLayoutProbe renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderLayoutProbe extends RenderProxyBox {
  _RenderLayoutProbe(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}
