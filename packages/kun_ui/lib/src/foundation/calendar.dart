/// Calendar locale tables, `kunFormatDate`, and the pure half of
/// `useCalendar.ts`. Not exported from `kun_ui.dart`.
library;

import 'package:flutter/foundation.dart';

/// What one pick commits. The contract's `KunDatePickerPrecision`.
enum KunDatePickerPrecision {
  /// A calendar day. The value is local midnight of that day.
  day,

  /// A calendar month. The value is the first day of that month.
  month,

  /// A calendar year. The value is 1 January of that year.
  year,
}

/// A range whose ends may be unset: the web's `[string | null, string | null]`.
@immutable
class KunDateRange {
  /// Creates a range. Either end may be null.
  const KunDateRange({this.start, this.end});

  /// The first day of the range, or null while unset.
  final DateTime? start;

  /// The last day of the range, or null while unset.
  final DateTime? end;

  @override
  bool operator ==(Object other) =>
      other is KunDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'KunDateRange(start: $start, end: $end)';
}

/// The three date-fns locales kun-ui bundles (`enUS`, `zhCN`, `ja`).
enum KunCalendarLocale {
  /// date-fns `enUS`.
  en,

  /// date-fns `zhCN`.
  zhCN,

  /// date-fns `ja`.
  ja,
}

/// Resolves a BCP 47 tag the way the web's `getLocale` does: `'zh-CN'` and
/// `'ja'` match, and every other string — including `'ja-JP'` — falls to en.
KunCalendarLocale kunResolveCalendarLocale(String? tag) {
  return switch (tag) {
    'zh-CN' => KunCalendarLocale.zhCN,
    'ja' => KunCalendarLocale.ja,
    _ => KunCalendarLocale.en,
  };
}

/// Weekday short (`EEEEEE`). Index 0 is Sunday. Extracted from date-fns 4.4.0.
const Map<KunCalendarLocale, List<String>> kunWeekdayShort =
    <KunCalendarLocale, List<String>>{
  KunCalendarLocale.en: <String>['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'],
  KunCalendarLocale.zhCN: <String>['日', '一', '二', '三', '四', '五', '六'],
  KunCalendarLocale.ja: <String>['日', '月', '火', '水', '木', '金', '土'],
};

/// Weekday narrow (`EEEEE`). Index 0 is Sunday. Extracted from date-fns 4.4.0.
const Map<KunCalendarLocale, List<String>> kunWeekdayNarrow =
    <KunCalendarLocale, List<String>>{
  KunCalendarLocale.en: <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'],
  KunCalendarLocale.zhCN: <String>['日', '一', '二', '三', '四', '五', '六'],
  KunCalendarLocale.ja: <String>['日', '月', '火', '水', '木', '金', '土'],
};

/// Weekday abbreviated (`E` / `EE` / `EEE`). Index 0 is Sunday.
/// Extracted from date-fns 4.4.0.
const Map<KunCalendarLocale, List<String>> kunWeekdayAbbreviated =
    <KunCalendarLocale, List<String>>{
  KunCalendarLocale.en: <String>[
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ],
  KunCalendarLocale.zhCN: <String>[
    '周日',
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
  ],
  KunCalendarLocale.ja: <String>['日', '月', '火', '水', '木', '金', '土'],
};

/// Weekday wide (`EEEE`). Index 0 is Sunday. Extracted from date-fns 4.4.0.
const Map<KunCalendarLocale, List<String>> kunWeekdayWide =
    <KunCalendarLocale, List<String>>{
  KunCalendarLocale.en: <String>[
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ],
  KunCalendarLocale.zhCN: <String>[
    '星期日',
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
  ],
  KunCalendarLocale.ja: <String>[
    '日曜日',
    '月曜日',
    '火曜日',
    '水曜日',
    '木曜日',
    '金曜日',
    '土曜日',
  ],
};

/// Month wide (`MMMM` / `LLLL`). Index 0 is January. Extracted from
/// date-fns 4.4.0.
const Map<KunCalendarLocale, List<String>> kunMonthWide =
    <KunCalendarLocale, List<String>>{
  KunCalendarLocale.en: <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ],
  KunCalendarLocale.zhCN: <String>[
    '一月',
    '二月',
    '三月',
    '四月',
    '五月',
    '六月',
    '七月',
    '八月',
    '九月',
    '十月',
    '十一月',
    '十二月',
  ],
  KunCalendarLocale.ja: <String>[
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
  ],
};

