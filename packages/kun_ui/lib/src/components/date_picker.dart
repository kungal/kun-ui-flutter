import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/anchored.dart';
import '../foundation/calendar.dart';
import '../foundation/control_metrics.dart';
import '../foundation/design.dart';
import '../foundation/dismiss_layers.dart';
import '../foundation/field_ring.dart';
import '../foundation/focus_outline.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'button.dart';

export '../foundation/calendar.dart' show KunDatePickerPrecision, KunDateRange;

part 'date_picker_field.dart';
part 'date_picker_panel.dart';

/// Gap between the trigger and the panel (web `offset(4)`).
const double _kPanelOffset = 4;

/// Floor for the panel's width (web `minWidth: '260px'`).
const double _kPanelMinWidth = 260;

/// Opening scale of the panel (web `scale-95`).
const double _kPanelScaleFrom = 0.95;

/// One date or two. The contract's `KunDatePickerMode`.
enum KunDatePickerMode {
  /// One committed [DateTime], or null.
  single,

  /// A [KunDateRange] whose ends may be unset.
  range,
}

/// A date or date-range picker.
///
/// The value is controlled: pass [value] or [range] and rebuild with what
/// [onChanged] / [onRangeChanged] give you (the web's `v-model`).
///
/// The panel opens under the trigger and follows it through scrolling and
/// resizing. It is a portal, not a route, so it works inside a [KunModal]:
/// Escape and the system back gesture close the picker and leave the modal
/// open. A [fullWidth] `false` picker is as wide as its content.
class KunDatePicker extends StatefulWidget {
  /// A single-date picker: [value] is the chosen date, or null.
  const KunDatePicker({
    super.key,
    this.value,
    this.onChanged,
    this.precision = KunDatePickerPrecision.day,
    this.label,
    this.placeholder,
    this.error,
    this.disabled = false,
    this.clearable = true,
    this.format,
    this.size = KunUISize.md,
    this.color = KunUIColor.neutral,
    this.rounded,
    this.icon,
    this.fullWidth = true,
    this.minDate,
    this.maxDate,
    this.isDateDisabled,
    this.locale,
    this.weekdays,
    this.months,
  })  : mode = KunDatePickerMode.single,
        range = const KunDateRange(),
        onRangeChanged = null;

  /// A range picker: [range] holds the two ends, either of which may be
  /// unset (web `mode="range"`).
  const KunDatePicker.range({
    super.key,
    this.range = const KunDateRange(),
    this.onRangeChanged,
    this.precision = KunDatePickerPrecision.day,
    this.label,
    this.placeholder,
    this.error,
    this.disabled = false,
    this.clearable = true,
    this.format,
    this.size = KunUISize.md,
    this.color = KunUIColor.neutral,
    this.rounded,
    this.icon,
    this.fullWidth = true,
    this.minDate,
    this.maxDate,
    this.isDateDisabled,
    this.locale,
    this.weekdays,
    this.months,
  })  : mode = KunDatePickerMode.range,
        value = null,
        onChanged = null;

  /// Whether this is a [KunDatePicker.range].
  final KunDatePickerMode mode;

  /// The chosen date for the single constructor; null for
  /// [KunDatePicker.range].
  ///
  /// Read by its year / month / day fields only. The committed value is
  /// local midnight on the first day of the chosen period.
  final DateTime? value;

  /// Called when the single-choice value changes (web `update:modelValue`).
  final ValueChanged<DateTime?>? onChanged;

  /// The chosen ends for [KunDatePicker.range]; empty for the single
  /// constructor.
  final KunDateRange range;

  /// Called when the range changes (web `update:modelValue`).
  final ValueChanged<KunDateRange>? onRangeChanged;

  /// What one click commits: a day, a whole month, or a whole year.
  ///
  /// The panel opens on the matching grid. The value is local midnight on
  /// the first day of the period, so `month` emits `DateTime(y, m)` and
  /// `year` emits `DateTime(y)`.
  final KunDatePickerPrecision precision;

