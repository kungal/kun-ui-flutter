import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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

/// How long the highlight leads before the window shifts (web `PHASE_MS`).
const Duration _kPhase = Duration(milliseconds: 150);

/// The highlight's slide (web `.kun-page-indicator` transition, 150ms).
const Duration _kSlide = Duration(milliseconds: 150);

/// The highlight's pop (web `kun-page-pop`, 340ms).
const Duration _kPop = Duration(milliseconds: 340);

/// How long staying numbers FLIP to their new slots (web `.kun-page-num-move`).
const Duration _kMove = Duration(milliseconds: 150);

/// How long an entering number fades in (web `.kun-page-num-enter-active`).
const Duration _kEnter = Duration(milliseconds: 150);

/// How long a leaving number fades out (web `.kun-page-num-leave-active`).
const Duration _kLeave = Duration(milliseconds: 120);

String _pageNumId(Widget child) => (child.key! as ValueKey<String>).value;

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
  final GlobalKey _numsKey = GlobalKey(debugLabel: 'KunPagination.nums');
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
        _phaseTimer = Timer(kunMotion(context, _kPhase), () {
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
    // localToGlobal follows the FLIP paint shift; the web reads offsetLeft
    // (the settled slot) so the pill slides in lockstep with the numbers.
    final RenderObject? nums = _numsKey.currentContext?.findRenderObject();
    final Offset flipShift =
        nums is _RenderPageNumRow ? nums.paintShiftOf(measured) : Offset.zero;
    _reveal(pageBox, flipShift);
    final Offset origin =
        measured.localToGlobal(Offset.zero, ancestor: rowBox) - flipShift;
    final Rect next = origin & measured.size;
    if (_indicator == next) {
      return;
    }
    setState(() => _indicator = next);
  }

  // Padded to the touch minimum, the buttons outgrow a phone's width where
  // the web's 32px ones fit, so the strip scrolls and keeps the current page
  // in view.
  void _reveal(RenderBox page, Offset flipShift) {
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
        page.localToGlobal(page.size.center(Offset.zero), ancestor: strip).dx -
            flipShift.dx;
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
    final Duration slide = kunMotion(context, _kSlide);

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
        _PageNumRow(
          key: _numsKey,
          gap: KunSpacing.unit,
          moveDuration: kunMotion(context, _kMove),
          enterDuration: kunMotion(context, _kEnter),
          leaveDuration: kunMotion(context, _kLeave),
          children: <Widget>[
            for (final _PageItem item in items)
              KeyedSubtree(
                key: ValueKey<String>(item.key),
                child: item.page != null
                    ? Semantics(
                        selected: widget.currentPage == item.page ? true : null,
                        button: true,
                        enabled: !widget.isLoading,
                        label: messages.pagination.page(page: item.page!),
                        onTap:
                            widget.isLoading ? null : () => _change(item.page!),
                        child: ExcludeSemantics(
                          child: KunButton(
                            key: _keyFor(item.page!),
                            variant: widget.currentPage == item.page &&
                                    !showIndicator
                                ? KunUIVariant.solid
                                : KunUIVariant.light,
                            size: KunUISize.sm,
                            disabled: widget.isLoading,
                            onPressed: () => _change(item.page!),
                            child: Text(
                              '${item.page}',
                              style: widget.currentPage == item.page &&
                                      showIndicator
                                  ? TextStyle(color: onSolid)
                                  : null,
                            ),
                          ),
                        ),
                      )
                    : Padding(
                        key: ValueKey<String>(item.key),
                        padding: const EdgeInsets.symmetric(
                          horizontal: KunSpacing.unit * 2,
                        ),
                        child: const Text('...'),
                      ),
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
    _controller = AnimationController(vsync: this, duration: _kPop);
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
    _controller.duration = kunMotion(context, _kPop);
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

class _NumEntry {
  _NumEntry({required this.id, required this.widget});

  final String id;
  Widget widget;
  bool leaving = false;
  Offset shiftFrom = Offset.zero;
  double opacityFrom = 1;
  double opacityTo = 1;

  Offset shiftAt(Duration elapsed, Duration move) {
    if (shiftFrom == Offset.zero || move == Duration.zero) {
      return Offset.zero;
    }
    final double t =
        (elapsed.inMicroseconds / move.inMicroseconds).clamp(0.0, 1.0);
    return Offset.lerp(
      shiftFrom,
      Offset.zero,
      KunEasing.standard.transform(t),
    )!;
  }

  double opacityAt(Duration elapsed, Duration leave, Duration enter) {
    if (opacityFrom == opacityTo) {
      return opacityTo;
    }
    final Duration duration = leaving ? leave : enter;
    if (duration == Duration.zero) {
      return opacityTo;
    }
    final double t =
        (elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
    return opacityFrom +
        (opacityTo - opacityFrom) * KunEasing.standard.transform(t);
  }
}

// Vue TransitionGroup: in-flow is the settled window, leaving items take no
// space, and the FLIP is a paint-only shift so the pill still measures the
// slot — putting the shift in layout offset made it track a mid-move number.
class _PageNumRow extends StatefulWidget {
  const _PageNumRow({
    required this.gap,
    required this.moveDuration,
    required this.enterDuration,
    required this.leaveDuration,
    required this.children,
    super.key,
  });

  final double gap;
  final Duration moveDuration;
  final Duration enterDuration;
  final Duration leaveDuration;
  final List<Widget> children;

  @override
  State<_PageNumRow> createState() => _PageNumRowState();
}

class _PageNumRowState extends State<_PageNumRow>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_NumEntry> _entries = <_NumEntry>[];
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _replace(widget.children);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PageNumRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<String> nextIds = <String>[
      for (final Widget child in widget.children) _pageNumId(child),
    ];
    final List<String> flowIds = <String>[
      for (final _NumEntry entry in _entries)
        if (!entry.leaving) entry.id,
    ];
    if (listEquals(flowIds, nextIds)) {
      final Map<String, Widget> next = <String, Widget>{
        for (final Widget child in widget.children) _pageNumId(child): child,
      };
      for (final _NumEntry entry in _entries) {
        final Widget? child = next[entry.id];
        if (child != null) {
          entry.widget = child;
        }
      }
      if (_jumps && _entries.any((_NumEntry entry) => entry.leaving)) {
        _jumpToRest();
      }
      return;
    }
    _flipTo(widget.children);
  }

  bool get _jumps =>
      widget.moveDuration == Duration.zero &&
      widget.enterDuration == Duration.zero &&
      widget.leaveDuration == Duration.zero;

  void _replace(List<Widget> children) {
    _entries
      ..clear()
      ..addAll(<_NumEntry>[
        for (final Widget child in children)
          _NumEntry(id: _pageNumId(child), widget: child),
      ]);
  }

  void _jumpToRest() {
    _ticker.stop();
    _elapsed = Duration.zero;
    _entries.removeWhere((_NumEntry entry) => entry.leaving);
    for (final _NumEntry entry in _entries) {
      entry.shiftFrom = Offset.zero;
      entry.opacityFrom = 1;
      entry.opacityTo = 1;
      entry.leaving = false;
    }
  }

  void _flipTo(List<Widget> children) {
    final _RenderPageNumRow? render =
        context.findRenderObject() as _RenderPageNumRow?;
    final Map<String, Offset> first =
        render?.visualPositions() ?? <String, Offset>{};
    final Map<String, Widget> nextById = <String, Widget>{
      for (final Widget child in children) _pageNumId(child): child,
    };
    final Map<String, _NumEntry> oldById = <String, _NumEntry>{
      for (final _NumEntry entry in _entries) entry.id: entry,
    };
    final bool jump = _jumps;
    final List<_NumEntry> next = <_NumEntry>[];
    for (final Widget child in children) {
      final String id = _pageNumId(child);
      final _NumEntry? old = oldById[id];
      if (old != null) {
        old.widget = child;
        old.leaving = false;
        old.opacityFrom = jump
            ? 1
            : old.opacityAt(
                _elapsed,
                widget.leaveDuration,
                widget.enterDuration,
              );
        old.opacityTo = 1;
        next.add(old);
      } else {
        next.add(
          _NumEntry(id: id, widget: child)
            ..opacityFrom = jump ? 1 : 0
            ..opacityTo = 1,
        );
      }
    }
    if (!jump) {
      for (final _NumEntry old in _entries) {
        if (nextById.containsKey(old.id)) {
          continue;
        }
        old.leaving = true;
        old.opacityFrom = old.opacityAt(
          _elapsed,
          widget.leaveDuration,
          widget.enterDuration,
        );
        old.opacityTo = 0;
        old.shiftFrom = Offset.zero;
        next.add(old);
      }
    }
    _entries
      ..clear()
      ..addAll(next);
    _elapsed = Duration.zero;
    _ticker.stop();
    if (jump) {
      render?.pendingFirst = null;
      for (final _NumEntry entry in _entries) {
        entry.shiftFrom = Offset.zero;
        entry.opacityFrom = entry.opacityTo;
      }
      return;
    }
    render?.pendingFirst = first;
    _ticker.start();
  }

  void _onInverted(Map<String, Offset> shifts) {
    for (final _NumEntry entry in _entries) {
      entry.shiftFrom =
          entry.leaving ? Offset.zero : (shifts[entry.id] ?? Offset.zero);
    }
  }

  void _tick(Duration elapsed) {
    if (!mounted) {
      return;
    }
    _elapsed = elapsed;
    final bool dropLeavers = elapsed >= widget.leaveDuration &&
        _entries.any((_NumEntry entry) => entry.leaving);
    setState(() {
      if (dropLeavers) {
        _entries.removeWhere((_NumEntry entry) => entry.leaving);
      }
    });
    final bool motionDone = elapsed >= widget.moveDuration &&
        elapsed >= widget.enterDuration &&
        elapsed >= widget.leaveDuration;
    if (motionDone) {
      _ticker.stop();
      _elapsed = Duration.zero;
      for (final _NumEntry entry in _entries) {
        entry.shiftFrom = Offset.zero;
        entry.opacityFrom = entry.opacityTo;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageNumTree(
      gap: widget.gap,
      textDirection: Directionality.of(context),
      onInverted: _onInverted,
      children: <Widget>[
        for (final _NumEntry entry in _entries)
          _PageNumSlot(
            key: ValueKey<String>(entry.id),
            id: entry.id,
            leaving: entry.leaving,
            shift: entry.shiftAt(_elapsed, widget.moveDuration),
            child: Opacity(
              opacity: entry.opacityAt(
                _elapsed,
                widget.leaveDuration,
                widget.enterDuration,
              ),
              child: IgnorePointer(
                ignoring: entry.leaving,
                child: ExcludeSemantics(
                  excluding: entry.leaving,
                  child: entry.widget,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PageNumParentData extends ContainerBoxParentData<RenderBox> {
  String id = '';
  bool leaving = false;
  Offset shift = Offset.zero;
}

class _PageNumSlot extends ParentDataWidget<_PageNumParentData> {
  const _PageNumSlot({
    required this.id,
    required this.leaving,
    required this.shift,
    required super.child,
    super.key,
  });

  final String id;
  final bool leaving;
  final Offset shift;

  @override
  void applyParentData(RenderObject renderObject) {
    final _PageNumParentData data =
        renderObject.parentData! as _PageNumParentData;
    bool needsLayout = false;
    bool needsPaint = false;
    if (data.id != id) {
      data.id = id;
      needsPaint = true;
    }
    if (data.leaving != leaving) {
      data.leaving = leaving;
      needsLayout = true;
    }
    if (data.shift != shift) {
      data.shift = shift;
      needsPaint = true;
    }
    if (needsLayout || needsPaint) {
      final RenderObject? parent = renderObject.parent;
      if (parent is RenderObject) {
        if (needsLayout) {
          parent.markNeedsLayout();
        }
        if (needsPaint) {
          parent.markNeedsPaint();
        }
      }
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _PageNumTree;
}

class _PageNumTree extends MultiChildRenderObjectWidget {
  const _PageNumTree({
    required this.gap,
    required this.textDirection,
    required this.onInverted,
    required super.children,
  });

  final double gap;
  final TextDirection textDirection;
  final ValueChanged<Map<String, Offset>> onInverted;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPageNumRow(
      gap: gap,
      textDirection: textDirection,
      onInverted: onInverted,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderPageNumRow renderObject,
  ) {
    renderObject
      ..gap = gap
      ..textDirection = textDirection
      ..onInverted = onInverted;
  }
}

class _RenderPageNumRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PageNumParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PageNumParentData> {
  _RenderPageNumRow({
    required double gap,
    required TextDirection textDirection,
    required this.onInverted,
  })  : _gap = gap,
        _textDirection = textDirection;

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (_gap == value) {
      return;
    }
    _gap = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  ValueChanged<Map<String, Offset>> onInverted;
  Map<String, Offset>? pendingFirst;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PageNumParentData) {
      child.parentData = _PageNumParentData();
    }
  }

  Map<String, Offset> visualPositions() {
    final Map<String, Offset> positions = <String, Offset>{};
    RenderBox? child = firstChild;
    while (child != null) {
      final _PageNumParentData data = child.parentData! as _PageNumParentData;
      if (data.id.isNotEmpty) {
        positions[data.id] = data.offset + data.shift;
      }
      child = childAfter(child);
    }
    return positions;
  }

  Offset paintShiftOf(RenderObject descendant) {
    RenderObject node = descendant;
    while (true) {
      final RenderObject? parent = node.parent;
      if (parent == null) {
        return Offset.zero;
      }
      if (parent == this) {
        final ParentData? data = node.parentData;
        if (data is _PageNumParentData) {
          return data.shift;
        }
        return Offset.zero;
      }
      node = parent;
    }
  }

  @override
  void performLayout() {
    final List<RenderBox> flow = <RenderBox>[];
    final List<RenderBox> gone = <RenderBox>[];
    RenderBox? child = firstChild;
    while (child != null) {
      final _PageNumParentData data = child.parentData! as _PageNumParentData;
      child.layout(constraints.loosen(), parentUsesSize: true);
      if (data.leaving) {
        gone.add(child);
      } else {
        flow.add(child);
      }
      child = childAfter(child);
    }

    double width = 0;
    double height = 0;
    for (final RenderBox box in flow) {
      height = math.max(height, box.size.height);
      width += box.size.width;
    }
    if (flow.isNotEmpty) {
      width += gap * (flow.length - 1);
    }
    size = constraints.constrain(Size(width, height));

    if (textDirection == TextDirection.ltr) {
      double x = 0;
      for (final RenderBox box in flow) {
        final _PageNumParentData data = box.parentData! as _PageNumParentData;
        data.offset = Offset(x, (size.height - box.size.height) / 2);
        x += box.size.width + gap;
      }
    } else {
      double x = size.width;
      for (final RenderBox box in flow) {
        x -= box.size.width;
        final _PageNumParentData data = box.parentData! as _PageNumParentData;
        data.offset = Offset(x, (size.height - box.size.height) / 2);
        x -= gap;
      }
    }

    if (pendingFirst != null) {
      final Map<String, Offset> first = pendingFirst!;
      pendingFirst = null;
      final Map<String, Offset> shifts = <String, Offset>{};
      for (final RenderBox box in flow) {
        final _PageNumParentData data = box.parentData! as _PageNumParentData;
        final Offset? origin = first[data.id];
        data.shift = origin == null ? Offset.zero : origin - data.offset;
        shifts[data.id] = data.shift;
      }
      for (final RenderBox box in gone) {
        final _PageNumParentData data = box.parentData! as _PageNumParentData;
        data.offset = first[data.id] ?? data.offset;
        data.shift = Offset.zero;
        shifts[data.id] = Offset.zero;
      }
      onInverted(shifts);
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    double width = 0;
    double height = 0;
    int n = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final _PageNumParentData data = child.parentData! as _PageNumParentData;
      if (!data.leaving) {
        final Size childSize = child.getDryLayout(constraints.loosen());
        height = math.max(height, childSize.height);
        width += childSize.width;
        n++;
      }
      child = childAfter(child);
    }
    if (n > 0) {
      width += gap * (n - 1);
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    double sum = 0;
    int n = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final _PageNumParentData data = child.parentData! as _PageNumParentData;
      if (!data.leaving) {
        sum += child.getMinIntrinsicWidth(height);
        n++;
      }
      child = childAfter(child);
    }
    return n == 0 ? 0 : sum + gap * (n - 1);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    double sum = 0;
    int n = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final _PageNumParentData data = child.parentData! as _PageNumParentData;
      if (!data.leaving) {
        sum += child.getMaxIntrinsicWidth(height);
        n++;
      }
      child = childAfter(child);
    }
    return n == 0 ? 0 : sum + gap * (n - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    double maxH = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final _PageNumParentData data = child.parentData! as _PageNumParentData;
      if (!data.leaving) {
        maxH = math.max(maxH, child.getMinIntrinsicHeight(double.infinity));
      }
      child = childAfter(child);
    }
    return maxH;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    double maxH = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final _PageNumParentData data = child.parentData! as _PageNumParentData;
      if (!data.leaving) {
        maxH = math.max(maxH, child.getMaxIntrinsicHeight(double.infinity));
      }
      child = childAfter(child);
    }
    return maxH;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    while (child != null) {
      final _PageNumParentData data = child.parentData! as _PageNumParentData;
      context.paintChild(child, offset + data.offset + data.shift);
      child = childAfter(child);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final _PageNumParentData data = child.parentData! as _PageNumParentData;
    final Offset origin = data.offset + data.shift;
    transform.translateByDouble(origin.dx, origin.dy, 0, 1);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      final _PageNumParentData data = child.parentData! as _PageNumParentData;
      if (!data.leaving) {
        final bool isHit = result.addWithPaintOffset(
          offset: data.offset + data.shift,
          position: position,
          hitTest: (BoxHitTestResult result, Offset transformed) {
            return child!.hitTest(result, position: transformed);
          },
        );
        if (isHit) {
          return true;
        }
      }
      child = childBefore(child);
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    RenderBox? child = firstChild;
    while (child != null) {
      final _PageNumParentData data = child.parentData! as _PageNumParentData;
      if (!data.leaving) {
        visitor(child);
      }
      child = childAfter(child);
    }
  }
}