/// Month abbreviated (`MMM` / `LLL`). Index 0 is January. Extracted from
/// date-fns 4.4.0.
const Map<KunCalendarLocale, List<String>> kunMonthAbbreviated =
    <KunCalendarLocale, List<String>>{
  KunCalendarLocale.en: <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ],
  KunCalendarLocale.zhCN: <String>[
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
  ],
  KunCalendarLocale.ja: <String>[
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
  ],
};

/// Month narrow (`MMMMM` / `LLLLL`). Index 0 is January. Extracted from
/// date-fns 4.4.0.
const Map<KunCalendarLocale, List<String>> kunMonthNarrow =
    <KunCalendarLocale, List<String>>{
  KunCalendarLocale.en: <String>[
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D',
  ],
  KunCalendarLocale.zhCN: <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '七',
    '八',
    '九',
    '十',
    '十一',
    '十二',
  ],
  KunCalendarLocale.ja: <String>[
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ],
};

/// Localized `P` / `PP` / `PPP` / `PPPP` patterns. Extracted from
/// date-fns 4.4.0.
const Map<KunCalendarLocale, List<String>> kunLocalizedDatePatterns =
    <KunCalendarLocale, List<String>>{
  KunCalendarLocale.en: <String>[
    'MM/dd/yyyy',
    'MMM d, y',
    'MMMM do, y',
    'EEEE, MMMM do, y',
  ],
  KunCalendarLocale.zhCN: <String>[
    'yy-MM-dd',
    'yyyy-MM-dd',
    "y'年'M'月'd'日'",
    "y'年'M'月'd'日' EEEE",
  ],
  KunCalendarLocale.ja: <String>[
    'y/MM/dd',
    'y/MM/dd',
    'y年M月d日',
    'y年M月d日EEEE',
  ],
};

/// The machine format a precision round-trips through.
String kunDefaultDateFormat(KunDatePickerPrecision precision) {
  return switch (precision) {
    KunDatePickerPrecision.day => 'yyyy-MM-dd',
    KunDatePickerPrecision.month => 'yyyy-MM',
    KunDatePickerPrecision.year => 'yyyy',
  };
}

/// An integer key of a local calendar date. Compare these, never instants:
/// a local midnight does not exist on some DST transitions.
int kunDateKey(DateTime date) =>
    date.year * 10000 + date.month * 100 + date.day;

/// Local midnight of [date], reading year / month / day only.
DateTime kunCalendarDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// First day of [date]'s month.
DateTime kunStartOfMonth(DateTime date) => DateTime(date.year, date.month);

/// 1 January of [date]'s year.
DateTime kunStartOfYear(DateTime date) => DateTime(date.year);

/// Last calendar day of [year]/[month].
int kunLastDayOfMonth(int year, int month) {
  const List<int> days = <int>[
    0,
    31,
    28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];
  if (month == 2 && _isLeapYear(year)) {
    return 29;
  }
  return days[month];
}

bool _isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// Sunday-first start of the week holding [date]. The web calls
/// `startOfWeek` without a locale.
DateTime kunStartOfWeek(DateTime date) {
  final DateTime day = kunCalendarDate(date);
  return DateTime(day.year, day.month, day.day - (day.weekday % 7));
}

/// Saturday end of the week holding [date].
DateTime kunEndOfWeek(DateTime date) {
  final DateTime start = kunStartOfWeek(date);
  return DateTime(start.year, start.month, start.day + 6);
}

/// date-fns `addMonths`: clamp the day to the target month's last day.
DateTime kunAddMonths(DateTime date, int amount) {
  int year = date.year;
  int month = date.month + amount;
  while (month > 12) {
    month -= 12;
    year += 1;
  }
  while (month < 1) {
    month += 12;
    year -= 1;
  }
  final int last = kunLastDayOfMonth(year, month);
  final int day = date.day < last ? date.day : last;
  return DateTime(year, month, day);
}

/// date-fns `addYears`, via [kunAddMonths] so Feb 29 clamps.
DateTime kunAddYears(DateTime date, int amount) =>
    kunAddMonths(date, amount * 12);

/// `useCalendar.ts` `stepPeriod`. Coarse steps snap to the period start
/// first so a day-of-month cannot overflow across a page turn.
DateTime kunStepPeriod(
  DateTime date,
  KunDatePickerPrecision unit,
  int amount,
) {
  if (unit == KunDatePickerPrecision.day) {
    return DateTime(date.year, date.month, date.day + amount);
  }
  if (unit == KunDatePickerPrecision.month) {
    return kunAddMonths(kunStartOfMonth(date), amount);
  }
  return kunAddYears(kunStartOfYear(date), amount);
}

