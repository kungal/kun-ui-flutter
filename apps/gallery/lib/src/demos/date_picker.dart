import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget _caption(BuildContext context, String text) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Text(
    text,
    style: KunText.sm.copyWith(color: scheme.neutral.shade600),
  );
}

Widget _mono(BuildContext context, String text) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Text(
    text,
    style: KunText.xs
        .merge(KunFontFamilies.monoStyle)
        .copyWith(color: scheme.foregroundMuted),
  );
}

String _fmt(
  DateTime? date, {
  KunDatePickerPrecision precision = KunDatePickerPrecision.day,
}) {
  if (date == null) {
    return '—';
  }
  final String y = date.year.toString().padLeft(4, '0');
  final String m = date.month.toString().padLeft(2, '0');
  final String d = date.day.toString().padLeft(2, '0');
  return switch (precision) {
    KunDatePickerPrecision.year => y,
    KunDatePickerPrecision.month => '$y-$m',
    KunDatePickerPrecision.day => '$y-$m-$d',
  };
}

Widget datePickerBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: const _SingleDemo(label: 'Pick a date'),
    ),
  );
}

Widget datePickerRange(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: const _RangeDemo(label: '选择日期范围'),
    ),
  );
}

Widget datePickerPrecision(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.sm),
      child: const _PrecisionDemo(),
    ),
  );
}

Widget datePickerFormat(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: const _FormatDemo(),
    ),
  );
}

Widget datePickerColors(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.md),
      child: const _ColorsDemo(),
    ),
  );
}

Widget datePickerStates(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.md),
      child: const _StatesDemo(),
    ),
  );
}

Widget datePickerError(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: const _SingleDemo(
        label: '出生日期',
        error: '请选择一个有效的日期',
      ),
    ),
  );
}

Widget datePickerDeadline(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
      child: const _DeadlineDemo(),
    ),
  );
}

Widget datePickerInModal(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: const _InModalDemo(),
  );
}

Widget datePickerLocale(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.sm),
      child: const _LocaleDemo(),
    ),
  );
}

Widget datePickerFilterBar(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: const _FilterBarDemo(),
  );
}

Widget datePickerSizes(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: const _SizesDemo(),
  );
}

class _SingleDemo extends StatefulWidget {
  const _SingleDemo({required this.label, this.error});

  final String label;
  final String? error;

  @override
  State<_SingleDemo> createState() => _SingleDemoState();
}

class _SingleDemoState extends State<_SingleDemo> {
  DateTime? _value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KunDatePicker(
          value: _value,
          onChanged: (DateTime? next) => setState(() => _value = next),
          label: widget.label,
          error: widget.error,
        ),
        SizedBox(height: KunSpacing.unit * 2),
        _caption(context, 'Value: ${_fmt(_value)}'),
      ],
    );
  }
}

class _RangeDemo extends StatefulWidget {
  const _RangeDemo({required this.label});

  final String label;

  @override
  State<_RangeDemo> createState() => _RangeDemoState();
}

class _RangeDemoState extends State<_RangeDemo> {
  KunDateRange _range = const KunDateRange();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KunDatePicker.range(
          range: _range,
          onRangeChanged: (KunDateRange next) => setState(() => _range = next),
          label: widget.label,
        ),
        SizedBox(height: KunSpacing.unit * 2),
        _caption(context, '起始：${_fmt(_range.start)}'),
        _caption(context, '结束：${_fmt(_range.end)}'),
      ],
    );
  }
}

class _PrecisionDemo extends StatefulWidget {
  const _PrecisionDemo();

  @override
  State<_PrecisionDemo> createState() => _PrecisionDemoState();
}

