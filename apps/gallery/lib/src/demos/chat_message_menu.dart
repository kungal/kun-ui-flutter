import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

class _BasicDemo extends StatefulWidget {
  const _BasicDemo();

  @override
  State<_BasicDemo> createState() => _BasicDemoState();
}

class _BasicDemoState extends State<_BasicDemo> {
  Offset? _menuAt;
  String? _reaction;
  String _log = '';

  static const List<KunChatMessageAction> _actions = <KunChatMessageAction>[
    KunChatMessageAction.reply,
    KunChatMessageAction.copy,
    KunChatMessageAction.pin,
    KunChatMessageMenuItem(
      key: 'translate',
      label: '翻译',
      icon: KunIcons.externalLink,
    ),
    KunChatMessageAction.report,
  ];

  void _openAt(Offset global) {
    setState(() => _menuAt = global);
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final Size view = MediaQuery.sizeOf(context);
    return ColoredBox(
      color: scheme.neutral.shade100,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (TapUpDetails details) =>
            _openAt(details.globalPosition),
        onLongPressStart: (LongPressStartDetails details) =>
            _openAt(details.globalPosition),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: view.width,
            minHeight: view.height,
          ),
          child: Padding(
            padding: const EdgeInsets.all(KunSpacing.unit * 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.content1,
                        borderRadius: BorderRadius.circular(KunRadius.lg),
                        boxShadow: KunShadows.sm,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          KunSpacing.unit * 3,
                          KunSpacing.unit * 2,
                          KunSpacing.unit * 3,
                          KunSpacing.unit * 2,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              demoUsers[1].name,
                              style: KunText.sm.copyWith(
                                color: scheme.primary.shade600,
                                fontWeight: KunFontWeights.medium,
                              ),
                            ),
                            const SizedBox(height: KunSpacing.unit),
                            Text(
                              demoMenuMessageSource,
                              style: KunText.sm.copyWith(
                                color: scheme.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KunSpacing.unit * 3),
                Text(
                  _log.isEmpty ? '右键点击上面的消息' : _log,
                  style: KunText.xs.copyWith(
                    fontFamily: KunFontFamilies.mono,
                    fontFamilyFallback: KunFontFamilies.monoFallback,
                    color: scheme.neutral.shade500,
                  ),
                ),
                KunChatMessageMenu(
                  visible: _menuAt != null,
                  position: _menuAt,
                  actions: _actions,
                  reactions: demoReactions,
                  currentReaction: _reaction,
                  onSelect: (String key) =>
                      setState(() => _log = 'select → $key'),
                  onReact: (String? key) => setState(() {
                    _reaction = key;
                    _log = 'react → $key';
                  }),
                  onClose: () => setState(() => _menuAt = null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget chatMessageMenuBasic(BuildContext context) => const _BasicDemo();
