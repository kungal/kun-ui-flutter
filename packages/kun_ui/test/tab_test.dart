import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/outer_shadow.dart';

Widget wrap(Widget child) => KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

Widget wrapWebKeys(Widget child) => Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
      },
      child: wrap(child),
    );

Widget wrapTraversal(Widget child) => Shortcuts(
      shortcuts: WidgetsApp.defaultShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          NextFocusIntent: NextFocusAction(),
          PreviousFocusIntent: PreviousFocusAction(),
        },
        child: wrapWebKeys(child),
      ),
    );

const List<KunTabItem> homeDocs = <KunTabItem>[
  KunTabItem(value: 'home', textValue: 'Home'),
  KunTabItem(value: 'docs', textValue: 'Docs'),
];

const List<KunTabItem> homeDocsSettings = <KunTabItem>[
  KunTabItem(value: 'home', textValue: 'Home'),
  KunTabItem(value: 'docs', textValue: 'Docs'),
  KunTabItem(value: 'settings', textValue: 'Settings'),
];

Finder tabOf(String value) => find.byKey(ValueKey<String>('KunTab.$value'));

Finder get indicator => find.byKey(const ValueKey<String>('KunTab.indicator'));

Finder get fallback => find.byKey(const ValueKey<String>('KunTab.fallback'));

TextStyle resolvedOf(WidgetTester tester, String text) => (tester
        .widget<RichText>(
          find.descendant(
            of: find.text(text),
            matching: find.byType(RichText),
          ),
        )
        .text as TextSpan)
    .style!;

Container tabContainer(WidgetTester tester, String value) {
  return tester.widget<Container>(
    find.descendant(of: tabOf(value), matching: find.byType(Container)).first,
  );
}

BoxDecoration? indicatorDecoration(WidgetTester tester) {
  if (indicator.evaluate().isEmpty) return null;
  return tester.widget<DecoratedBox>(indicator).decoration as BoxDecoration;
}

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    required this.items,
    this.initial = 'home',
    this.variant = KunTabVariant.underlined,
    this.orientation = KunTabOrientation.horizontal,
    this.disableAnimation = false,
    this.scrollButtons = true,
    this.onChanged,
  });

  final List<KunTabItem> items;
  final String initial;
  final KunTabVariant variant;
  final KunTabOrientation orientation;
  final bool disableAnimation;
  final bool scrollButtons;
  final ValueChanged<String>? onChanged;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return KunTab(
      items: widget.items,
      value: _value,
      onChanged: (String value) {
        setState(() => _value = value);
        widget.onChanged?.call(value);
      },
      variant: widget.variant,
      orientation: widget.orientation,
      disableAnimation: widget.disableAnimation,
      scrollButtons: widget.scrollButtons,
    );
  }
}

class _CountItem extends KunTabItem {
  const _CountItem({
    required super.value,
    required super.textValue,
    required this.unread,
  });

  final int unread;
}