class _PrecisionDemoState extends State<_PrecisionDemo> {
  DateTime? _day = DateTime(2026, 9, 5);
  DateTime? _month = DateTime(2026, 9);
  DateTime? _year = DateTime(2026);
  KunDateRange _yearRange = KunDateRange(
    start: DateTime(2018),
    end: DateTime(2024),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KunSpacing.unit * 4,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KunDatePicker(
                    value: _day,
                    onChanged: (DateTime? next) => setState(() => _day = next),
                    label: '发售日',
                  ),
                  SizedBox(height: KunSpacing.unit),
                  _mono(context, _fmt(_day)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KunDatePicker(
                    value: _month,
                    onChanged: (DateTime? next) =>
                        setState(() => _month = next),
                    precision: KunDatePickerPrecision.month,
                    label: '收录月份',
                  ),
                  SizedBox(height: KunSpacing.unit),
                  _mono(
                    context,
                    _fmt(_month, precision: KunDatePickerPrecision.month),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: KunSpacing.unit * 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KunSpacing.unit * 4,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KunDatePicker(
                    value: _year,
                    onChanged: (DateTime? next) => setState(() => _year = next),
                    precision: KunDatePickerPrecision.year,
                    label: '出品年份',
                  ),
                  SizedBox(height: KunSpacing.unit),
                  _mono(
                    context,
                    _fmt(_year, precision: KunDatePickerPrecision.year),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KunDatePicker.range(
                    range: _yearRange,
                    onRangeChanged: (KunDateRange next) =>
                        setState(() => _yearRange = next),
                    precision: KunDatePickerPrecision.year,
                    label: '年代区间',
                    minDate: DateTime(1995, 1, 1),
                  ),
                  SizedBox(height: KunSpacing.unit),
                  _mono(
                    context,
                    '${_fmt(_yearRange.start, precision: KunDatePickerPrecision.year)} → ${_fmt(_yearRange.end, precision: KunDatePickerPrecision.year)}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormatDemo extends StatefulWidget {
  const _FormatDemo();

  @override
  State<_FormatDemo> createState() => _FormatDemoState();
}

class _FormatDemoState extends State<_FormatDemo> {
  DateTime? _value;

  bool _isDateDisabled(DateTime date) {
    final DateTime today = DateTime.now();
    final DateTime start = DateTime(today.year, today.month, today.day);
    final DateTime day = DateTime(date.year, date.month, date.day);
    final int weekday = date.weekday;
    return day.isBefore(start) ||
        weekday == DateTime.saturday ||
        weekday == DateTime.sunday;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KunDatePicker(
          value: _value,
          onChanged: (DateTime? next) => setState(() => _value = next),
          label: '自定义格式与禁用日期',
          format: 'yyyy 年 MM 月 dd 日',
          isDateDisabled: _isDateDisabled,
        ),
        SizedBox(height: KunSpacing.unit * 2),
        _caption(context, 'Value: ${_fmt(_value)}'),
        _caption(context, '已禁用过去的日期、周六与周日'),
      ],
    );
  }
}

class _ColorsDemo extends StatefulWidget {
  const _ColorsDemo();

  @override
  State<_ColorsDemo> createState() => _ColorsDemoState();
}

class _ColorsDemoState extends State<_ColorsDemo> {
  DateTime? _a;
  DateTime? _b;
  DateTime? _c;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: [
        KunDatePicker(
          value: _a,
          onChanged: (DateTime? next) => setState(() => _a = next),
          color: KunUIColor.primary,
          label: 'primary',
        ),
        KunDatePicker(
          value: _b,
          onChanged: (DateTime? next) => setState(() => _b = next),
          color: KunUIColor.secondary,
          label: 'secondary',
        ),
        KunDatePicker(
          value: _c,
          onChanged: (DateTime? next) => setState(() => _c = next),
          color: KunUIColor.success,
          label: 'success',
        ),
      ],
    );
  }
}

class _StatesDemo extends StatefulWidget {
  const _StatesDemo();

  @override
  State<_StatesDemo> createState() => _StatesDemoState();
}

class _StatesDemoState extends State<_StatesDemo> {
  DateTime? _a = DateTime(2026, 6, 14);
  final DateTime _b = DateTime(2026, 6, 14);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: [
        KunDatePicker(
          value: _a,
          onChanged: (DateTime? next) => setState(() => _a = next),
          label: '可清除（默认）',
          clearable: true,
        ),
        KunDatePicker(
          value: _b,
          label: '禁用',
          disabled: true,
        ),
      ],
    );
  }
}

