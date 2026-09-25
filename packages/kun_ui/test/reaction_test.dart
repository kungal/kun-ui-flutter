import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Finder get burst => find.byKey(const ValueKey<String>('KunReaction.burst'));

Widget wrap(Widget child, {bool reducedMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: KunTheme(
        data: KunThemeData.light(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: child),
        ),
      ),
    );

Widget wrapWebKeys(Widget child) => Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
      },
      child: wrap(child),
    );

KunReaction heart({
  bool value = false,
  ValueChanged<bool>? onChanged,
  int? count,
  ValueChanged<int>? onCountChanged,
  VoidCallback? onPressed,
  KunUIColor color = KunUIColor.danger,
  Color? activeColor,
  KunReactionSize size = KunReactionSize.md,
  bool toggle = true,
  bool disabled = false,
  bool disableAnimation = false,
  String? label,
  Widget? child,
  IconData icon = KunIcons.plus,
  Widget Function(BuildContext, bool)? iconBuilder,
}) {
  return KunReaction(
    value: value,
    onChanged: onChanged,
    count: count,
    onCountChanged: onCountChanged,
    onPressed: onPressed,
    color: color,
    activeColor: activeColor,
    size: size,
    toggle: toggle,
    disabled: disabled,
    disableAnimation: disableAnimation,
    label: label,
    icon: icon,
    iconBuilder: iconBuilder,
    child: child,
  );
}

Color iconColorOf(WidgetTester tester) {
  return IconTheme.of(tester.element(find.byType(Icon))).color!;
}

EdgeInsets paddingOf(WidgetTester tester) {
  return tester
      .widget<AnimatedContainer>(find.byType(AnimatedContainer))
      .padding as EdgeInsets;
}

double scaleOf(WidgetTester tester) {
  return tester
      .widget<ScaleTransition>(find.byType(ScaleTransition))
      .scale
      .value;
}

