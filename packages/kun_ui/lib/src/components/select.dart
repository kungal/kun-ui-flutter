import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/control_metrics.dart';
import '../foundation/design.dart';
import '../foundation/field_ring.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'spinner.dart';

part 'select_field.dart';
part 'select_popup.dart';

/// Gap between the trigger and the popup (floating-ui `offset(4)`).
const double _kPopupOffset = 4;

/// Viewport margin the popup must keep (floating-ui `shift({ padding: 8 })`).
const double _kViewportPadding = 8;

/// Height cap on the popup (web `min(280, availableHeight - 8)`).
const double _kPopupMaxHeight = 280;

/// Opening scale of the popup (web `scale-95`).
const double _kPopupScaleFrom = 0.95;

/// Type-ahead buffer reset after the last character (web 600ms).
const Duration _kTypeaheadReset = Duration(milliseconds: 600);

/// Untranslated ARIA fallback when neither [KunSelect.semanticLabel] nor
/// [KunSelect.label] is set (web `aria-label="select"`).
const String _kSelectFallbackLabel = 'select';

/// Web type `KunSelectOption`. Not final: an app subclasses it to carry its own
/// fields and reads them back in [KunSelect.optionBuilder].
@immutable
class KunSelectOption<T> {
  /// Creates an option.
  const KunSelectOption({
    required this.value,
    required this.label,
    this.disabled = false,
  });

  /// The value reported through [KunSelect.onChanged] / [KunSelect.onSet].
  final T value;

  /// The text shown on the trigger, chips and default option row.
  final String label;

  /// Dims the row and blocks selecting it.
  final bool disabled;
}

/// Web type `KunSelectPopupWidth`.
sealed class KunSelectPopupWidth {
  /// Creates a popup-width mode.
  const KunSelectPopupWidth();

  /// Exactly the trigger's width (the default).
  static const KunSelectPopupWidth trigger = _KunSelectPopupWidthTrigger();

  /// The content's width, at least the trigger's.
  static const KunSelectPopupWidth auto = _KunSelectPopupWidthAuto();

  /// A fixed width.
  const factory KunSelectPopupWidth.fixed(double width) =
      _KunSelectPopupWidthFixed;
}

final class _KunSelectPopupWidthTrigger extends KunSelectPopupWidth {
  const _KunSelectPopupWidthTrigger();
}

final class _KunSelectPopupWidthAuto extends KunSelectPopupWidth {
  const _KunSelectPopupWidthAuto();
}

final class _KunSelectPopupWidthFixed extends KunSelectPopupWidth {
  const _KunSelectPopupWidthFixed(this.width);
  final double width;
}

/// Builds one option row's content (web slot `option`).
typedef KunSelectOptionBuilder<O> = Widget Function(
  BuildContext context,
  O option,
  int index,
  bool active,
  bool selected,
);

/// A single- or multiple-choice select.
///
/// The value is controlled: pass [value] or [values] and rebuild with what
/// [onChanged] / [onValuesChanged] give you (the web's `v-model`).
///
/// The popup opens under the trigger and follows it through scrolling and
/// resizing. It is a portal, not a route, so it works inside a [KunModal]:
/// Escape closes the popup and leaves the modal open. A [fullWidth] `false`
/// select is as wide as its content.
class KunSelect<T, O extends KunSelectOption<T>> extends StatefulWidget {
  /// A single-choice select: [value] is the chosen option's value, or null.
  const KunSelect({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.onSet,
    this.onSearch,
    this.optionBuilder,
    this.label,
    this.placeholder,
    this.description,
    this.error,
    this.semanticLabel,
    this.icon,
    this.color = KunUIColor.neutral,
    this.size = KunUISize.md,
    this.rounded,
    this.disabled = false,
    this.clearable = false,
    this.fullWidth = true,
    this.searchable = false,
    this.manualFilter = false,
    this.loading = false,
    this.debounce = Duration.zero,
    this.searchPlaceholder,
    this.noResultText,
    this.loadingText,
    this.popupWidth = KunSelectPopupWidth.trigger,
  })  : values = const [],
        onValuesChanged = null,
        multiple = false,
        maxVisibleTags = null;

