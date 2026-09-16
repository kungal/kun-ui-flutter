import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

const String _eightLines = 'one\ntwo\nthree\nfour\nfive\nsix\nseven\neight';
const String _threeLines = 'one\ntwo\nthree';
const String _twoLines = 'line one\nline two';

Widget textareaSizes(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: [
        for (final KunUISize size in KunUISize.values)
          SizedBox(
            width: 360,
            child: _Field(
              builder: (String value, ValueChanged<String> onChanged) {
                return KunTextarea(
                  value: value,
                  onChanged: onChanged,
                  size: size,
                  placeholder: size.name,
                );
              },
            ),
          ),
      ],
    ),
  );
}

Widget textareaLabelling(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 5,
        children: [
          const Text('label'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                label: 'Bio',
              );
            },
          ),
          const Text('required'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                label: 'Bio',
                required: true,
              );
            },
          ),
          const Text('placeholder + description'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                placeholder: 'Tell us about yourself',
                description: 'Shown under the field while there is no error.',
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget textareaValidation(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 5,
        children: [
          const Text('error replaces description (description is still set)'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                error: 'This field is required.',
                description: 'A helper line under the field.',
              );
            },
          ),
          const Text('description'),
          _Field(
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                description: 'A helper line under the field.',
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget textareaGrowth(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 5,
        children: [
          const Text('rows: 4, fixed'),
          _Field(
            initial: _eightLines,
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                rows: 4,
              );
            },
          ),
          const Text('rows: 2, autoGrow: true'),
          _Field(
            initial: _threeLines,
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                rows: 2,
                autoGrow: true,
              );
            },
          ),
          const Text('rows: 2, autoGrow: true, maxHeight: 120'),
          _Field(
            initial: _eightLines,
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                rows: 2,
                autoGrow: true,
                maxHeight: 120,
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget textareaCount(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 5,
        children: [
          const Text('maxLength: 20, showCharCount: true'),
          _Field(
            initial: 'KunUI',
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                maxLength: 20,
                showCharCount: true,
              );
            },
          ),
          const Text('showCharCount: true, no maxLength'),
          _Field(
            initial: 'KunUI',
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                showCharCount: true,
              );
            },
          ),
          const Text('maxLength: 10, showCharCount: true'),
          _Field(
            initial: '0123456789',
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                maxLength: 10,
                showCharCount: true,
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget textareaFocusRing(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: [
        const Text('click a field to see its ring'),
        Wrap(
          spacing: KunSpacing.unit * 5,
          runSpacing: KunSpacing.unit * 5,
          children: [
            for (final KunUIColor color in KunUIColor.values)
              SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: KunSpacing.unit * 3,
                  children: [
                    Text(color.name),
                    _Field(
                      builder: (String value, ValueChanged<String> onChanged) {
                        return KunTextarea(
                          value: value,
                          onChanged: onChanged,
                          color: color,
                          placeholder: color.name,
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

Widget textareaRounded(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: [
        Wrap(
          spacing: KunSpacing.unit * 5,
          runSpacing: KunSpacing.unit * 5,
          children: [
            for (final KunUIRounded rounded in KunUIRounded.values)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KunSpacing.unit * 3,
                children: [
                  Text(rounded.name),
                  SizedBox(
                    width: 320,
                    child: _Field(
                      builder: (String value, ValueChanged<String> onChanged) {
                        return KunTextarea(
                          value: value,
                          onChanged: onChanged,
                          rounded: rounded,
                          placeholder: rounded.name,
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
  );
}

Widget textareaEvents(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TextareaEvents(),
  );
}

Widget textareaStates(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 5,
        children: [
          const Text('normal'),
          _Field(
            initial: _twoLines,
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
              );
            },
          ),
          const Text('disabled'),
          _Field(
            initial: _twoLines,
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                disabled: true,
              );
            },
          ),
          const Text('readOnly'),
          _Field(
            initial: _twoLines,
            builder: (String value, ValueChanged<String> onChanged) {
              return KunTextarea(
                value: value,
                onChanged: onChanged,
                readOnly: true,
              );
            },
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

class _TextareaEvents extends StatefulWidget {
  const _TextareaEvents();

  @override
  State<_TextareaEvents> createState() => _TextareaEventsState();
}

class _TextareaEventsState extends State<_TextareaEvents> {
  String _value = '';
  String _last = '';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 5,
        children: [
          KunTextarea(
            value: _value,
            onChanged: (String value) => setState(() => _value = value),
            onFocus: () => setState(() => _last = 'focus'),
            onBlur: () => setState(() => _last = 'blur'),
          ),
          Text('value: $_value'),
          Text('last: $_last'),
        ],
      ),
    );
  }
}