/// Snaps [date] to the first instant of the period [precision] selects.
DateTime kunNormalize(DateTime date, KunDatePickerPrecision precision) {
  return switch (precision) {
    KunDatePickerPrecision.year => DateTime(date.year),
    KunDatePickerPrecision.month => DateTime(date.year, date.month),
    KunDatePickerPrecision.day => DateTime(date.year, date.month, date.day),
  };
}

/// Last instant (as a calendar date) of the period starting at [start].
DateTime kunPeriodEnd(DateTime start, KunDatePickerPrecision precision) {
  return switch (precision) {
    KunDatePickerPrecision.year => DateTime(start.year, 12, 31),
    KunDatePickerPrecision.month => DateTime(
        start.year,
        start.month,
        kunLastDayOfMonth(start.year, start.month),
      ),
    KunDatePickerPrecision.day => DateTime(start.year, start.month, start.day),
  };
}

/// A cell is disabled only when the **whole** period is out of bounds.
///
/// [isDateDisabled] receives [start], the first day of the period.
bool kunIsPeriodDisabled({
  required DateTime start,
  required DateTime end,
  DateTime? minDate,
  DateTime? maxDate,
  bool Function(DateTime date)? isDateDisabled,
}) {
  final DateTime? min = minDate == null ? null : kunCalendarDate(minDate);
  final DateTime? max = maxDate == null ? null : kunCalendarDate(maxDate);
  if (min != null && kunDateKey(end) < kunDateKey(min)) {
    return true;
  }
  if (max != null && kunDateKey(start) > kunDateKey(max)) {
    return true;
  }
  return isDateDisabled?.call(start) ?? false;
}

/// First year of the 10-year page [year] sits on.
int kunDecadeStart(int year) => (year ~/ 10) * 10;

/// `'<start> - <start+9>'`.
String kunDecadeLabel(int year) {
  final int start = kunDecadeStart(year);
  return '$start - ${start + 9}';
}

/// Pads [override] from [fallback] index by index. A short override leaves
/// the rest as the locale had them — an override of three months used to
/// leave nine blank cells that still committed.
List<String> kunPadNames(List<String> fallback, List<String>? override) {
  return <String>[
    for (int i = 0; i < fallback.length; i++)
      (override != null && i < override.length) ? override[i] : fallback[i],
  ];
}

/// Weekday headers (`EEEEEE`) padded from [override].
List<String> kunWeekdayLabels(
  KunCalendarLocale locale, [
  List<String>? override,
]) {
  return kunPadNames(kunWeekdayShort[locale]!, override);
}

/// Full month names (`LLLL`) padded from [override].
List<String> kunMonthLabels(
  KunCalendarLocale locale, [
  List<String>? override,
]) {
  return kunPadNames(kunMonthWide[locale]!, override);
}

/// Month-grid labels (`LLL`) padded from the same [override] as the full
/// names, matching `useCalendar.ts`.
List<String> kunMonthGridLabels(
  KunCalendarLocale locale, [
  List<String>? override,
]) {
  return kunPadNames(kunMonthAbbreviated[locale]!, override);
}

/// One day cell of `calendarGrid`.
@immutable
class KunCalendarDayCell {
  /// Creates a day cell.
  const KunCalendarDayCell({
    required this.date,
    required this.key,
    required this.dayOfMonth,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.isRangeStart,
    required this.isRangeEnd,
    required this.isInRange,
    required this.isDisabled,
  });

  /// Local midnight of the cell.
  final DateTime date;

  /// `yyyy-MM-dd`.
  final String key;

  /// `date.day`.
  final int dayOfMonth;

  /// Whether [date] sits in the page's month.
  final bool isCurrentMonth;

  /// Whether [date] is today.
  final bool isToday;

  /// Whether [date] is a committed end (or the single value).
  final bool isSelected;

  /// Whether [date] is the range start.
  final bool isRangeStart;

  /// Whether [date] is the range end.
  final bool isRangeEnd;

  /// Whether [date] sits strictly between the two ends.
  final bool isInRange;

  /// Whether the whole day is out of bounds.
  final bool isDisabled;
}

/// One month or year cell.
@immutable
class KunCalendarPeriodCell {
  /// Creates a period cell.
  const KunCalendarPeriodCell({
    required this.date,
    required this.key,
    required this.label,
    required this.isNow,
    required this.isSelected,
    required this.isRangeStart,
    required this.isRangeEnd,
    required this.isInRange,
    required this.isOutside,
    required this.isDisabled,
  });

