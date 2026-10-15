import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/anchored.dart';
import '../foundation/design.dart';
import '../foundation/dismiss_layers.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'command_palette.dart';
import 'command_results.dart';
import 'command_shortcuts.dart';
import 'input.dart';
import 'kbd.dart';
import 'spinner.dart';

/// The web's `offset: 4` between the field and its panel.
/// CommandSearch.vue `useKunFloating(..., { offset: 4 })`.
const double _kPanelOffset = 4;

/// Lower bound on the panel's width, CommandSearch.vue `MIN_PANEL_WIDTH`.
const double _kMinPanelWidth = 360;

/// Upper bound on the panel's height, CommandSearch.vue `maxHeight` default.
const double _kPanelMaxHeight = 420;

/// An always-visible search field whose results open in a panel under it.
///
/// The shell does not search: feed it [items] computed from [query]. The
/// panel is not a dialog; focus never leaves the field. Selecting or
/// submitting closes the panel and unfocuses the field.
class KunCommandSearch extends StatefulWidget {
  /// Creates a command search field.
  const KunCommandSearch({
    super.key,
    this.items = const <KunCommandGroup>[],
    this.query = '',
    this.onQueryChanged,
    this.loading = false,
    this.placeholder,
    this.noResultText,
    this.shortcut = KunCommandShortcut.modK,
    this.highlight = true,
    this.size = KunUISize.md,
    this.rounded,
    this.maxHeight = _kPanelMaxHeight,
    this.semanticLabel,
    this.onSelected,
    this.onSubmitted,
    this.onRemoved,
    this.itemBuilder,
    this.loadingBuilder,
    this.noResult,
    this.empty,
    this.footer,
    this.focusNode,
  });

  /// Results to show under the field: a flat list is one unlabelled
  /// [KunCommandGroup], the same shape [KunCommandPalette.items] takes.
  /// With an empty [query] these are what focus shows (recent searches,
  /// say). The field does no matching itself.
  final List<KunCommandGroup> items;

  /// The field's text (web `query`).
  final String query;

  /// Called on every edit (web `update:query`).
  final ValueChanged<String>? onQueryChanged;

  /// Async search in flight: the field's search icon becomes a spinner.
  /// With no rows to show, the panel shows a loading state instead of the
  /// no-result text; rows already showing stay until new ones arrive.
  final bool loading;

  /// Placeholder in the field; also its accessible name when
  /// [semanticLabel] is unset. Null uses the locale catalog.
  final String? placeholder;

  /// Shown when [query] is non-empty but there are no results. Null uses
  /// the locale catalog.
  final String? noResultText;

  /// Shortcut that focuses the field from anywhere.
  /// [KunCommandShortcut.modK] is the default; [KunCommandShortcut.none]
  /// disables it.
  final KunCommandShortcut shortcut;

  /// Highlight the query terms in the default item render.
  final bool highlight;

  /// Field size. The web's `size`.
  final KunUISize size;

  /// Corner radius of the field; the panel follows it. Null uses the
  /// theme's.
  final KunUIRounded? rounded;

  /// Upper bound on the panel's height in px. The panel is also never
  /// taller than the room below the field.
  final double maxHeight;

  /// Accessible name for the field (web `ariaLabel`).
  final String? semanticLabel;

  /// The row the user clicked, or highlighted with the arrow keys and
  /// confirmed with Enter. A disabled row never emits.
  final ValueChanged<KunCommandItem>? onSelected;

  /// Enter with no row highlighted, carrying the trimmed query.
  final ValueChanged<String>? onSubmitted;

  /// The remove button or Shift+Delete on a [KunCommandItem.removable]
  /// row. Drop the item from [items]; the highlight stays on the row that
  /// takes its place.
  final ValueChanged<KunCommandItem>? onRemoved;

  /// Custom row. The default paints the icon, section, highlighted label
  /// and description.
  final Widget Function(
    BuildContext context,
    KunCommandItem item,
    bool active,
  )? itemBuilder;

  /// Replaces the loading copy.
  final Widget? loadingBuilder;

  /// Replaces the no-result copy. The second argument is the trimmed query.
  final Widget Function(BuildContext context, String query)? noResult;

  /// Shown when the field is open, the query is empty, nothing is loading
  /// and there are no rows.
  final Widget? empty;

  /// Drawn below the scrolling list, inside the panel.
  final Widget? footer;

  /// Optional [FocusNode] for the field, the counterpart of the web's
  /// exposed `focus()`.
  final FocusNode? focusNode;

  @override
  State<KunCommandSearch> createState() => _KunCommandSearchState();
}

