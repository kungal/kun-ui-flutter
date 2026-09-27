import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

Widget _frame(
  BuildContext context, {
  required Widget child,
  EdgeInsetsGeometry? padding,
}) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.lg),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.neutral.shade100.withValues(
              alpha: KunColors.globalOpacity,
            ),
            borderRadius: BorderRadius.circular(KunRadius.lg),
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(KunSpacing.unit * 3),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    ),
  );
}

Widget chatBubbleBasic(BuildContext context) {
  final List<KunChatMessage> theirs = <KunChatMessage>[
    demoMessage('1002', demoChatTime(0, '21:03'), '在吗在吗'),
    demoMessage('1002', demoChatTime(0, '21:03'), '你之前说的那个补丁我装上了'),
    demoMessage('1002', demoChatTime(0, '21:04'), '但是一进游戏就乱码,是不是要转区?'),
  ];
  final KunChatMessage mine = demoMessage(
    demoMe,
    demoChatTime(0, '21:07'),
    '对,用 Locale Emulator 转区再开就好了',
  ).copyWith(editedAt: demoChatTime(0, '21:08'));
  const List<KunChatBubblePosition> positions = <KunChatBubblePosition>[
    KunChatBubblePosition.first,
    KunChatBubblePosition.middle,
    KunChatBubblePosition.last,
  ];
  return _frame(
    context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < theirs.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: KunSpacing.unit * 0.5),
          KunChatBubble(
            message: theirs[i],
            users: demoUsers,
            position: positions[i],
          ),
        ],
        const SizedBox(height: KunSpacing.unit * 2.5),
        Align(
          alignment: Alignment.centerRight,
          child: KunChatBubble(
            message: mine,
            users: demoUsers,
            own: true,
            status: KunChatSendStatus.read,
          ),
        ),
      ],
    ),
  );
}

class _ReplyDemo extends StatefulWidget {
  const _ReplyDemo();

  @override
  State<_ReplyDemo> createState() => _ReplyDemoState();
}

class _ReplyDemoState extends State<_ReplyDemo> {
  late final KunChatMessage original;
  late final KunChatMessage reply;
  late final KunChatMessage quote;
  late final KunChatMessage gone;
  int? clicked;

