import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

class _PickerDemo extends StatefulWidget {
  const _PickerDemo();

  @override
  State<_PickerDemo> createState() => _PickerDemoState();
}

class _PickerDemoState extends State<_PickerDemo> {
  String? _current = 'heart';
  String? _plainCurrent;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final List<KunChatReactionOption> plain = <KunChatReactionOption>[
      for (final KunChatReactionOption option in demoReactions.take(8))
        KunChatReactionOption(
          key: option.key,
          emoji: option.emoji,
          label: option.label,
        ),
    ];
    Widget card({required Widget child}) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: KunContainerWidths.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.content1,
            border: Border.all(
              color: scheme.neutral.solid.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(KunRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(KunSpacing.unit * 2),
            child: child,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          card(
            child: KunChatReactionPicker(
              options: demoReactions,
              columns: 7,
              value: _current,
              onChanged: (String? next) => setState(() => _current = next),
            ),
          ),
          const SizedBox(height: KunSpacing.unit * 4),
          card(
            child: KunChatReactionPicker(
              options: plain,
              value: _plainCurrent,
              onChanged: (String? next) => setState(() => _plainCurrent = next),
            ),
          ),
          const SizedBox(height: KunSpacing.unit * 4),
          Text(
            'v-model: $_current / $_plainCurrent',
            style: KunText.xs.copyWith(
              fontFamily: KunFontFamilies.mono,
              fontFamilyFallback: KunFontFamilies.monoFallback,
              color: scheme.foregroundMuted,
            ),
          ),
        ],
      ),
    );
  }
}

Widget chatReactionPickerBasic(BuildContext context) => const _PickerDemo();
