import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

Widget _shell(BuildContext context, {required Widget child, Widget? header}) {
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
            children: <Widget>[if (header != null) header, child],
          ),
        ),
      ),
    ),
  );
}

class _BasicDemo extends StatefulWidget {
  const _BasicDemo();

  @override
  State<_BasicDemo> createState() => _BasicDemoState();
}

class _BasicDemoState extends State<_BasicDemo> {
  String _draft = '周末去漫展吗?**上午十点** 地铁站 B 口集合,||我会 cos 白||';
  KunChatFormattedText? _sent;
  String? _typingAt;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return _shell(
      context,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_sent != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 192),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(KunSpacing.unit * 3),
                child: Text(
                  '${_sent!.text}\n${_sent!.entities}',
                  style: KunText.xs.copyWith(
                    color: scheme.foreground,
                    fontFamily: KunFontFamilies.mono,
                  ),
                ),
              ),
            ),
          if (_typingAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KunSpacing.unit * 3,
                KunSpacing.unit * 2,
                KunSpacing.unit * 3,
                0,
              ),
              child: Text(
                'typing 事件:$_typingAt',
                style: KunText.xs.copyWith(color: scheme.foregroundMuted),
              ),
            ),
        ],
      ),
      child: KunChatComposer(
        value: _draft,
        onChanged: (String value) => setState(() => _draft = value),
        prefix: Padding(
          padding: const EdgeInsets.only(right: KunSpacing.unit),
          child: Text('🙂', style: KunText.xl),
        ),
        suffix: const SizedBox.shrink(),
        onSend: (KunChatFormattedText message) {
          setState(() => _sent = message);
        },
        onTyping: () {
          final DateTime now = DateTime.now();
          setState(() {
            _typingAt =
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          });
        },
      ),
    );
  }
}

class _ReplyEditDemo extends StatefulWidget {
  const _ReplyEditDemo();

  @override
  State<_ReplyEditDemo> createState() => _ReplyEditDemoState();
}

class _ReplyEditDemoState extends State<_ReplyEditDemo> {
  late final KunChatMessage _hers;
  late final KunChatMessage _mine;
  String _draft = '这是还没发出去的草稿';
  KunChatMessage? _replyTo;
  KunChatReplyQuote? _quote;
  KunChatMessage? _editing;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _hers = demoMessage(
      '1002',
      demoChatTime(0, '10:35'),
      '最后那个反转你猜到了吗?原来||列车长就是白本人||',
    );
    _mine = demoMessage(
      demoMe,
      demoChatTime(0, '10:42'),
      '不过前作的__系统__有点老,存档记得**多开几个位**',
    );
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return _shell(
      context,
      header: Padding(
        padding: const EdgeInsets.all(KunSpacing.unit * 3),
        child: Wrap(
          spacing: KunSpacing.unit * 2,
          runSpacing: KunSpacing.unit * 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            KunButton(
              size: KunUISize.sm,
              variant: KunUIVariant.flat,
              onPressed: () {
                setState(() {
                  _replyTo = _hers;
                  _quote = null;
                });
              },
              child: const Text('回复她'),
            ),
            KunButton(
              size: KunUISize.sm,
              variant: KunUIVariant.flat,
              onPressed: () {
                setState(() {
                  _replyTo = _hers;
                  _quote = const KunChatReplyQuote(
                    text: '列车长就是白本人',
                    entities: <KunChatEntity>[],
                    offset: 14,
                  );
                });
              },
              child: const Text('引用一段'),
            ),
            KunButton(
              size: KunUISize.sm,
              variant: KunUIVariant.flat,
              onPressed: () => setState(() => _editing = _mine),
              child: const Text('编辑我的消息'),
            ),
            Text(
              _log,
              style: KunText.xs.copyWith(color: scheme.foregroundMuted),
            ),
          ],
        ),
      ),
      child: KunChatComposer(
        value: _draft,
        onChanged: (String value) => setState(() => _draft = value),
        replyTo: _replyTo,
        onReplyToChanged: (KunChatMessage? value) {
          setState(() => _replyTo = value);
        },
        quote: _quote,
        onQuoteChanged: (KunChatReplyQuote? value) {
          setState(() => _quote = value);
        },
        editing: _editing,
        onEditingChanged: (KunChatMessage? value) {
          setState(() => _editing = value);
        },
        users: demoUsers,
        onSend: (KunChatFormattedText message) {
          setState(() => _log = 'send:${message.text}');
        },
        onEdit: (KunChatFormattedText message, KunChatMessage target) {
          setState(() => _log = 'edit:${message.text}');
        },
        onEditLast: () => setState(() => _editing = _mine),
      ),
    );
  }
}

