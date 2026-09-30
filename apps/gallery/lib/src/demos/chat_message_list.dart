import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

const double _frameHeight = 30 * 16;

Widget _shell(
  BuildContext context, {
  required Widget child,
  Widget? header,
  Widget? footer,
}) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.content1,
          border: Border.all(
            color: scheme.neutral.solid.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(KunRadius.lg),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KunRadius.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (header != null) header,
              SizedBox(height: _frameHeight, child: child),
              if (footer != null) footer,
            ],
          ),
        ),
      ),
    ),
  );
}

class _DirectDemo extends StatefulWidget {
  const _DirectDemo();

  @override
  State<_DirectDemo> createState() => _DirectDemoState();
}

class _DirectDemoState extends State<_DirectDemo> {
  late final List<KunChatMessage> _messages = makeDirectConversation();
  int _readUpTo = 16;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return _shell(
      context,
      footer: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: scheme.neutral.solid.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KunSpacing.unit * 3,
            vertical: KunSpacing.unit * 1.5,
          ),
          child: Text(
            '已读到 seq $_readUpTo',
            style: KunText.xs.copyWith(color: scheme.foregroundMuted),
          ),
        ),
      ),
      child: ColoredBox(
        color: scheme.neutral.shade100.withValues(
          alpha: KunColors.globalOpacity,
        ),
        child: KunChatMessageList(
          messages: _messages,
          users: demoUsers,
          currentUserId: demoMe,
          lastReadSeq: 16,
          peerReadSeq: 14,
          reactionOptions: demoReactions,
          resolveMediaUrl: resolveDemoMedia,
          unreadCount: _messages
              .where(
                (KunChatMessage m) => m.senderId != demoMe && m.seq > _readUpTo,
              )
              .length,
          onRead: (int seq) => setState(() => _readUpTo = seq),
        ),
      ),
    );
  }
}

class _GroupDemo extends StatefulWidget {
  const _GroupDemo();

  @override
  State<_GroupDemo> createState() => _GroupDemoState();
}

