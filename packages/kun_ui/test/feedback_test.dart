import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
  bool enableFeedback = true,
}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(800, 600)),
    child: KunTheme(
      data: KunThemeData.light(enableFeedback: enableFeedback),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    ),
  );
}

Widget pressable({ValueChanged<Offset>? onLongPress}) {
  return KunPressable(
    onLongPress: onLongPress ?? (Offset _) {},
    builder: (BuildContext context, KunPressableState state) =>
        const SizedBox(width: 240, height: 56, child: Text('Row')),
  );
}

Widget refreshList({
  required Future<void> Function() onRefresh,
  GlobalKey<KunRefreshIndicatorState>? key,
}) {
  return KunRefreshIndicator(
    key: key,
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        for (final String label in <String>['A', 'B', 'C', 'D', 'E', 'F'])
          SizedBox(height: 200, child: Text(label)),
      ],
    ),
  );
}

List<MethodCall> mockPlatform(WidgetTester tester) {
  final List<MethodCall> log = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate' ||
          call.method == 'SystemSound.play') {
        log.add(call);
      }
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  return log;
}

Matcher get vibrate => isMethodCall('HapticFeedback.vibrate', arguments: null);

Matcher get heavyImpact => isMethodCall(
      'HapticFeedback.vibrate',
      arguments: 'HapticFeedbackType.heavyImpact',
    );

Matcher get lightImpact => isMethodCall(
      'HapticFeedback.vibrate',
      arguments: 'HapticFeedbackType.lightImpact',
    );

Matcher get mediumImpact => isMethodCall(
      'HapticFeedback.vibrate',
      arguments: 'HapticFeedbackType.mediumImpact',
    );

Matcher get clickSound => isMethodCall(
      'SystemSound.play',
      arguments: 'SystemSoundType.click',
    );

void main() {
  testWidgets(
    'KunPressable long press: Android vibrates',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<MethodCall> log = mockPlatform(tester);
      await tester.pumpWidget(wrap(pressable()));
      await tester.longPress(find.text('Row'));
      expect(log, <Matcher>[vibrate]);
      handle.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'KunPressable long press: iOS heavy impact and click',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<MethodCall> log = mockPlatform(tester);
      await tester.pumpWidget(wrap(pressable()));
      await tester.longPress(find.text('Row'));
      expect(log, <Matcher>[clickSound, heavyImpact]);
      handle.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'KunPressable long press: Linux is silent',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      await tester.pumpWidget(wrap(pressable()));
      await tester.longPress(find.text('Row'));
      expect(log, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'KunPressable long press: enableFeedback false is silent',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      await tester.pumpWidget(wrap(pressable(), enableFeedback: false));
      await tester.longPress(find.text('Row'));
      expect(log, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'KunSwitch: Android is silent',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      bool value = false;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return KunSwitch(
                value: value,
                onChanged: (bool next) => setState(() => value = next),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byType(KunSwitch));
      await tester.pump();
      expect(log, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'KunSwitch: iOS light impact',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      bool value = false;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return KunSwitch(
                value: value,
                onChanged: (bool next) => setState(() => value = next),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byType(KunSwitch));
      await tester.pump();
      expect(log, <Matcher>[lightImpact]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'KunSwitch: Linux is silent',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      bool value = false;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return KunSwitch(
                value: value,
                onChanged: (bool next) => setState(() => value = next),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byType(KunSwitch));
      await tester.pump();
      expect(log, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'KunSwitch: enableFeedback false is silent on iOS',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      bool value = false;
      await tester.pumpWidget(
        wrap(
          enableFeedback: false,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return KunSwitch(
                value: value,
                onChanged: (bool next) => setState(() => value = next),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byType(KunSwitch));
      await tester.pump();
      expect(log, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'KunRefreshIndicator pull arm: Android is silent',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      await tester.pumpWidget(
        wrap(refreshList(onRefresh: () async {})),
      );
      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.text('A')));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      expect(log, isEmpty);
      await gesture.up();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'KunRefreshIndicator pull arm: iOS medium impact',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      await tester.pumpWidget(
        wrap(refreshList(onRefresh: () async {})),
      );
      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.text('A')));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      expect(log, <Matcher>[mediumImpact]);
      await gesture.up();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'KunRefreshIndicator pull arm: Linux is silent',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      await tester.pumpWidget(
        wrap(refreshList(onRefresh: () async {})),
      );
      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.text('A')));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      expect(log, isEmpty);
      await gesture.up();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'KunRefreshIndicator pull arm: enableFeedback false is silent on iOS',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      await tester.pumpWidget(
        wrap(
          enableFeedback: false,
          refreshList(onRefresh: () async {}),
        ),
      );
      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.text('A')));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      expect(log, isEmpty);
      await gesture.up();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'KunRefreshIndicator.show is not a pull and does not fire',
    (WidgetTester tester) async {
      final List<MethodCall> log = mockPlatform(tester);
      final GlobalKey<KunRefreshIndicatorState> key =
          GlobalKey<KunRefreshIndicatorState>();
      await tester.pumpWidget(
        wrap(refreshList(key: key, onRefresh: () async {})),
      );
      unawaited(key.currentState!.show());
      await tester.pump();
      await tester.pump(KunDurations.fast);
      expect(log, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
