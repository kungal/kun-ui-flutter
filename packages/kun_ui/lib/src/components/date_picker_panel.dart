part of 'date_picker.dart';

class _KunDatePickerPanel extends StatelessWidget {
  const _KunDatePickerPanel({required this.state});

  final _KunDatePickerState state;

  @override
  Widget build(BuildContext context) {
    final KunDatePicker widget = state.widget;
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunUIRounded rounded = widget.rounded ?? theme.rounded;
    final double panelRadius =
        (rounded == KunUIRounded.full ? KunUIRounded.lg : rounded).radius;
    final KunDatePickerStrings strings =
        KunMessagesScope.of(context).datePicker;
    final KunCalendarLocale locale = state._calendarLocale(context);
    final List<String> weekdayLabels =
        kunWeekdayLabels(locale, widget.weekdays);

    return Listener(
      onPointerDown: (_) => state._setRingSuppressed(true),
      child: DecoratedBox(
        key: const ValueKey<String>('KunDatePicker.panel'),
        decoration: BoxDecoration(
          color: scheme.content1,
          borderRadius: BorderRadius.circular(panelRadius),
          boxShadow: KunShadows.md,
        ),
        child: Padding(
          padding: const EdgeInsets.all(KunSpacing.unit * 3),
          child: IntrinsicWidth(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, strings),
                  if (state._view == KunDatePickerPrecision.day) ...[
                    SizedBox(height: KunSpacing.unit * 3),
                    ExcludeSemantics(
                      child: Row(
                        children: [
                          for (final String day in weekdayLabels)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(KunSpacing.unit),
                                child: Text(
                                  day,
                                  textAlign: TextAlign.center,
                                  style: KunText.xs.copyWith(
                                    fontWeight: KunFontWeights.medium,
                                    color: scheme.neutral.shade600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: KunSpacing.unit),
                    _dayGrid(context, locale, scheme),
                  ] else ...[
                    SizedBox(height: KunSpacing.unit * 3),
                    _periodGrid(context, locale, scheme),
                  ],
                  SizedBox(height: KunSpacing.unit * 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.precision == KunDatePickerPrecision.day)
                        KunButton(
                          size: KunUISize.sm,
                          variant: KunUIVariant.light,
                          disabled: state._isTodayDisabled,
                          onPressed: () => state._handleDateSelect(
                            DateTime.now(),
                          ),
                          child: Text(strings.today),
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: KunSpacing.unit * 2,
                        children: [
                          if (widget.clearable)
                            KunButton(
                              size: KunUISize.sm,
                              variant: KunUIVariant.light,
                              onPressed: state._clear,
                              child: Text(strings.clear),
                            ),
                          KunButton(
                            size: KunUISize.sm,
                            variant: KunUIVariant.light,
                            onPressed: () => state._close(),
                            child: Text(strings.close),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, KunDatePickerStrings strings) {
    final bool dayView = state._view == KunDatePickerPrecision.day;
    final String step = state._stepUnit(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 2,
          children: [
            if (dayView)
              KunButton(
                variant: KunUIVariant.light,
                isIconOnly: true,
                size: KunUISize.sm,
                semanticLabel: strings.prevYear,
                onPressed: () => state._navigateYear(-1),
                child: const Icon(KunIcons.chevronsLeft),
              ),
            KunButton(
              key: const ValueKey<String>('KunDatePicker.prevPage'),
              variant: KunUIVariant.light,
              isIconOnly: true,
              size: KunUISize.sm,
              semanticLabel: strings.prevPage(unit: step),
              onPressed: () => state._stepPage(-1),
              child: const Icon(KunIcons.chevronLeft),
            ),
          ],
        ),
        _title(context, strings),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 2,
          children: [
            KunButton(
              key: const ValueKey<String>('KunDatePicker.nextPage'),
              variant: KunUIVariant.light,
              isIconOnly: true,
              size: KunUISize.sm,
              semanticLabel: strings.nextPage(unit: step),
              onPressed: () => state._stepPage(1),
              child: const Icon(KunIcons.chevronRight),
            ),
            if (dayView)
              KunButton(
                variant: KunUIVariant.light,
                isIconOnly: true,
                size: KunUISize.sm,
                semanticLabel: strings.nextYear,
                onPressed: () => state._navigateYear(1),
                child: const Icon(KunIcons.chevronsRight),
              ),
          ],
        ),
      ],
    );
  }

  Widget _title(BuildContext context, KunDatePickerStrings strings) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final bool canZoom = state._canZoomOut;
    final String label = state._headerLabel;
    return _TitleButton(
      focusNode: state._titleFocus,
      enabled: canZoom,
      label: canZoom ? strings.zoomOut(label: label) : label,
      onPressed: state._zoomOut,
      child: _HoverFill(
        enabled: canZoom,
        color: scheme.neutral.solid.withValues(alpha: 0.2),
        radius: BorderRadius.circular(KunRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KunSpacing.unit * 2,
            vertical: KunSpacing.unit * 0.5,
          ),
          child: Text(
            key: const ValueKey<String>('KunDatePicker.title'),
            label,
            textAlign: TextAlign.center,
            style: KunText.base.copyWith(
              fontWeight: KunFontWeights.semibold,
              color: scheme.foreground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayGrid(
    BuildContext context,
    KunCalendarLocale locale,
    KunColorScheme scheme,
  ) {
    final List<KunCalendarDayCell> cells = kunDayGrid(
      viewingDate: state._viewingDate,
      isRange: state._isRange,
      selected: state._singleValue,
      rangeStart: state._rangeStart,
      rangeEnd: state._rangeEnd,
      minDate: state.widget.minDate,
      maxDate: state.widget.maxDate,
      isDateDisabled: state.widget.isDateDisabled,
    );
    final List<List<KunCalendarDayCell>> rows = _chunk(cells, 7);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final List<KunCalendarDayCell> row in rows)
          Row(
            children: [
              for (final KunCalendarDayCell cell in row)
                Expanded(
                  child: _DayCell(
                    state: state,
                    cell: cell,
                    locale: locale,
                    scheme: scheme,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _periodGrid(
    BuildContext context,
    KunCalendarLocale locale,
    KunColorScheme scheme,
  ) {
    final List<KunCalendarPeriodCell> cells =
        state._view == KunDatePickerPrecision.month
            ? kunMonthGrid(
                year: state._viewingDate.year,
                locale: locale,
                isRange: state._isRange,
                selected: state._singleValue,
                rangeStart: state._rangeStart,
                rangeEnd: state._rangeEnd,
                minDate: state.widget.minDate,
                maxDate: state.widget.maxDate,
                isDateDisabled: state.widget.isDateDisabled,
                months: state.widget.months,
              )
            : kunYearGrid(
                viewingYear: state._viewingDate.year,
                isRange: state._isRange,
                selected: state._singleValue,
                rangeStart: state._rangeStart,
                rangeEnd: state._rangeEnd,
                minDate: state.widget.minDate,
                maxDate: state.widget.maxDate,
                isDateDisabled: state.widget.isDateDisabled,
              );
    final List<List<KunCalendarPeriodCell>> rows = _chunk(cells, 3);
    final KunDatePickerStrings strings =
        KunMessagesScope.of(context).datePicker;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final List<KunCalendarPeriodCell> row in rows)
          Row(
            children: [
              for (final KunCalendarPeriodCell cell in row)
                Expanded(
                  child: _PeriodCell(
                    state: state,
                    cell: cell,
                    scheme: scheme,
                    semanticLabel: state._view == KunDatePickerPrecision.month
                        ? strings.monthCell(
                            month: cell.label,
                            year: cell.date.year,
                          )
                        : cell.key,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

List<List<T>> _chunk<T>(List<T> items, int size) {
  return <List<T>>[
    for (int i = 0; i < items.length; i += size)
      items.sublist(i, i + size > items.length ? items.length : i + size),
  ];
}

class _TitleButton extends StatelessWidget {
  const _TitleButton({
    required this.focusNode,
    required this.enabled,
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final FocusNode focusNode;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onPressed : null,
      child: FocusableActionDetector(
        focusNode: focusNode,
        enabled: enabled,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onPressed();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              onPressed();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: enabled ? onPressed : null,
            child: ExcludeSemantics(child: child),
          ),
        ),
      ),
    );
  }
}

class _HoverFill extends StatefulWidget {
  const _HoverFill({
    required this.enabled,
    required this.color,
    required this.radius,
    required this.child,
  });

  final bool enabled;
  final Color color;
  final BorderRadius radius;
  final Widget child;

  @override
  State<_HoverFill> createState() => _HoverFillState();
}

class _HoverFillState extends State<_HoverFill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hovered = false) : null,
      child: AnimatedContainer(
        duration: kunMotion(context, KunDefaultTransition.duration),
        curve: KunDefaultTransition.curve,
        decoration: BoxDecoration(
          color: _hovered && widget.enabled ? widget.color : null,
          borderRadius: widget.radius,
        ),
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.state,
    required this.cell,
    required this.locale,
    required this.scheme,
  });

  final _KunDatePickerState state;
  final KunCalendarDayCell cell;
  final KunCalendarLocale locale;
  final KunColorScheme scheme;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final KunCalendarDayCell cell = widget.cell;
    final bool preview = kunIsInPreviewRange(
      date: cell.date,
      tempRangeStart: widget.state._tempRangeStart,
      hovered: widget.state._hoveredDate,
    );
    final bool inBand = cell.isInRange || preview;
    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 0.5),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: _CellButton(
          cellKey: cell.key,
          label: kunFormatDate(cell.date, 'PPPP', widget.locale),
          selected: cell.isSelected,
          disabled: cell.isDisabled,
          day: true,
          inBand: inBand,
          isRangeStart: cell.isRangeStart,
          isRangeEnd: cell.isRangeEnd,
          isToday: cell.isToday,
          isMuted: !cell.isCurrentMonth,
          hovered: _hovered,
          scheme: widget.scheme,
          text: '${cell.dayOfMonth}',
          onTap: () => widget.state._handleCellSelect(cell.date),
          onHover: (bool value) {
            setState(() => _hovered = value);
            widget.state.setState(() {
              widget.state._hoveredDate = value ? cell.date : null;
            });
          },
        ),
      ),
    );
  }
}

class _PeriodCell extends StatefulWidget {
  const _PeriodCell({
    required this.state,
    required this.cell,
    required this.scheme,
    required this.semanticLabel,
  });

  final _KunDatePickerState state;
  final KunCalendarPeriodCell cell;
  final KunColorScheme scheme;
  final String semanticLabel;

  @override
  State<_PeriodCell> createState() => _PeriodCellState();
}

class _PeriodCellState extends State<_PeriodCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final KunCalendarPeriodCell cell = widget.cell;
    final bool preview = kunIsInPreviewRange(
      date: cell.date,
      tempRangeStart: widget.state._tempRangeStart,
      hovered: widget.state._hoveredDate,
    );
    final bool inBand = cell.isInRange || preview;
    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 0.5),
      child: _CellButton(
        cellKey: cell.key,
        label: widget.semanticLabel,
        selected: cell.isSelected,
        disabled: cell.isDisabled,
        day: false,
        inBand: inBand,
        isRangeStart: cell.isRangeStart,
        isRangeEnd: cell.isRangeEnd,
        isToday: cell.isNow,
        isMuted: cell.isOutside,
        hovered: _hovered,
        scheme: widget.scheme,
        text: cell.label,
        onTap: () => widget.state._handleCellSelect(cell.date),
        onHover: (bool value) {
          setState(() => _hovered = value);
          widget.state.setState(() {
            widget.state._hoveredDate = value ? cell.date : null;
          });
        },
      ),
    );
  }
}

class _CellButton extends StatelessWidget {
  const _CellButton({
    required this.cellKey,
    required this.label,
    required this.selected,
    required this.disabled,
    required this.day,
    required this.inBand,
    required this.isRangeStart,
    required this.isRangeEnd,
    required this.isToday,
    required this.isMuted,
    required this.hovered,
    required this.scheme,
    required this.text,
    required this.onTap,
    required this.onHover,
  });

  final String cellKey;
  final String label;
  final bool selected;
  final bool disabled;
  final bool day;
  final bool inBand;
  final bool isRangeStart;
  final bool isRangeEnd;
  final bool isToday;
  final bool isMuted;
  final bool hovered;
  final KunColorScheme scheme;
  final String text;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final Color primary = scheme.primary.solid;
    Color? background;
    Color foreground = scheme.foreground;
    if (isMuted) {
      foreground = scheme.neutral.shade400;
    }
    if (isToday) {
      background = primary.withValues(alpha: 0.2);
    }
    if (inBand && !selected) {
      background = primary.withValues(alpha: 0.1);
    }
    if (hovered && !selected && !disabled) {
      background = scheme.neutral.solid.withValues(alpha: 0.2);
    }
    if (selected) {
      background = hovered ? primary.withValues(alpha: 0.9) : primary;
      foreground = scheme.primary.onSolid;
    }

    BorderRadius radius = BorderRadius.circular(
      day ? KunRadius.full : KunRadius.md,
    );
    if (inBand && !selected) {
      radius = BorderRadius.zero;
    }
    if (isRangeStart) {
      radius = radius.copyWith(
        topRight: Radius.zero,
        bottomRight: Radius.zero,
      );
    }
    if (isRangeEnd) {
      radius = radius.copyWith(
        topLeft: Radius.zero,
        bottomLeft: Radius.zero,
      );
    }

    Widget box = AnimatedContainer(
      duration: kunMotion(context, KunDefaultTransition.duration),
      curve: KunDefaultTransition.curve,
      height: day ? KunSpacing.unit * 8 : KunSpacing.unit * 9,
      width: day ? KunSpacing.unit * 8 : null,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
          color: isToday ? primary : primary.withValues(alpha: 0),
        ),
        borderRadius: radius,
      ),
      child: ExcludeSemantics(
        child: Text(
          text,
          style: KunText.sm.copyWith(color: foreground),
        ),
      ),
    );

    if (disabled) {
      box = Opacity(opacity: 0.5, child: box);
    }

    box = MouseRegion(
      cursor:
          disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: disabled ? null : (_) => onHover(true),
      onExit: disabled ? null : (_) => onHover(false),
      child: box,
    );

    // The node's tap is the Semantics below. Two tap actions cannot merge,
    // so a second one here put an unnamed clickable View beside every cell
    // in the Android node tree.
    box = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: disabled ? null : onTap,
      child: box,
    );

    return Semantics(
      key: ValueKey<String>('KunDatePicker.cell.$cellKey'),
      container: true,
      button: true,
      enabled: !disabled,
      selected: selected,
      label: label,
      onTap: disabled ? null : onTap,
      child: box,
    );
  }
}
