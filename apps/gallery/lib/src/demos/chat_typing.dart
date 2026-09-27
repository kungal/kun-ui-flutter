import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

class _TypingDemo extends StatefulWidget {
  const _TypingDemo();

  @override
  State<_TypingDemo> createState() => _TypingDemoState();
}

class _TypingDemoState extends State<_TypingDemo> {
  final List<KunChatTypingEvent> _events = <KunChatTypingEvent>[];

  void _type(String id) {
    setState(() {
      _events.add(KunChatTypingEvent(userId: id, at: DateTime.now()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: KunContainerWidths.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: KunSpacing.unit * 2,
              runSpacing: KunSpacing.unit * 2,
              children: <Widget>[
                for (final KunChatUser user in demoUsers.sublist(1, 4))
                  KunButton(
                    size: KunUISize.sm,
                    variant: KunUIVariant.flat,
                    onPressed: () => _type(user.id),
                    child: Text('${user.name} 输入'),
                  ),
              ],
            ),
            const SizedBox(height: KunSpacing.unit * 3),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.content1,
                border: Border.all(
                  color: scheme.neutral.solid.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(KunRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KunSpacing.unit * 4,
                  vertical: KunSpacing.unit * 2,
                ),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: KunSpacing.unit * 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      KunChatTyping(
                        events: _events,
                        users: demoUsers,
                        kind: KunChatKind.group,
                      ),
                      KunChatTyping(events: _events),
                      KunChatTyping(
                        events: _events,
                        users: demoUsers,
                        kind: KunChatKind.group,
                        showText: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget chatTypingBasic(BuildContext context) => const _TypingDemo();
