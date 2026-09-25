import 'package:flutter/widgets.dart';

import '../components/scrollbar.dart';

/// How KunUI scrollables overscroll and whether they grow a scrollbar.
///
/// Physics stay [ScrollBehavior]'s: bouncing on iOS and macOS, clamping
/// everywhere else. The mouse is not added to [dragDevices] — the web never
/// drag-scrolls with a mouse, and `KunScrollShadow(draggable: true)` is the
/// opt-in.
///
/// On Android and Fuchsia the overscroll indicator is Material 3's
/// [StretchingOverscrollIndicator]. Desktop platforms get a [KunScrollbar]
/// wherever [ScrollBehavior.buildScrollbar] would have built a
/// [RawScrollbar].
class KunScrollBehavior extends ScrollBehavior {
  /// Creates the KunUI scroll behavior.
  const KunScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (getPlatform(context)) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return StretchingOverscrollIndicator(
          axisDirection: details.direction,
          clipBehavior: details.decorationClipBehavior ?? Clip.hardEdge,
          child: child,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return child;
    }
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        assert(details.controller != null);
        return KunScrollbar(controller: details.controller, child: child);
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}
