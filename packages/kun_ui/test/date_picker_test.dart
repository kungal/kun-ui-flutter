import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/dismiss_layers.dart';
import 'package:kun_ui/src/foundation/focus_outline.dart';
import 'package:kun_ui/src/foundation/tap_target.dart';

Finder get trigger =>
    find.byKey(const ValueKey<String>('KunDatePicker.trigger'));
Finder get triggerLayout =>
    find.ancestor(of: trigger, matching: find.byType(KunTapBand));
Finder get panel => find.byKey(const ValueKey<String>('KunDatePicker.panel'));
Finder get panelFade =>
    find.byKey(const ValueKey<String>('KunDatePicker.panelFade'));
Finder get panelScale =>
    find.byKey(const ValueKey<String>('KunDatePicker.panelScale'));
Finder get title => find.byKey(const ValueKey<String>('KunDatePicker.title'));
Finder get nextPage =>
    find.byKey(const ValueKey<String>('KunDatePicker.nextPage'));
Finder get clearIcon =>
    find.byKey(const ValueKey<String>('KunDatePicker.clear'));
Finder get selectTrigger =>
    find.byKey(const ValueKey<String>('KunSelect.trigger'));

Finder cell(String key) =>
    find.byKey(ValueKey<String>('KunDatePicker.cell.$key'));

KunFocusOutline cellOutline(WidgetTester tester, String key) {
  return tester.widget<KunFocusOutline>(
    find.descendant(of: cell(key), matching: find.byType(KunFocusOutline)),
  );
}

const List<KunSelectOption<String>> _selectOptions = <KunSelectOption<String>>[
  KunSelectOption<String>(value: 'vue', label: 'Vue'),
];

Widget wrap(
  Widget child, {
  KunThemeData? theme,
  KunMessages? messages,
  Widget Function(Widget child)? wrapHome,
}) {
  Widget home = child;
  if (messages != null) {
    home = KunMessagesScope(messages: messages, child: home);
  }
  if (wrapHome != null) {
    home = wrapHome(home);
  }
  return KunTheme(
    data: theme ?? KunThemeData.light(),
    child: WidgetsApp(
      color: KunColors.black,
      debugShowCheckedModeBanner: false,
      home: Align(alignment: Alignment.topCenter, child: home),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return builder(context);
          },
        );
      },
    ),
  );
}

Widget wrapWebKeys(Widget child) => wrap(
      Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
        },
        child: child,
      ),
    );

Future<void> openByTap(WidgetTester tester) async {
  await tester.tap(triggerLayout);
  await tester.pump();
  await tester.pump(KunDurations.base);
}