  @override
  void initState() {
    super.initState();
    original = demoMessage(
      '1002',
      demoChatTime(0, '10:35'),
      '最后那个反转你猜到了吗?原来||列车长就是白本人||',
    );
    reply = demoMessage(
      demoMe,
      demoChatTime(0, '10:41'),
      '猜到一半,第三章那封信就有暗示了',
    ).copyWith(replyTo: demoReplyTo(original));
    quote = demoMessage(demoMe, demoChatTime(0, '10:42'), '这句我也没想到').copyWith(
      replyTo: demoReplyTo(original),
      replyQuote: const KunChatReplyQuote(text: '列车长就是白本人', offset: 14),
    );
    gone = demoMessage('1002', demoChatTime(0, '10:50'), '那条我删了哈哈').copyWith(
      replyTo: KunChatReplyTo(
        seq: original.seq,
        senderId: original.senderId,
        text: '',
        deleted: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return _frame(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          KunChatBubble(message: original, users: demoUsers),
          const SizedBox(height: KunSpacing.unit * 1.5),
          Align(
            alignment: Alignment.centerRight,
            child: KunChatBubble(
              message: reply,
              users: demoUsers,
              own: true,
              status: KunChatSendStatus.read,
              onReplyTap: (int seq) => setState(() => clicked = seq),
            ),
          ),
          const SizedBox(height: KunSpacing.unit * 1.5),
          Align(
            alignment: Alignment.centerRight,
            child: KunChatBubble(
              message: quote,
              users: demoUsers,
              own: true,
              status: KunChatSendStatus.read,
              onReplyTap: (int seq) => setState(() => clicked = seq),
            ),
          ),
          const SizedBox(height: KunSpacing.unit * 1.5),
          KunChatBubble(message: gone, users: demoUsers),
          if (clicked != null) ...<Widget>[
            const SizedBox(height: KunSpacing.unit),
            Text(
              'reply-click → seq $clicked',
              style: KunText.xs.copyWith(
                fontFamily: KunFontFamilies.mono,
                color: scheme.neutral.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget chatBubbleReply(BuildContext context) => const _ReplyDemo();

Widget chatBubbleMedia(BuildContext context) {
  final KunChatMessage photo = demoMessage(
    '1002',
    demoChatTime(0, '09:13'),
    '',
  ).copyWith(media: demoChatPhoto('bg/bg36', 1920, 1080));
  final KunChatMessage captioned = demoMessage(
    '1002',
    demoChatTime(0, '09:14'),
    '片头曲好好听,这张是开场动画的截图',
  ).copyWith(media: demoChatPhoto('ren/2337', 290, 599));
  final List<KunChatPhoto> stills = <KunChatPhoto>[
    demoChatPhoto('bg/bg12', 1920, 1080),
    demoChatPhoto('ren/2339', 367, 602),
    demoChatPhoto('bg/bg25', 1920, 1239),
    demoChatPhoto('bg/bg4', 1920, 1200),
    demoChatPhoto('bg/bg45', 1920, 1268),
  ];
  final List<KunChatMessage> album = <KunChatMessage>[
    for (int i = 0; i < stills.length; i++)
      demoMessage(
        '1002',
        demoChatTime(0, '10:33'),
        i == 4 ? '通关了!最喜欢的五张 CG' : '',
      ).copyWith(media: stills[i], mediaGroupId: '5001'),
  ];
  return _frame(
    context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        KunChatBubble(
          message: photo,
          users: demoUsers,
          resolveMediaUrl: resolveDemoMedia,
        ),
        const SizedBox(height: KunSpacing.unit * 2),
        KunChatBubble(
          message: captioned,
          users: demoUsers,
          resolveMediaUrl: resolveDemoMedia,
        ),
        const SizedBox(height: KunSpacing.unit * 2),
        KunChatBubble(
          message: album.last,
          album: album,
          users: demoUsers,
          resolveMediaUrl: resolveDemoMedia,
        ),
      ],
    ),
  );
}

class _StatusDemo extends StatefulWidget {
  const _StatusDemo();

  @override
  State<_StatusDemo> createState() => _StatusDemoState();
}

class _StatusDemoState extends State<_StatusDemo> {
  static const List<KunChatSendStatus> _initial = <KunChatSendStatus>[
    KunChatSendStatus.sending,
    KunChatSendStatus.sent,
    KunChatSendStatus.read,
    KunChatSendStatus.failed,
  ];
  static const List<String> _texts = <String>[
    '正在发送的消息',
    '已送达,对方还没看',
    '对方已读',
    '网络断了,没发出去',
  ];

  late final List<KunChatMessage> _messages;
  late List<KunChatSendStatus> _status;

  @override
  void initState() {
    super.initState();
    _messages = <KunChatMessage>[
      for (int i = 0; i < _texts.length; i++)
        demoMessage(demoMe, demoChatTime(0, '22:0$i'), _texts[i]),
    ];
    _status = List<KunChatSendStatus>.from(_initial);
  }

  @override
  Widget build(BuildContext context) {
    return _frame(
      context,
      padding: const EdgeInsets.fromLTRB(
        KunSpacing.unit * 12,
        KunSpacing.unit * 3,
        KunSpacing.unit * 3,
        KunSpacing.unit * 3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < _messages.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: KunSpacing.unit),
            KunChatBubble(
              message: _messages[i],
              users: demoUsers,
              own: true,
              status: _status[i],
              onRetry: () {
                setState(() => _status[i] = KunChatSendStatus.sending);
                Timer(KunDurations.slow * 2 + KunDurations.base, () {
                  if (mounted) {
                    setState(() => _status[i] = KunChatSendStatus.sent);
                  }
                });
              },
            ),
          ],
        ],
      ),
    );
  }
}

Widget chatBubbleStatus(BuildContext context) => const _StatusDemo();

class _ReactionsDemo extends StatefulWidget {
  const _ReactionsDemo({this.many = false});

  final bool many;

  @override
  State<_ReactionsDemo> createState() => _ReactionsDemoState();
}

class _ReactionsDemoState extends State<_ReactionsDemo> {
  late KunChatMessage _message;

  @override
  void initState() {
    super.initState();
    _message = demoMessage(
      '1004',
      demoChatTime(0, '08:45'),
      '第三章校对完成,辛苦大家!',
    ).copyWith(
      reactions: widget.many
          ? <KunChatReaction>[
              for (int i = 0; i < 12; i++)
                KunChatReaction(
                  reaction: demoReactions[i].key,
                  count: i == 1 ? 3 : 1,
                  reacted: i == 1,
                ),
            ]
          : const <KunChatReaction>[
              KunChatReaction(reaction: 'party', count: 4, reacted: false),
              KunChatReaction(reaction: 'heart', count: 3, reacted: true),
              KunChatReaction(reaction: 'salute', count: 1, reacted: false),
            ],
    );
  }

  void _react(String? key) {
    final List<KunChatReaction> next = <KunChatReaction>[
      for (final KunChatReaction reaction in _message.reactions)
        if (reaction.reacted)
          KunChatReaction(
            reaction: reaction.reaction,
            count: reaction.count - 1,
            reacted: false,
          )
        else
          reaction,
    ].where((KunChatReaction r) => r.count > 0).toList();
    if (key != null) {
      final int at = next.indexWhere((KunChatReaction r) => r.reaction == key);
      if (at >= 0) {
        final KunChatReaction hit = next[at];
        next[at] = KunChatReaction(
          reaction: hit.reaction,
          count: hit.count + 1,
          reacted: true,
        );
      } else {
        next.add(KunChatReaction(reaction: key, count: 1, reacted: true));
      }
    }
    setState(() => _message = _message.copyWith(reactions: next));
  }

  @override
  Widget build(BuildContext context) {
    return _frame(
      context,
      child: KunChatBubble(
        message: _message,
        users: demoUsers,
        reactionOptions: demoReactions,
        onReact: _react,
      ),
    );
  }
}

Widget chatBubbleReactions(BuildContext context) => const _ReactionsDemo();

Widget chatBubbleReactionsMany(BuildContext context) =>
    const _ReactionsDemo(many: true);

Widget chatBubbleService(BuildContext context) {
  final List<KunChatMessage> service = <KunChatMessage>[
    demoMessage(demoMe, demoChatTime(0, '19:00'), '').copyWith(
      kind: KunChatMessageKind.service,
      serviceAction: const KunChatGroupCreatedAction(title: 'Galgame 汉化交流'),
    ),
    demoMessage(demoMe, demoChatTime(0, '19:01'), '').copyWith(
      kind: KunChatMessageKind.service,
      serviceAction: const KunChatMembersAddedAction(
        userIds: <String>['1002', '1003', '1004'],
      ),
    ),
    demoMessage('1004', demoChatTime(0, '19:05'), '').copyWith(
      kind: KunChatMessageKind.service,
      serviceAction: const KunChatTitleChangedAction(title: '汉化交流 · 校对组'),
    ),
    demoMessage('1005', demoChatTime(0, '19:06'), '').copyWith(
      kind: KunChatMessageKind.service,
      serviceAction: const KunChatMemberLeftAction(),
    ),
  ];
  final KunChatMessage withContext =
      demoMessage('1002', demoChatTime(0, '21:16'), '这个补丁的汉化是完整的吗?').copyWith(
    context: const KunChatContext(
      site: 'moyu',
      kind: 'patch',
      id: '3021',
      title: '《星空鉄道とシロの旅》汉化补丁 v0.9',
      url: 'https://www.moyu.moe/patch/3021/introduction',
    ),
  );
  return _frame(
    context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < service.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: KunSpacing.unit * 2),
          KunChatBubble(
            message: service[i],
            users: demoUsers,
            currentUserId: demoMe,
          ),
        ],
        const SizedBox(height: KunSpacing.unit * 2),
        Align(
          alignment: Alignment.centerLeft,
          child: KunChatBubble(message: withContext, users: demoUsers),
        ),
      ],
    ),
  );
}
