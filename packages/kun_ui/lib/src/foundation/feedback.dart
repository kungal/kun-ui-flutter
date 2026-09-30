import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Platform feedback for a long press that acts, matching
/// `material/ink_well.dart` calling [Feedback.forLongPress].
///
/// No-op when [KunThemeData.enableFeedback] is false, and on Linux, macOS
/// and Windows (via [Feedback.forLongPress] itself).
void kunLongPressFeedback(BuildContext context) {
  if (!KunTheme.of(context).enableFeedback) {
    return;
  }
  Feedback.forLongPress(context);
}

/// Platform feedback when a [KunSwitch] changes value by user action,
/// matching `cupertino/switch.dart` `_emitVibration`: a light impact on
/// iOS, nothing elsewhere.
void kunSwitchChangeFeedback(BuildContext context) {
  if (!KunTheme.of(context).enableFeedback) {
    return;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      HapticFeedback.lightImpact();
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      break;
  }
}

/// Platform feedback when a [KunRefreshIndicator] pull crosses the arm
/// threshold, matching `cupertino/refresh.dart`: a medium impact on iOS,
/// nothing elsewhere. A keyboard- or [KunRefreshIndicatorState.show]
/// triggered refresh must not call this.
void kunRefreshArmFeedback(BuildContext context) {
  if (!KunTheme.of(context).enableFeedback) {
    return;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      HapticFeedback.mediumImpact();
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      break;
  }
}