List<SemanticsData> collectSemantics(WidgetTester tester) {
  final List<SemanticsData> data = <SemanticsData>[];
  void walk(SemanticsNode node) {
    data.add(node.getSemanticsData());
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
  }

  walk(tester
      .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
  return data;
}

void main() {
  testWidgets('tap opens, shows the value month, pick emits and closes',
      (WidgetTester tester) async {
    DateTime? changed;
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            value: DateTime(2026, 9, 26),
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    expect(panel, findsNothing);
    await openByTap(tester);
    expect(panel, findsOneWidget);
    expect(find.text('2026 / 9'), findsOneWidget);
    await tester.tap(cell('2026-09-05'));
    await tester.pump();
    await tester.pump(KunDurations.exit);
    expect(changed, DateTime(2026, 9, 5));
    expect(panel, findsNothing);
  });

  testWidgets('minDate = today disables yesterday and keeps Today enabled',
      (WidgetTester tester) async {
    DateTime? changed;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = DateTime(today.year, today.month, today.day - 1);
    final String todayKey =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final String yesterdayKey =
        '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            minDate: today,
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    await openByTap(tester);

    final SemanticsHandle semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(cell(yesterdayKey))
          .getSemanticsData()
          .flagsCollection
          .isEnabled,
      Tristate.isFalse,
    );
    expect(
      tester
          .getSemantics(cell(todayKey))
          .getSemanticsData()
          .flagsCollection
          .isEnabled,
      Tristate.isTrue,
    );
    await tester.tap(cell(yesterdayKey));
    await tester.pump();
    expect(changed, isNull);

    await tester.ensureVisible(find.text('今天'));
    await tester.tap(find.text('今天'));
    await tester.pump();
    expect(changed, today);
    semantics.dispose();
  });

  testWidgets('Today is disabled when maxDate is in the past',
      (WidgetTester tester) async {
    DateTime? changed;
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            maxDate: DateTime(2020, 1, 1),
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.ensureVisible(find.text('今天'));
    await tester.tap(find.text('今天'));
    await tester.pump();
    expect(changed, isNull);
    expect(panel, findsOneWidget);
  });

  testWidgets('month and year precision emit period starts; title zooms',
      (WidgetTester tester) async {
    DateTime? changed;
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            precision: KunDatePickerPrecision.month,
            value: DateTime(2026, 9),
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(find.text('2026'), findsOneWidget);
    await tester.tap(title);
    await tester.pump();
    expect(find.text('2020 - 2029'), findsOneWidget);
    await tester.tap(cell('2024'));
    await tester.pump();
    expect(changed, isNull);
    expect(find.text('2024'), findsOneWidget);
    await tester.tap(cell('2024-03'));
    await tester.pump();
    await tester.pump(KunDurations.exit);
    expect(changed, DateTime(2024, 3));
    expect(panel, findsNothing);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            precision: KunDatePickerPrecision.year,
            value: DateTime(2026),
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    changed = null;
    await openByTap(tester);
    await tester.tap(cell('2021'));
    await tester.pump();
    await tester.pump(KunDurations.exit);
    expect(changed, DateTime(2021));
  });

  testWidgets('day title zooms out day → month → year',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(value: DateTime(2026, 9, 26)),
        ),
      ),
    );
    await openByTap(tester);
    expect(find.text('2026 / 9'), findsOneWidget);
    await tester.tap(title);
    await tester.pump();
    expect(find.text('2026'), findsOneWidget);
    await tester.tap(title);
    await tester.pump();
    expect(find.text('2020 - 2029'), findsOneWidget);
  });

  testWidgets('range: half, ordered pair, display, clear-then-pick',
      (WidgetTester tester) async {
    KunDateRange? changed;
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 360,
          child: _RangeHost(
            range: KunDateRange(start: DateTime(2026, 9, 1)),
            onChanged: (KunDateRange next) => changed = next,
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(panel, findsOneWidget);

    await tester.tap(cell('2026-09-10'));
    await tester.pump();
    expect(changed, KunDateRange(start: DateTime(2026, 9, 10)));
    expect(panel, findsOneWidget);
    expect(find.text('2026-09-10 -'), findsOneWidget);

    await tester.tap(cell('2026-09-20'));
    await tester.pump();
    await tester.pump(KunDurations.exit);
    expect(
      changed,
      KunDateRange(
        start: DateTime(2026, 9, 10),
        end: DateTime(2026, 9, 20),
      ),
    );
    expect(panel, findsNothing);
    expect(find.text('2026-09-10 - 2026-09-20'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 360,
          child: _RangeHost(
            range: KunDateRange(end: DateTime(2026, 9, 20)),
          ),
        ),
      ),
    );
    expect(find.text('- 2026-09-20'), findsOneWidget);

    changed = null;
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 360,
          child: _RangeHost(
            range: KunDateRange(
              start: DateTime(2026, 9, 10),
              end: DateTime(2026, 9, 20),
            ),
            onChanged: (KunDateRange next) => changed = next,
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.ensureVisible(find.text('清空'));
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(changed, const KunDateRange());
    expect(panel, findsOneWidget);

    await tester.tap(cell('2026-09-20'));
    await tester.pump();
    expect(changed, KunDateRange(start: DateTime(2026, 9, 20)));
    expect(panel, findsOneWidget);
  });

  testWidgets('keyboard: open, page, commit, disabled, escape, backspace',
      (WidgetTester tester) async {
    DateTime? changed;
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            value: DateTime(2026, 9, 30),
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    await tester.tap(triggerLayout);
    await tester.pump();
    final FocusNode node = Focus.of(tester.element(trigger));
    expect(node.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(KunDurations.exit);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(panel, findsOneWidget);
    expect(find.text('2026 / 9'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('2026 / 10'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(KunDurations.exit);
    expect(changed, DateTime(2026, 10, 1));
    expect(panel, findsNothing);
    expect(node.hasPrimaryFocus, isTrue);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            value: DateTime(2026, 9, 26),
            minDate: DateTime(2026, 9, 27),
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    changed = null;
    await tester.tap(triggerLayout);
    await tester.pump();
    await tester.pump(KunDurations.base);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(changed, isNull);
    expect(panel, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(KunDurations.exit);
    expect(panel, findsNothing);
    expect(node.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(changed, isNull);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            value: DateTime(2026, 9, 26),
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    await tester.tap(triggerLayout);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(changed, isNull);
  });

  testWidgets('Enter on the next-page KunButton pages and does not commit',
      (WidgetTester tester) async {
    DateTime? changed;
    await tester.pumpWidget(
      wrapWebKeys(
        SizedBox(
          width: 320,
          child: _Host(
            value: DateTime(2026, 9, 26),
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    await openByTap(tester);
    final Finder nextInner = find.descendant(
      of: nextPage,
      matching: find.byType(Icon),
    );
    Focus.of(tester.element(nextInner)).requestFocus();
    await tester.pump();
    expect(Focus.of(tester.element(nextInner)).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(changed, isNull);
    expect(find.text('2026 / 10'), findsOneWidget);
    expect(panel, findsOneWidget);
  });

  testWidgets(
      'focus falls back to the trigger when the title disables at year view',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(value: DateTime(2026, 9, 26)),
        ),
      ),
    );
    await openByTap(tester);
    Focus.of(tester.element(title)).requestFocus();
    await tester.pump();
    await tester.tap(title);
    await tester.pump();
    Focus.of(tester.element(title)).requestFocus();
    await tester.pump();
    await tester.tap(title);
    await tester.pump();
    expect(find.text('2020 - 2029'), findsOneWidget);
    expect(Focus.of(tester.element(trigger)).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(panel, findsOneWidget);
  });

  testWidgets('the × clears, does not open, and is absent from semantics',
      (WidgetTester tester) async {
    DateTime? changed = DateTime(2026, 6, 14);
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            value: DateTime(2026, 6, 14),
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    final SemanticsHandle semantics = tester.ensureSemantics();
    expect(clearIcon, findsOneWidget);
    final List<SemanticsData> before = collectSemantics(tester);
    expect(
      before.where((SemanticsData d) => d.label.contains('清空')),
      isEmpty,
    );

    await tester.tap(clearIcon);
    await tester.pump();
    expect(changed, isNull);
    expect(panel, findsNothing);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            value: DateTime(2026, 6, 14),
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.ensureVisible(find.text('清空'));
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(changed, isNull);
    expect(panel, findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the × takes taps 6px past its glyph, and no further',
      (WidgetTester tester) async {
    Future<DateTime?> tapAt(Offset Function(Rect icon) at) async {
      DateTime? changed = DateTime(2026, 6, 14);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 320,
            child: _Host(
              value: DateTime(2026, 6, 14),
              onChanged: (DateTime? next) => changed = next,
            ),
          ),
          theme: KunThemeData.light(
            tapTargetSize: KunTapTargetSize.shrinkWrap,
          ),
        ),
      );
      await tester.tapAt(at(tester.getRect(clearIcon)));
      await tester.pump();
      return changed;
    }

    expect(await tapAt((Rect r) => r.centerLeft - const Offset(5, 0)), isNull);
    expect(panel, findsNothing);
    expect(await tapAt((Rect r) => r.centerRight + const Offset(5, 0)), isNull);
    expect(await tapAt((Rect r) => r.topCenter - const Offset(0, 5)), isNull);
    expect(
      await tapAt((Rect r) => r.centerLeft - const Offset(8, 0)),
      DateTime(2026, 6, 14),
    );
    await tester.pump(KunDurations.base);
    expect(panel, findsOneWidget);
  });

  testWidgets('each cell and the title is one semantics node',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(SizedBox(width: 320, child: _Host(value: DateTime(2026, 9, 26)))),
    );
    await openByTap(tester);
    final List<SemanticsData> nodes = collectSemantics(tester);
    final Iterable<SemanticsData> unnamedTaps = nodes.where(
      (SemanticsData d) => d.hasAction(SemanticsAction.tap) && d.label.isEmpty,
    );
    expect(unnamedTaps, isEmpty);
    semantics.dispose();
  });

  testWidgets('the panel is content-wide with a 260px floor',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(SizedBox(width: 320, child: _Host(value: DateTime(2026, 9, 26)))),
    );
    await openByTap(tester);
    // The test font draws every glyph 1em wide, which widens the title past
    // the grid; in a real font the day view is exactly the grid's 276.
    expect(tester.getSize(panel).width, greaterThanOrEqualTo(276));
    await tester.tap(title);
    await tester.pump();
    expect(tester.getSize(panel).width, 260);
  });

  testWidgets('without a value, reopening keeps the page the panel was on',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const SizedBox(width: 320, child: _Host())));
    await openByTap(tester);
    final DateTime now = DateTime.now();
    await tester.tap(nextPage);
    await tester.pump();
    final DateTime next = DateTime(now.year, now.month + 1);
    expect(find.text('${next.year} / ${next.month}'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pump();
    await tester.pump(KunDurations.exit);
    expect(panel, findsNothing);
    await openByTap(tester);
    expect(find.text('${next.year} / ${next.month}'), findsOneWidget);
  });

  testWidgets('trigger height matches KunSelect at every size',
      (WidgetTester tester) async {
    for (final KunUISize size in KunUISize.values) {
      await tester.pumpWidget(
        wrap(
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 280,
                  child: KunDatePicker(
                    size: size,
                    onChanged: (_) {},
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: KunSelect<String, KunSelectOption<String>>(
                    size: size,
                    options: _selectOptions,
                    value: null,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(trigger).height,
        tester.getSize(selectTrigger).height,
        reason: 'empty $size',
      );

      await tester.pumpWidget(
        wrap(
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 280,
                  child: KunDatePicker(
                    size: size,
                    value: DateTime(2026, 6, 14),
                    onChanged: (_) {},
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: KunSelect<String, KunSelectOption<String>>(
                    size: size,
                    options: _selectOptions,
                    value: 'vue',
                    clearable: true,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(trigger).height,
        tester.getSize(selectTrigger).height,
        reason: 'valued $size',
      );
    }
  });

  testWidgets('semantics: trigger, day cells, weekdays, selected',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            value: DateTime(2026, 9, 26),
            label: '截止日期',
          ),
        ),
      ),
    );
    List<SemanticsData> data = collectSemantics(tester);
    final SemanticsData combo = data.singleWhere(
      (SemanticsData d) => d.label == '截止日期' && d.value.isNotEmpty,
    );
    expect(combo.value, '2026-09-26');
    expect(combo.flagsCollection.isExpanded, Tristate.isFalse);

    await openByTap(tester);
    data = collectSemantics(tester);
    expect(
      data
          .singleWhere(
            (SemanticsData d) => d.label == '截止日期' && d.value.isNotEmpty,
          )
          .flagsCollection
          .isExpanded,
      Tristate.isTrue,
    );
    expect(
      data.where((SemanticsData d) => d.label == '2026年9月26日 星期六'),
      isNotEmpty,
    );
    expect(
      data
          .singleWhere((SemanticsData d) => d.label == '2026年9月26日 星期六')
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      data.where((SemanticsData d) => d.label == '日' && d.value.isEmpty),
      isEmpty,
    );

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            key: const ValueKey<String>('en'),
            value: DateTime(2026, 9, 26),
            locale: 'en',
          ),
        ),
      ),
    );
    await openByTap(tester);
    data = collectSemantics(tester);
    expect(
      data.where(
        (SemanticsData d) => d.label == 'Saturday, September 26th, 2026',
      ),
      isNotEmpty,
    );

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            key: const ValueKey<String>('ja'),
            value: DateTime(2026, 9, 26),
            locale: 'ja',
          ),
        ),
      ),
    );
    await openByTap(tester);
    data = collectSemantics(tester);
    expect(
      data.where((SemanticsData d) => d.label == '2026年9月26日土曜日'),
      isNotEmpty,
    );
    semantics.dispose();
  });

  testWidgets('locale and weekday / month overrides',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(value: DateTime(2026, 9, 26)),
        ),
      ),
    );
    await openByTap(tester);
    expect(find.text('日'), findsWidgets);
    expect(find.text('一'), findsWidgets);
    expect(find.text('Su'), findsNothing);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            key: const ValueKey<String>('en-weekdays'),
            value: DateTime(2026, 9, 26),
            locale: 'en',
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(find.text('Su'), findsOneWidget);
    expect(find.text('Mo'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            key: const ValueKey<String>('overrides'),
            value: DateTime(2026, 9, 26),
            weekdays: const <String>['A'],
            months: const <String>['X'],
          ),
        ),
      ),
    );
    await openByTap(tester);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('一'), findsWidgets);
    await tester.tap(title);
    await tester.pump();
    expect(find.text('X'), findsOneWidget);
    expect(find.text('2月'), findsOneWidget);
  });

  testWidgets('custom format renders the docs example',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 360,
          child: _Host(
            value: DateTime(2026, 6, 14),
            format: 'yyyy 年 MM 月 dd 日',
          ),
        ),
      ),
    );
    expect(find.text('2026 年 06 月 14 日'), findsOneWidget);
  });

  testWidgets('trigger format uses the calendar locale',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 420,
          child: _Host(
            value: DateTime(2026, 9, 27),
            format: 'yyyy MMMM do EEEE',
          ),
        ),
      ),
    );
    expect(find.text('2026 九月 27日 星期日'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 420,
          child: _Host(
            key: const ValueKey<String>('en-format'),
            value: DateTime(2026, 9, 27),
            format: 'yyyy MMMM do EEEE',
            locale: 'en',
          ),
        ),
      ),
    );
    expect(find.text('2026 September 27th Sunday'), findsOneWidget);
  });

  testWidgets('default trigger formats are unchanged',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(value: DateTime(2026, 9, 26)),
        ),
      ),
    );
    expect(find.text('2026-09-26'), findsOneWidget);
  });

  testWidgets('keyboard active cell draws a ring; click open does not',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(value: DateTime(2026, 9, 15)),
        ),
      ),
    );
    await openByTap(tester);
    expect(cellOutline(tester, '2026-09-15').visible, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(cellOutline(tester, '2026-09-16').visible, isTrue);
    expect(cellOutline(tester, '2026-09-15').visible, isFalse);
    expect(
      cellOutline(tester, '2026-09-16').color,
      KunColors.light.neutral.solid.withValues(alpha: 0.5),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(KunDurations.exit);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(panel, findsOneWidget);
    expect(cellOutline(tester, '2026-09-15').visible, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(cellOutline(tester, '2026-09-16').visible, isTrue);

    await tester.tapAt(tester.getTopLeft(panel) + const Offset(8, 8));
    await tester.pump();
    expect(cellOutline(tester, '2026-09-16').visible, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(KunDurations.exit);
    await openByTap(tester);
    expect(cellOutline(tester, '2026-09-15').visible, isFalse);
  });

  testWidgets('active-cell ring follows arrows across a page turn',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(value: DateTime(2026, 9, 30)),
        ),
      ),
    );
    await tester.tap(triggerLayout);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(KunDurations.exit);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(cellOutline(tester, '2026-09-30').visible, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('2026 / 10'), findsOneWidget);
    expect(cellOutline(tester, '2026-10-01').visible, isTrue);
    expect(cellOutline(tester, '2026-09-30').visible, isFalse);
  });

  testWidgets('active-cell ring on the month and year grids',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(value: DateTime(2026, 9, 15)),
        ),
      ),
    );
    await openByTap(tester);
    await tester.tap(title);
    await tester.pump();
    expect(cellOutline(tester, '2026-09').visible, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(cellOutline(tester, '2026-10').visible, isTrue);

    await tester.tap(title);
    await tester.pump();
    expect(cellOutline(tester, '2026').visible, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(cellOutline(tester, '2027').visible, isTrue);
  });

  testWidgets('inside a modal, back closes the picker and leaves the modal',
      (WidgetTester tester) async {
    DateTime? changed;
    await tester.pumpWidget(
      wrap(
        _ModalHost(onChanged: (DateTime? next) => changed = next),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Form'), findsOneWidget);
    expect(find.byType(KunInput), findsOneWidget);
    await openByTap(tester);
    expect(panel, findsOneWidget);
    expect(KunDismissLayers.debugLayers, hasLength(2));

    await tester.tap(cell('2026-09-05'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(changed, DateTime(2026, 9, 5));
    expect(panel, findsNothing);
    expect(find.text('Form'), findsOneWidget);
    expect(KunDismissLayers.debugLayers, hasLength(1));

    await tester.pumpWidget(
      wrap(const _ModalHost()),
    );
    await tester.pumpAndSettle();
    await openByTap(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(find.text('Form'), findsOneWidget);
    expect(KunDismissLayers.debugLayers, hasLength(1));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Form'), findsNothing);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('a tap outside closes without emitting',
      (WidgetTester tester) async {
    DateTime? changed = DateTime(2026, 9, 26);
    await tester.pumpWidget(
      wrap(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: _Host(
              value: DateTime(2026, 9, 26),
              onChanged: (DateTime? next) => changed = next,
            ),
          ),
        ),
      ),
    );
    await openByTap(tester);
    await tester.tapAt(const Offset(790, 590));
    await tester.pump();
    await tester.pump(KunDurations.exit);
    expect(panel, findsNothing);
    expect(changed, DateTime(2026, 9, 26));
  });

  testWidgets(
      'disabled: a tap does not open, and the trigger cannot take focus',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(
            width: 320,
            child: _Host(disabled: true),
          ),
        ),
      ),
    );
    await tester.tap(triggerLayout);
    await tester.pump();
    expect(panel, findsNothing);
    Focus.of(tester.element(trigger)).requestFocus();
    await tester.pump();
    expect(Focus.of(tester.element(trigger)).hasFocus, isFalse);
  });

  testWidgets('reduced motion: the panel is fully shown on the first frame',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(value: DateTime(2026, 9, 26)),
        ),
        wrapHome: (Widget child) {
          return MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child,
          );
        },
      ),
    );
    await tester.tap(triggerLayout);
    await tester.pump();
    expect(tester.widget<FadeTransition>(panelFade).opacity.value, 1);
    expect(tester.widget<Transform>(panelScale).transform.storage[0], 1);
  });

  testWidgets('padded grows the trigger, not the drawn box', (tester) async {
    Size? drawn;
    Offset? iconFromRight;
    for (final size in [
      KunTapTargetSize.padded,
      KunTapTargetSize.shrinkWrap,
    ]) {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 320,
            child: _Host(value: DateTime(2026, 6, 14)),
          ),
          theme: KunThemeData.light(tapTargetSize: size),
        ),
      );
      final box = tester.getSize(trigger);
      final icon = tester.getRect(clearIcon);
      final boxRect = tester.getRect(trigger);
      if (size == KunTapTargetSize.padded) {
        expect(box.height, KunControlMetrics.of(KunUISize.md).square);
        drawn = box;
        iconFromRight = Offset(
          boxRect.right - icon.right,
          icon.center.dy - boxRect.center.dy,
        );
      } else {
        expect(box, drawn);
        expect(
          Offset(
            boxRect.right - icon.right,
            icon.center.dy - boxRect.center.dy,
          ),
          iconFromRight,
        );
      }
    }
  });

  testWidgets('the band above the value opens, the band above clear clears',
      (tester) async {
    DateTime? changed = DateTime(2026, 6, 14);
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(
            value: DateTime(2026, 6, 14),
            onChanged: (DateTime? next) => changed = next,
          ),
        ),
      ),
    );
    final drawn = tester.getRect(trigger);
    await tester.tapAt(Offset(drawn.left + 24, drawn.top - 3));
    await tester.pump();
    await tester.pump(KunDurations.base);
    expect(panel, findsOneWidget);

    await tester.tapAt(drawn.center);
    await tester.pump();
    await tester.pump(KunDurations.exit);
    expect(panel, findsNothing);

    changed = DateTime(2026, 6, 14);
    await tester.tapAt(
      Offset(tester.getRect(clearIcon).center.dx, drawn.top - 3),
    );
    await tester.pump();
    expect(changed, isNull);
    expect(panel, findsNothing);
  });

  testWidgets('the trigger meets the Android guideline', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 320,
          child: _Host(value: DateTime(2026, 6, 14), label: 'Date'),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.value,
    this.onChanged,
    this.precision = KunDatePickerPrecision.day,
    this.label,
    this.disabled = false,
    this.format,
    this.minDate,
    this.maxDate,
    this.locale,
    this.weekdays,
    this.months,
  });

  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final KunDatePickerPrecision precision;
  final String? label;
  final bool disabled;
  final String? format;
  final DateTime? minDate;
  final DateTime? maxDate;
  final String? locale;
  final List<String>? weekdays;
  final List<String>? months;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late DateTime? _value = widget.value;

  @override
  void didUpdateWidget(_Host oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KunDatePicker(
      value: _value,
      onChanged: (DateTime? next) {
        setState(() => _value = next);
        widget.onChanged?.call(next);
      },
      precision: widget.precision,
      label: widget.label,
      disabled: widget.disabled,
      format: widget.format,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      locale: widget.locale,
      weekdays: widget.weekdays,
      months: widget.months,
    );
  }
}

