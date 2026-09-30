import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

const double _kFrameHeight = 36 * 16;

class _Conv {
  _Conv({
    required this.id,
    required this.kind,
    required this.messages,
    required this.lastReadSeq,
    required this.peerReadSeq,
  });

  final String id;
  final KunChatKind kind;
  List<KunChatMessage> messages;
  int lastReadSeq;
  int peerReadSeq;
}

class _LayoutAppDemo extends StatefulWidget {
  const _LayoutAppDemo();

  @override
  State<_LayoutAppDemo> createState() => _LayoutAppDemoState();
}

class _LayoutAppDemoState extends State<_LayoutAppDemo> {
  late final List<_Conv> _conversations;
  String? _openId = 'direct';
  String? _lastOpen = 'direct';
  double _sidebarSize = 320;
  String _draft = '';
  KunChatMessage? _replyTo;
  KunChatReplyQuote? _quote;
  KunChatMessage? _editing;
  List<KunChatTypingEvent> _typing = const <KunChatTypingEvent>[];
  final KunChatMessageListController _list = KunChatMessageListController();
  final List<Timer> _timers = <Timer>[];
  int _sent = 0;

  KunChatUser get _peer => demoUsers[1];

  @override
  void initState() {
    super.initState();
    _conversations = <_Conv>[
      _Conv(
        id: 'direct',
        kind: KunChatKind.direct,
        messages: <KunChatMessage>[
          for (final KunChatMessage message in makeDirectConversation())
            message.text.contains('主线是完整的') ||
                    (message.media is KunChatPhoto &&
                        message.text.contains('前作'))
                ? message.copyWith(pinnedAt: message.createdAt)
                : message,
        ],
        lastReadSeq: 16,
        peerReadSeq: 14,
      ),
      _Conv(
        id: 'group',
        kind: KunChatKind.group,
        messages: makeGroupConversation(),
        lastReadSeq: 210,
        peerReadSeq: 210,
      ),
    ];
  }

  @override
  void dispose() {
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    _list.dispose();
    super.dispose();
  }

  void _later(Duration wait, VoidCallback fn) {
    _timers.add(
      Timer(wait, () {
        if (!mounted) {
          return;
        }
        fn();
      }),
    );
  }

  _Conv? _byId(String? id) {
    if (id == null) {
      return null;
    }
    for (final _Conv conversation in _conversations) {
      if (conversation.id == id) {
        return conversation;
      }
    }
    return null;
  }

  int _nextSeq(_Conv conversation) {
    int maxSeq = 0;
    for (final KunChatMessage message in conversation.messages) {
      maxSeq = math.max(maxSeq, message.seq);
    }
    return maxSeq + 1;
  }

  int _unread(_Conv conversation) {
    return conversation.messages
        .where(
          (KunChatMessage message) =>
              message.senderId != demoMe &&
              message.seq > conversation.lastReadSeq &&
              message.kind == KunChatMessageKind.message,
        )
        .length;
  }

  void _replace(
    _Conv conversation,
    KunChatMessage target,
    KunChatMessage next,
  ) {
    final int index = conversation.messages.indexWhere(
      (KunChatMessage message) =>
          message.clientMessageId != null &&
              message.clientMessageId == target.clientMessageId ||
          message.id == target.id,
    );
    if (index < 0) {
      return;
    }
    conversation.messages = <KunChatMessage>[
      ...conversation.messages.sublist(0, index),
      next,
      ...conversation.messages.sublist(index + 1),
    ];
  }

  void _send(KunChatFormattedText body) {
    final _Conv? conversation = _byId(_openId);
    if (conversation == null) {
      return;
    }
    _sent += 1;
    final String clientId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final KunChatMessage pending = KunChatMessage(
      id: clientId,
      conversationId: conversation.id,
      seq: 0,
      senderId: demoMe,
      createdAt: DateTime.now(),
      text: body.text,
      entities: body.entities,
      replyTo: _replyTo == null ? null : demoReplyTo(_replyTo!),
      replyQuote: _quote,
      clientMessageId: clientId,
      status: KunChatSendStatus.sending,
    );
    setState(() {
      conversation.messages = <KunChatMessage>[
        ...conversation.messages,
        pending,
      ];
      _draft = '';
      _replyTo = null;
      _quote = null;
    });
    final bool fail = _sent == 3;
    _later(const Duration(milliseconds: 700), () {
      setState(() {
        _replace(
          conversation,
          pending,
          fail
              ? pending.copyWith(status: KunChatSendStatus.failed)
              : pending.copyWith(seq: _nextSeq(conversation), status: null),
        );
      });
      if (fail || conversation.kind != KunChatKind.direct) {
        return;
      }
      _later(const Duration(milliseconds: 900), () {
        setState(() {
          _typing = <KunChatTypingEvent>[
            KunChatTypingEvent(userId: _peer.id, at: DateTime.now()),
          ];
        });
      });
      _later(const Duration(milliseconds: 2600), () {
        setState(() {
          _typing = const <KunChatTypingEvent>[];
          conversation.messages = <KunChatMessage>[
            ...conversation.messages,
            demoMessage(_peer.id, DateTime.now(), '收到~ 我先去吃个饭,晚点细聊').copyWith(
              conversationId: conversation.id,
              seq: _nextSeq(conversation),
            ),
          ];
        });
        _later(const Duration(milliseconds: 1200), () {
          setState(() {
            conversation.peerReadSeq = _nextSeq(conversation) - 1;
          });
        });
      });
    });
  }

