import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget switchSizes(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 3,
      children: [
        for (final KunUISize size in KunUISize.values)
          _Switch(
            initial: true,
            builder: (bool value, ValueChanged<bool> onChanged) {
              return KunSwitch(
                value: value,
                onChanged: onChanged,
                size: size,
                label: size.name,
              );
            },
          ),
      ],
    ),
  );
}

Widget switchStates(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: [
        const Text('off'),
        _Switch(
          builder: (bool value, ValueChanged<bool> onChanged) {
            return KunSwitch(
              value: value,
              onChanged: onChanged,
              label: 'off',
            );
          },
        ),
        const Text('on'),
        _Switch(
          initial: true,
          builder: (bool value, ValueChanged<bool> onChanged) {
            return KunSwitch(
              value: value,
              onChanged: onChanged,
              label: 'on',
            );
          },
        ),
        const Text('disabled off'),
        const KunSwitch(
          value: false,
          disabled: true,
          label: 'disabled off',
        ),
        const Text('disabled on'),
        const KunSwitch(
          value: true,
          disabled: true,
          label: 'disabled on',
        ),
      ],
    ),
  );
}

Widget switchHelp(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: [
        const Text('description'),
        _Switch(
          builder: (bool value, ValueChanged<bool> onChanged) {
            return KunSwitch(
              value: value,
              onChanged: onChanged,
              label: 'Notify',
              description: 'Shown under the switch while there is no error.',
            );
          },
        ),
        const Text('error replaces description (description is still set)'),
        _Switch(
          builder: (bool value, ValueChanged<bool> onChanged) {
            return KunSwitch(
              value: value,
              onChanged: onChanged,
              label: 'Notify',
              error: 'This field is required.',
              description: 'A helper line under the switch.',
            );
          },
        ),
      ],
    ),
  );
}

Widget switchEvents(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _SwitchEvents(),
  );
}

class _Switch extends StatefulWidget {
  const _Switch({required this.builder, this.initial = false});

  final bool initial;
  final Widget Function(bool value, ValueChanged<bool> onChanged) builder;

  @override
  State<_Switch> createState() => _SwitchState();
}

class _SwitchState extends State<_Switch> {
  late bool _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      _value,
      (bool value) => setState(() => _value = value),
    );
  }
}

class _SwitchEvents extends StatefulWidget {
  const _SwitchEvents();

  @override
  State<_SwitchEvents> createState() => _SwitchEventsState();
}

class _SwitchEventsState extends State<_SwitchEvents> {
  bool _value = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: [
        KunSwitch(
          value: _value,
          onChanged: (bool value) => setState(() => _value = value),
          label: 'Notify',
        ),
        Text('value: $_value'),
      ],
    );
  }
}
