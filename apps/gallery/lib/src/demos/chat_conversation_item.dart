import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

class _BasicDemo extends StatefulWidget {
  const _BasicDemo();

  @override
  State<_BasicDemo> createState() => _BasicDemoState();
}

class _BasicDemoState extends State<_BasicDemo> {
  String _selected = 'haru';
  List<KunChatTypingEvent> _typing = <KunChatTypingEvent>[];
  Timer? _timer;
  late final KunChatMessage _haruLast;
  late final KunChatMessage _ayaseLast;
  late final KunChatMessage _lunaLast;
  late final KunChatMessage _groupLast;
  late final KunChatMessage _goneLast;

  @override
  void initState() {
    super.initState();
    _haruLast = demoMessage(
      '1002',
      demoChatTime(0, '09:14'),
      '对了,[@鲲](mention:$demoMe) 周末的线下聚会你去吗?',
    );
    _ayaseLast = demoMessage(demoMe, demoChatTime(0, '08:02'), '存档我发你了');
    _lunaLast = demoMessage(
      '1004',
      demoChatTime(0, '07:40'),
      '',
    ).copyWith(media: demoChatPhoto('bg/bg4', 1920, 1200));
    _groupLast = demoMessage('1004', demoChatTime(3, '19:12'), '有兴趣帮忙校对的私聊我');
    _goneLast = demoMessage(demoMe, demoChatTime(40, '12:00'), '谢谢你的补丁!');
    _typing = <KunChatTypingEvent>[
      KunChatTypingEvent(userId: '1003', at: DateTime.now()),
    ];
    _timer = Timer.periodic(kunChatTypingInterval, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _typing = <KunChatTypingEvent>[
          KunChatTypingEvent(userId: '1003', at: DateTime.now()),
        ];
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunChatUser haru = demoUsers[1];
    final KunChatUser ayase = demoUsers[2];
    final KunChatUser luna = demoUsers[3];
    final KunChatUser gone = demoUsers[4];
    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: KunContainerWidths.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.content1,
            border: Border.all(
              color: scheme.neutral.solid.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(KunRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(KunSpacing.unit * 1.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                KunChatConversationItem(
                  user: haru,
                  lastMessage: _haruLast,
                  unreadCount: 3,
                  mentionCount: 1,
                  selected: _selected == 'haru',
                  currentUserId: demoMe,
                  users: demoUsers,
                  onTap: () => setState(() => _selected = 'haru'),
                ),
                KunChatConversationItem(
                  user: ayase,
                  lastMessage: _ayaseLast,
                  lastMessageSender: '你',
                  status: KunChatSendStatus.read,
                  typing: _typing,
                  pinned: true,
                  selected: _selected == 'ayase',
                  currentUserId: demoMe,
                  users: demoUsers,
                  onTap: () => setState(() => _selected = 'ayase'),
                ),
                KunChatConversationItem(
                  user: luna,
                  lastMessage: _lunaLast,
                  draft: const KunChatFormattedText(text: '第三章的校对我明天'),
                  selected: _selected == 'luna',
                  currentUserId: demoMe,
                  users: demoUsers,
                  onTap: () => setState(() => _selected = 'luna'),
                ),
                KunChatConversationItem(
                  title: 'Galgame 汉化交流 · 校对组',
                  kind: KunChatKind.group,
                  avatar: luna.avatar,
                  lastMessage: _groupLast,
                  lastMessageSender: '樱小路露娜',
                  unreadCount: 128,
                  muted: true,
                  selected: _selected == 'group',
                  currentUserId: demoMe,
                  users: demoUsers,
                  onTap: () => setState(() => _selected = 'group'),
                ),
                KunChatConversationItem(
                  user: gone,
                  lastMessage: _goneLast,
                  lastMessageSender: '你',
                  status: KunChatSendStatus.sent,
                  markedUnread: true,
                  currentUserId: demoMe,
                  users: demoUsers,
                  time: _goneLast.createdAt,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeDemo extends StatefulWidget {
  const _SwipeDemo();

  @override
  State<_SwipeDemo> createState() => _SwipeDemoState();
}

class _SwipeDemoState extends State<_SwipeDemo> {
  String _log = '';
  late final KunChatMessage _last;

  @override
  void initState() {
    super.initState();
    _last = demoMessage('1002', demoChatTime(0, '09:14'), '周末的线下聚会你去吗?');
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: KunContainerWidths.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.content1,
            border: Border.all(
              color: scheme.neutral.solid.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(KunRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(KunSpacing.unit * 1.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                KunChatConversationItem(
                  user: demoUsers[1],
                  lastMessage: _last,
                  unreadCount: 1,
                  currentUserId: demoMe,
                  leadingActions: const <KunChatSwipeAction>[
                    KunChatSwipeAction(
                      key: 'read',
                      label: '标为已读',
                      icon: KunIcons.mailOpen,
                      color: KunUIColor.primary,
                    ),
                  ],
                  trailingActions: const <KunChatSwipeAction>[
                    KunChatSwipeAction(
                      key: 'mute',
                      label: '静音',
                      icon: KunIcons.bellOff,
                      color: KunUIColor.warning,
                    ),
                    KunChatSwipeAction(
                      key: 'pin',
                      label: '置顶',
                      icon: KunIcons.pin,
                      color: KunUIColor.success,
                    ),
                    KunChatSwipeAction(
                      key: 'archive',
                      label: '归档',
                      icon: KunIcons.archive,
                      color: KunUIColor.neutral,
                    ),
                  ],
                  onAction: (String key) =>
                      setState(() => _log = 'action → $key'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KunSpacing.unit * 2,
                    vertical: KunSpacing.unit * 2,
                  ),
                  child: Text(
                    _log.isEmpty ? '在触屏上左右滑动这一行' : _log,
                    style: KunText.xs.copyWith(color: scheme.foregroundMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget chatConversationItemBasic(BuildContext context) => const _BasicDemo();

Widget chatConversationItemSwipe(BuildContext context) => const _SwipeDemo();