class _DeadlineDemo extends StatefulWidget {
  const _DeadlineDemo();

  @override
  State<_DeadlineDemo> createState() => _DeadlineDemoState();
}

class _DeadlineDemoState extends State<_DeadlineDemo> {
  DateTime? _value;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KunDatePicker(
          value: _value,
          onChanged: (DateTime? next) => setState(() => _value = next),
          label: '截止日期 (可选)',
          minDate: today,
          maxDate: DateTime(today.year + 2, today.month, today.day),
        ),
        SizedBox(height: KunSpacing.unit * 2),
        _caption(context, 'Value: ${_fmt(_value)}'),
      ],
    );
  }
}

class _InModalDemo extends StatefulWidget {
  const _InModalDemo();

  @override
  State<_InModalDemo> createState() => _InModalDemoState();
}

class _InModalDemoState extends State<_InModalDemo> {
  bool _open = false;
  String _title = '';
  DateTime? _closesAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KunButton(
          onPressed: () => setState(() => _open = true),
          child: const Text('Open modal'),
        ),
        KunModal(
          value: _open,
          onChanged: (bool next) => setState(() => _open = next),
          title: '发起投票',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KunInput(
                  value: _title,
                  onChanged: (String next) => setState(() => _title = next),
                  label: '标题',
                ),
                SizedBox(height: KunSpacing.unit * 3),
                KunDatePicker(
                  value: _closesAt,
                  onChanged: (DateTime? next) =>
                      setState(() => _closesAt = next),
                  label: '截止日期 (可选)',
                  minDate: DateTime.now(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LocaleDemo extends StatefulWidget {
  const _LocaleDemo();

  @override
  State<_LocaleDemo> createState() => _LocaleDemoState();
}

class _LocaleDemoState extends State<_LocaleDemo> {
  DateTime? _en = DateTime(2026, 9, 26);
  DateTime? _ja = DateTime(2026, 9, 26);
  DateTime? _override = DateTime(2026, 9, 26);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 4,
      children: [
        KunDatePicker(
          value: _en,
          onChanged: (DateTime? next) => setState(() => _en = next),
          locale: 'en',
          label: 'en',
        ),
        KunDatePicker(
          value: _ja,
          onChanged: (DateTime? next) => setState(() => _ja = next),
          locale: 'ja',
          label: 'ja',
        ),
        KunDatePicker(
          value: _override,
          onChanged: (DateTime? next) => setState(() => _override = next),
          weekdays: const <String>['周天', '周一'],
          months: const <String>['正月'],
          label: 'weekdays / months',
        ),
      ],
    );
  }
}

class _FilterBarDemo extends StatefulWidget {
  const _FilterBarDemo();

  @override
  State<_FilterBarDemo> createState() => _FilterBarDemoState();
}

class _FilterBarDemoState extends State<_FilterBarDemo> {
  DateTime? _value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KunDatePicker(
          value: _value,
          onChanged: (DateTime? next) => setState(() => _value = next),
          fullWidth: false,
          icon: KunIcons.filter,
          placeholder: '日期',
          size: KunUISize.sm,
          rounded: KunUIRounded.full,
        ),
      ],
    );
  }
}

class _SizesDemo extends StatefulWidget {
  const _SizesDemo();

  @override
  State<_SizesDemo> createState() => _SizesDemoState();
}

class _SizesDemoState extends State<_SizesDemo> {
  final Map<String, DateTime?> _values = <String, DateTime?>{};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: [
        for (final KunUISize size in KunUISize.values) ...[
          _caption(context, size.name),
          Wrap(
            spacing: KunSpacing.unit * 3,
            runSpacing: KunSpacing.unit * 3,
            children: [
              for (final KunUIRounded rounded in KunUIRounded.values)
                SizedBox(
                  width: 200,
                  child: KunDatePicker(
                    value: _values['${size.name}-${rounded.name}'],
                    onChanged: (DateTime? next) => setState(
                      () => _values['${size.name}-${rounded.name}'] = next,
                    ),
                    size: size,
                    rounded: rounded,
                    fullWidth: false,
                    label: rounded.name,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
