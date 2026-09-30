import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'button.dart';
import 'input.dart';

class _PageItem {
  const _PageItem.page(this.page) : key = 'p$page';

  const _PageItem.gap(String side)
      : page = null,
        key = 'gap-$side';

  final String key;
  final int? page;
}

/// Page numbers for a catalogue, implementing the web `KunPagination`
/// contract.
///
/// [currentPage] and [totalPage] are required. [onCurrentPageChanged] is the
/// web's `update:currentPage`. [isLoading] disables every control.
///
/// The left and right arrow keys page while nothing has keyboard focus, or
/// while focus is on the pagination's own buttons. The web also pages from
/// any other element that does not own the arrows; here that would take
/// them from a focused widget that does. On a phone the buttons, padded to
/// the touch minimum, can outgrow the width: the row then scrolls and keeps
/// the current page in view.
class KunPagination extends StatefulWidget {
  /// Creates a pagination control.
  const KunPagination({
    required this.currentPage,
    required this.totalPage,
    this.isLoading = false,
    this.onCurrentPageChanged,
    super.key,
  });

  /// The page the user is on, 1-based.
  final int currentPage;

  /// How many pages there are.
  final int totalPage;

  /// Disables every control while a page of results is in flight.
  final bool isLoading;

  /// Called with the page the user asked for. The parent owns
  /// [currentPage] and rebuilds with the new value.
  final ValueChanged<int>? onCurrentPageChanged;

  @override
  State<KunPagination> createState() => _KunPaginationState();
}

class _KunPaginationState extends State<KunPagination> {
  final GlobalKey _rowKey = GlobalKey(debugLabel: 'KunPagination.pages');
  final Map<int, GlobalKey> _pageKeys = <int, GlobalKey>{};

  late int _windowPage;
  Rect? _indicator;
  bool _hasMounted = false;
  int _popKey = 0;
  String _jumpText = '';
  Timer? _phaseTimer;
  final FocusNode _jumpFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _stripKey = GlobalKey(debugLabel: 'KunPagination.strip');
  ModalRoute<Object?>? _route;
  int? _revealedPage;