void main() {
  testWidgets('toggle on/off reports value and count, never below 0',
      (tester) async {
    bool? value;
    int? count;
    await tester.pumpWidget(
      wrap(
        heart(
          count: 128,
          onChanged: (bool next) => value = next,
          onCountChanged: (int next) => count = next,
        ),
      ),
    );

    await tester.tap(find.byType(KunReaction));
    expect(value, isTrue);
    expect(count, 129);

    await tester.pumpWidget(
      wrap(
        heart(
          value: true,
          count: 129,
          onChanged: (bool next) => value = next,
          onCountChanged: (int next) => count = next,
        ),
      ),
    );
    await tester.tap(find.byType(KunReaction));
    expect(value, isFalse);
    expect(count, 128);

    await tester.pumpWidget(
      wrap(
        heart(
          value: true,
          count: 0,
          onChanged: (bool next) => value = next,
          onCountChanged: (int next) => count = next,
        ),
      ),
    );
    await tester.tap(find.byType(KunReaction));
    expect(value, isFalse);
    expect(count, 0);
  });

  testWidgets('action mode calls only onPressed, keeps the count, never bursts',
      (tester) async {
    var presses = 0;
    var changes = 0;
    var counts = 0;
    await tester.pumpWidget(
      wrap(
        heart(
          toggle: false,
          count: 34,
          onChanged: (_) => changes++,
          onCountChanged: (_) => counts++,
          onPressed: () => presses++,
        ),
      ),
    );

    await tester.tap(find.byType(KunReaction));
    await tester.pump();
    expect(presses, 1);
    expect(changes, 0);
    expect(counts, 0);
    expect(find.text('34'), findsOneWidget);
    expect(burst, findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    expect(scaleOf(tester), greaterThan(1));
  });

  testWidgets('disabled does nothing and dims', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      wrap(
        heart(
          disabled: true,
          count: 3,
          onChanged: (_) => presses++,
          onCountChanged: (_) => presses++,
          onPressed: () => presses++,
        ),
      ),
    );

    await tester.tap(find.byType(KunReaction), warnIfMissed: false);
    await tester.pump();
    expect(presses, 0);
    expect(find.text('3'), findsOneWidget);
    expect(
      tester.widget<Opacity>(find.byType(Opacity).first).opacity,
      0.5,
    );
    expect(burst, findsNothing);
  });

  testWidgets('a null onChanged still animates and does not dim',
      (tester) async {
    await tester.pumpWidget(wrap(heart()));
    expect(
      tester.widget<Opacity>(find.byType(Opacity).first).opacity,
      1,
    );

    await tester.tap(find.byType(KunReaction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450) * 0.35);
    expect(scaleOf(tester), closeTo(1.35, 0.02));
    expect(burst, findsOneWidget);
    expect(
      tester.widget<Opacity>(find.byType(Opacity).first).opacity,
      1,
    );
  });

  testWidgets('inactive is neutral 500; on is the scale solid', (tester) async {
    await tester.pumpWidget(wrap(heart()));
    await tester.pumpAndSettle();
    expect(iconColorOf(tester), KunColors.light.neutral.shade500);

    await tester.pumpWidget(wrap(heart(value: true)));
    await tester.pumpAndSettle();
    expect(iconColorOf(tester), KunColors.light.danger.solid);
  });

  testWidgets('neutral paints foreground; activeColor wins', (tester) async {
    await tester.pumpWidget(
      wrap(heart(value: true, color: KunUIColor.neutral)),
    );
    await tester.pumpAndSettle();
    expect(iconColorOf(tester), KunColors.light.foreground);

    const Color brand = Color.from(alpha: 1, red: 1, green: 0, blue: 0);
    await tester.pumpWidget(
      wrap(
        heart(
          value: true,
          color: KunUIColor.primary,
          activeColor: brand,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(iconColorOf(tester), brand);
  });

  testWidgets('size paddings, type and icon sizes match the web sizeMap',
      (tester) async {
    const sizes =
        <KunReactionSize, ({EdgeInsets padding, double fontSize, double icon})>{
      KunReactionSize.sm: (
        padding: EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 1.5,
          vertical: KunSpacing.unit * 0.5,
        ),
        fontSize: 12,
        icon: 16,
      ),
      KunReactionSize.md: (
        padding: EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 2,
          vertical: KunSpacing.unit * 1,
        ),
        fontSize: 14,
        icon: 18.4,
      ),
      KunReactionSize.lg: (
        padding: EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 2.5,
          vertical: KunSpacing.unit * 1.5,
        ),
        fontSize: 16,
        icon: 22.4,
      ),
    };

    for (final MapEntry<KunReactionSize,
            ({EdgeInsets padding, double fontSize, double icon})> entry
        in sizes.entries) {
      await tester.pumpWidget(wrap(heart(size: entry.key, count: 1)));
      expect(paddingOf(tester), entry.value.padding, reason: entry.key.name);
      expect(
        tester.widget<Icon>(find.byType(Icon)).size,
        entry.value.icon,
        reason: '${entry.key.name} icon',
      );
      expect(
        tester.widget<Text>(find.text('1')).style!.fontSize,
        entry.value.fontSize,
        reason: '${entry.key.name} type',
      );
    }
  });

  testWidgets('the pop scale at 35% of 450 ms is 1.35', (tester) async {
    await tester.pumpWidget(wrap(heart(onChanged: (_) {})));
    await tester.tap(find.byType(KunReaction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450) * 0.35);
    expect(scaleOf(tester), closeTo(1.35, 0.02));
  });

  testWidgets(
      'the burst exists only after a toggle-on press and is gone after 500 ms',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        heart(
          value: true,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byType(KunReaction));
    await tester.pump();
    expect(burst, findsNothing, reason: 'toggle-off does not burst');

    await tester.pumpWidget(wrap(heart(onChanged: (_) {})));
    await tester.tap(find.byType(KunReaction));
    await tester.pump();
    expect(burst, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(burst, findsNothing);
  });

  testWidgets('the count rolls up on +1 and down on -1', (tester) async {
    late StateSetter setState;
    bool liked = false;
    int count = 128;
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) {
            setState = set;
            return heart(
              value: liked,
              count: count,
              onChanged: (bool next) => setState(() => liked = next),
              onCountChanged: (int next) => setState(() => count = next),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byType(KunReaction));
    await tester.pump();
    await tester.pump(KunDurations.base * 0.5);
    expect(find.text('128'), findsOneWidget);
    expect(find.text('129'), findsOneWidget);
    final List<double> up = tester
        .widgetList<FractionalTranslation>(find.byType(FractionalTranslation))
        .map((FractionalTranslation t) => t.translation.dy)
        .toList();
    expect(up, hasLength(2));
    expect(up[0].sign, isNot(up[1].sign));

    await tester.pumpAndSettle();
    expect(find.text('129'), findsOneWidget);
    expect(find.text('128'), findsNothing);

    await tester.tap(find.byType(KunReaction));
    await tester.pump();
    await tester.pump(KunDurations.base * 0.5);
    expect(find.text('129'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    final List<double> down = tester
        .widgetList<FractionalTranslation>(find.byType(FractionalTranslation))
        .map((FractionalTranslation t) => t.translation.dy)
        .toList();
    expect(down, hasLength(2));
    expect(down[0].sign, isNot(down[1].sign));
  });

  testWidgets(
      'the count swaps instantly under reduced motion and disableAnimation',
      (tester) async {
    late StateSetter setState;
    bool liked = false;
    int count = 128;

    Future<void> mount({required bool reduced, required bool disable}) async {
      liked = false;
      count = 128;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter set) {
              setState = set;
              return heart(
                value: liked,
                count: count,
                disableAnimation: disable,
                onChanged: (bool next) => setState(() => liked = next),
                onCountChanged: (int next) => setState(() => count = next),
              );
            },
          ),
          reducedMotion: reduced,
        ),
      );
    }

    await mount(reduced: true, disable: false);
    await tester.tap(find.byType(KunReaction));
    await tester.pump();
    expect(find.text('129'), findsOneWidget);
    expect(find.text('128'), findsNothing);
    expect(find.byType(FractionalTranslation), findsNothing);

    await mount(reduced: false, disable: true);
    await tester.tap(find.byType(KunReaction));
    await tester.pump();
    expect(find.text('129'), findsOneWidget);
    expect(find.text('128'), findsNothing);
    expect(find.byType(FractionalTranslation), findsNothing);
  });

  testWidgets('no pop or burst under reduced motion', (tester) async {
    await tester.pumpWidget(
      wrap(heart(onChanged: (_) {}), reducedMotion: true),
    );
    await tester.tap(find.byType(KunReaction));
    await tester.pump();
    expect(scaleOf(tester), 1);
    expect(burst, findsNothing);
    await tester.pump(const Duration(milliseconds: 450) * 0.35);
    expect(scaleOf(tester), 1);
    expect(burst, findsNothing);
  });

  testWidgets('semantics: button, toggled only in toggle mode, label,count',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(heart(count: 128, label: 'Like', onChanged: (_) {})),
    );
    expect(
      tester.getSemantics(find.byType(KunReaction)),
      isSemantics(
        isButton: true,
        hasToggledState: true,
        isToggled: false,
        label: 'Like,128',
        hasTapAction: true,
      ),
    );

    await tester.pumpWidget(
      wrap(
        heart(
          value: true,
          toggle: false,
          count: 12,
          label: 'Share',
          onPressed: () {},
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(KunReaction)),
      isSemantics(
        isButton: true,
        hasToggledState: false,
        label: 'Share,12',
      ),
    );

    await tester.pumpWidget(
      wrap(
        heart(
          count: 7,
          label: 'Like',
          onChanged: (_) {},
          child: const KunChip(child: Text('点赞')),
        ),
      ),
    );
    final SemanticsData data =
        tester.getSemantics(find.byType(KunReaction)).getSemanticsData();
    expect(data.label, contains('点赞'));
    expect(data.label.contains('7'), isFalse);
    semantics.dispose();
  });

  testWidgets('a slotted KunChip is part of the tap target', (tester) async {
    bool? value;
    await tester.pumpWidget(
      wrap(
        heart(
          onChanged: (bool next) => value = next,
          child: const KunChip(child: Text('点赞')),
        ),
      ),
    );
    await tester.tap(find.byType(KunChip));
    expect(value, isTrue);
  });

  testWidgets('Space and web Enter press a focused reaction', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      wrapWebKeys(heart(onChanged: (_) => presses++)),
    );
    Focus.of(tester.element(find.byType(Icon))).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(presses, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses, 2);
  });

  testWidgets('iconBuilder receives value', (tester) async {
    bool? seen;
    await tester.pumpWidget(
      wrap(
        heart(
          value: true,
          iconBuilder: (BuildContext context, bool active) {
            seen = active;
            return const SizedBox.square(dimension: 16);
          },
        ),
      ),
    );
    expect(seen, isTrue);
  });

  testWidgets('the default heart fills while on', (tester) async {
    await tester.pumpWidget(wrap(const KunReaction()));
    expect(tester.widget<Icon>(find.byType(Icon)).icon, KunIcons.heart);

    await tester.pumpWidget(wrap(const KunReaction(value: true)));
    expect(tester.widget<Icon>(find.byType(Icon)).icon, KunIcons.heartFilled);
  });

  testWidgets('a custom icon keeps its glyph unless activeIcon is set',
      (tester) async {
    await tester.pumpWidget(
      wrap(const KunReaction(value: true, icon: KunIcons.check)),
    );
    expect(tester.widget<Icon>(find.byType(Icon)).icon, KunIcons.check);

    await tester.pumpWidget(
      wrap(
        const KunReaction(
          value: true,
          icon: KunIcons.eye,
          activeIcon: KunIcons.eyeOff,
        ),
      ),
    );
    expect(tester.widget<Icon>(find.byType(Icon)).icon, KunIcons.eyeOff);

    await tester.pumpWidget(
      wrap(
        const KunReaction(icon: KunIcons.eye, activeIcon: KunIcons.eyeOff),
      ),
    );
    expect(tester.widget<Icon>(find.byType(Icon)).icon, KunIcons.eye);
  });
}