class _KunCommandSearchState extends State<KunCommandSearch>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final Object _tapGroup = Object();
  final GlobalKey _fieldKey = GlobalKey(debugLabel: 'KunCommandSearch.field');
  final ScrollController _listScroll = ScrollController();
  final Map<int, GlobalKey> _rowKeys = <int, GlobalKey>{};
  final TextEditingController _controller = TextEditingController();

  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;
  late final AnimationController _openClose;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;

  bool _isOpen = false;
  int _activeIndex = -1;
  int? _hoveredIndex;
  ({Object key, int index})? _removed;
  KunCommandShortcutRegistration? _shortcutRegistration;
  final ValueNotifier<KunAnchorResolution> _resolved =
      ValueNotifier<KunAnchorResolution>(
    const KunAnchorResolution(side: KunAnchorSide.bottom, arrowCross: 0),
  );

  List<KunCommandRowGroup> get _groups => kunCommandToRows(widget.items);
  List<KunCommandItem> get _flat => kunCommandFlat(_groups);
  bool get _hasResults => _flat.isNotEmpty;
  String get _trimmed => _controller.text.trim();

  bool get _shown =>
      _isOpen &&
      (widget.loading ||
          _hasResults ||
          _trimmed.isNotEmpty ||
          widget.empty != null);

  bool get _isComposing {
    final TextRange composing = _controller.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode =
        widget.focusNode ?? FocusNode(debugLabel: 'KunCommandSearch.field');
    _focusNode.addListener(_onFocusNode);
    _controller.text = widget.query;
    _controller.addListener(_onControllerTick);
    _openClose = AnimationController(
      vsync: this,
      duration: KunDurations.base,
      reverseDuration: KunDurations.exit,
    );
    _curve = kunSurfaceCurve(_openClose);
    _scale = Tween<double>(begin: 0.95, end: 1).animate(_curve);
    _openClose.addListener(_hidePortalIfDismissed);
    _openClose.addStatusListener(_onOpenCloseStatus);
    _shortcutRegistration =
        KunCommandShortcutCoordinator.instance.registerSearch(
      shortcut: () => widget.shortcut,
      eligible: _eligibleForShortcut,
      activate: _activateFromShortcut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openClose.duration = kunMotion(context, KunDurations.base);
    _openClose.reverseDuration = kunMotion(context, KunDurations.exit);
  }

  @override
  void didUpdateWidget(KunCommandSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text && !_isComposing) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
    if (widget.query != oldWidget.query) {
      _removed = null;
      _activeIndex = -1;
    }
    if (!_sameRows(oldWidget.items, widget.items)) {
      _applyItemsChanged();
    }
    if (_isOpen) {
      _syncPortal();
    }
  }

  @override
  void dispose() {
    _shortcutRegistration?.unregister();
    _shortcutRegistration = null;
    KunDismissLayers.remove(this);
    _openClose.removeListener(_hidePortalIfDismissed);
    _openClose.removeStatusListener(_onOpenCloseStatus);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _openClose.dispose();
    _curve.dispose();
    _listScroll.dispose();
    _resolved.dispose();
    _controller.removeListener(_onControllerTick);
    _controller.dispose();
    _focusNode.removeListener(_onFocusNode);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusNode() {
    if (!mounted) {
      return;
    }
    if (_focusNode.hasFocus) {
      _open();
    } else {
      _close();
    }
    setState(() {});
  }

  void _hidePortalIfDismissed() {
    if (!_isOpen && _openClose.value == 0 && _portal.isShowing) {
      _portal.hide();
    }
  }

  void _onOpenCloseStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !_isOpen && _portal.isShowing) {
      _portal.hide();
    }
  }

  bool _sameRows(List<KunCommandGroup> a, List<KunCommandGroup> b) {
    if (identical(a, b)) {
      return true;
    }
    final List<KunCommandItem> left = kunCommandFlat(kunCommandToRows(a));
    final List<KunCommandItem> right = kunCommandFlat(kunCommandToRows(b));
    if (left.length != right.length) {
      return false;
    }
    for (int i = 0; i < left.length; i++) {
      if (!identical(left[i], right[i])) {
        return false;
      }
    }
    return true;
  }

  void _onControllerTick() {
    if (mounted) {
      setState(() {});
    }
  }

  void _applyItemsChanged() {
    final ({Object key, int index})? removed = _removed;
    _removed = null;
    final List<KunCommandItem> list = _flat;
    final int i = removed != null &&
            !list.any(
              (KunCommandItem item) => item.resolvedValue == removed.key,
            )
        ? math.min(removed.index, list.length - 1)
        : -1;
    _activeIndex = i >= 0 && !list[i].disabled ? i : -1;
  }

  void _syncPortal() {
    if (_shown) {
      KunDismissLayers.add(this);
      if (!_portal.isShowing) {
        _portal.show();
      }
      _openClose.forward();
    } else if (_portal.isShowing || _openClose.value > 0) {
      KunDismissLayers.remove(this);
      _openClose.reverse();
    }
  }

  void _open() {
    if (_isOpen) {
      _syncPortal();
      return;
    }
    setState(() => _isOpen = true);
    _syncPortal();
  }

  void _close() {
    if (!_isOpen) {
      return;
    }
    KunDismissLayers.remove(this);
    setState(() {
      _isOpen = false;
      _activeIndex = -1;
      _hoveredIndex = null;
    });
    _openClose.reverse();
  }

  bool _eligibleForShortcut() {
    if (!mounted) {
      return false;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      return false;
    }
    if (!TickerMode.valuesOf(context).enabled) {
      return false;
    }
    final BuildContext? fieldContext = _fieldKey.currentContext;
    final RenderObject? obj = fieldContext?.findRenderObject();
    if (obj is! RenderBox || !obj.hasSize || obj.size.isEmpty) {
      return false;
    }
    RenderObject? node = obj;
    while (node != null) {
      if (node is RenderOffstage && node.offstage) {
        return false;
      }
      node = node.parent;
    }
    return true;
  }

  void _activateFromShortcut() {
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _open();
  }

  void _onInput(String text) {
    _removed = null;
    _activeIndex = -1;
    widget.onQueryChanged?.call(text);
    _open();
  }

  void _clear() {
    _controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    _removed = null;
    _activeIndex = -1;
    widget.onQueryChanged?.call('');
    _focusNode.requestFocus();
    _open();
  }

  void _select(KunCommandItem item) {
    if (item.disabled) {
      return;
    }
    widget.onSelected?.call(item);
    final String? href = item.href;
    if (href != null) {
      KunUIConfigScope.of(context).navigateTo(context, href);
    }
    _close();
    _focusNode.unfocus();
  }

  void _submit() {
    widget.onSubmitted?.call(_trimmed);
    _close();
    _focusNode.unfocus();
  }

  void _confirm() {
    final List<KunCommandItem> flat = _flat;
    if (_shown && _activeIndex >= 0 && _activeIndex < flat.length) {
      _select(flat[_activeIndex]);
      return;
    }
    if (_trimmed.isNotEmpty) {
      _submit();
    }
  }

  void _removeItem(KunCommandItem item, int index) {
    if (item.disabled) {
      return;
    }
    _removed = (key: item.resolvedValue, index: index);
    widget.onRemoved?.call(item);
  }

  void _onListExit() {
    _removed = null;
    setState(() {
      _activeIndex = -1;
      _hoveredIndex = null;
    });
  }

  void _move(int delta) {
    final List<KunCommandItem> flat = _flat;
    final int n = flat.length;
    if (n == 0) {
      return;
    }
    int i = _activeIndex;
    for (int step = 0; step <= n; step++) {
      i += delta;
      if (i >= n) {
        i = -1;
      } else if (i < -1) {
        i = n - 1;
      }
      if (i == -1 || !flat[i].disabled) {
        setState(() => _activeIndex = i);
        if (i >= 0) {
          _scrollActiveIntoView();
        }
        return;
      }
    }
  }

  GlobalKey _rowKey(int index) => _rowKeys.putIfAbsent(index, GlobalKey.new);

  void _scrollActiveIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeIndex < 0) {
        return;
      }
      final BuildContext? row = _rowKey(_activeIndex).currentContext;
      if (row != null) {
        Scrollable.ensureVisible(
          row,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        Scrollable.ensureVisible(
          row,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (_isComposing) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        if (!_shown) {
          _open();
        } else {
          _move(1);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (!_shown) {
          _open();
        } else {
          _move(-1);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
        final List<KunCommandItem> flat = _flat;
        final KunCommandItem? row =
            _shown && _activeIndex >= 0 && _activeIndex < flat.length
                ? flat[_activeIndex]
                : null;
        if (row != null) {
          _select(row);
          return KeyEventResult.handled;
        }
        if (_trimmed.isNotEmpty) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.escape:
        if (_shown) {
          _close();
          return KeyEventResult.handled;
        }
        if (_controller.text.isNotEmpty) {
          _controller.value = const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          );
          widget.onQueryChanged?.call('');
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.tab:
        _close();
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.delete:
        if (HardwareKeyboard.instance.isShiftPressed) {
          final List<KunCommandItem> flat = _flat;
          if (_shown && _activeIndex >= 0 && _activeIndex < flat.length) {
            final KunCommandItem row = flat[_activeIndex];
            if (row.removable) {
              _removeItem(row, _activeIndex);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  void _onFocusChange(bool focused) {
    if (focused) {
      _open();
      return;
    }
    _close();
  }

  void _onResolved(KunAnchorResolution resolution) {
    if (_resolved.value == resolution) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resolved.value = resolution;
      }
    });
  }

  String _statusText(KunCommandPaletteStrings strings) {
    if (!_shown) {
      return '';
    }
    if (_hasResults) {
      return _trimmed.isNotEmpty
          ? strings.resultCount(count: _flat.length)
          : '';
    }
    if (widget.loading) {
      return strings.loading;
    }
    return _trimmed.isNotEmpty ? (widget.noResultText ?? strings.noResult) : '';
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunUIRounded rounded = widget.rounded ?? theme.rounded;
    final double radius =
        (rounded == KunUIRounded.full ? KunUIRounded.lg : rounded).radius;
    final Rect anchor = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    final KunCommandPaletteStrings strings =
        KunMessagesScope.of(context).commandPalette;
    final List<KunCommandRowGroup> groups = _groups;
    final List<KunCommandItem> flat = _flat;
    final bool hasResults = flat.isNotEmpty;
    final String trimmed = _trimmed;
    final TextStyle muted = KunText.sm.copyWith(
      color: scheme.foregroundMuted,
    );

    Widget body;
    if (hasResults) {
      body = Semantics(
        key: const ValueKey<String>('KunCommandSearch.list'),
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.list,
        label: _fieldName(strings),
        child: KunCommandResults(
          groups: groups,
          activeIndex: _activeIndex,
          hoveredIndex: _hoveredIndex,
          query: _controller.text,
          highlight: widget.highlight,
          itemKeyPrefix: 'KunCommandSearch.item',
          rowKey: _rowKey,
          itemBuilder: widget.itemBuilder,
          onSelect: _select,
          onHover: (int index) {
            if (index >= 0 &&
                index < flat.length &&
                !flat[index].disabled &&
                _activeIndex != index) {
              setState(() => _activeIndex = index);
            }
          },
          onPointerEnter: (int index) {
            if (_hoveredIndex != index) {
              setState(() => _hoveredIndex = index);
            }
          },
          onPointerExit: (int index) {
            if (_hoveredIndex == index) {
              setState(() => _hoveredIndex = null);
            }
          },
          onRemove: _removeItem,
          onListExit: _onListExit,
        ),
      );
    } else if (widget.loading) {
      body = widget.loadingBuilder ??
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 3,
              vertical: KunSpacing.unit * 6,
            ),
            child: Center(
              child: Text(strings.loading, style: muted),
            ),
          );
    } else if (trimmed.isNotEmpty) {
      body = widget.noResult?.call(context, trimmed) ??
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 3,
              vertical: KunSpacing.unit * 6,
            ),
            child: Center(
              child: Text(
                widget.noResultText ?? strings.noResult,
                textAlign: TextAlign.center,
                style: muted,
              ),
            ),
          );
    } else {
      body = widget.empty ?? const SizedBox.shrink();
    }

    final Widget list = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        overscroll: false,
      ),
      child: SingleChildScrollView(
        controller: _listScroll,
        padding: const EdgeInsets.all(KunSpacing.unit * 1.5),
        child: body,
      ),
    );

    final Widget panel = DecoratedBox(
      key: const ValueKey<String>('KunCommandSearch.panel'),
      decoration: BoxDecoration(
        color: scheme.content1,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.border),
        boxShadow: KunShadows.md,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Flexible(child: list),
            if (widget.footer != null) widget.footer!,
          ],
        ),
      ),
    );

    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _KunCommandSearchListLayout(
          anchor: anchor,
          viewport: kunAnchorViewport(context, info.overlaySize),
          maxHeight: widget.maxHeight,
          onResolved: _onResolved,
        ),
        child: TextFieldTapRegion(
          child: TapRegion(
            groupId: _tapGroup,
            child: FadeTransition(
              opacity: _curve,
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[_scale, _resolved]),
                builder: (BuildContext context, Widget? child) =>
                    Transform.scale(
                  scale: _scale.value,
                  alignment: kunAnchorOrigin(
                    _resolved.value.side,
                    KunAnchorAlign.start,
                  ),
                  child: child,
                ),
                child: ExcludeFocus(child: panel),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fieldName(KunCommandPaletteStrings strings) {
    if (widget.semanticLabel != null && widget.semanticLabel!.isNotEmpty) {
      return widget.semanticLabel!;
    }
    return widget.placeholder ?? strings.placeholder;
  }

  Widget _prefix(KunColorScheme scheme) {
    final double size = KunText.base.fontSize ?? KunSpacing.unit * 4;
    if (widget.loading) {
      return ExcludeSemantics(
        child: KunSpinner(
          size: size,
          color: scheme.neutral.shade400,
        ),
      );
    }
    return ExcludeSemantics(
      child: Icon(
        KunIcons.search,
        size: size,
        color: scheme.neutral.shade400,
      ),
    );
  }

  Widget? _suffix(KunColorScheme scheme, KunCommandPaletteStrings strings) {
    if (_controller.text.isNotEmpty) {
      return _KunCommandSearchClear(
        scheme: scheme,
        label: strings.clear,
        onPressed: _clear,
      );
    }
    if (widget.shortcut != KunCommandShortcut.none && !_focusNode.hasFocus) {
      return ExcludeSemantics(
        child: IgnorePointer(
          child: KunKbd(keys: widget.shortcut.keys),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunCommandPaletteStrings strings =
        KunMessagesScope.of(context).commandPalette;
    final String placeholder = widget.placeholder ?? strings.placeholder;
    final String name = _fieldName(strings);
    final String status = _statusText(strings);

    final Widget field = KunInput(
      key: _fieldKey,
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _onInput,
      onSubmitted: (String _) {
        if (!_isComposing) {
          _confirm();
        }
      },
      placeholder: placeholder,
      size: widget.size,
      rounded: widget.rounded,
      textInputAction: TextInputAction.search,
      semanticLabel: name,
      expanded: _shown,
      prefix: _prefix(scheme),
      suffix: _suffix(scheme, strings),
    );

    final Widget named = Semantics(
      container: true,
      explicitChildNodes: true,
      child: Stack(
        children: <Widget>[
          Listener(
            onPointerDown: (_) => _open(),
            child: field,
          ),
          Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: Semantics(
                container: true,
                liveRegion: true,
                label: status,
                child: const SizedBox(width: 1, height: 1),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      child: PopScope(
        canPop: !_shown,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop && KunDismissLayers.isTop(this)) {
            _close();
          }
        },
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onKeyEvent: (FocusNode node, KeyEvent event) => _onKey(event),
          onFocusChange: _onFocusChange,
          child: TapRegion(
            groupId: _tapGroup,
            onTapOutside: (PointerDownEvent event) {
              if (_isOpen) {
                _close();
              }
            },
            child: OverlayPortal.overlayChildLayoutBuilder(
              controller: _portal,
              overlayLocation: OverlayChildLocation.rootOverlay,
              overlayChildBuilder: _buildOverlay,
              child: named,
            ),
          ),
        ),
      ),
    );
  }
}

/// Width `min(max(fieldWidth, 360), available)`; height capped at
/// [maxHeight] and the room the shared [KunAnchoredLayout] leaves after
/// its 8 px viewport padding, the web's `size({ padding: 8 })`.
class _KunCommandSearchListLayout extends KunAnchoredLayout {
  _KunCommandSearchListLayout({
    required super.anchor,
    required super.viewport,
    required this.maxHeight,
    required super.onResolved,
  }) : super(
          side: KunAnchorSide.bottom,
          align: KunAnchorAlign.start,
          offset: _kPanelOffset,
        );

  /// CommandSearch.vue `props.maxHeight`.
  final double maxHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final BoxConstraints shared = super.getConstraintsForChild(constraints);
    final double width = math.min(
      math.max(anchor.width, _kMinPanelWidth),
      shared.maxWidth,
    );
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.min(maxHeight, shared.maxHeight),
    );
  }
}

class _KunCommandSearchClear extends StatefulWidget {
  const _KunCommandSearchClear({
    required this.scheme,
    required this.label,
    required this.onPressed,
  });

  final KunColorScheme scheme;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_KunCommandSearchClear> createState() => _KunCommandSearchClearState();
}

class _KunCommandSearchClearState extends State<_KunCommandSearchClear> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      descendantsAreFocusable: false,
      child: Semantics(
        container: true,
        button: true,
        label: widget.label,
        onTap: widget.onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: widget.onPressed,
            child: Icon(
              KunIcons.circleX,
              size: KunSpacing.unit * 4,
              color: _hovered
                  ? widget.scheme.neutral.shade600
                  : widget.scheme.neutral.shade400,
            ),
          ),
        ),
      ),
    );
  }
}
