import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui_gallery/main.dart';
import 'package:kun_ui_gallery/src/registry.dart';
import 'package:kun_ui_gallery/src/registry.g.dart';

/// Components the touch-target sweep has not reached yet. Each one leaves
/// this set in the change that pads it.
const Set<String> pending = <String>{
  'kunautocomplete',
  'kunbadge',
  'kunchatbubble',
  'kunchatcomposer',
  'kunchatheader',
  'kunchatlayout',
  'kunchatmessagelist',
  'kunchatpinnedbar',
  'kunchatreactionpicker',
  'kunchattext',
  'kuncheckbox',
  'kuncheckboxgroup',
  'kunchip',
  'kundatepicker',
  'kuninput',
  'kunloading',
  'kunradiogroup',
  'kunreaction',
  'kunselect',
  'kunswitch',
  'kuntab',
  'kuntooltip',
};

/// Demos that stay below the minimum by decision, with the reason.
const Map<String, String> exempt = <String, String>{};

void main() {
  for (final GalleryComponent component in galleryComponents) {
    if (pending.contains(component.slug)) continue;
    for (final GalleryDemo demo in component.demos) {
      final String path = '${component.slug}/${demo.slug}';
      if (exempt.containsKey(path)) continue;
      testWidgets(
        path,
        (WidgetTester tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          tester.view.physicalSize = const Size(1024, 3000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          tester.binding.platformDispatcher.defaultRouteNameTestValue =
              '/$path';
          addTearDown(
            tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
          );
          await tester.pumpWidget(const GalleryApp());
          await tester.pump(const Duration(milliseconds: 500));
          await expectLater(
            tester,
            meetsGuideline(
              defaultTargetPlatform == TargetPlatform.iOS
                  ? iOSTapTargetGuideline
                  : androidTapTargetGuideline,
            ),
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(minutes: 1));
          handle.dispose();
        },
        variant: const TargetPlatformVariant(
          <TargetPlatform>{TargetPlatform.android, TargetPlatform.iOS},
        ),
      );
    }
  }
}