  /// First day of the period.
  final DateTime date;

  /// `yyyy-MM` for a month, `'<y>'` for a year.
  final String key;

  /// Painted text.
  final String label;

  /// Whether this period contains today.
  final bool isNow;

  /// Whether this period is a committed end (or the single value).
  final bool isSelected;

  /// Whether this period is the range start.
  final bool isRangeStart;

  /// Whether this period is the range end.
  final bool isRangeEnd;

  /// Whether this period sits strictly between the two ends.
  final bool isInRange;

  /// Year cells outside the decade.
  final bool isOutside;

  /// Whether the whole period is out of bounds.
  final bool isDisabled;
}

/// The result of [kunSelectDate].
@immutable
class KunCalendarPick {
  /// Creates a pick result.
  const KunCalendarPick({
    this.single,
    this.range,
    this.tempRangeStart,
  });

  /// The committed single value.
  final DateTime? single;

  /// The committed range (possibly half-open).
  final KunDateRange? range;

  /// The remembered range start after this pick. Null after a complete
  /// range or a clear.
  final DateTime? tempRangeStart;
}

/// Range selection plus the remembered start. A pick after a complete
/// range starts over. [currentEnd] is the committed range end, so a
/// stale start cannot survive a clear that left [tempRangeStart] set.
KunCalendarPick kunSelectDate({
  required DateTime input,
  required KunDatePickerPrecision precision,
  required bool isRange,
  required DateTime? tempRangeStart,
  DateTime? currentEnd,
}) {
  final DateTime date = kunNormalize(input, precision);
  if (!isRange) {
    return KunCalendarPick(single: date);
  }
  if (tempRangeStart == null || currentEnd != null) {
    return KunCalendarPick(
      range: KunDateRange(start: date),
      tempRangeStart: date,
    );
  }
  if (kunDateKey(date) < kunDateKey(tempRangeStart)) {
    return KunCalendarPick(
      range: KunDateRange(start: date, end: tempRangeStart),
    );
  }
  return KunCalendarPick(
    range: KunDateRange(start: tempRangeStart, end: date),
  );
}

bool _sameDay(DateTime a, DateTime b) => kunDateKey(a) == kunDateKey(b);

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

bool _sameYear(DateTime a, DateTime b) => a.year == b.year;

