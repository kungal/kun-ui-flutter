import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget pressableRows(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _PressableRows(),
  );
}

Widget pressableStates(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _PressableStates(),
  );
}

const List<String> _topics = <String>[
  'Which route did you take first?',
  'Patch 1.2 notes',
  'Soundtrack recommendations',
];

class _PressableRows extends StatefulWidget {
  const _PressableRows();

  @override
  State<_PressableRows> createState() => _PressableRowsState();
}

class _PressableRowsState extends State<_PressableRows> {
  String _last = 'Click, right-click, long-press, or Tab and press Enter.';

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return SizedBox(
      width: KunSpacing.unit * 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final String topic in _topics)
            KunPressable(
              onTap: () => setState(() => _last = 'Opened "$topic"'),
              onSecondaryTap: (Offset at) => setState(
                () => _last = 'Menu for "$topic" at ${_point(at)}',
              ),
              onLongPress: (Offset at) => setState(
                () => _last = 'Long press on "$topic" at ${_point(at)}',
              ),
              builder: (BuildContext context, KunPressableState state) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KunSpacing.unit * 3,
                    vertical: KunSpacing.unit * 3,
                  ),
                  decoration: BoxDecoration(
                    color: state.hovered || state.pressed
                        ? scheme.neutral.shade100
                            .withValues(alpha: KunColors.globalOpacity)
                        : scheme.neutral.shade100.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(KunRadius.md),
                  ),
                  child: Text(
                    topic,
                    style: KunText.sm.copyWith(color: scheme.foreground),
                  ),
                );
              },
            ),
          const SizedBox(height: KunSpacing.unit * 4),
          Text(
            _last,
            style: KunText.xs.copyWith(color: scheme.foregroundMuted),
          ),
        ],
      ),
    );
  }

  static String _point(Offset at) => '(${at.dx.round()}, ${at.dy.round()})';
}

class _PressableStates extends StatelessWidget {
  const _PressableStates();

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    Widget tile(String label, {bool disabled = false}) => KunPressable(
          disabled: disabled,
          rounded: KunUIRounded.lg,
          onTap: () {},
          builder: (BuildContext context, KunPressableState state) {
            final List<String> flags = <String>[
              if (state.hovered) 'hovered',
              if (state.pressed) 'pressed',
              if (state.focused) 'focused',
              if (state.disabled) 'disabled',
            ];
            return Opacity(
              opacity: state.disabled ? 0.5 : 1,
              child: Container(
                width: KunSpacing.unit * 40,
                padding: const EdgeInsets.all(KunSpacing.unit * 4),
                decoration: BoxDecoration(
                  color: scheme.content1,
                  border: Border.all(color: scheme.border),
                  borderRadius: BorderRadius.circular(KunRadius.lg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: KunSpacing.unit,
                  children: <Widget>[
                    Text(
                      label,
                      style: KunText.sm.copyWith(
                        color: scheme.foreground,
                        fontWeight: KunFontWeights.medium,
                      ),
                    ),
                    Text(
                      flags.isEmpty ? 'idle' : flags.join(', '),
                      style: KunText.xs.copyWith(color: scheme.foregroundMuted),
                    ),
                  ],
                ),
              ),
            );
          },
        );

    return Wrap(
      spacing: KunSpacing.unit * 4,
      runSpacing: KunSpacing.unit * 4,
      children: <Widget>[
        tile('Enabled'),
        tile('Disabled', disabled: true),
      ],
    );
  }
}
