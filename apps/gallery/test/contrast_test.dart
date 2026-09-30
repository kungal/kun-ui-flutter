import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui_gallery/main.dart';
import 'package:kun_ui_gallery/src/registry.dart';
import 'package:kun_ui_gallery/src/registry.g.dart';

/// Demos the test cannot render, with the reason.
const Map<String, String> skipped = <String, String>{
  'kuntab/align': "its 160-wide columns (the web's w-40) overflow in the "
      'test font, which draws every glyph 1em wide',
};

/// Demos the guideline fails for a reason that is not a colour this repo
/// owns, with the reason.
///
/// Disabled text needs no entry: the guideline skips a node marked disabled.
/// A caption in a demo needs no entry either: demos draw secondary text in
/// `foregroundMuted`, as the library does.
const Map<String, String> exempt = <String, String>{
  // The guideline samples the text's box, which is larger than the fill.
  'kunbadge/colors': 'the count "5" measures 2.10:1 against the page behind '
      "the badge; onSolid on solid is at least 4.59:1 for every hue",
  'kunbadge/sizes': 'the sm count "5" at 10px measures 4.41:1 the same way',
  'kunchatbubble/basic': 'own-bubble "已编辑" measures 2.65:1 light and 3.86:1 '
      'dark; its pixels sample 6.80:1 and 5.78:1 on the bubble',
  // The guideline reads the merge boundary's own flags, not the merged ones.
  'kunnavitem/sidebar': 'the disabled item is disabled in its merged '
      'semantics, which is what TalkBack reads',
};

void main() {
  for (final GalleryComponent component in galleryComponents) {
    for (final GalleryDemo demo in component.demos) {
      final String path = '${component.slug}/${demo.slug}';
      if (skipped.containsKey(path)) {
        continue;
      }
      for (final String theme in <String>['light', 'dark']) {
        final String route = theme == 'dark' ? '/$path?theme=dark' : '/$path';
        testWidgets(
          '$path $theme',
          (WidgetTester tester) async {
            final SemanticsHandle handle = tester.ensureSemantics();
            tester.view.physicalSize = const Size(1024, 3000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            tester.binding.platformDispatcher.defaultRouteNameTestValue = route;
            addTearDown(
              tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
            );
            await tester.pumpWidget(const GalleryApp());
            await tester.pump(const Duration(milliseconds: 500));
            if (!exempt.containsKey(path)) {
              await expectLater(tester, meetsGuideline(textContrastGuideline));
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(minutes: 1));
            handle.dispose();
          },
        );
      }
    }
  }
}