/// 1×1 PNG so the attachment strip has a real [MemoryImage].
final Uint8List _kPng = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x02,
  0x00,
  0x00,
  0x00,
  0x90,
  0x77,
  0x53,
  0xDE,
  0x00,
  0x00,
  0x00,
  0x0C,
  0x49,
  0x44,
  0x41,
  0x54,
  0x08,
  0xD7,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x00,
  0x03,
  0x00,
  0x01,
  0x18,
  0xDD,
  0x8D,
  0xB0,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _AttachmentsDemo extends StatefulWidget {
  const _AttachmentsDemo();

  @override
  State<_AttachmentsDemo> createState() => _AttachmentsDemoState();
}

class _AttachmentsDemoState extends State<_AttachmentsDemo> {
  String _draft = '';
  final List<KunChatAttachment> _attachments = <KunChatAttachment>[];
  final Map<String, Timer> _ticks = <String, Timer>{};
  int _count = 0;

  @override
  void dispose() {
    for (final Timer timer in _ticks.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _upload(String key) {
    _ticks[key]?.cancel();
    final int index = _attachments.indexWhere(
      (KunChatAttachment a) => a.key == key,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _attachments[index] = KunChatAttachment(
        key: key,
        image: _attachments[index].image,
        name: _attachments[index].name,
        progress: 0,
      );
    });
    final bool fail = ++_count % 3 == 0;
    _ticks[key] = Timer.periodic(const Duration(milliseconds: 250), (Timer t) {
      final int i = _attachments.indexWhere(
        (KunChatAttachment a) => a.key == key,
      );
      if (i < 0) {
        t.cancel();
        return;
      }
      final KunChatAttachment current = _attachments[i];
      final double next = ((current.progress ?? 0) + 0.2).clamp(0.0, 1.0);
      setState(() {
        if (fail && next >= 0.6) {
          t.cancel();
          _attachments[i] = KunChatAttachment(
            key: key,
            image: current.image,
            name: current.name,
            progress: next,
            error: true,
          );
        } else if (next >= 1) {
          t.cancel();
          _attachments[i] = KunChatAttachment(
            key: key,
            image: current.image,
            name: current.name,
          );
        } else {
          _attachments[i] = KunChatAttachment(
            key: key,
            image: current.image,
            name: current.name,
            progress: next,
          );
        }
      });
    });
  }

  void _onAttach() {
    // There is no framework file picker. Each press adds two in-memory
    // thumbnails the way the docs demo would after a pick.
    final int stamp = DateTime.now().millisecondsSinceEpoch;
    final List<String> keys = <String>['shot-$stamp-a', 'shot-$stamp-b'];
    setState(() {
      for (final String key in keys) {
        _attachments.add(
          KunChatAttachment(
            key: key,
            image: MemoryImage(_kPng),
            name: '$key.png',
            progress: 0,
          ),
        );
      }
    });
    for (final String key in keys) {
      _upload(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return _shell(
      context,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(
          KunSpacing.unit * 3,
          KunSpacing.unit * 3,
          KunSpacing.unit * 3,
          0,
        ),
        child: Text(
          '点回形针添加内存图（无法打开系统选图器）。',
          style: KunText.xs.copyWith(color: scheme.foregroundMuted),
        ),
      ),
      child: KunChatComposer(
        value: _draft,
        onChanged: (String value) => setState(() => _draft = value),
        attachments: List<KunChatAttachment>.from(_attachments),
        onAttach: _onAttach,
        onRemoveAttachment: (String key) {
          _ticks[key]?.cancel();
          setState(() {
            _attachments.removeWhere((KunChatAttachment a) => a.key == key);
          });
        },
        onRetryAttachment: _upload,
        onSend: (_) {
          for (final Timer timer in _ticks.values) {
            timer.cancel();
          }
          setState(() => _attachments.clear());
        },
      ),
    );
  }
}

class _LimitDemo extends StatefulWidget {
  const _LimitDemo();

  @override
  State<_LimitDemo> createState() => _LimitDemoState();
}

class _LimitDemoState extends State<_LimitDemo> {
  String _draft = '${'这是一段很长的攻略。' * 398}**结尾**';

  @override
  Widget build(BuildContext context) {
    return _shell(
      context,
      child: KunChatComposer(
        value: _draft,
        onChanged: (String value) => setState(() => _draft = value),
        maxRows: 4,
      ),
    );
  }
}

Widget chatComposerBasic(BuildContext context) => const _BasicDemo();

Widget chatComposerReplyEdit(BuildContext context) => const _ReplyEditDemo();

Widget chatComposerAttachments(BuildContext context) =>
    const _AttachmentsDemo();

Widget chatComposerLimit(BuildContext context) => const _LimitDemo();

Widget chatComposerDisabled(BuildContext context) {
  return _shell(
    context,
    child: const KunChatComposer(
      disabled: true,
      disabledText: '对方已注销,无法继续发送消息',
    ),
  );
}
