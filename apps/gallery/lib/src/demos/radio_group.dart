import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

const List<KunRadioOption<String>> _plans = <KunRadioOption<String>>[
  KunRadioOption<String>(
    value: 'free',
    label: 'Free',
    description: 'One project, community support.',
    icon: KunIcons.lollipop,
  ),
  KunRadioOption<String>(
    value: 'pro',
    label: 'Pro',
    description: 'Unlimited projects and priority support.',
    icon: KunIcons.check,
  ),
  KunRadioOption<String>(
    value: 'team',
    label: 'Team',
    description: 'Seats, roles and an audit log.',
    icon: KunIcons.info,
  ),
  KunRadioOption<String>(
    value: 'legacy',
    label: 'Legacy',
    description: 'No longer sold.',
    disabled: true,
  ),
];

Widget _caption(BuildContext context, String text) {
  return Text(
    text,
    style: KunText.sm.copyWith(
      color: KunTheme.of(context).colors.neutral.shade600,
    ),
  );
}

class _Group extends StatefulWidget {
  const _Group({required this.builder});

  final Widget Function(String value, ValueChanged<String> onChanged) builder;

  @override
  State<_Group> createState() => _GroupState();
}

class _GroupState extends State<_Group> {
  String _value = 'free';

  @override
  Widget build(BuildContext context) => widget.builder(
        _value,
        (String value) => setState(() => _value = value),
      );
}

Widget _page(BuildContext context, String caption, List<Widget> children) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: <Widget>[_caption(context, caption), ...children],
    ),
  );
}

Widget radioGroupBasic(BuildContext context) {
  return _page(
    context,
    'One tab stop for the group. The arrow keys move and choose in one step, '
    'skipping the disabled option and wrapping round.',
    <Widget>[
      _Group(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunRadioGroup<String>(
          value: value,
          onChanged: onChanged,
          options: _plans,
          label: 'Plan',
        ),
      ),
    ],
  );
}

Widget radioGroupVariants(BuildContext context) {
  return _page(context, 'classic, pill and card.', <Widget>[
    for (final KunRadioVariant variant in KunRadioVariant.values)
      _Group(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunRadioGroup<String>(
          value: value,
          onChanged: onChanged,
          options: _plans,
          variant: variant,
          label: variant.name,
        ),
      ),
  ]);
}

Widget radioGroupOrientation(BuildContext context) {
  return _page(
    context,
    'Horizontal wraps, and a horizontal card keeps a floor of 8rem.',
    <Widget>[
      _Group(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunRadioGroup<String>(
          value: value,
          onChanged: onChanged,
          options: _plans,
          variant: KunRadioVariant.pill,
          orientation: KunRadioOrientation.horizontal,
        ),
      ),
      _Group(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunRadioGroup<String>(
          value: value,
          onChanged: onChanged,
          options: _plans,
          variant: KunRadioVariant.card,
          orientation: KunRadioOrientation.horizontal,
        ),
      ),
    ],
  );
}

Widget radioGroupCards(BuildContext context) {
  return _page(
    context,
    'hideIndicator drops the dot and lets the tinted border and icon carry '
    'the choice. rounded is the card variant only.',
    <Widget>[
      _Group(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunRadioGroup<String>(
          value: value,
          onChanged: onChanged,
          options: _plans,
          variant: KunRadioVariant.card,
          hideIndicator: true,
          rounded: KunUIRounded.lg,
          color: KunUIColor.secondary,
        ),
      ),
    ],
  );
}

Widget radioGroupScale(BuildContext context) {
  return _page(context, 'The shared selection scale, and every hue.', <Widget>[
    for (final KunUISize size in KunUISize.values)
      _Group(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunRadioGroup<String>(
          value: value,
          onChanged: onChanged,
          options: _plans.sublist(0, 2),
          size: size,
          label: size.name,
          orientation: KunRadioOrientation.horizontal,
        ),
      ),
    for (final KunUIColor color in KunUIColor.values)
      _Group(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunRadioGroup<String>(
          value: value,
          onChanged: onChanged,
          options: _plans.sublist(0, 2),
          color: color,
          variant: KunRadioVariant.pill,
          orientation: KunRadioOrientation.horizontal,
        ),
      ),
  ]);
}

Widget radioGroupStates(BuildContext context) {
  return _page(
    context,
    'A disabled group, and an error under the options.',
    <Widget>[
      KunRadioGroup<String>(
        value: 'pro',
        options: _plans,
        disabled: true,
        label: 'Plan',
      ),
      KunRadioGroup<String>(
        value: null,
        options: _plans,
        semanticLabel: 'Plan',
        error: 'Pick a plan to continue.',
      ),
    ],
  );
}

Widget radioGroupEvents(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _RadioEvents(),
  );
}

class _RadioEvents extends StatefulWidget {
  const _RadioEvents();

  @override
  State<_RadioEvents> createState() => _RadioEventsState();
}

class _RadioEventsState extends State<_RadioEvents> {
  String _value = 'free';
  final List<String> _log = <String>[];

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(context, 'Newest first. Choosing the chosen one is silent.'),
        KunRadioGroup<String>(
          value: _value,
          options: _plans,
          onChanged: (String value) => setState(() => _value = value),
          onSelected: (String value, int index) => setState(() {
            _log.insert(0, 'change: $value at $index');
            if (_log.length > 6) _log.removeLast();
          }),
        ),
        for (final String line in _log)
          Text(
            line,
            style: KunText.sm.copyWith(color: scheme.neutral.shade600),
          ),
      ],
    );
  }
}
