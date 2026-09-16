import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

void _press() {}

Widget inputSizes(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunCardPadding.sm.value,
      children: [
        for (final KunUISize size in KunUISize.values)
          SizedBox(
            width: 360,
            child: Row(
              spacing: KunCardPadding.sm.value,
              children: [
                Expanded(
                  child: _Field(
                    builder: (String value, ValueChanged<String> onChanged) {
                      return KunInput(
                        value: value,
                        onChanged: onChanged,
                        size: size,
                        placeholder: size.name,
                      );
                    },
                  ),
                ),
                KunButton(
                  size: size,
                  onPressed: _press,
                  child: const Text('GO'),
                ),
                KunButton(
                  size: size,
                  isIconOnly: true,
                  semanticLabel: 'search',
                  onPressed: _press,
                  child: const Icon(KunIcons.search),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget inputLabelling(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunCardPadding.md.value,
        children: [
          const Text('label'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunInput(
                value: value,
                onChanged: onChanged,
                label: 'Name',
              );
            },
          ),
          const Text('required'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunInput(
                value: value,
                onChanged: onChanged,
                label: 'Email',
                required: true,
              );
            },
          ),
          const Text('placeholder'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunInput(
                value: value,
                onChanged: onChanged,
                placeholder: 'Search',
              );
            },
          ),
          const Text('description'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunInput(
                value: value,
                onChanged: onChanged,
                description: 'Shown under the field while there is no error.',
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget inputValidation(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunCardPadding.md.value,
        children: [
          const Text('description'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunInput(
                value: value,
                onChanged: onChanged,
                description: 'A helper line under the field.',
              );
            },
          ),
          const Text('isInvalid, with description'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunInput(
                value: value,
                onChanged: onChanged,
                isInvalid: true,
                description: 'A helper line under the field.',
              );
            },
          ),
          const Text('error replaces description (description is still set)'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunInput(
                value: value,
                onChanged: onChanged,
                error: 'This address is taken.',
                description: 'A helper line under the field.',
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget inputAffixes(BuildContext context) {
  final KunThemeData theme = KunTheme.of(context);
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunCardPadding.md.value,
        children: [
          const Text('prefix'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunInput(
                value: value,
                onChanged: onChanged,
                prefix: const Icon(KunIcons.search, size: 16),
                placeholder: 'Search',
              );
            },
          ),
          const Text('suffix'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunInput(
                value: value,
                onChanged: onChanged,
                suffix: Text(
                  '.com',
                  style: KunControlMetrics.of(KunUISize.md).textStyle.copyWith(
                        color: theme.colors.neutral.shade500,
                      ),
                ),
              );
            },
          ),
          const Text('isClearable'),
          _Field(
            initial: 'clear me',
            builder: (String value, ValueChanged<String> onChanged) {
              return KunInput(
                value: value,
                onChanged: onChanged,
                isClearable: true,
              );
            },
          ),
          const Text('password, revealPassword'),
          _Field(
            initial: 'secret',
            builder: (String value, ValueChanged<String> onChanged) {
              return KunInput(
                value: value,
                onChanged: onChanged,
                type: KunInputType.password,
                revealPassword: true,
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget inputFocusRing(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunCardPadding.md.value,
      children: [
        const Text('click a field to see its ring'),
        Wrap(
          spacing: KunCardPadding.md.value,
          runSpacing: KunCardPadding.md.value,
          children: [
            for (final KunUIColor color in KunUIColor.values)
              SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: KunCardPadding.sm.value,
                  children: [
                    Text(color.name),
                    _Field(
                      builder: (String value, ValueChanged<String> onChanged) {
                        return KunInput(
                          value: value,
                          onChanged: onChanged,
                          color: color,
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

Widget inputEvents(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: const _InputEvents(),
  );
}

Widget inputStates(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: KunCardPadding.md.value,
        children: [
          SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: KunCardPadding.sm.value,
              children: [
                const Text('normal'),
                _Field(
                  initial: 'editable',
                  builder: (String value, ValueChanged<String> onChanged) {
                    return KunInput(
                      value: value,
                      onChanged: onChanged,
                      isClearable: true,
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: KunCardPadding.sm.value,
              children: [
                const Text('disabled'),
                _Field(
                  initial: 'locked',
                  builder: (String value, ValueChanged<String> onChanged) {
                    return KunInput(
                      value: value,
                      onChanged: onChanged,
                      disabled: true,
                      isClearable: true,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Field extends StatefulWidget {
  const _Field({required this.builder, this.initial = ''});

  final String initial;
  final Widget Function(String value, ValueChanged<String> onChanged) builder;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late String _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      _value,
      (String value) => setState(() => _value = value),
    );
  }
}

class _InputEvents extends StatefulWidget {
  const _InputEvents();

  @override
  State<_InputEvents> createState() => _InputEventsState();
}

class _InputEventsState extends State<_InputEvents> {
  String _value = '';
  bool _focused = false;
  int _focusCount = 0;
  int _blurCount = 0;
  int _clearCount = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunCardPadding.md.value,
        children: [
          KunInput(
            value: _value,
            onChanged: (String value) => setState(() => _value = value),
            isClearable: true,
            onFocus: () => setState(() {
              _focused = true;
              _focusCount += 1;
            }),
            onBlur: () => setState(() {
              _focused = false;
              _blurCount += 1;
            }),
            onClear: () => setState(() => _clearCount += 1),
          ),
          Text('value: $_value'),
          Text('focused: $_focused'),
          Text(
            'focus: $_focusCount  blur: $_blurCount  clear: $_clearCount',
          ),
        ],
      ),
    );
  }
}