  @override
  void initState() {
    super.initState();
    _windowPage = widget.currentPage;
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _hasMounted = true);
      _measureIndicator();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(KunPagination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPage != oldWidget.currentPage) {
      _popKey++;
      _phaseTimer?.cancel();
      _phaseTimer = null;
      final bool lead =
          (widget.currentPage - oldWidget.currentPage).abs() == 1 &&
              _isCentered(widget.currentPage) &&
              _isCentered(oldWidget.currentPage) &&
              _pageKeys[widget.currentPage]?.currentContext != null &&
              !kunReducedMotion(context);
      if (lead) {
        _scheduleMeasure();
        _phaseTimer = Timer(kunMotion(context, KunDurations.fast), () {
          _phaseTimer = null;
          if (!mounted) {
            return;
          }
          setState(() => _windowPage = widget.currentPage);
        });
      } else {
        _windowPage = widget.currentPage;
        _scheduleMeasure();
      }
    } else if (widget.totalPage != oldWidget.totalPage) {
      _scheduleMeasure();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    _phaseTimer?.cancel();
    _jumpFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _isCentered(int page) =>
      widget.totalPage > 7 && page > 3 && page < widget.totalPage - 2;

  GlobalKey _keyFor(int page) => _pageKeys.putIfAbsent(page, GlobalKey.new);

  List<_PageItem> _displayedPages() {
    final List<_PageItem> items = <_PageItem>[];
    void push(int page) => items.add(_PageItem.page(page));
    void gap(String side) => items.add(_PageItem.gap(side));
    final int cur = _windowPage;
    final int total = widget.totalPage;
    const int maxVisiblePages = 7;

    if (total <= maxVisiblePages) {
      for (int i = 1; i <= total; i++) {
        push(i);
      }
      return items;
    }

    push(1);
    if (cur > 3) {
      gap('l');
    }

    int start = math.max(2, cur - 1);
    int end = math.min(total - 1, cur + 1);
    if (cur <= 3) {
      end = math.min(total - 1, 4);
    }
    if (cur >= total - 2) {
      start = math.max(2, total - 3);
    }

    for (int i = start; i <= end; i++) {
      push(i);
    }

    if (cur < total - 2) {
      gap('r');
    }
    push(total);
    return items;
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _measureIndicator();
      }
    });
  }

  void _measureIndicator() {
    final BuildContext? pageContext =
        _pageKeys[widget.currentPage]?.currentContext;
    final BuildContext? rowContext = _rowKey.currentContext;
    if (pageContext == null || rowContext == null) {
      if (_indicator != null) {
        setState(() => _indicator = null);
      }
      return;
    }
    final RenderBox? pageBox = pageContext.findRenderObject() as RenderBox?;
    final RenderBox? rowBox = rowContext.findRenderObject() as RenderBox?;
    if (pageBox == null ||
        rowBox == null ||
        !pageBox.hasSize ||
        !rowBox.hasSize) {
      return;
    }
    // KunButton's layout box is the padded tap target on phones; the web
    // measures the drawn control. The first RenderStack inside is that
    // drawn box.
    RenderBox measured = pageBox;
    RenderStack? drawn;
    void findStack(RenderObject child) {
      if (drawn != null) {
        return;
      }
      if (child is RenderStack) {
        drawn = child;
        return;
      }
      child.visitChildren(findStack);
    }

    pageBox.visitChildren(findStack);
    if (drawn != null && drawn!.hasSize) {
      measured = drawn!;
    }
    _reveal(pageBox);
    final Offset origin = measured.localToGlobal(Offset.zero, ancestor: rowBox);
    final Rect next = origin & measured.size;
    if (_indicator == next) {
      return;
    }
    setState(() => _indicator = next);
  }

  // Padded to the touch minimum, the buttons outgrow a phone's width where
  // the web's 32px ones fit, so the strip scrolls and keeps the current page
  // in view.
  void _reveal(RenderBox page) {
    final RenderObject? strip = _stripKey.currentContext?.findRenderObject();
    if (_revealedPage == widget.currentPage ||
        !_scroll.hasClients ||
        strip is! RenderBox) {
      return;
    }
    final ScrollPosition position = _scroll.position;
    if (position.maxScrollExtent <= 0) {
      return;
    }
    final double centre =
        page.localToGlobal(page.size.center(Offset.zero), ancestor: strip).dx;
    final double target = (centre - position.viewportDimension / 2)
        .clamp(0, position.maxScrollExtent);
    final Duration duration = kunMotion(context, KunDurations.fast);
    if (_revealedPage == null || duration == Duration.zero) {
      position.jumpTo(target);
    } else {
      position.animateTo(target, duration: duration, curve: KunEasing.standard);
    }
    _revealedPage = widget.currentPage;
  }

  void _change(int page) {
    if (widget.isLoading || page == widget.currentPage) {
      return;
    }
    if (widget.totalPage <= 0) {
      return;
    }
    widget.onCurrentPageChanged?.call(page);
  }

  void _jump() {
    if (widget.isLoading) {
      return;
    }
    // The web's parseInt reads the leading digits, so "2.5" is page 2.
    final int? page = int.tryParse(
      RegExp(r'^\s*\+?\d+').stringMatch(_jumpText)?.trim() ?? '',
    );
    if (page != null && page >= 1 && page <= widget.totalPage) {
      widget.onCurrentPageChanged?.call(page);
      setState(() => _jumpText = '');
    }
  }

  // The web pages from any element that does not own the arrows, and leaves
  // the key to that element as well. This handler runs before the focused
  // widget sees the key, so paging from anywhere would take the arrows from a
  // date grid or any app widget that no role marks: it pages only while
  // nothing has focus, or focus is on this pagination's own buttons. A route
  // pushed on top keeps this page mounted, so it also stops paging then.
  bool _ownsArrowKeys() {
    if (!(_route?.isCurrent ?? true)) {
      return false;
    }
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus is FocusScopeNode) {
      return true;
    }
    if (_jumpFocus.hasFocus) {
      return false;
    }
    return focus.context?.findAncestorStateOfType<_KunPaginationState>() ==
        this;
  }

  bool _onGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent || widget.isLoading || !_ownsArrowKeys()) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (widget.currentPage > 1) {
        _change(widget.currentPage - 1);
        return true;
      }
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (widget.currentPage < widget.totalPage) {
        _change(widget.currentPage + 1);
        return true;
      }
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final KunMessages messages = KunMessagesScope.of(context);
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final Color onSolid = scheme.primary.onSolid;
    final List<_PageItem> items = _displayedPages();
    final bool showIndicator = _hasMounted && _indicator != null;
    final Duration slide = kunMotion(context, KunDurations.fast);

    if (_hasMounted) {
      _scheduleMeasure();
    }

    final Widget prev = KunButton(
      key: const ValueKey<String>('KunPagination.prev'),
      isIconOnly: true,
      variant: KunUIVariant.light,
      size: KunUISize.sm,
      semanticLabel: messages.pagination.prev,
      disabled: widget.isLoading || widget.currentPage <= 1,
      onPressed: () => _change(widget.currentPage - 1),
      child: const Icon(KunIcons.chevronLeft),
    );
    final Widget next = KunButton(
      key: const ValueKey<String>('KunPagination.next'),
      isIconOnly: true,
      variant: KunUIVariant.light,
      size: KunUISize.sm,
      semanticLabel: messages.pagination.next,
      disabled: widget.isLoading || widget.currentPage >= widget.totalPage,
      onPressed: () => _change(widget.currentPage + 1),
      child: const Icon(KunIcons.chevronRight),
    );

    final Widget numbers = Stack(
      key: _rowKey,
      clipBehavior: Clip.none,
      children: <Widget>[
        if (showIndicator)
          AnimatedPositioned(
            duration: slide,
            curve: KunEasing.standard,
            left: _indicator!.left,
            top: _indicator!.top,
            width: _indicator!.width,
            height: _indicator!.height,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: _PagePop(
                  key: ValueKey<int>(_popKey),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary.solid,
                      borderRadius: BorderRadius.circular(KunRadius.md),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit,
          children: <Widget>[
            for (final _PageItem item in items)
              if (item.page != null)
                Semantics(
                  selected: widget.currentPage == item.page ? true : null,
                  button: true,
                  enabled: !widget.isLoading,
                  label: messages.pagination.page(page: item.page!),
                  onTap: widget.isLoading ? null : () => _change(item.page!),
                  child: ExcludeSemantics(
                    child: KunButton(
                      key: _keyFor(item.page!),
                      variant: widget.currentPage == item.page && !showIndicator
                          ? KunUIVariant.solid
                          : KunUIVariant.light,
                      size: KunUISize.sm,
                      disabled: widget.isLoading,
                      onPressed: () => _change(item.page!),
                      child: Text(
                        '${item.page}',
                        style: widget.currentPage == item.page && showIndicator
                            ? TextStyle(color: onSolid)
                            : null,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  key: ValueKey<String>(item.key),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KunSpacing.unit * 2,
                  ),
                  child: const Text('...'),
                ),
          ],
        ),
      ],
    );

    final Widget hint = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 2,
      children: <Widget>[
        Text(
          messages.pagination.hintBefore,
          style: KunText.sm.copyWith(color: scheme.foregroundMuted),
        ),
        Icon(
          KunIcons.arrowLeft,
          size: KunText.sm.fontSize,
          color: scheme.foregroundMuted,
        ),
        Icon(
          KunIcons.arrowRight,
          size: KunText.sm.fontSize,
          color: scheme.foregroundMuted,
        ),
        Text(
          messages.pagination.hintAfter,
          style: KunText.sm.copyWith(color: scheme.foregroundMuted),
        ),
      ],
    );

    final Widget jump = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 2,
      children: <Widget>[
        MergeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: KunSpacing.unit * 2,
            children: <Widget>[
              Text(messages.pagination.jumpLabel, style: KunText.sm),
              SizedBox(
                width: KunSpacing.unit * 24,
                child: KunInput(
                  key: const ValueKey<String>('KunPagination.jump'),
                  focusNode: _jumpFocus,
                  value: _jumpText,
                  type: KunInputType.number,
                  size: KunUISize.sm,
                  disabled: widget.isLoading,
                  textInputAction: TextInputAction.go,
                  onChanged: (String value) =>
                      setState(() => _jumpText = value),
                  onSubmitted: (_) => _jump(),
                ),
              ),
            ],
          ),
        ),
        KunButton(
          key: const ValueKey<String>('KunPagination.go'),
          size: KunUISize.sm,
          disabled: widget.isLoading,
          onPressed: _jump,
          child: Text(messages.pagination.jump),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool showHint = !constraints.maxWidth.isFinite ||
            constraints.maxWidth >= KunTheme.of(context).breakpoints.sm;
        return Semantics(
          container: true,
          explicitChildNodes: true,
          role: SemanticsRole.navigation,
          label: messages.pagination.nav,
          child: SizedBox(
            width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
            child: Wrap(
              spacing: KunSpacing.unit * 4,
              runSpacing: KunSpacing.unit * 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Wrap(
                  spacing: KunSpacing.unit * 2,
                  runSpacing: KunSpacing.unit * 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        scrollbars: false,
                        overscroll: false,
                      ),
                      child: SingleChildScrollView(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          key: _stripKey,
                          mainAxisSize: MainAxisSize.min,
                          spacing: KunSpacing.unit * 2,
                          children: <Widget>[prev, numbers, next],
                        ),
                      ),
                    ),
                    if (showHint) hint,
                  ],
                ),
                jump,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PagePop extends StatefulWidget {
  const _PagePop({required this.child, super.key});

  final Widget child;

  @override
  State<_PagePop> createState() => _PagePopState();
}

class _PagePopState extends State<_PagePop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: KunDurations.slow);
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 1.1),
        weight: 38,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.1, end: 0.98),
        weight: 30,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.98, end: 1),
        weight: 32,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: KunEasing.standard));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = kunMotion(context, KunDurations.slow);
    if (!_started) {
      _started = true;
      if (kunReducedMotion(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