  /// A multiple-choice select: [values] are the chosen values, in the order
  /// they were picked (web `multiple`).
  const KunSelect.multiple({
    super.key,
    required this.options,
    required this.values,
    this.onValuesChanged,
    this.maxVisibleTags,
    this.onSet,
    this.onSearch,
    this.optionBuilder,
    this.label,
    this.placeholder,
    this.description,
    this.error,
    this.semanticLabel,
    this.icon,
    this.color = KunUIColor.neutral,
    this.size = KunUISize.md,
    this.rounded,
    this.disabled = false,
    this.clearable = false,
    this.fullWidth = true,
    this.searchable = false,
    this.manualFilter = false,
    this.loading = false,
    this.debounce = Duration.zero,
    this.searchPlaceholder,
    this.noResultText,
    this.loadingText,
    this.popupWidth = KunSelectPopupWidth.trigger,
  })  : value = null,
        onChanged = null,
        multiple = true;

  /// The options to show (and to filter, unless [manualFilter]).
  final List<O> options;

  /// The chosen value for the single constructor; null for [KunSelect.multiple].
  final T? value;

  /// The chosen values for [KunSelect.multiple], in pick order; empty for the
  /// single constructor.
  final List<T> values;

  /// Called when the single-choice value changes (web `update:modelValue`).
  final ValueChanged<T?>? onChanged;

  /// Called when the multiple-choice values change (web `update:modelValue`).
  final ValueChanged<List<T>>? onValuesChanged;

  /// Whether this is a [KunSelect.multiple].
  final bool multiple;

  /// How many chips a multiple trigger renders before collapsing the rest into
  /// a `+N` chip. Null renders every chip. [KunSelect.multiple] only.
  final int? maxVisibleTags;

  /// The option the user just picked and its index in [options] (web `set`).
  final void Function(T value, int index)? onSet;

  /// The filter text, delayed by [debounce] (web `search`).
  final ValueChanged<String>? onSearch;

  /// Custom option-row content (web slot `option`).
  final KunSelectOptionBuilder<O>? optionBuilder;

  /// Label above the field.
  final String? label;

  /// Shown on the trigger while nothing is selected.
  final String? placeholder;

  /// Helper text below the field. Hidden while [error] is set.
  final String? description;

  /// Error message below the field. Also turns the trigger's border and ring
  /// `danger`.
  final String? error;

  /// Accessible name of the trigger (web `ariaLabel`).
  final String? semanticLabel;

  /// Glyph before the value in the trigger.
  final IconData? icon;

  /// Semantic color of the focus ring.
  final KunUIColor color;

  /// Height, padding and font size — the shared form-control scale.
  final KunUISize size;

  /// Corner radius. Left null it follows [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// Blocks opening and dims the trigger.
  final bool disabled;

  /// Shows a button that clears the selection.
  final bool clearable;

  /// Stretch the control to its container. Turn it off so the trigger shrinks
  /// to its own content; the wrapper shrink-wraps its widest child.
  final bool fullWidth;

  /// Render a filter field at the top of the list.
  final bool searchable;

  /// Skip the built-in label filter — the parent owns [options] and drives
  /// them from [onSearch].
  final bool manualFilter;

  /// Show a spinner in the list instead of options or [noResultText].
  final bool loading;

  /// Delay [onSearch] by this duration. Zero (the default) emits at once.
  final Duration debounce;

  /// Placeholder in the in-panel search box. Null uses
  /// [KunMessages.select.searchPlaceholder].
  final String? searchPlaceholder;

  /// Shown when the filter matches nothing. Null uses
  /// [KunMessages.select.noResult].
  final String? noResultText;

  /// Text under the loading spinner. Null uses [KunMessages.select.loading].
  final String? loadingText;

  /// How wide the popup is.
  final KunSelectPopupWidth popupWidth;

  @override
  State<KunSelect<T, O>> createState() => _KunSelectState<T, O>();
}

