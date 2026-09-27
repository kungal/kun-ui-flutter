import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';

/// Direct or group conversation, the web's `KunChatKind`.
enum KunChatKind {
  /// A one-to-one chat. Typing says "typing…" without a name.
  direct,

  /// A group. Typing names who is typing.
  group,
}

/// A link tap in chat text. Call [preventDefault] to stop the widget from
/// handing [url] to [KunUIConfig.navigateTo].
class KunChatLinkEvent {
  /// Creates a link event for [url].
  KunChatLinkEvent(this.url);

  /// The accepted href.
  final String url;

  bool _defaultPrevented = false;

  /// Whether [preventDefault] has been called.
  bool get defaultPrevented => _defaultPrevented;

  /// Cancels the widget's default navigation.
  void preventDefault() => _defaultPrevented = true;
}

/// A tap on a user: a mention, or a sender name. Call [preventDefault] to
/// stop the widget from navigating to the user's profile.
class KunChatUserEvent {
  /// Creates a user event for [userId].
  KunChatUserEvent(this.userId);

  /// The user's id.
  final String userId;

  bool _defaultPrevented = false;

  /// Whether [preventDefault] has been called.
  bool get defaultPrevented => _defaultPrevented;

  /// Cancels the widget's default navigation.
  void preventDefault() => _defaultPrevented = true;
}

/// Called when a chat link is tapped.
typedef KunChatLinkCallback = void Function(KunChatLinkEvent event);

/// Called when a chat user is tapped: a mention, or a sender name.
typedef KunChatUserCallback = void Function(KunChatUserEvent event);

/// Reaction art at [size]. Empty or failed [imageUrl] draws [emoji] in the
/// same box so Flutter's error box never reaches the screen or the
/// semantics tree.
Widget kunChatReactionArt({
  required BuildContext context,
  required double size,
  required String emoji,
  String? imageUrl,
  TextStyle? style,
}) {
  final Widget fallback = ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          emoji,
          style: (style ?? KunText.xl2).copyWith(
            height: 1,
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      ),
    ),
  );
  if (imageUrl == null || imageUrl.isEmpty) {
    return fallback;
  }
  return Image(
    image: KunUIConfigScope.of(context).imageProvider(imageUrl),
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
    frameBuilder: (
      BuildContext context,
      Widget child,
      int? frame,
      bool wasSynchronouslyLoaded,
    ) {
      return wasSynchronouslyLoaded || frame != null ? child : fallback;
    },
    errorBuilder: (
      BuildContext context,
      Object error,
      StackTrace? stackTrace,
    ) {
      // A missing errorBuilder paints Flutter's debug error box and puts
      // the exception in the semantics tree.
      return fallback;
    },
  );
}