  void _retry(KunChatMessage message) {
    final _Conv? conversation = _byId(_openId);
    if (conversation == null) {
      return;
    }
    setState(() {
      _replace(
        conversation,
        message,
        message.copyWith(status: KunChatSendStatus.sending),
      );
    });
    _later(const Duration(milliseconds: 600), () {
      setState(() {
        _replace(
          conversation,
          message,
          message.copyWith(seq: _nextSeq(conversation), status: null),
        );
      });
    });
  }

  void _edit(KunChatFormattedText body, KunChatMessage target) {
    final _Conv? conversation = _byId(_openId);
    if (conversation == null) {
      return;
    }
    setState(() {
      _replace(
        conversation,
        target,
        target.copyWith(
          text: body.text,
          entities: body.entities,
          editedAt: DateTime.now(),
        ),
      );
      _editing = null;
    });
  }

  void _react(KunChatMessage message, String? reaction) {
    final _Conv? conversation = _byId(_openId);
    if (conversation == null) {
      return;
    }
    final List<KunChatReaction> reactions = <KunChatReaction>[
      for (final KunChatReaction entry in message.reactions)
        if (entry.reacted)
          KunChatReaction(
            reaction: entry.reaction,
            count: entry.count - 1,
            reacted: false,
          )
        else
          entry,
    ].where((KunChatReaction entry) => entry.count > 0).toList();
    if (reaction != null) {
      final int hit = reactions.indexWhere(
        (KunChatReaction entry) => entry.reaction == reaction,
      );
      if (hit >= 0) {
        final KunChatReaction entry = reactions[hit];
        reactions[hit] = KunChatReaction(
          reaction: entry.reaction,
          count: entry.count + 1,
          reacted: true,
        );
      } else {
        reactions.add(
          KunChatReaction(reaction: reaction, count: 1, reacted: true),
        );
      }
    }
    setState(() {
      _replace(conversation, message, message.copyWith(reactions: reactions));
    });
  }

  void _onAction(
    String action,
    KunChatMessage message,
    KunChatReplyQuote? quote,
  ) {
    final _Conv? conversation = _byId(_openId);
    if (conversation == null) {
      return;
    }
    if (action == 'reply' || action == 'quote') {
      setState(() {
        _editing = null;
        _replyTo = message;
        _quote = quote;
      });
      return;
    }
    if (action == 'edit') {
      setState(() => _editing = message);
      return;
    }
    if (action == 'delete') {
      setState(() {
        conversation.messages = conversation.messages
            .where((KunChatMessage item) => item.id != message.id)
            .toList();
      });
      return;
    }
    if (action == 'pin' || action == 'unpin') {
      setState(() {
        _replace(
          conversation,
          message,
          message.copyWith(pinnedAt: action == 'pin' ? DateTime.now() : null),
        );
      });
    }
  }

  List<KunChatMessageAction> _actions(KunChatMessage message, bool own) {
    return <KunChatMessageAction>[
      KunChatMessageAction.reply,
      KunChatMessageAction.quote,
      KunChatMessageAction.copy,
      if (own && message.text.isNotEmpty) KunChatMessageAction.edit,
      if (message.pinnedAt != null)
        KunChatMessageAction.unpin
      else
        KunChatMessageAction.pin,
      KunChatMessageAction.retry,
      if (own) KunChatMessageAction.delete else KunChatMessageAction.report,
    ];
  }

  void _editLast() {
    final _Conv? conversation = _byId(_openId);
    if (conversation == null) {
      return;
    }
    for (final KunChatMessage message in conversation.messages.reversed) {
      if (message.senderId == demoMe && message.text.isNotEmpty) {
        setState(() => _editing = message);
        return;
      }
    }
  }

  void _open(String id) {
    setState(() {
      _openId = id;
      _lastOpen = id;
    });
  }