class _RangeHost extends StatefulWidget {
  const _RangeHost({this.range = const KunDateRange(), this.onChanged});

  final KunDateRange range;
  final ValueChanged<KunDateRange>? onChanged;

  @override
  State<_RangeHost> createState() => _RangeHostState();
}

class _RangeHostState extends State<_RangeHost> {
  late KunDateRange _range = widget.range;

  @override
  void didUpdateWidget(_RangeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range) {
      _range = widget.range;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KunDatePicker.range(
      range: _range,
      onRangeChanged: (KunDateRange next) {
        setState(() => _range = next);
        widget.onChanged?.call(next);
      },
    );
  }
}

class _ModalHost extends StatefulWidget {
  const _ModalHost({this.onChanged});

  final ValueChanged<DateTime?>? onChanged;

  @override
  State<_ModalHost> createState() => _ModalHostState();
}

class _ModalHostState extends State<_ModalHost> {
  bool _open = true;
  DateTime? _value = DateTime(2026, 9, 26);
  String _name = '';

  @override
  Widget build(BuildContext context) {
    return KunModal(
      value: _open,
      onChanged: (bool next) => setState(() => _open = next),
      title: 'Form',
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KunInput(
              value: _name,
              onChanged: (String next) => setState(() => _name = next),
              label: 'Name',
            ),
            KunDatePicker(
              value: _value,
              onChanged: (DateTime? next) {
                setState(() => _value = next);
                widget.onChanged?.call(next);
              },
              label: 'Date',
            ),
          ],
        ),
      ),
    );
  }
}
