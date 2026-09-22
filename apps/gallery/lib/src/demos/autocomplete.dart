import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

const List<KunAutocompleteOption> _frameworks = <KunAutocompleteOption>[
  KunAutocompleteOption(value: 'vue', label: 'Vue'),
  KunAutocompleteOption(value: 'react', label: 'React'),
  KunAutocompleteOption(value: 'svelte', label: 'Svelte'),
  KunAutocompleteOption(value: 'solid', label: 'Solid'),
  KunAutocompleteOption(value: 'qwik', label: 'Qwik'),
  KunAutocompleteOption(value: 'angular', label: 'Angular', disabled: true),
];

Widget _caption(BuildContext context, String text) {
  return Text(
    text,
    style: KunText.sm.copyWith(
      color: KunTheme.of(context).colors.neutral.shade600,
    ),
  );
}

class _Field extends StatefulWidget {
  const _Field({required this.builder});

  final Widget Function(String value, ValueChanged<String> onChanged) builder;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  String _value = '';

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
      children: <Widget>[
        _caption(context, caption),
        SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: KunSpacing.unit * 5,
            children: children,
          ),
        ),
      ],
    ),
  );
}

Widget autocompleteBasic(BuildContext context) {
  return _page(
    context,
    'Focus the field to see everything, then type to filter. The arrow keys '
    'move, Enter commits, Escape closes — the keyboard never leaves the '
    'field.',
    <Widget>[
      _Field(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunAutocomplete<KunAutocompleteOption>(
          options: _frameworks,
          value: value,
          onChanged: onChanged,
          label: 'Framework',
          placeholder: 'Start typing…',
        ),
      ),
    ],
  );
}

Widget autocompleteFree(BuildContext context) {
  return _page(
    context,
    'The left field keeps whatever you type; the right one empties itself '
    'shortly after losing focus unless the text is one of the options.',
    <Widget>[
      _Field(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunAutocomplete<KunAutocompleteOption>(
          options: _frameworks,
          value: value,
          onChanged: onChanged,
          label: 'Free text (default)',
          clearable: true,
        ),
      ),
      _Field(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunAutocomplete<KunAutocompleteOption>(
          options: _frameworks,
          value: value,
          onChanged: onChanged,
          allowCustomValue: false,
          label: 'One of the options only',
          clearable: true,
        ),
      ),
    ],
  );
}

Widget autocompleteStates(BuildContext context) {
  return _page(
    context,
    'The field is a KunInput, so it carries the same label, helper text, '
    'error and control scale.',
    <Widget>[
      for (final KunUISize size in KunUISize.values)
        _Field(
          builder: (String value, ValueChanged<String> onChanged) =>
              KunAutocomplete<KunAutocompleteOption>(
            options: _frameworks,
            value: value,
            onChanged: onChanged,
            size: size,
            placeholder: size.name,
          ),
        ),
      _Field(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunAutocomplete<KunAutocompleteOption>(
          options: _frameworks,
          value: value,
          onChanged: onChanged,
          label: 'With help',
          description: 'Pick the one the project ships.',
          color: KunUIColor.primary,
        ),
      ),
      _Field(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunAutocomplete<KunAutocompleteOption>(
          options: _frameworks,
          value: value,
          onChanged: onChanged,
          label: 'With an error',
          error: 'This one is required.',
        ),
      ),
      const KunAutocomplete<KunAutocompleteOption>(
        options: _frameworks,
        label: 'Disabled',
        disabled: true,
      ),
    ],
  );
}

Widget autocompleteRemote(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _Remote(),
  );
}

class _Remote extends StatefulWidget {
  const _Remote();

  @override
  State<_Remote> createState() => _RemoteState();
}

class _RemoteState extends State<_Remote> {
  String _value = '';
  bool _loading = false;
  List<KunAutocompleteOption> _options = _frameworks;
  Timer? _request;

  @override
  void dispose() {
    _request?.cancel();
    super.dispose();
  }

  /// Stands in for a request: the parent filters, so `manualFilter` is on.
  void _search(String query) {
    _request?.cancel();
    setState(() => _loading = true);
    _request = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final String q = query.trim().toLowerCase();
      setState(() {
        _loading = false;
        _options = q.isEmpty
            ? _frameworks
            : <KunAutocompleteOption>[
                for (final KunAutocompleteOption option in _frameworks)
                  if (option.label.toLowerCase().contains(q)) option,
              ];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: <Widget>[
        _caption(
          context,
          'A remote source: the search waits 300ms after you stop typing, and '
          'the spinner covers both that gap and the request, so a pending '
          'fetch never reads as "no matches".',
        ),
        SizedBox(
          width: 360,
          child: KunAutocomplete<KunAutocompleteOption>(
            options: _options,
            value: _value,
            manualFilter: true,
            loading: _loading,
            debounce: const Duration(milliseconds: 300),
            label: 'Framework',
            placeholder: 'Type to search…',
            clearable: true,
            onChanged: (String value) => setState(() => _value = value),
            onSearch: _search,
          ),
        ),
      ],
    );
  }
}

Widget autocompleteOption(BuildContext context) {
  return _page(
    context,
    'A builder draws each row, so an option can carry more than a label.',
    <Widget>[
      _Field(
        builder: (String value, ValueChanged<String> onChanged) =>
            KunAutocomplete<KunAutocompleteOption>(
          options: _frameworks,
          value: value,
          onChanged: onChanged,
          label: 'Framework',
          optionBuilder: (BuildContext context, KunAutocompleteOption option,
              bool active) {
            final KunColorScheme scheme = KunTheme.of(context).colors;
            return Row(
              mainAxisSize: MainAxisSize.min,
              spacing: KunSpacing.unit * 2,
              children: <Widget>[
                Icon(
                  KunIcons.lollipop,
                  size: KunSpacing.unit * 4,
                  color:
                      active ? scheme.primary.solid : scheme.neutral.shade400,
                ),
                Text(option.label, style: KunText.sm),
                Text(
                  option.value,
                  style: KunText.xs.copyWith(color: scheme.neutral.shade400),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}