class _KunSelectState<T, O extends KunSelectOption<T>>
    extends State<KunSelect<T, O>> with TickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final FocusNode _triggerFocus = FocusNode(debugLabel: 'KunSelect.trigger');
  final FocusNode _searchFocus = FocusNode(debugLabel: 'KunSelect.search');
  final TextEditingController _searchController = TextEditingController();
  final Object _tapGroup = Object();
  final List<GlobalKey> _rowKeys = <GlobalKey>[];

  late final AnimationController _openClose;
  late final CurvedAnimation _openCloseCurve;
  late final Animation<double> _popupScale;

  Map<T, O> _optionCache = <T, O>{};
  bool _isOpen = false;
  bool _pending = false;
  bool _showTriggerRing = false;
  bool _ringSuppressed = false;
  bool _triggerHadFocus = false;
  bool _popupAbove = false;
  bool _absorbTriggerTap = false;
  String _query = '';
  int _activeIndex = -1;
  String _typeBuffer = '';
  Timer? _searchTimer;
  Timer? _typeTimer;

  List<T> get _selected {
    if (widget.multiple) {
      return widget.values;
    }
    final T? value = widget.value;
    return value == null ? const [] : <T>[value];
  }

  Set<T> get _selectedSet => _selected.toSet();

  bool get _hasSelection => _selected.isNotEmpty;

  bool get _showSpinner => widget.loading || _pending;

  bool get _imeComposing {
    final TextRange composing = _searchController.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  List<O> get _shown {
    if (!widget.searchable || widget.manualFilter || _query.trim().isEmpty) {
      return widget.options;
    }
    final String q = _query.trim().toLowerCase();
    return widget.options
        .where((O o) => o.label.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _openClose = AnimationController(
      vsync: this,
      duration: KunDurations.base,
      reverseDuration: KunDurations.exit,
    );
    _openCloseCurve = CurvedAnimation(
      parent: _openClose,
      curve: KunEasing.enter,
      reverseCurve: KunEasing.exit,
    );
    _popupScale = Tween<double>(begin: _kPopupScaleFrom, end: 1).animate(
      _openCloseCurve,
    );
    _openClose.addStatusListener(_onOpenCloseStatus);
    // OverlayPortal.hide() from the dismissed status alone left the
    // popup mounted after pumping KunDurations.exit — the tick is the
    // moment the controller value is actually 0.
    _openClose.addListener(_hidePortalIfDismissed);
    _triggerFocus
      ..addListener(_handleTriggerFocus)
      ..onKeyEvent = (FocusNode node, KeyEvent event) => _onKey(event);
    _searchFocus.onKeyEvent = (FocusNode node, KeyEvent event) => _onKey(event);
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
    _searchController.addListener(_onSearchController);
    _syncCache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openClose.duration = kunMotion(context, KunDurations.base);
    _openClose.reverseDuration = kunMotion(context, KunDurations.exit);
  }

  @override
  void didUpdateWidget(KunSelect<T, O> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _triggerFocus.canRequestFocus = !widget.disabled;
    if (widget.disabled && _isOpen) {
      _close(returnFocus: false);
    }
    _syncCache();
    if (_isOpen) {
      _repairActive();
    }
  }

  @override
  void dispose() {
    _cancelPendingSearch();
    _typeTimer?.cancel();
    _openClose.removeStatusListener(_onOpenCloseStatus);
    _openClose.removeListener(_hidePortalIfDismissed);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _openClose.dispose();
    _openCloseCurve.dispose();
    _triggerFocus.removeListener(_handleTriggerFocus);
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _triggerFocus.dispose();
    _searchFocus.dispose();
    _searchController.removeListener(_onSearchController);
    _searchController.dispose();
    super.dispose();
  }

  void _onOpenCloseStatus(AnimationStatus status) {
    _hidePortalIfDismissed();
  }

  void _hidePortalIfDismissed() {
    if (_isOpen || _openClose.value > 0 || !_portal.isShowing) {
      return;
    }
    _portal.hide();
  }

  void _handleHighlightMode(FocusHighlightMode mode) {
    _syncTriggerPresentation();
  }

  void _handleTriggerFocus() {
    _syncTriggerPresentation();
  }

  bool _computeShowTriggerRing() {
    return !widget.disabled &&
        _triggerFocus.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional &&
        !_ringSuppressed;
  }

  void _syncTriggerPresentation() {
    final bool hasFocus = _triggerFocus.hasFocus;
    final bool show = _computeShowTriggerRing();
    if (hasFocus == _triggerHadFocus && show == _showTriggerRing) {
      return;
    }
    setState(() {
      _triggerHadFocus = hasFocus;
      _showTriggerRing = show;
    });
  }

  void _setRingSuppressed(bool value) {
    if (_ringSuppressed == value) {
      return;
    }
    _ringSuppressed = value;
    _syncTriggerPresentation();
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  void _setActiveIndex(int index) {
    if (_activeIndex == index) {
      return;
    }
    setState(() => _activeIndex = index);
  }

  void _onSearchController() {
    if (!_isOpen || !widget.searchable) {
      return;
    }
    if (_imeComposing) {
      return;
    }
    _applySearch(_searchController.text);
  }

  void _syncCache() {
    final Set<T> keep = _selectedSet;
    final Map<T, O> next = <T, O>{};
    for (final MapEntry<T, O> entry in _optionCache.entries) {
      if (keep.contains(entry.key)) {
        next[entry.key] = entry.value;
      }
    }
    for (final O option in widget.options) {
      if (keep.contains(option.value)) {
        next[option.value] = option;
      }
    }
    _optionCache = next;
  }

  O? _optionFor(T value) {
    for (final O option in widget.options) {
      if (option.value == value) {
        return option;
      }
    }
    return _optionCache[value];
  }

  String _labelFor(T value) => _optionFor(value)?.label ?? value.toString();

  List<({T value, String label})> get _selectedChips =>
      <({T value, String label})>[
        for (final T value in _selected)
          (value: value, label: _labelFor(value)),
      ];

  List<({T value, String label})> get _visibleTags {
    if (widget.maxVisibleTags == null) {
      return _selectedChips;
    }
    final int n = math.max(0, widget.maxVisibleTags!);
    return _selectedChips.take(n).toList();
  }

  int get _hiddenTagCount => _selected.length - _visibleTags.length;

  bool get _showsChips =>
      widget.multiple && _hasSelection && _visibleTags.isNotEmpty;

  String get _triggerText {
    if (!widget.multiple) {
      if (_hasSelection) {
        return _labelFor(_selected.first);
      }
      return widget.placeholder ?? '';
    }
    if (!_hasSelection) {
      return widget.placeholder ?? '';
    }
    final int n = _selected.length;
    final String? placeholder = widget.placeholder;
    if (placeholder != null && placeholder.isNotEmpty) {
      return '$placeholder · $n';
    }
    return '$n';
  }

  String _triggerSemanticLabel() {
    final String? semantic = widget.semanticLabel;
    if (semantic != null && semantic.isNotEmpty) {
      return semantic;
    }
    final String? label = widget.label;
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return _kSelectFallbackLabel;
  }

  int _firstEnabled({int from = 0, int dir = 1}) {
    final List<O> list = _shown;
    for (int i = from; i >= 0 && i < list.length; i += dir) {
      if (!list[i].disabled) {
        return i;
      }
    }
    return -1;
  }

  int _indexOfFirstSelected() {
    final Set<T> selected = _selectedSet;
    final List<O> list = _shown;
    for (int i = 0; i < list.length; i++) {
      if (selected.contains(list[i].value)) {
        return i;
      }
    }
    return -1;
  }

  void _repairActive() {
    if (!_isOpen) {
      return;
    }
    final List<O> list = _shown;
    if (_activeIndex < 0 ||
        _activeIndex >= list.length ||
        list[_activeIndex].disabled) {
      final int next = _firstEnabled();
      if (next != _activeIndex) {
        setState(() => _activeIndex = next);
      }
    }
  }

  void _ensureRowKeys(int length) {
    while (_rowKeys.length < length) {
      _rowKeys.add(GlobalKey());
    }
    if (_rowKeys.length > length) {
      _rowKeys.removeRange(length, _rowKeys.length);
    }
  }

  void _cancelPendingSearch() {
    _searchTimer?.cancel();
    _searchTimer = null;
    if (_pending) {
      _pending = false;
    }
  }

  void _emitSearch(String query, {bool immediate = false}) {
    _searchTimer?.cancel();
    _searchTimer = null;
    if (_pending) {
      setState(() => _pending = false);
    }
    if (!widget.searchable) {
      return;
    }
    if (immediate || widget.debounce <= Duration.zero) {
      widget.onSearch?.call(query);
      return;
    }
    setState(() => _pending = true);
    _searchTimer = Timer(widget.debounce, () {
      _searchTimer = null;
      if (!mounted) {
        return;
      }
      setState(() => _pending = false);
      widget.onSearch?.call(query);
    });
  }

  void _applySearch(String value) {
    if (value == _query) {
      return;
    }
    setState(() {
      _query = value;
      _activeIndex = _firstEnabled();
    });
    _emitSearch(value);
  }

  void _open() {
    if (widget.disabled || _isOpen) {
      return;
    }
    setState(() {
      _isOpen = true;
      _query = '';
      _pending = false;
      if (_searchController.text.isNotEmpty) {
        _searchController.value = TextEditingValue.empty;
      }
      final int selected = _indexOfFirstSelected();
      _activeIndex = selected >= 0 ? selected : _firstEnabled();
    });
    if (!_portal.isShowing) {
      _portal.show();
    }
    _openClose.forward();
    if (kunReducedMotion(context)) {
      _openClose.value = 1;
    }
    if (widget.searchable) {
      _emitSearch('', immediate: true);
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isOpen) {
        return;
      }
      if (widget.searchable) {
        _searchFocus.requestFocus();
      }
      _ensureActiveVisible();
    });
  }

  void _close({bool returnFocus = true}) {
    if (!_isOpen) {
      return;
    }
    setState(() {
      _isOpen = false;
      _query = '';
      if (_searchController.text.isNotEmpty) {
        _searchController.value = TextEditingValue.empty;
      }
    });
    _cancelPendingSearch();
    _typeTimer?.cancel();
    _typeBuffer = '';
    if (kunReducedMotion(context)) {
      _openClose.value = 0;
    } else {
      _openClose.reverse();
    }
    _hidePortalIfDismissed();
    if (returnFocus) {
      _triggerFocus.requestFocus();
    }
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _selectOption(O option) {
    if (widget.disabled || option.disabled) {
      return;
    }
    final int origIndex =
        widget.options.indexWhere((O o) => o.value == option.value);
    if (widget.multiple) {
      final List<T> cur = List<T>.of(widget.values);
      final int at = cur.indexWhere((T v) => v == option.value);
      if (at >= 0) {
        cur.removeAt(at);
      } else {
        cur.add(option.value);
      }
      widget.onValuesChanged?.call(cur);
      if (widget.searchable) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isOpen) {
            _searchFocus.requestFocus();
          }
        });
      }
    } else {
      widget.onChanged?.call(option.value);
      _close();
    }
    widget.onSet?.call(option.value, origIndex);
  }

  void _selectActive() {
    if (_showSpinner) {
      return;
    }
    final List<O> list = _shown;
    if (_activeIndex < 0 || _activeIndex >= list.length) {
      return;
    }
    _selectOption(list[_activeIndex]);
  }

  void _removeValue(T value) {
    if (widget.disabled || !widget.multiple) {
      return;
    }
    widget.onValuesChanged?.call(
      widget.values.where((T v) => v != value).toList(),
    );
  }

  void _clearAll() {
    if (widget.disabled) {
      return;
    }
    if (widget.multiple) {
      widget.onValuesChanged?.call(<T>[]);
    } else {
      widget.onChanged?.call(null);
    }
  }

  void _ensureActiveVisible() {
    if (_showSpinner || _activeIndex < 0 || _activeIndex >= _rowKeys.length) {
      return;
    }
    final BuildContext? ctx = _rowKeys[_activeIndex].currentContext;
    if (ctx == null) {
      return;
    }
    final RenderObject? object = ctx.findRenderObject();
    if (object == null) {
      return;
    }
    // Scrollable.ensureVisible walks every ancestor Scrollable in the
    // element tree. OverlayPortal still inserts the overlay child under
    // the select, so a page SingleChildScrollView would be an ancestor
    // and the page would jump — the web bug scrollItemIntoView.ts
    // records. Only the list moves, and only enough to reveal the row.
    final ScrollableState? scrollable = Scrollable.maybeOf(ctx);
    final RenderAbstractViewport? viewport =
        RenderAbstractViewport.maybeOf(object);
    if (scrollable == null || viewport == null) {
      return;
    }
    final double leading = viewport.getOffsetToReveal(object, 0).offset;
    final double trailing = viewport.getOffsetToReveal(object, 1).offset;
    final double current = scrollable.position.pixels;
    final double target;
    if (current > leading && current > trailing) {
      target = math.max(leading, trailing);
    } else if (current < leading && current < trailing) {
      target = math.min(leading, trailing);
    } else {
      return;
    }
    scrollable.position.jumpTo(
      target.clamp(
        scrollable.position.minScrollExtent,
        scrollable.position.maxScrollExtent,
      ),
    );
  }

  void _moveActive(int dir) {
    if (_showSpinner) {
      return;
    }
    final List<O> list = _shown;
    final int n = list.length;
    if (n == 0) {
      return;
    }
    int i = _activeIndex;
    for (int step = 0; step < n; step++) {
      i = (i + dir + n) % n;
      if (!list[i].disabled) {
        setState(() => _activeIndex = i);
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _ensureActiveVisible();
          }
        });
        return;
      }
    }
  }

  void _setEdgeActive(int dir) {
    if (_showSpinner) {
      return;
    }
    final int next = dir == 1
        ? _firstEnabled()
        : _firstEnabled(from: _shown.length - 1, dir: -1);
    if (next == _activeIndex) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureActiveVisible();
        }
      });
      return;
    }
    setState(() => _activeIndex = next);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureActiveVisible();
      }
    });
  }

  void _typeahead(String char) {
    if (_showSpinner) {
      return;
    }
    _typeBuffer += char.toLowerCase();
    _typeTimer?.cancel();
    _typeTimer = Timer(_kTypeaheadReset, () => _typeBuffer = '');
    final int i = widget.options.indexWhere(
      (O o) => !o.disabled && o.label.toLowerCase().startsWith(_typeBuffer),
    );
    if (i >= 0) {
      setState(() => _activeIndex = i);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureActiveVisible();
        }
      });
    }
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is KeyDownEvent && !_isModifierKey(event.logicalKey)) {
      _setRingSuppressed(false);
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (widget.disabled) {
      return KeyEventResult.ignored;
    }
    if (widget.searchable && _imeComposing) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (!_isOpen) {
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.space) {
        _open();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveActive(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveActive(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _setEdgeActive(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _setEdgeActive(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _selectActive();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      if (!widget.searchable) {
        _selectActive();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _close();
      return KeyEventResult.handled;
    }
    if (!widget.searchable) {
      final String? character = event.character;
      if (character != null &&
          character.length == 1 &&
          !HardwareKeyboard.instance.isControlPressed &&
          !HardwareKeyboard.instance.isAltPressed &&
          !HardwareKeyboard.instance.isMetaPressed) {
        _typeahead(character);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Rect _viewportOf(BuildContext context, Size overlaySize) {
    final MediaQueryData view = MediaQueryData.fromView(View.of(context));
    return Rect.fromLTRB(
      math.max(view.viewPadding.left, view.viewInsets.left),
      math.max(view.viewPadding.top, view.viewInsets.top),
      overlaySize.width -
          math.max(view.viewPadding.right, view.viewInsets.right),
      overlaySize.height -
          math.max(view.viewPadding.bottom, view.viewInsets.bottom),
    );
  }

  double _measureTextWidth(BuildContext context, String text) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: KunText.sm),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }

  double _measureAutoContentWidth(BuildContext context) {
    final double em =
        MediaQuery.textScalerOf(context).scale(KunText.sm.fontSize!);
    final Set<T> selected = _selectedSet;
    double widest = 0;
    if (_showSpinner) {
      widest = _measureTextWidth(
            context,
            widget.loadingText ?? KunMessagesScope.of(context).select.loading,
          ) +
          KunSpacing.unit * 3 * 2;
    } else if (_shown.isEmpty) {
      widest = _measureTextWidth(
            context,
            widget.noResultText ?? KunMessagesScope.of(context).select.noResult,
          ) +
          KunSpacing.unit * 3 * 2;
    } else {
      for (final O option in _shown) {
        double row =
            _measureTextWidth(context, option.label) + KunSpacing.unit * 3 * 2;
        if (selected.contains(option.value)) {
          row += KunSpacing.unit * 2 + em;
        }
        widest = math.max(widest, row);
      }
    }
    if (widget.searchable) {
      final double searchFloor = 20 * _measureTextWidth(context, '0') +
          KunSpacing.unit * 2.5 * 2 +
          2 +
          KunSpacing.unit * 1 * 2;
      widest = math.max(widest, searchFloor);
    }
    return widest;
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final Rect triggerRect = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    final Rect viewport = _viewportOf(context, info.overlaySize);
    final double triggerWidth = triggerRect.width;
    final double viewportCap =
        math.max(0, viewport.width - _kViewportPadding * 2);
    final double width = switch (widget.popupWidth) {
      _KunSelectPopupWidthTrigger() => triggerWidth,
      _KunSelectPopupWidthAuto() => math.min(
          viewportCap,
          math.max(
            triggerWidth,
            _measureAutoContentWidth(context) + KunSpacing.unit * 1 * 2,
          ),
        ),
      _KunSelectPopupWidthFixed(:final double width) => math.min(
          viewportCap,
          width,
        ),
    };

    double left = triggerRect.left;
    if (width + _kViewportPadding * 2 <= viewport.width) {
      left = left.clamp(
        viewport.left + _kViewportPadding,
        viewport.right - _kViewportPadding - width,
      );
    }

    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _KunSelectPopupLayout(
          triggerRect: triggerRect,
          viewport: viewport,
          width: width,
          left: left,
          onSideChosen: (bool above) => _popupAbove = above,
        ),
        child: TapRegion(
          groupId: _tapGroup,
          child: TextFieldTapRegion(
            // A press on a non-focusable widget takes no focus. The only
            // thief is EditableText's tap-outside unfocus, and this
            // TextFieldTapRegion around the overlay child prevents it.
            child: FadeTransition(
              key: const ValueKey<String>('KunSelect.popupFade'),
              opacity: _openCloseCurve,
              child: AnimatedBuilder(
                animation: _openCloseCurve,
                builder: (BuildContext context, Widget? child) {
                  return Transform.scale(
                    key: const ValueKey<String>('KunSelect.popupScale'),
                    scale: _popupScale.value,
                    // First opening frame paints at opacity 0; alignment is
                    // correct from the next tick without a setState.
                    alignment:
                        _popupAbove ? Alignment.bottomLeft : Alignment.topLeft,
                    child: child,
                  );
                },
                child: _KunSelectPopup<T, O>(state: this),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureRowKeys(_showSpinner ? 0 : _shown.length);
    final Widget trigger = _KunSelectTrigger<T, O>(state: this);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: (FocusNode node, KeyEvent event) => _onKey(event),
      onFocusChange: (bool focused) {
        if (!focused) {
          _setRingSuppressed(false);
        }
      },
      child: _KunSelectField<T, O>(
        state: this,
        trigger: OverlayPortal.overlayChildLayoutBuilder(
          controller: _portal,
          overlayLocation: OverlayChildLocation.rootOverlay,
          overlayChildBuilder: _buildOverlay,
          child: trigger,
        ),
      ),
    );
  }
}

class _KunSelectPopupLayout extends SingleChildLayoutDelegate {
  _KunSelectPopupLayout({
    required this.triggerRect,
    required this.viewport,
    required this.width,
    required this.left,
    required this.onSideChosen,
  });

  final Rect triggerRect;
  final Rect viewport;
  final double width;
  final double left;
  final ValueChanged<bool> onSideChosen;

  double get _roomBelow => viewport.bottom - triggerRect.bottom - _kPopupOffset;

  double get _roomAbove => triggerRect.top - viewport.top - _kPopupOffset;

  double get _maxHeight => math.max(
        0,
        math.min(
          _kPopupMaxHeight,
          math.max(_roomBelow, _roomAbove) - _kViewportPadding,
        ),
      );

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: 0,
      maxHeight: _maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double h = childSize.height;
    final double roomBelow = _roomBelow;
    final double roomAbove = _roomAbove;
    final bool fitsBelow = h <= roomBelow - _kViewportPadding;
    final bool fitsAbove = h <= roomAbove - _kViewportPadding;
    final bool above;
    if (fitsBelow) {
      above = false;
    } else if (fitsAbove) {
      above = true;
    } else {
      above = roomAbove > roomBelow;
    }
    onSideChosen(above);
    final double top = above
        ? triggerRect.top - _kPopupOffset - h
        : triggerRect.bottom + _kPopupOffset;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _KunSelectPopupLayout oldDelegate) {
    return triggerRect != oldDelegate.triggerRect ||
        viewport != oldDelegate.viewport ||
        width != oldDelegate.width ||
        left != oldDelegate.left;
  }
}