  /// Label above the field.
  final String? label;

  /// Shown on the trigger while nothing is selected. Null uses the locale
  /// default for [precision] (`placeholderDay` / `placeholderMonth` /
  /// `placeholderYear`).
  final String? placeholder;

  /// Error message below the field. Also turns the trigger's border and ring
  /// `danger`.
  final String? error;

  /// Blocks opening and dims the trigger.
  ///
  /// A null [onChanged] does not gray the picker out — the web separates
  /// looks from listeners.
  final bool disabled;

  /// Shows an × in the trigger that clears the value.
  ///
  /// The × is pointer-only and excluded from semantics. From the keyboard,
  /// Backspace or Delete on the focused trigger clears it, and the panel's
  /// Clear button is the path for a screen reader.
  final bool clearable;

  /// Pattern for the text shown in the trigger. Null or empty uses the
  /// default for [precision] (`yyyy-MM-dd` / `yyyy-MM` / `yyyy`).
  ///
  /// Formatted with the calendar locale: [locale], else
  /// [KunMessagesScope.of]'s [KunMessages.code]. `'zh-CN'` and `'ja'`
  /// match; anything else is English. Machine keys still use unlocalized
  /// `kunFormatDate`.
  ///
  /// Supported letters, as runs of the same letter:
  ///
  /// * `y` / `yy` / `yyy…` — year, unpadded / last two digits / padded
  /// * `M` `MM` `MMM` `MMMM` `MMMMM` (and `L…`) — month number or name
  /// * `d` `dd` — day of month
  /// * `do` — ordinal day
  /// * `E` `EE` `EEE` `EEEE` `EEEEE` `EEEEEE` — weekday
  /// * `P` `PP` `PPP` `PPPP` — the locale's localized date
  /// * `'…'` — literal text; `''` is a literal apostrophe
  ///
  /// Any other unquoted latin letter throws [ArgumentError].
  final String? format;

  /// Height, padding and font size — the shared form-control scale.
  final KunUISize size;

  /// Semantic color of the focus ring. The resting border and text stay
  /// neutral.
  final KunUIColor color;

  /// Corner radius. Left null it follows [KunThemeData.rounded]. `full`
  /// means a pill on the trigger; the panel falls back to `lg`.
  final KunUIRounded? rounded;

  /// Glyph before the value in the trigger. The trailing calendar glyph is
  /// the disclosure indicator and stays either way.
  final IconData? icon;

  /// Stretch the control to its container. Turn it off so the trigger
  /// shrinks to its own content; the wrapper shrink-wraps its widest child.
  final bool fullWidth;

  /// Inclusive lower bound. Read by its year / month / day fields only.
  final DateTime? minDate;

  /// Inclusive upper bound. Read by its year / month / day fields only.
  final DateTime? maxDate;

  /// Extra per-cell veto. Called with the first day of the period a cell
  /// covers — the day itself, the 1st of the month, or 1 January — so one
  /// predicate works at every [precision].
  final bool Function(DateTime date)? isDateDisabled;

  /// BCP 47 tag for the calendar grid (weekday and month names, and the
  /// full date each day cell announces). Null uses
  /// [KunMessagesScope.of]'s [KunMessages.code]. Only `'zh-CN'` and `'ja'`
  /// match; anything else, including `'ja-JP'`, falls to English.
  final String? locale;

  /// Short weekday headers, Sunday first. A shorter list is padded from
  /// the locale.
  final List<String>? weekdays;

  /// Full month names, also the source for the month grid's labels (the
  /// abbreviated form is used unless this overrides it). A shorter list is
  /// padded from the locale.
  final List<String>? months;

  @override
  State<KunDatePicker> createState() => _KunDatePickerState();
}