  Widget _row(_Conv conversation) {
    final KunChatMessage? last =
        conversation.messages.isEmpty ? null : conversation.messages.last;
    final bool selected = _openId == conversation.id;
    if (conversation.kind == KunChatKind.direct) {
      return KunChatConversationItem(
        user: _peer,
        lastMessage: last,
        lastMessageSender: last?.senderId == demoMe ? '你' : null,
        typing: _openId == 'direct' ? _typing : const <KunChatTypingEvent>[],
        unreadCount: selected ? 0 : _unread(conversation),
        selected: selected,
        trailingActions: const <KunChatSwipeAction>[
          KunChatSwipeAction(
            key: 'archive',
            label: '归档',
            icon: KunIcons.archive,
          ),
        ],
        onTap: () => _open(conversation.id),
      );
    }
    return KunChatConversationItem(
      title: 'Galgame 汉化交流 · 校对组',
      kind: KunChatKind.group,
      avatar: demoUsers[3].avatar,
      lastMessage: last,
      users: demoUsers,
      currentUserId: demoMe,
      unreadCount: selected ? 0 : 4,
      muted: true,
      selected: selected,
      onTap: () => _open(conversation.id),
    );
  }

  Widget _chat(_Conv conversation) {
    final List<KunChatMessage> pinned = conversation.messages
        .where((KunChatMessage message) => message.pinnedAt != null)
        .toList();
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      children: <Widget>[
        KunChatHeader(
          user: conversation.kind == KunChatKind.direct ? _peer : null,
          title: conversation.kind == KunChatKind.group
              ? 'Galgame 汉化交流 · 校对组'
              : null,
          avatar: conversation.kind == KunChatKind.group
              ? demoUsers[3].avatar
              : null,
          kind: conversation.kind,
          subtitle: conversation.kind == KunChatKind.group ? '4 位成员' : '最近在线',
          typing: conversation.kind == KunChatKind.direct
              ? _typing
              : const <KunChatTypingEvent>[],
          users: demoUsers,
          onBack: () => setState(() => _openId = null),
        ),
        if (pinned.isNotEmpty)
          KunChatPinnedBar(
            messages: pinned,
            resolveMediaUrl: resolveDemoMedia,
            onJump: (int seq) => _list.scrollToSeq(seq),
          ),
        Expanded(
          child: ColoredBox(
            color: scheme.neutral.shade100.withValues(
              alpha: KunColors.globalOpacity,
            ),
            child: KunChatMessageList(
              controller: _list,
              messages: conversation.messages,
              users: demoUsers,
              currentUserId: demoMe,
              kind: conversation.kind,
              lastReadSeq: conversation.lastReadSeq,
              peerReadSeq: conversation.peerReadSeq,
              reactionOptions: demoReactions,
              resolveMediaUrl: resolveDemoMedia,
              actions: _actions,
              onAction: _onAction,
              onReact: _react,
              onRetry: _retry,
            ),
          ),
        ),
        KunChatComposer(
          value: _draft,
          onChanged: (String value) => setState(() => _draft = value),
          replyTo: _replyTo,
          onReplyToChanged: (KunChatMessage? value) =>
              setState(() => _replyTo = value),
          quote: _quote,
          onQuoteChanged: (KunChatReplyQuote? value) =>
              setState(() => _quote = value),
          editing: _editing,
          onEditingChanged: (KunChatMessage? value) =>
              setState(() => _editing = value),
          users: demoUsers,
          onSend: _send,
          onEdit: _edit,
          onEditLast: _editLast,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final _Conv? open = _byId(_openId ?? _lastOpen);
    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: KunContainerWidths.xl5,
          minWidth: 0,
        ),
        child: SizedBox(
          height: _kFrameHeight,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: scheme.neutral.solid.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(KunRadius.lg),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KunRadius.lg),
              child: KunChatLayout(
                resizable: true,
                sidebarSize: _sidebarSize,
                onSidebarSizeChanged: (double value) =>
                    setState(() => _sidebarSize = value),
                showConversation: _openId != null,
                onBack: () => setState(() => _openId = null),
                sidebar: ColoredBox(
                  color: scheme.content1,
                  child: ListView(
                    padding: const EdgeInsets.all(KunSpacing.unit * 1.5),
                    children: <Widget>[
                      for (final _Conv conversation in _conversations)
                        _row(conversation),
                    ],
                  ),
                ),
                empty: ColoredBox(
                  color: scheme.neutral.shade100.withValues(
                    alpha: KunColors.globalOpacity,
                  ),
                  child: Center(
                    child: Text(
                      '选择一个对话开始聊天',
                      style: KunText.sm.copyWith(
                        color: scheme.foregroundMuted,
                      ),
                    ),
                  ),
                ),
                child: open == null ? null : _chat(open),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget chatLayoutApp(BuildContext context) => const _LayoutAppDemo();