/// Sunday-first month grid of 4–6 weeks.
List<KunCalendarDayCell> kunDayGrid({
  required DateTime viewingDate,
  required bool isRange,
  DateTime? selected,
  DateTime? rangeStart,
  DateTime? rangeEnd,
  DateTime? minDate,
  DateTime? maxDate,
  bool Function(DateTime date)? isDateDisabled,
  DateTime? now,
}) {
  final DateTime today = kunCalendarDate(now ?? DateTime.now());
  final DateTime first = kunStartOfMonth(viewingDate);
  final DateTime last = DateTime(
    first.year,
    first.month,
    kunLastDayOfMonth(first.year, first.month),
  );
  final DateTime gridStart = kunStartOfWeek(first);
  final DateTime gridEnd = kunEndOfWeek(last);
  final DateTime? single = selected == null ? null : kunCalendarDate(selected);
  final DateTime? start =
      rangeStart == null ? null : kunCalendarDate(rangeStart);
  final DateTime? end = rangeEnd == null ? null : kunCalendarDate(rangeEnd);

  final List<KunCalendarDayCell> cells = <KunCalendarDayCell>[];
  DateTime cursor = gridStart;
  while (kunDateKey(cursor) <= kunDateKey(gridEnd)) {
    final DateTime day = cursor;
    final bool isRangeStart = start != null && _sameDay(day, start);
    final bool isRangeEnd = end != null && _sameDay(day, end);
    final bool isSelected = isRange
        ? isRangeStart || isRangeEnd
        : single != null && _sameDay(day, single);
    cells.add(
      KunCalendarDayCell(
        date: day,
        key: kunFormatDate(day, 'yyyy-MM-dd', KunCalendarLocale.en),
        dayOfMonth: day.day,
        isCurrentMonth: _sameMonth(day, viewingDate),
        isToday: _sameDay(day, today),
        isSelected: isSelected,
        isRangeStart: isRangeStart,
        isRangeEnd: isRangeEnd,
        isInRange: start != null &&
            end != null &&
            kunDateKey(day) > kunDateKey(start) &&
            kunDateKey(day) < kunDateKey(end),
        isDisabled: kunIsPeriodDisabled(
          start: day,
          end: day,
          minDate: minDate,
          maxDate: maxDate,
          isDateDisabled: isDateDisabled,
        ),
      ),
    );
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return cells;
}

/// Twelve month cells of [year].
List<KunCalendarPeriodCell> kunMonthGrid({
  required int year,
  required KunCalendarLocale locale,
  required bool isRange,
  DateTime? selected,
  DateTime? rangeStart,
  DateTime? rangeEnd,
  DateTime? minDate,
  DateTime? maxDate,
  bool Function(DateTime date)? isDateDisabled,
  List<String>? months,
  DateTime? now,
}) {
  final DateTime today = now ?? DateTime.now();
  final List<String> labels = kunMonthGridLabels(locale, months);
  final DateTime? start =
      rangeStart == null ? null : kunStartOfMonth(rangeStart);
  final DateTime? end = rangeEnd == null ? null : kunStartOfMonth(rangeEnd);
  final List<KunCalendarPeriodCell> cells = <KunCalendarPeriodCell>[];
  for (int m = 1; m <= 12; m++) {
    final DateTime date = DateTime(year, m);
    final DateTime periodEnd = DateTime(year, m, kunLastDayOfMonth(year, m));
    final bool isRangeStartCell = start != null && _sameMonth(date, start);
    final bool isRangeEndCell = end != null && _sameMonth(date, end);
    cells.add(
      KunCalendarPeriodCell(
        date: date,
        key: kunFormatDate(date, 'yyyy-MM', KunCalendarLocale.en),
        label: labels[m - 1],
        isNow: _sameMonth(date, today),
        isSelected: isRange
            ? isRangeStartCell || isRangeEndCell
            : selected != null && _sameMonth(date, selected),
        isRangeStart: isRangeStartCell,
        isRangeEnd: isRangeEndCell,
        isInRange: start != null &&
            end != null &&
            kunDateKey(date) > kunDateKey(start) &&
            kunDateKey(date) < kunDateKey(end),
        isOutside: false,
        isDisabled: kunIsPeriodDisabled(
          start: date,
          end: periodEnd,
          minDate: minDate,
          maxDate: maxDate,
          isDateDisabled: isDateDisabled,
        ),
      ),
    );
  }
  return cells;
}

/// Twelve year cells: the decade plus one year on each side.
List<KunCalendarPeriodCell> kunYearGrid({
  required int viewingYear,
  required bool isRange,
  DateTime? selected,
  DateTime? rangeStart,
  DateTime? rangeEnd,
  DateTime? minDate,
  DateTime? maxDate,
  bool Function(DateTime date)? isDateDisabled,
  DateTime? now,
}) {
  final DateTime today = now ?? DateTime.now();
  final int base = kunDecadeStart(viewingYear);
  final DateTime? start =
      rangeStart == null ? null : kunStartOfYear(rangeStart);
  final DateTime? end = rangeEnd == null ? null : kunStartOfYear(rangeEnd);
  final List<KunCalendarPeriodCell> cells = <KunCalendarPeriodCell>[];
  for (int i = 0; i < 12; i++) {
    final int y = base - 1 + i;
    final DateTime date = DateTime(y);
    final DateTime periodEnd = DateTime(y, 12, 31);
    final bool isRangeStartCell = start != null && _sameYear(date, start);
    final bool isRangeEndCell = end != null && _sameYear(date, end);
    cells.add(
      KunCalendarPeriodCell(
        date: date,
        key: '$y',
        label: '$y',
        isNow: _sameYear(date, today),
        isSelected: isRange
            ? isRangeStartCell || isRangeEndCell
            : selected != null && _sameYear(date, selected),
        isRangeStart: isRangeStartCell,
        isRangeEnd: isRangeEndCell,
        isInRange: start != null &&
            end != null &&
            kunDateKey(date) > kunDateKey(start) &&
            kunDateKey(date) < kunDateKey(end),
        isOutside: y < base || y > base + 9,
        isDisabled: kunIsPeriodDisabled(
          start: date,
          end: periodEnd,
          minDate: minDate,
          maxDate: maxDate,
          isDateDisabled: isDateDisabled,
        ),
      ),
    );
  }
  return cells;
}

/// Whether [date] sits strictly between [tempRangeStart] and [hovered].
bool kunIsInPreviewRange({
  required DateTime date,
  required DateTime? tempRangeStart,
  required DateTime? hovered,
}) {
  if (tempRangeStart == null || hovered == null) {
    return false;
  }
  final int key = kunDateKey(date);
  final int a = kunDateKey(tempRangeStart);
  final int b = kunDateKey(hovered);
  return (key > a && key < b) || (key < a && key > b);
}

/// date-fns `format` for the subset [KunDatePicker.format] documents.
///
/// Runs of the same letter form one token. `'…'` is a literal; `''` is a
/// literal apostrophe. An unquoted latin letter that is not in the subset
/// throws [ArgumentError].
String kunFormatDate(
  DateTime date,
  String pattern,
  KunCalendarLocale locale,
) {
  return _formatDate(date, pattern, locale);
}

String _formatDate(
  DateTime date,
  String pattern,
  KunCalendarLocale locale,
) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i < pattern.length) {
    final String c = pattern[i];
    if (c == "'") {
      if (i + 1 < pattern.length && pattern[i + 1] == "'") {
        out.write("'");
        i += 2;
        continue;
      }
      i += 1;
      while (i < pattern.length) {
        if (pattern[i] == "'") {
          if (i + 1 < pattern.length && pattern[i + 1] == "'") {
            out.write("'");
            i += 2;
            continue;
          }
          i += 1;
          break;
        }
        out.write(pattern[i]);
        i += 1;
      }
      continue;
    }
    if (c == 'd' && i + 1 < pattern.length && pattern[i + 1] == 'o') {
      out.write(_ordinalDay(date.day, locale));
      i += 2;
      continue;
    }
    if (_isLatinLetter(c)) {
      int j = i + 1;
      while (j < pattern.length && pattern[j] == c) {
        j += 1;
      }
      out.write(_formatToken(date, pattern.substring(i, j), locale));
      i = j;
      continue;
    }
    out.write(c);
    i += 1;
  }
  return out.toString();
}

