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