class _KunDatePickerState extends State<KunDatePicker>
    with TickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final FocusNode _triggerFocus =
      FocusNode(debugLabel: 'KunDatePicker.trigger');
  final FocusNode _titleFocus = FocusNode(debugLabel: 'KunDatePicker.title');
  final Object _tapGroup = Object();
  final GlobalKey _clearKey = GlobalKey();
  final ValueNotifier<KunAnchorResolution> _resolved =
      ValueNotifier<KunAnchorResolution>(
    const KunAnchorResolution(side: KunAnchorSide.bottom, arrowCross: 0),
  );

  late final AnimationController _openClose;
  late final CurvedAnimation _openCloseCurve;
  late final Animation<double> _panelScale;

  bool _isOpen = false;
  bool _showTriggerRing = false;
  bool _ringSuppressed = false;
  bool _triggerHadFocus = false;
  bool _clearHovered = false;
  late KunDatePickerPrecision _view;
  late DateTime _viewingDate;
  late DateTime _activeDate;
  DateTime? _tempRangeStart;
  DateTime? _hoveredDate;

  // DOM focus stays on the trigger while the arrows move `aria-activedescendant`,
  // so no cell ever matches :focus-visible and a sighted keyboard user saw
  // nothing move until the page turned. The active cell draws the focus ring
  // itself, after a key and not after a click, as React Aria's useOption shows a
  // virtually focused option focus-visible only under keyboard modality.
  bool _keyboardActive = false;

  bool get _isRange => widget.mode == KunDatePickerMode.range;

  DateTime? get _singleValue =>
      widget.value == null ? null : kunCalendarDate(widget.value!);

  DateTime? get _rangeStart =>
      widget.range.start == null ? null : kunCalendarDate(widget.range.start!);

  DateTime? get _rangeEnd =>
      widget.range.end == null ? null : kunCalendarDate(widget.range.end!);

  DateTime? get _anchorValue => _isRange ? _rangeStart : _singleValue;

  String get _resolvedFormat {
    final String? format = widget.format;
    if (format == null || format.isEmpty) {
      return kunDefaultDateFormat(widget.precision);
    }
    return format;
  }

  String _formatTrigger(BuildContext context, DateTime date) =>
      kunFormatDate(date, _resolvedFormat, _calendarLocale(context));

  String _displayTextOf(BuildContext context) {
    if (_isRange) {
      final DateTime? start = _rangeStart;
      final DateTime? end = _rangeEnd;
      if (start != null && end != null) {
        return '${_formatTrigger(context, start)} - ${_formatTrigger(context, end)}';
      }
      // A half-open range is not hypothetical: the first click of every
      // range selection emits a start and a null end. Rendering '' for it
      // left the trigger reading "nothing selected" and hid the ×.
      if (start != null) {
        return '${_formatTrigger(context, start)} -';
      }
      if (end != null) {
        return '- ${_formatTrigger(context, end)}';
      }
      return '';
    }
    final DateTime? value = _singleValue;
    return value == null ? '' : _formatTrigger(context, value);
  }

  String _resolvedPlaceholder(BuildContext context) {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }
    final KunDatePickerStrings strings =
        KunMessagesScope.of(context).datePicker;
    return switch (widget.precision) {
      KunDatePickerPrecision.day => strings.placeholderDay,
      KunDatePickerPrecision.month => strings.placeholderMonth,
      KunDatePickerPrecision.year => strings.placeholderYear,
    };
  }

  KunCalendarLocale _calendarLocale(BuildContext context) {
    return kunResolveCalendarLocale(
      widget.locale ?? KunMessagesScope.of(context).code,
    );
  }

  bool get _canZoomOut => _view != KunDatePickerPrecision.year;

  String get _headerLabel {
    if (_view == KunDatePickerPrecision.year) {
      return kunDecadeLabel(_viewingDate.year);
    }
    if (_view == KunDatePickerPrecision.month) {
      return '${_viewingDate.year}';
    }
    return '${_viewingDate.year} / ${_viewingDate.month}';
  }

  String _stepUnit(BuildContext context) {
    final KunDatePickerStrings strings =
        KunMessagesScope.of(context).datePicker;
    return switch (_view) {
      KunDatePickerPrecision.day => strings.unitMonth,
      KunDatePickerPrecision.month => strings.unitYear,
      KunDatePickerPrecision.year => strings.unitDecade,
    };
  }

  bool get _isTodayDisabled {
    final DateTime today = kunCalendarDate(DateTime.now());
    return kunIsPeriodDisabled(
      start: today,
      end: today,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      isDateDisabled: widget.isDateDisabled,
    );
  }

  String get _activeKey {
    if (_view == KunDatePickerPrecision.year) {
      return '${_activeDate.year}';
    }
    return kunFormatDate(
      _activeDate,
      _view == KunDatePickerPrecision.month ? 'yyyy-MM' : 'yyyy-MM-dd',
      KunCalendarLocale.en,
    );
  }

  bool _activeCellDisabled(BuildContext context) {
    final KunCalendarLocale locale = _calendarLocale(context);
    if (_view == KunDatePickerPrecision.day) {
      return kunDayGrid(
        viewingDate: _viewingDate,
        isRange: _isRange,
        selected: _singleValue,
        rangeStart: _rangeStart,
        rangeEnd: _rangeEnd,
        minDate: widget.minDate,
        maxDate: widget.maxDate,
        isDateDisabled: widget.isDateDisabled,
      ).any((KunCalendarDayCell c) => c.key == _activeKey && c.isDisabled);
    }
    if (_view == KunDatePickerPrecision.month) {
      return kunMonthGrid(
        year: _viewingDate.year,
        locale: locale,
        isRange: _isRange,
        selected: _singleValue,
        rangeStart: _rangeStart,
        rangeEnd: _rangeEnd,
        minDate: widget.minDate,
        maxDate: widget.maxDate,
        isDateDisabled: widget.isDateDisabled,
        months: widget.months,
      ).any((KunCalendarPeriodCell c) => c.key == _activeKey && c.isDisabled);
    }
    return kunYearGrid(
      viewingYear: _viewingDate.year,
      isRange: _isRange,
      selected: _singleValue,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      isDateDisabled: widget.isDateDisabled,
    ).any((KunCalendarPeriodCell c) => c.key == _activeKey && c.isDisabled);
  }

  @override
  void initState() {
    super.initState();
    _view = widget.precision;
    _viewingDate = _anchorValue ?? kunCalendarDate(DateTime.now());
    _activeDate = _viewingDate;
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
    _panelScale = Tween<double>(begin: _kPanelScaleFrom, end: 1).animate(
      _openCloseCurve,
    );
    _openClose.addListener(_hidePortalIfDismissed);
    _triggerFocus
      ..canRequestFocus = !widget.disabled
      ..addListener(_handleTriggerFocus);
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openClose.duration = kunMotion(context, KunDurations.base);
    _openClose.reverseDuration = kunMotion(context, KunDurations.exit);
  }

  @override
  void didUpdateWidget(KunDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _triggerFocus.canRequestFocus = !widget.disabled;
    if (widget.disabled && _isOpen) {
      _close(returnFocus: false);
    }
    if (oldWidget.precision != widget.precision) {
      // The page has to follow the view. Without this the grid rendered
      // whatever page viewingDate was left on while activeDate pointed at
      // a cell that page does not contain.
      setState(() {
        _view = widget.precision;
        _viewingDate = _activeDate;
      });
    }
  }

  @override
  void dispose() {
    KunDismissLayers.remove(this);
    _openClose.removeListener(_hidePortalIfDismissed);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _openClose.dispose();
    _openCloseCurve.dispose();
    _triggerFocus.removeListener(_handleTriggerFocus);
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _triggerFocus.dispose();
    _titleFocus.dispose();
    _resolved.dispose();
    super.dispose();
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

  void _onPanelPointerDown() {
    _setRingSuppressed(true);
    if (_keyboardActive) {
      setState(() => _keyboardActive = false);
    }
  }

  void _setViewingDate(DateTime date) {
    setState(() {
      _viewingDate = date;
      _activeDate = date;
    });
  }

  void _restoreTriggerFocusIfOrphaned() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isOpen) {
        return;
      }
      if (_triggerFocus.hasFocus) {
        return;
      }
      final FocusNode? primary = FocusManager.instance.primaryFocus;
      if (primary == null ||
          primary.context == null ||
          !primary.canRequestFocus ||
          primary is FocusScopeNode) {
        _triggerFocus.requestFocus();
      }
    });
  }

  void _open({bool fromKey = false}) {
    if (widget.disabled || _isOpen) {
      return;
    }
    KunDismissLayers.add(this);
    setState(() {
      _isOpen = true;
      _view = widget.precision;
      // Re-anchor on the value, not on wherever the last session wandered.
      final DateTime? anchor = _anchorValue;
      if (anchor != null) {
        _viewingDate = anchor;
        _activeDate = anchor;
      }
      _hoveredDate = null;
      if (fromKey) {
        _keyboardActive = true;
      }
    });
    if (!_portal.isShowing) {
      _portal.show();
    }
    _openClose.forward();
    if (kunReducedMotion(context)) {
      _openClose.value = 1;
    }
  }

  void _close({bool returnFocus = true}) {
    if (!_isOpen) {
      return;
    }
    KunDismissLayers.remove(this);
    setState(() {
      _isOpen = false;
      _hoveredDate = null;
      _keyboardActive = false;
    });
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

  void _clear() {
    if (widget.disabled) {
      return;
    }
    // Without this the half-picked start survived 清空 and the NEXT click
    // closed a range around it: pick Sep 10, clear, click Sep 20, and the
    // model came back as that pair.
    _tempRangeStart = null;
    if (_isRange) {
      widget.onRangeChanged?.call(const KunDateRange());
    } else {
      widget.onChanged?.call(null);
    }
  }

  // The web's `-m-1.5 p-1.5` gives the × 6px of hit area on each side and
  // no layout. A hit-test override on the × itself never saw those points:
  // every box between it and the trigger is the glyph's size and rejected
  // them first. So the trigger, which does contain them, decides.
  bool _hitsClear(Offset global) {
    final RenderObject? box = _clearKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return false;
    }
    final Rect rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    return rect.inflate(KunSpacing.unit * 1.5).contains(global);
  }

  void _setClearHovered(bool value) {
    if (_clearHovered == value) {
      return;
    }
    setState(() => _clearHovered = value);
  }

  void _zoomOut() {
    if (!_canZoomOut) {
      return;
    }
    setState(() {
      _view = _view == KunDatePickerPrecision.day
          ? KunDatePickerPrecision.month
          : KunDatePickerPrecision.year;
    });
    _restoreTriggerFocusIfOrphaned();
  }

  void _stepPage(int direction) {
    if (_view == KunDatePickerPrecision.day) {
      _setViewingDate(kunAddMonths(_viewingDate, direction));
    } else if (_view == KunDatePickerPrecision.month) {
      _setViewingDate(kunAddYears(_viewingDate, direction));
    } else {
      _setViewingDate(kunAddYears(_viewingDate, direction * 10));
    }
    _restoreTriggerFocusIfOrphaned();
  }

  void _navigateYear(int direction) {
    _setViewingDate(kunAddYears(_viewingDate, direction));
    _restoreTriggerFocusIfOrphaned();
  }

  void _moveActive(int step, String axis) {
    final int rows = _view == KunDatePickerPrecision.day ? 7 : 3;
    final DateTime next = kunStepPeriod(
      _activeDate,
      _view,
      axis == 'x' ? step : step * rows,
    );
    final bool leftPage = switch (_view) {
      KunDatePickerPrecision.day =>
        next.month != _viewingDate.month || next.year != _viewingDate.year,
      KunDatePickerPrecision.month => next.year != _viewingDate.year,
      KunDatePickerPrecision.year =>
        kunDecadeStart(next.year) != kunDecadeStart(_viewingDate.year),
    };
    setState(() {
      _keyboardActive = true;
      _activeDate = next;
      if (leftPage) {
        _viewingDate = next;
      }
    });
  }

  void _handleCellSelect(DateTime date) {
    if (_view != widget.precision) {
      setState(() {
        _viewingDate = date;
        _activeDate = date;
        _view = _view == KunDatePickerPrecision.year
            ? KunDatePickerPrecision.month
            : KunDatePickerPrecision.day;
      });
      _restoreTriggerFocusIfOrphaned();
      return;
    }
    _handleDateSelect(date);
  }

  void _handleDateSelect(DateTime date) {
    final KunCalendarPick pick = kunSelectDate(
      input: date,
      precision: widget.precision,
      isRange: _isRange,
      tempRangeStart: _tempRangeStart,
      currentEnd: _rangeEnd,
    );
    _tempRangeStart = pick.tempRangeStart;
    if (_isRange) {
      widget.onRangeChanged?.call(pick.range ?? const KunDateRange());
      if (pick.range?.end != null) {
        _close();
      }
    } else {
      widget.onChanged?.call(pick.single);
      _close();
    }
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is KeyDownEvent && !kunIsModifierKey(event.logicalKey)) {
      _setRingSuppressed(false);
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (widget.disabled) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if ((key == LogicalKeyboardKey.backspace ||
            key == LogicalKeyboardKey.delete) &&
        _triggerFocus.hasPrimaryFocus) {
      if (widget.clearable && _displayTextOf(context).isNotEmpty) {
        _clear();
      }
      return KeyEventResult.handled;
    }
    if (!_isOpen) {
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.space) {
        _open(fromKey: true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveActive(-1, 'x');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _moveActive(1, 'x');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveActive(-1, 'y');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveActive(1, 'y');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      // Enter and Space stay with whatever button holds focus — stealing
      // them here would page the calendar AND commit a date.
      if (!_triggerFocus.hasPrimaryFocus) {
        return KeyEventResult.ignored;
      }
      if (!_activeCellDisabled(context)) {
        _handleCellSelect(_activeDate);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onResolved(KunAnchorResolution resolution) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resolved.value = resolution;
      }
    });
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final Rect triggerRect = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    return Positioned.fill(
      child: TapRegion(
        groupId: _tapGroup,
        child: TextFieldTapRegion(
          child: CustomSingleChildLayout(
            delegate: KunAnchoredLayout(
              anchor: triggerRect,
              viewport: kunAnchorViewport(context, info.overlaySize),
              side: KunAnchorSide.bottom,
              align: KunAnchorAlign.start,
              offset: _kPanelOffset,
              padding: kKunAnchorPadding,
              capSize: true,
              minWidth: _kPanelMinWidth,
              onResolved: _onResolved,
            ),
            child: FadeTransition(
              key: const ValueKey<String>('KunDatePicker.panelFade'),
              opacity: _openCloseCurve,
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  _openCloseCurve,
                  _resolved,
                ]),
                builder: (BuildContext context, Widget? child) {
                  return Transform.scale(
                    key: const ValueKey<String>('KunDatePicker.panelScale'),
                    scale: _panelScale.value,
                    alignment: kunAnchorOrigin(
                      _resolved.value.side,
                      KunAnchorAlign.start,
                    ),
                    child: child,
                  );
                },
                child: _KunDatePickerPanel(state: this),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget trigger = _KunDatePickerTrigger(state: this);
    return PopScope(
      canPop: !_isOpen,
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
        onFocusChange: (bool focused) {
          if (!focused) {
            _setRingSuppressed(false);
          }
        },
        child: _KunDatePickerField(
          state: this,
          trigger: OverlayPortal.overlayChildLayoutBuilder(
            controller: _portal,
            overlayLocation: OverlayChildLocation.rootOverlay,
            overlayChildBuilder: _buildOverlay,
            child: trigger,
          ),
        ),
      ),
    );
  }
}
