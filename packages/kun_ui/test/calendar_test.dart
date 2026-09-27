import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/src/foundation/calendar.dart';

void main() {
  final DateTime sample = DateTime(2026, 9, 26);

  group('kunFormatDate pins from date-fns 4.4.0', () {
    test('en P / PP / PPP / PPPP', () {
      expect(
        kunFormatDate(sample, 'P', KunCalendarLocale.en),
        '09/26/2026',
      );
      expect(
        kunFormatDate(sample, 'PP', KunCalendarLocale.en),
        'Sep 26, 2026',
      );
      expect(
        kunFormatDate(sample, 'PPP', KunCalendarLocale.en),
        'September 26th, 2026',
      );
      expect(
        kunFormatDate(sample, 'PPPP', KunCalendarLocale.en),
        'Saturday, September 26th, 2026',
      );
    });

    test('zh-CN P / PP / PPP / PPPP', () {
      expect(
        kunFormatDate(sample, 'P', KunCalendarLocale.zhCN),
        '26-09-26',
      );
      expect(
        kunFormatDate(sample, 'PP', KunCalendarLocale.zhCN),
        '2026-09-26',
      );
      expect(
        kunFormatDate(sample, 'PPP', KunCalendarLocale.zhCN),
        '2026年9月26日',
      );
      expect(
        kunFormatDate(sample, 'PPPP', KunCalendarLocale.zhCN),
        '2026年9月26日 星期六',
      );
    });

    test('ja P / PP / PPP / PPPP', () {
      expect(
        kunFormatDate(sample, 'P', KunCalendarLocale.ja),
        '2026/09/26',
      );
      expect(
        kunFormatDate(sample, 'PP', KunCalendarLocale.ja),
        '2026/09/26',
      );
      expect(
        kunFormatDate(sample, 'PPP', KunCalendarLocale.ja),
        '2026年9月26日',
      );
      expect(
        kunFormatDate(sample, 'PPPP', KunCalendarLocale.ja),
        '2026年9月26日土曜日',
      );
    });

    test('en do ordinals', () {
      const List<int> days = <int>[1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31];
      const List<String> expected = <String>[
        '1st',
        '2nd',
        '3rd',
        '4th',
        '11th',
        '12th',
        '13th',
        '21st',
        '22nd',
        '23rd',
        '31st',
      ];
      for (int i = 0; i < days.length; i++) {
        expect(
          kunFormatDate(DateTime(2026, 1, days[i]), 'do', KunCalendarLocale.en),
          expected[i],
        );
      }
    });

    test('web docs Format example', () {
      expect(
        kunFormatDate(
          DateTime(2026, 6, 14),
          'yyyy 年 MM 月 dd 日',
          KunCalendarLocale.en,
        ),
        '2026 年 06 月 14 日',
      );
    });

    test('quoting and escaped apostrophe', () {
      expect(
        kunFormatDate(sample, "'yyyy'", KunCalendarLocale.en),
        'yyyy',
      );
      expect(
        kunFormatDate(sample, "yyyy''MM", KunCalendarLocale.en),
        "2026'09",
      );
      expect(
        kunFormatDate(sample, "'today''s' d", KunCalendarLocale.en),
        "today's 26",
      );
    });

    test('unsupported latin letter throws ArgumentError', () {
      expect(
        () => kunFormatDate(sample, 'HH:mm', KunCalendarLocale.en),
        throwsArgumentError,
      );
    });
  });

  group('stepping and clamp', () {
    test('Jan 31 + 1 month is Feb 28, and Feb 29 in 2028', () {
      expect(kunAddMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(kunAddMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });

    test('coarse stepping from Jan 31 snaps to the period start first', () {
      expect(
        kunStepPeriod(DateTime(2026, 1, 31), KunDatePickerPrecision.month, 1),
        DateTime(2026, 2),
      );
      expect(
        kunStepPeriod(DateTime(2026, 1, 31), KunDatePickerPrecision.year, 1),
        DateTime(2027),
      );
    });

    test('year 5 is a real year', () {
      final DateTime year5 = DateTime(5);
      expect(year5.year, 5);
      expect(kunNormalize(year5, KunDatePickerPrecision.year), DateTime(5));
      expect(
        kunFormatDate(year5, 'yyyy', KunCalendarLocale.en),
        '0005',
      );
      expect(kunDecadeStart(5), 0);
      expect(
        kunYearGrid(viewingYear: 5, isRange: false)
            .map((KunCalendarPeriodCell c) => c.date.year)
            .contains(5),
        isTrue,
      );
    });
  });

  group('bounds', () {
    test('minDate of 2026-03-15 leaves March enabled and disables February',
        () {
      final DateTime min = DateTime(2026, 3, 15);
      final List<KunCalendarPeriodCell> months = kunMonthGrid(
        year: 2026,
        locale: KunCalendarLocale.en,
        isRange: false,
        minDate: min,
      );
      expect(months[1].isDisabled, isTrue);
      expect(months[2].isDisabled, isFalse);
    });

    test('isDateDisabled receives the period first day at each precision', () {
      final List<DateTime> seen = <DateTime>[];
      bool veto(DateTime date) {
        seen.add(date);
        return false;
      }

      kunIsPeriodDisabled(
        start: DateTime(2026, 3, 15),
        end: DateTime(2026, 3, 15),
        isDateDisabled: veto,
      );
      kunIsPeriodDisabled(
        start: DateTime(2026, 3),
        end: DateTime(2026, 3, 31),
        isDateDisabled: veto,
      );
      kunIsPeriodDisabled(
        start: DateTime(2026),
        end: DateTime(2026, 12, 31),
        isDateDisabled: veto,
      );
      expect(seen, <DateTime>[
        DateTime(2026, 3, 15),
        DateTime(2026, 3),
        DateTime(2026),
      ]);
    });
  });

  test('locale resolution matches getLocale', () {
    expect(kunResolveCalendarLocale('zh-CN'), KunCalendarLocale.zhCN);
    expect(kunResolveCalendarLocale('ja'), KunCalendarLocale.ja);
    expect(kunResolveCalendarLocale('en'), KunCalendarLocale.en);
    expect(kunResolveCalendarLocale('ja-JP'), KunCalendarLocale.en);
    expect(kunResolveCalendarLocale(null), KunCalendarLocale.en);
  });
}
