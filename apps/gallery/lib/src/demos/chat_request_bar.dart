import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

class _RequestBarDemo extends StatefulWidget {
  const _RequestBarDemo();

  @override
  State<_RequestBarDemo> createState() => _RequestBarDemoState();
}

class _RequestBarDemoState extends State<_RequestBarDemo> {
  KunChatRequestAction? _loading;
  String _result = '';
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _run(KunChatRequestAction action) {
    _timer?.cancel();
    setState(() {
      _loading = action;
    });
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = null;
        _result = '${action.name} 完成';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: KunContainerWidths.lg),
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
              children: <Widget>[
                KunChatRequestBar(
                  user: demoUsers[2],
                  loading: _loading,
                  onAccept: () => _run(KunChatRequestAction.accept),
                  onDelete: () => _run(KunChatRequestAction.delete),
                  onBlock: () => _run(KunChatRequestAction.block),
                  onReport: () => _run(KunChatRequestAction.report),
                ),
                Padding(
                  padding: const EdgeInsets.all(KunSpacing.unit * 3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _result.isEmpty ? '选一个操作' : _result,
                      style:
                          KunText.xs.copyWith(color: scheme.neutral.shade500),
                    ),
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

Widget chatRequestBarBasic(BuildContext context) => const _RequestBarDemo();