void main() {
  testWidgets('sizes match padding, type size and gap', (tester) async {
    const sizes =
        <KunTabSize, ({double padH, double padV, double gap, double font})>{
      KunTabSize.sm: (padH: 10, padV: 6, gap: 4, font: 14),
      KunTabSize.md: (padH: 12, padV: 8, gap: 6, font: 14),
      KunTabSize.lg: (padH: 16, padV: 10, gap: 8, font: 16),
    };
    for (final entry in sizes.entries) {
      await tester.pumpWidget(
        wrap(
          KunTab(
            items: const [
              KunTabItem(value: 'home', textValue: 'Home'),
              KunTabItem(value: 'next', textValue: 'Next'),
            ],
            value: 'home',
            size: entry.key,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      final padding = tabContainer(tester, 'home').padding! as EdgeInsets;
      expect(padding.horizontal / 2, entry.value.padH,
          reason: '${entry.key} padH');
      expect(padding.vertical / 2, entry.value.padV,
          reason: '${entry.key} padV');
      expect(
        resolvedOf(tester, 'Home').fontSize,
        entry.value.font,
        reason: '${entry.key} font',
      );
      final Rect a = tester.getRect(tabOf('home'));
      final Rect b = tester.getRect(tabOf('next'));
      expect(b.left - a.right, entry.value.gap, reason: '${entry.key} gap');
    }
  });

  testWidgets('tapping an unselected tab calls onChanged; selected does not',
      (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(
      wrap(
        KunTab(
          items: homeDocs,
          value: 'home',
          onChanged: seen.add,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Docs'));
    expect(seen, ['docs']);

    seen.clear();
    await tester.tap(find.text('Home'));
    expect(seen, isEmpty);
    expect(resolvedOf(tester, 'Home').color, KunColors.light.primary.solid);
    expect(resolvedOf(tester, 'Docs').color, KunColors.light.neutral.shade500);
  });

  testWidgets('disabled item and group block taps, dim, and set cursors',
      (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(
      wrap(
        KunTab(
          items: const [
            KunTabItem(value: 'home', textValue: 'Home'),
            KunTabItem(value: 'docs', textValue: 'Docs', disabled: true),
          ],
          value: 'home',
          onChanged: seen.add,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Docs'), warnIfMissed: false);
    expect(seen, isEmpty);
    final itemOpacity = tester.widget<Opacity>(
      find.descendant(of: tabOf('docs'), matching: find.byType(Opacity)),
    );
    expect(itemOpacity.opacity, 0.5);
    expect(
      tester
          .widget<MouseRegion>(
            find.descendant(
                of: tabOf('docs'), matching: find.byType(MouseRegion)),
          )
          .cursor,
      SystemMouseCursors.forbidden,
    );

    await tester.pumpWidget(
      wrap(
        KunTab(
          items: homeDocs,
          value: 'home',
          disabled: true,
          onChanged: seen.add,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Docs'), warnIfMissed: false);
    expect(seen, isEmpty);
    final groupOpacity = tester.widget<Opacity>(
      find
          .descendant(of: find.byType(KunTab), matching: find.byType(Opacity))
          .first,
    );
    expect(groupOpacity.opacity, 0.5);
    expect(
      tester
          .widget<MouseRegion>(
            find.descendant(
                of: tabOf('home'), matching: find.byType(MouseRegion)),
          )
          .cursor,
      SystemMouseCursors.click,
    );

    await tester.pumpWidget(
      wrap(
        KunTab(
          items: const [
            KunTabItem(value: 'home', textValue: 'Home'),
            KunTabItem(value: 'docs', textValue: 'Docs', disabled: true),
          ],
          value: 'home',
          disabled: true,
          onChanged: seen.add,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(of: find.byType(KunTab), matching: find.byType(Opacity)),
      findsAtLeast(2),
    );
    final nested = tester.widget<Opacity>(
      find.descendant(of: tabOf('docs'), matching: find.byType(Opacity)),
    );
    expect(nested.opacity, 0.5);
    expect(
      tester
          .widget<Opacity>(
            find
                .descendant(
                    of: find.byType(KunTab), matching: find.byType(Opacity))
                .first,
          )
          .opacity,
      0.5,
    );
  });

  testWidgets('href navigates on every selection and skips when disabled',
      (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      wrap(
        KunUIConfigScope(
          config: KunUIConfig(
            navigate: (BuildContext context, String href) {
              log.add('nav:$href');
            },
          ),
          child: _Host(
            items: const [
              KunTabItem(value: 'home', textValue: 'Home', href: '/'),
              KunTabItem(value: 'docs', textValue: 'Docs', href: '/docs'),
              KunTabItem(
                value: 'off',
                textValue: 'Off',
                href: '/off',
                disabled: true,
              ),
            ],
            onChanged: (String value) => log.add('change:$value'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();
    expect(log, ['change:docs', 'nav:/docs']);

    log.clear();
    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();
    expect(log, ['nav:/docs']);

    log.clear();
    await tester.tap(find.text('Off'), warnIfMissed: false);
    expect(log, isEmpty);
  });

  testWidgets('selected and hover text colours, including mid-transition',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        KunTab(
          items: homeDocs,
          value: 'home',
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(resolvedOf(tester, 'Home').color, KunColors.light.primary.solid);
    expect(resolvedOf(tester, 'Docs').color, KunColors.light.neutral.shade500);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('Docs')));
    await tester.pump();
    await tester.pump(KunDurations.base ~/ 2);
    final Color mid = resolvedOf(tester, 'Docs').color!;
    expect(mid, isNot(KunColors.light.neutral.shade500));
    expect(mid, isNot(KunColors.light.foreground));
    await tester.pump(KunDurations.base);
    expect(resolvedOf(tester, 'Docs').color, KunColors.light.foreground);

    await tester.pumpWidget(
      wrap(
        KunTab(
          items: homeDocs,
          value: 'home',
          variant: KunTabVariant.solid,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(resolvedOf(tester, 'Home').color, KunColors.light.primary.onSolid);

    await tester.pumpWidget(
      wrap(
        KunTab(
          items: homeDocs,
          value: 'home',
          color: KunUIColor.neutral,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(resolvedOf(tester, 'Home').color, KunColors.light.foreground);
  });

  testWidgets('indicator rect and decoration follow the selected tab',
      (tester) async {
    Future<void> pumpVariant(KunTabVariant variant,
        {KunTabOrientation orientation = KunTabOrientation.horizontal}) async {
      await tester.pumpWidget(
        wrap(
          _Host(
            items: homeDocsSettings,
            variant: variant,
            orientation: orientation,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpVariant(KunTabVariant.underlined);
    Rect tab = tester.getRect(tabOf('home'));
    Rect bar = tester.getRect(indicator);
    expect(bar.height, 2);
    expect(bar.left, tab.left);
    expect(bar.width, tab.width);
    expect(bar.bottom, tester.getRect(find.byType(KunTab)).bottom);
    expect(indicatorDecoration(tester)!.color, KunColors.light.primary.solid);
    expect(
      indicatorDecoration(tester)!.borderRadius,
      BorderRadius.circular(KunRadius.full),
    );

    await pumpVariant(
      KunTabVariant.underlined,
      orientation: KunTabOrientation.vertical,
    );
    tab = tester.getRect(tabOf('home'));
    bar = tester.getRect(indicator);
    expect(bar.width, 2);
    expect(bar.top, tab.top);
    expect(bar.height, tab.height);
    expect(bar.left, tester.getRect(tabOf('home')).left);

    await pumpVariant(KunTabVariant.solid);
    expect(tester.getRect(indicator), tester.getRect(tabOf('home')));
    expect(indicatorDecoration(tester)!.color, KunColors.light.primary.solid);
    expect(
      indicatorDecoration(tester)!.borderRadius,
      BorderRadius.circular(KunRadius.md),
    );

    await pumpVariant(KunTabVariant.bordered);
    expect(tester.getRect(indicator), tester.getRect(tabOf('home')));
    expect(indicatorDecoration(tester)!.color, isNull);
    expect(indicatorDecoration(tester)!.border!.top.width, 1);
    expect(
      indicatorDecoration(tester)!.border!.top.color,
      KunColors.light.primary.solid,
    );

    await pumpVariant(KunTabVariant.light);
    expect(tester.getRect(indicator), tester.getRect(tabOf('home')));
    expect(
      indicatorDecoration(tester)!.color,
      KunColors.light.primary.solid.withValues(alpha: 0.15),
    );

    await pumpVariant(KunTabVariant.pills);
    expect(tester.getRect(indicator), tester.getRect(tabOf('home')));
    expect(
      indicatorDecoration(tester)!.borderRadius,
      BorderRadius.circular(KunRadius.full),
    );

    await tester.pumpWidget(
      wrap(_Host(key: UniqueKey(), items: homeDocsSettings)),
    );
    await tester.pumpAndSettle();
    final double from = tester.getRect(indicator).left;
    final double to = tester.getRect(tabOf('docs')).left;
    await tester.tap(find.text('Docs'));
    await tester.pump();
    await tester.pump();
    await tester.pump(KunDurations.base ~/ 2);
    final double mid = tester.getRect(indicator).left;
    expect(mid, greaterThan(from));
    expect(mid, lessThan(to));
    await tester.pumpAndSettle();
    expect(tester.getRect(indicator).left, tester.getRect(tabOf('docs')).left);

    await tester.pumpWidget(
      wrap(
        _Host(
          key: UniqueKey(),
          items: homeDocsSettings,
          disableAnimation: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump();
    expect(
      tester.getRect(indicator).left,
      tester.getRect(tabOf('settings')).left,
    );
    expect(
      tester.getRect(indicator).width,
      tester.getRect(tabOf('settings')).width,
    );

    await tester.pumpWidget(
      wrap(
        KunTab(
          items: const [
            KunTabItem(value: 'home', textValue: 'Hi'),
            KunTabItem(value: 'docs', textValue: 'Docs'),
          ],
          value: 'home',
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final double shortWidth = tester.getRect(indicator).width;
    await tester.pumpWidget(
      wrap(
        KunTab(
          items: const [
            KunTabItem(value: 'home', textValue: 'HomeHomeHome'),
            KunTabItem(value: 'docs', textValue: 'Docs'),
          ],
          value: 'home',
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.getRect(indicator).width, greaterThan(shortWidth));
    expect(
        tester.getRect(indicator).width, tester.getRect(tabOf('home')).width);

    await tester.pumpWidget(
      wrap(
        KunTab(
          items: homeDocs,
          value: 'missing',
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(indicator, findsNothing);
  });

  testWidgets('first frame paints a fallback, then the indicator takes over',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        KunTab(
          key: UniqueKey(),
          items: homeDocs,
          value: 'home',
          variant: KunTabVariant.solid,
          onChanged: (_) {},
        ),
      ),
    );
    expect(indicator, findsNothing);
    expect(fallback, findsOneWidget);
    expect(
      tester.widget<Container>(fallback).decoration,
      isA<BoxDecoration>().having(
        (BoxDecoration d) => d.color,
        'color',
        KunColors.light.primary.solid,
      ),
    );
    await tester.pump();
    expect(fallback, findsNothing);
    expect(indicator, findsOneWidget);

    await tester.pumpWidget(
      wrap(
        KunTab(
          key: UniqueKey(),
          items: homeDocs,
          value: 'home',
          onChanged: (_) {},
        ),
      ),
    );
    expect(indicator, findsNothing);
    expect(fallback, findsOneWidget);
    final BoxDecoration fg = tester
        .widget<Container>(fallback)
        .foregroundDecoration! as BoxDecoration;
    expect(fg.border!.bottom.width, 2);
    await tester.pump();
    expect(fallback, findsNothing);
    expect(indicator, findsOneWidget);
  });

  testWidgets('keyboard moves relative to the selection and wraps',
      (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });

    final seen = <String>[];
    const items = <KunTabItem>[
      KunTabItem(value: 'A', textValue: 'A'),
      KunTabItem(value: 'B', textValue: 'B', disabled: true),
      KunTabItem(value: 'C', textValue: 'C'),
      KunTabItem(value: 'D', textValue: 'D'),
    ];
    await tester.pumpWidget(
      wrapWebKeys(
        _Host(
          items: items,
          initial: 'A',
          onChanged: seen.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(seen, ['C']);
    expect(
      tester
          .widget<Focus>(
            find.descendant(of: tabOf('C'), matching: find.byType(Focus)),
          )
          .focusNode!
          .hasFocus,
      isTrue,
    );

    seen.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(seen, ['D']);

    seen.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(seen, ['A']);

    seen.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(seen, ['D']);

    seen.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(seen, ['A']);

    seen.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(seen, ['D']);

    await tester.pumpWidget(
      wrapWebKeys(
        _Host(
          items: items,
          initial: 'A',
          orientation: KunTabOrientation.vertical,
          onChanged: seen.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pump();
    seen.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(seen, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(seen, ['C']);
    seen.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(seen, ['A']);

    await tester.pumpWidget(
      wrapWebKeys(
        KunTab(
          items: items,
          value: 'A',
          onChanged: seen.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    seen.clear();
    await tester.tap(find.text('C'));
    await tester.pump();
    expect(seen, ['C']);
    seen.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(seen, ['C']);

    seen.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(seen, ['C']);

    seen.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pump();
    expect(seen, ['C']);

    await tester.pumpWidget(
      wrapWebKeys(
        KunTab(
          items: items,
          value: 'A',
          disabled: true,
          onChanged: seen.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    seen.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(seen, isEmpty);
  });

  testWidgets('tab from a widget before the strip lands on the selected tab',
      (tester) async {
    final FocusNode before = FocusNode();
    final FocusNode after = FocusNode();
    addTearDown(before.dispose);
    addTearDown(after.dispose);
    await tester.pumpWidget(
      wrapTraversal(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(
              focusNode: before,
              child: const SizedBox(width: 10, height: 10),
            ),
            KunTab(
              items: homeDocsSettings,
              value: 'docs',
              onChanged: (_) {},
            ),
            Focus(
              focusNode: after,
              child: const SizedBox(width: 10, height: 10),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    before.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester
          .widget<Focus>(
            find.descendant(of: tabOf('docs'), matching: find.byType(Focus)),
          )
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(after.hasFocus, isTrue);
  });

  testWidgets(
      'horizontal overflow fades, chevrons and keeps the selection in view',
      (tester) async {
    final items = <KunTabItem>[
      for (int i = 1; i <= 12; i++)
        KunTabItem(value: 's$i', textValue: '分区 $i'),
    ];
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 200,
          child: _Host(items: items, initial: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(KunTab)).width, 200);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .maxScrollExtent,
      greaterThan(0),
    );
    expect(find.byIcon(KunIcons.chevronRight), findsOneWidget);
    expect(find.byIcon(KunIcons.chevronLeft), findsNothing);
    expect(find.byType(ShaderMask), findsOneWidget);
    final BoxDecoration chevron = tester
        .widget<Container>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('KunTab.chevron.right')),
            matching: find.byType(Container),
          ),
        )
        .decoration! as BoxDecoration;
    expect(chevron.color!.a, closeTo(0.56, 1e-6));
    expect(
      chevron.color,
      KunColors.light.background.withValues(alpha: 0.7 * 0.8),
    );
    expect(
      (chevron.border! as Border).top.color,
      KunColors.light.neutral.shade100,
    );
    expect(chevron.boxShadow, isNull);
    final KunOuterShadowDecoration chevronShadow = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('KunTab.chevron.right')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((DecoratedBox box) => box.decoration)
        .whereType<KunOuterShadowDecoration>()
        .single;
    expect(chevronShadow.shadows, KunShadows.sm);
    expect(chevronShadow.shape, BoxShape.circle);

    await tester
        .tap(find.byKey(const ValueKey<String>('KunTab.chevron.right')));
    await tester.pumpAndSettle();
    final ScrollPosition afterChevron =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(afterChevron.viewportDimension, 200);
    expect(afterChevron.pixels, closeTo(160, 0.5));
    expect(find.byIcon(KunIcons.chevronRight), findsOneWidget);
    expect(find.byIcon(KunIcons.chevronLeft), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 200,
          child: _Host(
            items: items,
            initial: 's1',
            scrollButtons: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(KunIcons.chevronRight), findsNothing);
    expect(find.byIcon(KunIcons.chevronLeft), findsNothing);
    expect(find.byType(ShaderMask), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 200,
          child: _Host(key: UniqueKey(), items: items, initial: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ScrollPosition toLast =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    toLast.jumpTo(toLast.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('分区 12'));
    await tester.pumpAndSettle();
    final Rect last = tester.getRect(tabOf('s12'));
    final Rect strip = tester.getRect(find.byType(KunTab));
    expect(last.right, lessThanOrEqualTo(strip.right + 0.5));
    final double spare = strip.right - last.right;
    final ScrollPosition afterSelect =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(
      spare >= 44 - 0.5 ||
          afterSelect.pixels >= afterSelect.maxScrollExtent - 0.5,
      isTrue,
    );

    await tester.pumpWidget(
      wrap(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 200,
            child: KunTab(
              items: items,
              value: 's1',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      0,
    );
    await tester.pumpWidget(
      wrap(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 200,
            child: KunTab(
              items: items,
              value: 's12',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );

    await tester.pumpWidget(
      wrap(
        KunTab(
          items: homeDocs,
          value: 'home',
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byIcon(KunIcons.chevronRight), findsNothing);
    expect(find.byIcon(KunIcons.chevronLeft), findsNothing);
  });

  testWidgets('layout: fullWidth packs at the start; vertical stretches',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 400,
          child: KunTab(
            items: homeDocs,
            value: 'home',
            fullWidth: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(KunTab)).width, 400);
    expect(
      tester.getRect(tabOf('home')).left,
      tester.getRect(find.byType(KunTab)).left,
    );

    await tester.pumpWidget(
      wrap(
        KunTab(
          items: const [
            KunTabItem(value: 'home', textValue: 'Home'),
            KunTabItem(value: 'docs', textValue: 'Documentation'),
          ],
          value: 'home',
          orientation: KunTabOrientation.vertical,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(tabOf('home')).width,
      tester.getSize(tabOf('docs')).width,
    );

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 400,
          child: KunTab(
            items: homeDocs,
            value: 'home',
            orientation: KunTabOrientation.vertical,
            fullWidth: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(KunTab)).width, 400);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          height: 60,
          child: KunTab(
            items: const [
              KunTabItem(value: 'a', textValue: 'Alpha'),
              KunTabItem(value: 'b', textValue: 'Beta'),
              KunTabItem(value: 'c', textValue: 'Gamma'),
            ],
            value: 'a',
            orientation: KunTabOrientation.vertical,
            scrollable: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scrollable>(find.byType(Scrollable)).axisDirection,
      AxisDirection.down,
    );
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .maxScrollExtent,
      greaterThan(0),
    );

    final FlutterExceptionHandler? old = FlutterError.onError;
    var overflowed = false;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.toString().contains('overflowed')) {
        overflowed = true;
        return;
      }
      old?.call(details);
    };
    addTearDown(() => FlutterError.onError = old);
    await tester.pumpWidget(
      wrap(
        SizedBox(
          height: 60,
          child: KunTab(
            items: const [
              KunTabItem(value: 'a', textValue: 'Alpha'),
              KunTabItem(value: 'b', textValue: 'Beta'),
              KunTabItem(value: 'c', textValue: 'Gamma'),
            ],
            value: 'a',
            orientation: KunTabOrientation.vertical,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Scrollable), findsNothing);
    expect(overflowed || tester.takeException() != null, isTrue);
  });

  testWidgets('assistive technology sees a tab bar of tabs', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 200,
          child: KunTab(
            items: const [
              KunTabItem(value: 'home', textValue: 'Home'),
              KunTabItem(value: 'docs', textValue: 'Docs', disabled: true),
              KunTabItem(value: 'more', textValue: 'More'),
            ],
            value: 'home',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    SemanticsNode? tabBar;
    void walk(SemanticsNode node) {
      if (node.getSemanticsData().role == SemanticsRole.tabBar) {
        tabBar = node;
      }
      node.visitChildren((SemanticsNode child) {
        walk(child);
        return true;
      });
    }

    final SemanticsNode root = tester
        .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;
    walk(root);
    expect(tabBar, isNotNull);
    final List<SemanticsNode> tabs = <SemanticsNode>[];
    tabBar!.visitChildren((SemanticsNode child) {
      tabs.add(child);
      return true;
    });
    expect(tabs.length, 3);
    expect(
        tabs.every((SemanticsNode n) =>
            n.getSemanticsData().role == SemanticsRole.tab),
        isTrue);
    expect(tabs[0].getSemanticsData().label, 'Home');
    expect(
      tabs[0].getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tabs[1].getSemanticsData().flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    expect(tabs[1].getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(find.byIcon(KunIcons.chevronRight), findsOneWidget);
    bool chevronNode = false;
    void walkAll(SemanticsNode node) {
      final String label = node.getSemanticsData().label;
      if (label.contains('chevron') || label.contains('Chevron')) {
        chevronNode = true;
      }
      node.visitChildren((SemanticsNode child) {
        walkAll(child);
        return true;
      });
    }

    walkAll(root);
    expect(chevronNode, isFalse);
    semantics.dispose();
  });

  testWidgets(
      'tabBuilder receives the subclass field and active, in the tab colour',
      (tester) async {
    const items = <_CountItem>[
      _CountItem(value: 'home', textValue: 'Home', unread: 3),
      _CountItem(value: 'docs', textValue: 'Docs', unread: 0),
    ];
    await tester.pumpWidget(
      wrap(
        KunTab<_CountItem>(
          items: items,
          value: 'home',
          onChanged: (_) {},
          tabBuilder:
              (BuildContext context, _CountItem item, int index, bool active) {
            return Text('${item.textValue} ${item.unread} $active');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home 3 true'), findsOneWidget);
    expect(find.text('Docs 0 false'), findsOneWidget);
    expect(
      resolvedOf(tester, 'Home 3 true').color,
      KunColors.light.primary.solid,
    );
  });

  testWidgets('the indicator follows a relayout that rebuilds nothing',
      (tester) async {
    final Widget column = KunTab(
      items: homeDocsSettings,
      value: 'home',
      variant: KunTabVariant.solid,
      orientation: KunTabOrientation.vertical,
      fullWidth: true,
    );
    Widget sized(double width) => wrap(SizedBox(width: width, child: column));
    await tester.pumpWidget(sized(200));
    await tester.pumpAndSettle();
    await tester.pumpWidget(sized(300));
    await tester.pumpAndSettle();
    expect(tester.getSize(tabOf('home')).width, greaterThan(250));
    expect(tester.getRect(indicator), tester.getRect(tabOf('home')));

    final Widget row = KunTab(
      items: homeDocsSettings,
      value: 'docs',
      variant: KunTabVariant.solid,
    );
    Widget scaled(double factor) => MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(factor)),
          child: wrap(row),
        );
    await tester.pumpWidget(scaled(1));
    await tester.pumpAndSettle();
    final Rect before = tester.getRect(tabOf('docs'));
    await tester.pumpWidget(scaled(2));
    await tester.pumpAndSettle();
    expect(tester.getRect(tabOf('docs')), isNot(before));
    expect(tester.getRect(indicator), tester.getRect(tabOf('docs')));

    final Widget strip = KunTab(
      items: <KunTabItem>[
        for (int i = 1; i <= 6; i++)
          KunTabItem(value: 's$i', textValue: '分区 $i'),
      ],
      value: 's1',
    );
    Widget wide(double width) => wrap(SizedBox(width: width, child: strip));
    await tester.pumpWidget(wide(200));
    await tester.pumpAndSettle();
    expect(find.byIcon(KunIcons.chevronRight), findsOneWidget);
    await tester.pumpWidget(wide(800));
    await tester.pumpAndSettle();
    expect(find.byIcon(KunIcons.chevronRight), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('reduced motion jumps the indicator and the text colour',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: wrap(const _Host(items: homeDocsSettings)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Docs'));
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(indicator).left, tester.getRect(tabOf('docs')).left);
    expect(resolvedOf(tester, 'Docs').color, KunColors.light.primary.solid);
    expect(resolvedOf(tester, 'Home').color, KunColors.light.neutral.shade500);
  });

  testWidgets('a selection past the edge starts scrolled into view',
      (tester) async {
    final items = <KunTabItem>[
      for (int i = 1; i <= 12; i++)
        KunTabItem(value: 's$i', textValue: '分区 $i'),
    ];
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 200,
          child: KunTab(items: items, value: 's12'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ScrollPosition position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, position.maxScrollExtent);
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets(
      'focus traversal inside an outer scroll view scrolls the strip '
      'by its own geometry', (tester) async {
    final items = <KunTabItem>[
      for (int i = 1; i <= 12; i++)
        KunTabItem(value: 's$i', textValue: '分区 $i'),
    ];
    final FocusNode before = FocusNode();
    addTearDown(before.dispose);
    await tester.pumpWidget(
      wrapTraversal(
        ListView(
          children: <Widget>[
            const SizedBox(height: 900),
            Focus(focusNode: before, child: const SizedBox(height: 10)),
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                child: KunTab(items: items, value: 's1'),
              ),
            ),
            const SizedBox(height: 900),
          ],
        ),
      ),
    );
    final Finder strip = find.descendant(
      of: find.byType(KunTab),
      matching: find.byType(Scrollable),
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(600);
    await tester.pumpAndSettle();
    before.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(strip).position.pixels, 0);
  });
}