class _GroupDemoState extends State<_GroupDemo> {
  late final List<KunChatMessage> _messages = <KunChatMessage>[
    ...makeGroupConversation(),
    demoMessage(demoMe, demoChatTime(0, '08:50'), '这条没发出去').copyWith(
      status: KunChatSendStatus.failed,
    ),
  ];
  final KunChatMessageListController _controller =
      KunChatMessageListController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    KunChatMessage? pinned;
    for (final KunChatMessage message in _messages) {
      if (message.pinnedAt != null) {
        pinned = message;
        break;
      }
    }
    return _shell(
      context,
      header: pinned == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: scheme.neutral.solid.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(KunSpacing.unit * 2),
                child: KunButton(
                  size: KunUISize.sm,
                  variant: KunUIVariant.flat,
                  onPressed: () => _controller.scrollToSeq(pinned!.seq),
                  child: const Text('跳到置顶消息'),
                ),
              ),
            ),
      child: ColoredBox(
        color: scheme.neutral.shade100.withValues(
          alpha: KunColors.globalOpacity,
        ),
        child: KunChatMessageList(
          controller: _controller,
          kind: KunChatKind.group,
          messages: _messages,
          users: demoUsers,
          currentUserId: demoMe,
          reactionOptions: demoReactions,
          resolveMediaUrl: resolveDemoMedia,
          onRetry: (_) {},
          footer: Padding(
            padding: const EdgeInsets.only(bottom: KunSpacing.unit * 2),
            child: Center(
              child: Text(
                'Ayase 正在输入…',
                style: KunText.xs.copyWith(color: scheme.primary.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PagingDemo extends StatefulWidget {
  const _PagingDemo();

  @override
  State<_PagingDemo> createState() => _PagingDemoState();
}

class _PagingDemoState extends State<_PagingDemo> {
  static const int _page = 30;
  late final List<KunChatMessage> _history = makeHistory(400);
  late List<KunChatMessage> _loaded;
  bool _loadingOlder = false;
  bool _loadingNewer = false;
  final KunChatMessageListController _controller =
      KunChatMessageListController();

  @override
  void initState() {
    super.initState();
    _loaded = _slice(_history.length - _page + 1, _history.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<KunChatMessage> _slice(int from, int to) {
    return _history
        .where((KunChatMessage m) => m.seq >= from && m.seq <= to)
        .toList();
  }

  int get _first => _loaded.isEmpty ? 0 : _loaded.first.seq;

  int get _last => _loaded.isEmpty ? 0 : _loaded.last.seq;

  bool get _hasOlder => _first > 1;

  bool get _hasNewer => _last < _history.length;

  void _loadOlder() {
    setState(() => _loadingOlder = true);
    Timer(KunDurations.slow, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _loaded = <KunChatMessage>[
          ..._slice(_first - _page, _first - 1),
          ..._loaded,
        ];
        _loadingOlder = false;
      });
    });
  }

  void _loadNewer() {
    setState(() => _loadingNewer = true);
    Timer(KunDurations.slow, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _loaded = <KunChatMessage>[
          ..._loaded,
          ..._slice(_last + 1, _last + _page),
        ];
        _loadingNewer = false;
      });
    });
  }

  void _jump(int seq) {
    if (_controller.scrollToSeq(seq)) {
      return;
    }
    setState(() {
      _loaded = _slice(seq - _page ~/ 2, seq + _page ~/ 2);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.scrollToSeq(seq);
    });
  }

  void _latest() {
    setState(() {
      _loaded = _slice(_history.length - _page + 1, _history.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return _shell(
      context,
      header: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.neutral.solid.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KunSpacing.unit * 3,
            vertical: KunSpacing.unit * 2,
          ),
          child: Row(
            children: <Widget>[
              KunButton(
                size: KunUISize.sm,
                variant: KunUIVariant.flat,
                onPressed: () => _jump(5),
                child: const Text('跳到第 5 条'),
              ),
              const SizedBox(width: KunSpacing.unit * 2),
              Expanded(
                child: Text(
                  '已载入 seq $_first–$_last,共 ${_history.length} 条',
                  style: KunText.sm.copyWith(color: scheme.foregroundMuted),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ColoredBox(
        color: scheme.neutral.shade100.withValues(
          alpha: KunColors.globalOpacity,
        ),
        child: KunChatMessageList(
          controller: _controller,
          messages: _loaded,
          users: demoUsers,
          currentUserId: demoMe,
          hasOlder: _hasOlder,
          hasNewer: _hasNewer,
          loadingOlder: _loadingOlder,
          loadingNewer: _loadingNewer,
          resolveMediaUrl: resolveDemoMedia,
          onLoadOlder: _loadOlder,
          onLoadNewer: _loadNewer,
          onJump: _jump,
          onLatest: _latest,
          start: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: KunSpacing.unit * 4,
            ),
            child: Text(
              '这是你们对话的开始',
              textAlign: TextAlign.center,
              style: KunText.xs.copyWith(color: scheme.foregroundMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThousandsDemo extends StatefulWidget {
  const _ThousandsDemo();

  @override
  State<_ThousandsDemo> createState() => _ThousandsDemoState();
}

class _ThousandsDemoState extends State<_ThousandsDemo> {
  List<KunChatMessage> _messages = const <KunChatMessage>[];
  int? _took;

  void _load(int count) {
    final DateTime start = DateTime.now();
    final List<KunChatMessage> next = makeHistory(count);
    setState(() {
      _messages = next;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _took = DateTime.now().difference(start).inMilliseconds;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _messages.isEmpty) {
        _load(5000);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return _shell(
      context,
      header: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.neutral.solid.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KunSpacing.unit * 3,
            vertical: KunSpacing.unit * 2,
          ),
          child: Row(
            children: <Widget>[
              KunButton(
                size: KunUISize.sm,
                variant: KunUIVariant.flat,
                onPressed: () => _load(5000),
                child: const Text('载入 5000 条'),
              ),
              const SizedBox(width: KunSpacing.unit * 2),
              if (_took != null)
                Text(
                  '${_messages.length} 条,首次渲染 $_took ms',
                  style: KunText.sm.copyWith(color: scheme.foregroundMuted),
                ),
            ],
          ),
        ),
      ),
      child: ColoredBox(
        color: scheme.neutral.shade100.withValues(
          alpha: KunColors.globalOpacity,
        ),
        child: KunChatMessageList(
          messages: _messages,
          users: demoUsers,
          currentUserId: demoMe,
          reactionOptions: demoReactions,
          resolveMediaUrl: resolveDemoMedia,
          empty: Text(
            '点上面的按钮载入 5000 条消息',
            textAlign: TextAlign.center,
            style: KunText.sm.copyWith(color: scheme.foregroundMuted),
          ),
        ),
      ),
    );
  }
}

/// Docs Direct.vue.
Widget chatMessageListDirect(BuildContext context) => const _DirectDemo();

/// Docs Group.vue.
Widget chatMessageListGroup(BuildContext context) => const _GroupDemo();

/// Docs Paging.vue.
Widget chatMessageListPaging(BuildContext context) => const _PagingDemo();

/// Docs Thousands.vue, loading 5,000 messages.
Widget chatMessageListThousands(BuildContext context) => const _ThousandsDemo();
