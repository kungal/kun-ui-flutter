import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

class _HeaderDemo extends StatefulWidget {
  const _HeaderDemo();

  @override
  State<_HeaderDemo> createState() => _HeaderDemoState();
}

class _HeaderDemoState extends State<_HeaderDemo> {
  List<KunChatTypingEvent> _typing = const <KunChatTypingEvent>[];

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunChatUser haru = demoUsers[1];
    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: KunContainerWidths.lg,
          minWidth: 0,
        ),
        child: SizedBox(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  KunChatHeader(
                    user: haru,
                    users: demoUsers,
                    subtitle: '最近在线',
                    typing: _typing,
                    actions: KunButton(
                      isIconOnly: true,
                      variant: KunUIVariant.light,
                      semanticLabel: '搜索',
                      onPressed: () {},
                      child: const Icon(KunIcons.search),
                    ),
                  ),
                  KunChatHeader(
                    title: 'Galgame 汉化交流 · 校对组',
                    kind: KunChatKind.group,
                    avatar: demoUsers[3].avatar,
                    users: demoUsers,
                    subtitle: '4 位成员',
                    back: KunChatHeaderBack.always,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(KunSpacing.unit * 3),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: KunButton(
                        size: KunUISize.sm,
                        variant: KunUIVariant.flat,
                        onPressed: () => setState(() {
                          _typing = <KunChatTypingEvent>[
                            KunChatTypingEvent(
                              userId: haru.id,
                              at: DateTime.now(),
                            ),
                          ];
                        }),
                        child: const Text('模拟对方正在输入(6 秒后消失)'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget chatHeaderBasic(BuildContext context) => const _HeaderDemo();
