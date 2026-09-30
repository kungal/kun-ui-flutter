import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../chat/grouping.dart';
import '../chat/support.dart';
import '../chat/types.dart';
import '../config/config.dart';
import '../foundation/motion.dart';
import '../foundation/tap_target.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'avatar.dart';
import 'chat_bubble.dart';
import 'chat_message_menu.dart';
import 'chat_shared.dart';
import 'lightbox.dart';
import 'message.dart';
import 'spinner.dart';

part 'chat_message_list_state.dart';
part 'chat_message_list_rows.dart';

/// Web `bg-default/30` on the swipe icon in `ChatMessageList.vue:919`.
const double _kSwipeIconFill = 0.3;

/// Web `BOTTOM_THRESHOLD` in `ChatMessageList.vue:156`.
const double _kBottomThreshold = 50;

/// Web `EDGE_MARGIN` in `ChatMessageList.vue:326`.
const double _kEdgeMargin = 800;

/// Web unread divider offset in `ChatMessageList.vue:297-298`.
const double _kUnreadTop = 10;

/// Web `offsetToShow` margin in `ChatMessageList.vue:251-254`.
const double _kJumpMargin = 20;

/// Web `SWIPE_MAX` in `ChatMessageList.vue:604`.
const double _kSwipeMax = 64;

/// Web `SWIPE_TRIGGER` in `ChatMessageList.vue:605`.
const double _kSwipeTrigger = 48;

/// Web `AXIS_LOCK` in `ChatMessageList.vue:606`.
const double _kAxisLock = 20;

/// Web `EDGE_GUARD` in `ChatMessageList.vue:607`.
const double _kEdgeGuard = 30;

/// Web `LONG_PRESS_MS` in `ChatMessageList.vue:608`.
const Duration _kLongPress = Duration(milliseconds: 450);

/// Web cancel slop in `ChatMessageList.vue:662`.
const double _kPressSlop = 8;

/// Web flash length in `ChatMessageList.vue:288` and `:1008`.
const Duration _kFlash = Duration(milliseconds: 1500);

/// Web `oklch(var(--primary-500) / 0.18)` in `ChatMessageList.vue:1014`.
const double _kFlashAlpha = 0.18;

/// Web `ease-out` on the flash in `ChatMessageList.vue:1009`.
const Cubic _kFlashEase = Cubic(0, 0, 0.58, 1);

/// Web reduced-motion outline in `ChatMessageList.vue:1023`.
const double _kFlashOutlineAlpha = 0.5;

/// Web outline width in `ChatMessageList.vue:1023`.
const double _kFlashOutline = 2;

/// Web `contain-intrinsic-size: auto 64px` in `ChatMessageList.vue:997`.
const double _kIntrinsicRow = 64;

/// Web announcement cap in `ChatMessageList.vue:479`.
const int _kAnnounceCap = 3;

/// Web badge cap in `ChatMessageList.vue:961`.
const int _kFabBadgeCap = 999;

/// Web `bg-default/15` on the unread divider in `ChatMessageList.vue:825`.
const double _kUnreadFill = 0.15;

/// Web `focus-visible:bg-primary/10` in `ChatMessageList.vue:837`.
const double _kFocusFill = 0.1;

/// Web menu-at-row inset in `ChatMessageList.vue:749`.
const double _kMenuAtRowX = 16;

/// Web menu-at-row inset in `ChatMessageList.vue:749`.
const double _kMenuAtRowY = 8;

/// Opens, scrolls and reports whether a [KunChatMessageList] sits at the
/// newest message — the web `defineExpose` of `scrollToSeq`,
/// `scrollToBottom` and `atBottom`.
class KunChatMessageListController {
  _KunChatMessageListState? _state;
  final ValueNotifier<bool> _atBottom = ValueNotifier<bool>(true);

  /// Whether the viewport is within [50] px of the newest loaded message.
  ValueListenable<bool> get atBottom => _atBottom;

  /// Scrolls a loaded message into view and, by default, flashes it.
  ///
  /// Returns false when [seq] is not in the loaded [KunChatMessageList.messages];
  /// load around it and call again.
  bool scrollToSeq(
    int seq, {
    bool highlight = true,
    bool animate = true,
  }) {
    return _state?._scrollToSeq(
          seq,
          highlight: highlight,
          animate: animate,
        ) ??
        false;
  }

  /// Scrolls to the newest loaded message.
  void scrollToBottom({bool animate = false}) {
    _state?._scrollToBottom(animate: animate);
  }

  /// Releases [atBottom]. Call if this controller is created by the app.
  void dispose() {
    _atBottom.dispose();
  }

  void _attach(_KunChatMessageListState state) {
    _state = state;
  }

  void _detach(_KunChatMessageListState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }
}

/// The conversation view: a bottom-origin scroller of grouped bubbles,
/// day pills, an unread divider, a shared lightbox and a message menu.
///
/// Quote from a text selection is not ported yet. The web offers `quote`
/// only while text in the message is selected (`ChatMessageList.vue:544-552`),
/// so the menu here never offers it, as on a touch screen on the web.
class KunChatMessageList extends StatefulWidget {
  /// Creates a conversation view.
  const KunChatMessageList({
    super.key,
    required this.currentUserId,
    required this.messages,
    this.actions,
    this.semanticLabel,
    this.groupWindow = const Duration(minutes: 10),
    this.hasNewer = false,
    this.hasOlder = false,
    this.kind = KunChatKind.direct,
    this.lastReadSeq,
    this.loadingNewer = false,
    this.loadingOlder = false,
    this.peerReadSeq,
    this.reactionOptions = const <KunChatReactionOption>[],
    this.resolveMediaUrl,
    this.swipeToReply = true,
    this.unreadCount,
    this.users = const <KunChatUser>[],
    this.controller,
    this.empty,
    this.footer,
    this.start,
    this.onAction,
    this.onJump,
    this.onLatest,
    this.onLink,
    this.onLoadNewer,
    this.onLoadOlder,
    this.onMention,
    this.onReact,
    this.onRead,
    this.onRetry,
    this.onUserTap,
  });

