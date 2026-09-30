import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
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

/// Demos that stay below the minimum by decision, with the reason. Their
/// tappable nodes are still checked for a label.
const Map<String, String> exempt = <String, String>{
  'kunchatbubble/reply': 'reply quote inside the bubble',
  'kunchatbubble/status': 'retry button inside the bubble',
  'kunchatbubble/reactions': 'reaction chips inside the bubble',
  'kunchatbubble/many': 'reaction chips inside the bubble',
  'kunchatmessagelist/group':
      'message row, avatar, sender name, reaction chip and retry nodes',
  'kunchatmessagelist/paging': 'reply quote and reaction chip in a message',
  'kunchatmessagelist/thousands': 'reaction chip in a message',
  'kunchatreactionpicker/basic': 'reaction picker items (popup content)',
  'kunchattext/basic': 'code-block copy button in chat text',
  'kunchattext/spoiler': 'spoiler in chat text',
};

// The SDK's guideline skips every link, after WCAG's exception for a link
// in a sentence. That hid a linked KunAvatar drawn at 24dp: a standalone
// link has no sentence to excuse it. A link span in text keeps the
// exception, and it is the only link node with a key, which RenderParagraph
// and RenderEditable give each span they assemble.
class _LinkTapTargetGuideline extends MinimumTapTargetGuideline {
  const _LinkTapTargetGuideline({required super.size, required super.link});

  @override
  bool shouldSkipNode(SemanticsNode node) {
    final SemanticsData data = node.getSemanticsData();
    return (!data.hasAction(SemanticsAction.tap) &&
            !data.hasAction(SemanticsAction.longPress)) ||
        data.flagsCollection.isHidden ||
        (data.flagsCollection.isLink && node.key != null);
  }
}

const _LinkTapTargetGuideline _android = _LinkTapTargetGuideline(
  size: Size(48, 48),
  link: 'https://support.google.com/accessibility/android/answer/7101858',
);

const _LinkTapTargetGuideline _iOS = _LinkTapTargetGuideline(
  size: Size(44, 44),
  link: 'https://developer.apple.com/design/human-interface-guidelines/buttons',
);

void main() {
  for (final GalleryComponent component in galleryComponents) {
    for (final GalleryDemo demo in component.demos) {
      final String path = '${component.slug}/${demo.slug}';
      if (skipped.containsKey(path)) continue;
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
          if (!exempt.containsKey(path)) {
            await expectLater(
              tester,
              meetsGuideline(
                defaultTargetPlatform == TargetPlatform.iOS ? _iOS : _android,
              ),
            );
          }
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
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
