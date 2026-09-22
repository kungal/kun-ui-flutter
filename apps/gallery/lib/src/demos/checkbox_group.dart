import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

const List<KunCheckBoxGroupOption<String>> _frameworks =
    <KunCheckBoxGroupOption<String>>[
  KunCheckBoxGroupOption<String>(
    value: 'vue',
    label: 'Vue',
    description: 'The one KunUI is written in.',
    icon: KunIcons.check,
  ),
  KunCheckBoxGroupOption<String>(
    value: 'react',
    label: 'React',
    description: 'A library, strictly.',
    icon: KunIcons.info,
  ),
  KunCheckBoxGroupOption<String>(
    value: 'svelte',
    label: 'Svelte',
    description: 'Compiles away.',
    icon: KunIcons.lollipop,
  ),
  KunCheckBoxGroupOption<String>(
    value: 'angular',
    label: 'Angular',
    description: 'Not on offer here.',
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

class _Group extends StatefulWidget {
  const _Group({required this.builder});

  final Widget Function(
    List<String> values,
    ValueChanged<List<String>> onChanged,
  ) builder;

  @override
  State<_Group> createState() => _GroupState();
}

class _GroupState extends State<_Group> {
  List<String> _values = <String>['vue'];

  @override
  Widget build(BuildContext context) => widget.builder(
        _values,
        (List<String> values) => setState(() => _values = values),
      );
}

Widget checkboxGroupBasic(BuildContext context) {
  return _page(
    context,
    'Every box is its own tab stop and Space toggles it — the checkbox '
    'keyboard, not the radio one.',
    <Widget>[
      _Group(
        builder: (List<String> values, ValueChanged<List<String>> onChanged) =>
            KunCheckBoxGroup<String>(
          values: values,
          onChanged: onChanged,
          options: _frameworks,
          label: 'Frameworks',
        ),
      ),
    ],
  );
}

Widget checkboxGroupVariants(BuildContext context) {
  return _page(context, 'classic, pill and card.', <Widget>[
    for (final KunCheckBoxGroupVariant variant
        in KunCheckBoxGroupVariant.values)
      _Group(
        builder: (List<String> values, ValueChanged<List<String>> onChanged) =>
            KunCheckBoxGroup<String>(
          values: values,
          onChanged: onChanged,
          options: _frameworks,
          variant: variant,
          label: variant.name,
        ),
      ),
  ]);
}

Widget checkboxGroupOrientation(BuildContext context) {
  return _page(
    context,
    'Horizontal wraps. hideIndicator drops the box and lets the tinted '
    'border and icon carry the choice.',
    <Widget>[
      _Group(
        builder: (List<String> values, ValueChanged<List<String>> onChanged) =>
            KunCheckBoxGroup<String>(
          values: values,
          onChanged: onChanged,
          options: _frameworks,
          variant: KunCheckBoxGroupVariant.pill,
          orientation: KunCheckBoxGroupOrientation.horizontal,
        ),
      ),
      _Group(
        builder: (List<String> values, ValueChanged<List<String>> onChanged) =>
            KunCheckBoxGroup<String>(
          values: values,
          onChanged: onChanged,
          options: _frameworks,
          variant: KunCheckBoxGroupVariant.card,
          orientation: KunCheckBoxGroupOrientation.horizontal,
          hideIndicator: true,
          rounded: KunUIRounded.lg,
        ),
      ),
    ],
  );
}

Widget checkboxGroupScale(BuildContext context) {
  return _page(context, 'The shared selection scale, and every hue.', <Widget>[
    for (final KunUISize size in KunUISize.values)
      _Group(
        builder: (List<String> values, ValueChanged<List<String>> onChanged) =>
            KunCheckBoxGroup<String>(
          values: values,
          onChanged: onChanged,
          options: _frameworks.sublist(0, 2),
          size: size,
          label: size.name,
          orientation: KunCheckBoxGroupOrientation.horizontal,
        ),
      ),
    for (final KunUIColor color in KunUIColor.values)
      _Group(
        builder: (List<String> values, ValueChanged<List<String>> onChanged) =>
            KunCheckBoxGroup<String>(
          values: values,
          onChanged: onChanged,
          options: _frameworks.sublist(0, 2),
          color: color,
          variant: KunCheckBoxGroupVariant.pill,
          orientation: KunCheckBoxGroupOrientation.horizontal,
        ),
      ),
  ]);
}

Widget checkboxGroupStates(BuildContext context) {
  return _page(
    context,
    'A disabled group, and an error under the options.',
    <Widget>[
      const KunCheckBoxGroup<String>(
        values: <String>['vue'],
        options: _frameworks,
        disabled: true,
        label: 'Frameworks',
      ),
      const KunCheckBoxGroup<String>(
        values: <String>[],
        options: _frameworks,
        semanticLabel: 'Frameworks',
        error: 'Pick at least one.',
      ),
    ],
  );
}

Widget checkboxGroupMax(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _CheckBoxGroupMax(),
  );
}

class _CheckBoxGroupMax extends StatefulWidget {
  const _CheckBoxGroupMax();

  @override
  State<_CheckBoxGroupMax> createState() => _CheckBoxGroupMaxState();
}

class _CheckBoxGroupMaxState extends State<_CheckBoxGroupMax> {
  List<String> _values = <String>['vue'];
  String? _refused;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'At the cap of two, an unchosen option dims and refuses; a chosen '
          'one still toggles off.',
        ),
        KunCheckBoxGroup<String>(
          values: _values,
          options: _frameworks,
          max: 2,
          label: 'Pick two',
          onChanged: (List<String> values) => setState(() {
            _values = values;
            _refused = null;
          }),
          onInvalid: (KunCheckBoxGroupInvalidReason reason) =>
              setState(() => _refused = reason.name),
        ),
        if (_refused != null)
          Text(
            'refused: $_refused',
            style: KunText.sm.copyWith(color: scheme.danger.solid),
          ),
      ],
    );
  }
}
