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

Widget pressableSelection(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _PressableSelection(),
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
  String _last = 'Click, right-click, long-press, or Tab and press Enter or '
      'Shift+F10.';
  String? _menuFor;
  Offset _menuAt = Offset.zero;

  static const List<KunContextMenuItem> _actions = <KunContextMenuItem>[
    KunContextMenuItem(key: 'open', label: 'Open', icon: KunIcons.arrowRight),
    KunContextMenuItem(key: 'copy', label: 'Copy link', icon: KunIcons.copy),
    KunContextMenuItem(
      key: 'report',
      label: 'Report',
      icon: KunIcons.x,
      color: KunUIColor.danger,
    ),
  ];

  void _openMenu(String topic, Offset at) => setState(() {
        _menuFor = topic;
        _menuAt = at;
      });

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return KunContextMenu(
      visible: _menuFor != null,
      position: _menuAt,
      items: _actions,
      onSelected: (KunContextMenuItem item) =>
          setState(() => _last = '${item.label}: "$_menuFor"'),
      onClose: () => setState(() => _menuFor = null),
      child: SizedBox(
        width: KunSpacing.unit * 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final String topic in _topics)
              KunPressable(
                linkUrl: Uri(path: '/topic/${_topics.indexOf(topic) + 1}'),
                onTap: () => setState(() => _last = 'Opened "$topic"'),
                onSecondaryTap: (Offset at) => _openMenu(topic, at),
                onLongPress: (Offset at) => _openMenu(topic, at),
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
      ),
    );
  }
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

const List<String> _answers = <String>['Kyoto', 'Osaka', 'Sapporo'];

class _PressableSelection extends StatefulWidget {
  const _PressableSelection();

  @override
  State<_PressableSelection> createState() => _PressableSelectionState();
}

class _PressableSelectionState extends State<_PressableSelection> {
  String? _answer;
  bool _rulesOpen = false;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    Color fill(KunPressableState state, {bool chosen = false}) => chosen
        ? scheme.primary.solid.withValues(alpha: 0.2)
        : scheme.neutral.shade100.withValues(
            alpha: state.hovered || state.pressed ? KunColors.globalOpacity : 0,
          );

    return SizedBox(
      width: KunSpacing.unit * 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: KunSpacing.unit,
        children: <Widget>[
          Text(
            'Which city hosts the event?',
            style: KunText.sm.copyWith(
              color: scheme.foreground,
              fontWeight: KunFontWeights.medium,
            ),
          ),
          for (final String answer in _answers)
            KunPressable(
              selected: _answer == answer,
              onTap: () => setState(() => _answer = answer),
              builder: (BuildContext context, KunPressableState state) =>
                  Container(
                padding: const EdgeInsets.all(KunSpacing.unit * 3),
                decoration: BoxDecoration(
                  color: fill(state, chosen: _answer == answer),
                  borderRadius: BorderRadius.circular(KunRadius.md),
                ),
                child: Text(
                  answer,
                  style: KunText.sm.copyWith(
                    color: _answer == answer
                        ? scheme.primary.text
                        : scheme.foreground,
                  ),
                ),
              ),
            ),
          const SizedBox(height: KunSpacing.unit * 3),
          KunPressable(
            expanded: _rulesOpen,
            onTap: () => setState(() => _rulesOpen = !_rulesOpen),
            builder: (BuildContext context, KunPressableState state) =>
                Container(
              padding: const EdgeInsets.all(KunSpacing.unit * 3),
              decoration: BoxDecoration(
                color: fill(state),
                borderRadius: BorderRadius.circular(KunRadius.md),
              ),
              child: Row(
                spacing: KunSpacing.unit * 2,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Entry rules',
                      style: KunText.sm.copyWith(color: scheme.foreground),
                    ),
                  ),
                  Icon(
                    _rulesOpen ? KunIcons.chevronDown : KunIcons.chevronRight,
                    size: KunText.base.fontSize,
                    color: scheme.foregroundMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_rulesOpen)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KunSpacing.unit * 3,
              ),
              child: Text(
                'One entry per account. Winners are drawn on Sunday.',
                style: KunText.xs.copyWith(color: scheme.foregroundMuted),
              ),
            ),
        ],
      ),
    );
  }
}