  /// The viewer's id. Their messages sit on the right, and a pending send
  /// (`status: sending`) always scrolls to the bottom.
  final String currentUserId;

  /// Messages in display order, oldest first.
  final List<KunChatMessage> messages;

  /// Menu actions for a message. Null uses the web fallback of reply and
  /// copy (`ChatMessageList.vue:543`).
  final List<KunChatMessageAction> Function(
    KunChatMessage message,
    bool own,
  )? actions;

  /// Accessible name of the scroll region. Null uses `chat.messages`.
  final String? semanticLabel;

  /// Sender-group window, the web's 600 s.
  final Duration groupWindow;

  /// A newer page exists toward the live end.
  final bool hasNewer;

  /// An older page exists toward the start.
  final bool hasOlder;

  /// Direct or group. Group chats show names and avatars on others' runs.
  final KunChatKind kind;

  /// Last seq the viewer has read. Places the unread divider after it.
  final int? lastReadSeq;

  /// A newer page is in flight.
  final bool loadingNewer;

  /// An older page is in flight.
  final bool loadingOlder;

  /// Highest seq the peer has read. Colours own-message ticks.
  final int? peerReadSeq;

  /// Reaction vocabulary for chips and the menu.
  final List<KunChatReactionOption> reactionOptions;

  /// Turns a photo into a URL. Without it a photo shows its
  /// [KunChatPhoto.url].
  final KunChatMediaUrlResolver? resolveMediaUrl;

  /// Whether a touch swipe on a row emits `reply`.
  final bool swipeToReply;

  /// Unread badge on the scroll-down button. Null uses the local count.
  final int? unreadCount;

  /// Users the conversation refers to.
  final List<KunChatUser> users;

  /// Exposed `scrollToSeq` / `scrollToBottom` / `atBottom`.
  final KunChatMessageListController? controller;

  /// Shown when there are no messages. Null uses `chat.empty`.
  final Widget? empty;

  /// Below the last message, e.g. a typing bubble.
  final Widget? footer;

  /// Above the first message once there is no older history.
  final Widget? start;

  /// A menu action or a swipe (`reply`). `copy` has already been done.
  ///
  /// [quote] is always null until quoting a selection is ported.
  final void Function(
    String action,
    KunChatMessage message,
    KunChatReplyQuote? quote,
  )? onAction;

  /// A reply target that is not loaded was clicked.
  final ValueChanged<int>? onJump;

  /// The scroll-down button was pressed while [hasNewer].
  final VoidCallback? onLatest;

  /// A link in a message was tapped.
  final KunChatLinkCallback? onLink;

  /// Scrolled near the bottom while [hasNewer].
  final VoidCallback? onLoadNewer;

  /// Scrolled near the top while [hasOlder].
  final VoidCallback? onLoadOlder;

  /// A mention in a message was tapped.
  final KunChatUserCallback? onMention;

  /// A reaction was chosen or cleared.
  final void Function(KunChatMessage message, String? reaction)? onReact;

  /// Others' messages up to this seq have been on screen while the app was
  /// resumed. Only ever increases.
  final ValueChanged<int>? onRead;

  /// Resend a failed message.
  final ValueChanged<KunChatMessage>? onRetry;

  /// A sender's avatar or name was tapped.
  final KunChatUserCallback? onUserTap;

  /// How many times grouping has run; for tests of change detection.
  @visibleForTesting
  static int debugGroupComputations = 0;

  /// The scroller, for tests.
  @visibleForTesting
  static const Key scrollKey = ValueKey<String>('KunChatMessageList.scroll');

  /// The scroll-to-bottom button, for tests.
  @visibleForTesting
  static const Key fabKey = ValueKey<String>('KunChatMessageList.fab');

  /// The overlay day pill, for tests.
  @visibleForTesting
  static const Key stickyDayKey = ValueKey<String>(
    'KunChatMessageList.stickyDay',
  );

  /// The unread divider, for tests.
  @visibleForTesting
  static const Key unreadKey = ValueKey<String>('KunChatMessageList.unread');

  /// A row's key, for tests.
  @visibleForTesting
  static Key rowKey(String id) =>
      ValueKey<String>('KunChatMessageList.row.$id');

  /// An in-flow day pill, for tests.
  @visibleForTesting
  static Key dayKey(String day) =>
      ValueKey<String>('KunChatMessageList.day.$day');

  /// The older-history spinner, for tests.
  @visibleForTesting
  static const Key olderSpinnerKey = ValueKey<String>(
    'KunChatMessageList.olderSpinner',
  );

  /// The newer-history spinner, for tests.
  @visibleForTesting
  static const Key newerSpinnerKey = ValueKey<String>(
    'KunChatMessageList.newerSpinner',
  );

  @override
  State<KunChatMessageList> createState() => _KunChatMessageListState();
}

class _MoveFocusIntent extends Intent {
  const _MoveFocusIntent(this.delta)
      : home = false,
        end = false;

  const _MoveFocusIntent.home()
      : delta = 0,
        home = true,
        end = false;

  const _MoveFocusIntent.end()
      : delta = 0,
        home = false,
        end = true;

  final int delta;
  final bool home;
  final bool end;
}

class _OpenMenuIntent extends Intent {
  const _OpenMenuIntent();
}
