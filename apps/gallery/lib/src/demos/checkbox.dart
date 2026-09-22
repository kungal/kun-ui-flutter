import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget _caption(BuildContext context, String text) {
  return Text(
    text,
    style: KunText.sm.copyWith(
      color: KunTheme.of(context).colors.neutral.shade600,
    ),
  );
}

Widget _page(BuildContext context, String caption, List<Widget> children) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[_caption(context, caption), ...children],
    ),
  );
}

class _Box extends StatefulWidget {
  const _Box({required this.builder, this.initial = false});

  final Widget Function(bool value, ValueChanged<bool> onChanged) builder;
  final bool initial;

  @override
  State<_Box> createState() => _BoxState();
}

class _BoxState extends State<_Box> {
  late bool _value = widget.initial;

  @override
  Widget build(BuildContext context) => widget.builder(
        _value,
        (bool value) => setState(() => _value = value),
      );
}

Widget checkboxBasic(BuildContext context) {
  return _page(context, 'The label is part of the tap target.', <Widget>[
    _Box(
      builder: (bool value, ValueChanged<bool> onChanged) => KunCheckBox(
        value: value,
        onChanged: onChanged,
        label: 'Remember me',
      ),
    ),
    _Box(
      initial: true,
      builder: (bool value, ValueChanged<bool> onChanged) => KunCheckBox(
        value: value,
        onChanged: onChanged,
        label: 'Send me release notes',
        color: KunUIColor.primary,
      ),
    ),
  ]);
}

Widget checkboxSizes(BuildContext context) {
  return _page(
    context,
    'The selection scale, shared with KunRadioGroup: a checkbox and a radio '
    'of one size match.',
    <Widget>[
      for (final KunUISize size in KunUISize.values)
        _Box(
          initial: true,
          builder: (bool value, ValueChanged<bool> onChanged) => KunCheckBox(
            value: value,
            onChanged: onChanged,
            size: size,
            label: size.name,
            color: KunUIColor.primary,
          ),
        ),
    ],
  );
}

Widget checkboxColors(BuildContext context) {
  return _page(context, 'Every hue, checked.', <Widget>[
    for (final KunUIColor color in KunUIColor.values)
      _Box(
        initial: true,
        builder: (bool value, ValueChanged<bool> onChanged) => KunCheckBox(
          value: value,
          onChanged: onChanged,
          color: color,
          label: color.name,
        ),
      ),
  ]);
}

Widget checkboxStates(BuildContext context) {
  return _page(
    context,
    'Indeterminate is the select-all parent: a dash instead of a check, '
    'reported as a mixed state. A single checkbox is a circle.',
    <Widget>[
      const KunCheckBox(indeterminate: true, label: 'Some but not all'),
      const KunCheckBox(
        value: true,
        type: KunCheckBoxType.single,
        color: KunUIColor.primary,
        label: 'A single choice',
      ),
      const KunCheckBox(disabled: true, label: 'Disabled'),
      const KunCheckBox(value: true, disabled: true, label: 'Disabled, on'),
    ],
  );
}

Widget checkboxHelp(BuildContext context) {
  return _page(
    context,
    'An error takes the place of the helper text.',
    <Widget>[
      const KunCheckBox(
        label: 'Marketing email',
        description: 'At most one a month.',
      ),
      const KunCheckBox(
        label: 'Terms of service',
        description: 'At most one a month.',
        error: 'You have to accept these to continue.',
      ),
    ],
  );
}

Widget checkboxSlot(BuildContext context) {
  return _page(
    context,
    'A widget can sit between the box and the label.',
    <Widget>[
      _Box(
        builder: (bool value, ValueChanged<bool> onChanged) => KunCheckBox(
          value: value,
          onChanged: onChanged,
          label: 'Starred',
          color: KunUIColor.warning,
          child: Icon(
            KunIcons.check,
            size: KunSpacing.unit * 4,
            color: KunTheme.of(context).colors.warning.solid,
          ),
        ),
      ),
    ],
  );
}