bool _isLatinLetter(String c) {
  final int code = c.codeUnitAt(0);
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
}

String _formatToken(
  DateTime date,
  String token,
  KunCalendarLocale locale,
) {
  switch (token[0]) {
    case 'y':
      return _formatYear(date.year, token.length);
    case 'M':
    case 'L':
      return _formatMonth(date.month, token.length, locale);
    case 'd':
      if (token.length == 1) {
        return '${date.day}';
      }
      if (token.length == 2) {
        return date.day.toString().padLeft(2, '0');
      }
      throw ArgumentError.value(token, 'pattern', 'unsupported date token');
    case 'E':
      return _formatWeekday(date, token.length, locale);
    case 'P':
      if (token.length > 4) {
        throw ArgumentError.value(token, 'pattern', 'unsupported date token');
      }
      return _formatDate(
        date,
        kunLocalizedDatePatterns[locale]![token.length - 1],
        locale,
      );
    default:
      throw ArgumentError.value(token, 'pattern', 'unsupported date token');
  }
}

String _formatYear(int year, int length) {
  if (length == 1) {
    return '$year';
  }
  if (length == 2) {
    return (year % 100).abs().toString().padLeft(2, '0');
  }
  return year.abs().toString().padLeft(length, '0');
}

String _formatMonth(int month, int length, KunCalendarLocale locale) {
  if (length == 1) {
    return '$month';
  }
  if (length == 2) {
    return month.toString().padLeft(2, '0');
  }
  if (length == 3) {
    return kunMonthAbbreviated[locale]![month - 1];
  }
  if (length == 4) {
    return kunMonthWide[locale]![month - 1];
  }
  if (length == 5) {
    return kunMonthNarrow[locale]![month - 1];
  }
  throw ArgumentError.value(
    'M' * length,
    'pattern',
    'unsupported date token',
  );
}

String _formatWeekday(
  DateTime date,
  int length,
  KunCalendarLocale locale,
) {
  final int index = date.weekday % 7;
  if (length <= 3) {
    return kunWeekdayAbbreviated[locale]![index];
  }
  if (length == 4) {
    return kunWeekdayWide[locale]![index];
  }
  if (length == 5) {
    return kunWeekdayNarrow[locale]![index];
  }
  if (length == 6) {
    return kunWeekdayShort[locale]![index];
  }
  throw ArgumentError.value(
    'E' * length,
    'pattern',
    'unsupported date token',
  );
}

String _ordinalDay(int day, KunCalendarLocale locale) {
  if (locale != KunCalendarLocale.en) {
    return '$day日';
  }
  final int mod100 = day % 100;
  if (mod100 >= 11 && mod100 <= 13) {
    return '${day}th';
  }
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}
