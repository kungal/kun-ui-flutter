import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

class _PinnedBarDemo extends StatefulWidget {
  const _PinnedBarDemo();

  @override
  State<_PinnedBarDemo> createState() => _PinnedBarDemoState();
}

class _PinnedBarDemoState extends State<_PinnedBarDemo> {
  late final List<KunChatMessage> _pinned = demoPinnedBarMessages();
  final List<int> _log = <int>[];

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final String line = _log.isEmpty ? '点一下置顶条' : _log.take(5).join(', ');
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
                  KunChatPinnedBar(
                    messages: _pinned,
                    resolveMediaUrl: resolveDemoMedia,
                    unpinnable: true,
                    onJump: (int seq) => setState(() => _log.insert(0, seq)),
                    onUnpin: (int seq) => setState(() => _log.insert(0, -seq)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(KunSpacing.unit * 3),
                    child: Text(
                      'jump → $line',
                      style:
                          KunText.xs.copyWith(color: scheme.neutral.shade500),
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

Widget chatPinnedBarBasic(BuildContext context) => const _PinnedBarDemo();
