import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

const List<KunDropdownItem> _items = <KunDropdownItem>[
  KunDropdownItem(key: 'copy', label: 'Copy link', icon: KunIcons.copy),
  KunDropdownItem(
      key: 'open', label: 'Open in a tab', icon: KunIcons.externalLink),
  KunDropdownItem(
    key: 'download',
    label: 'Download',
    icon: KunIcons.download,
    disabled: true,
  ),
  KunDropdownItem(
    key: 'delete',
    label: 'Delete',
    icon: KunIcons.x,
    color: KunUIColor.danger,
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

Widget _trigger(String label) {
  return KunButton(
    onPressed: null,
    variant: KunUIVariant.bordered,
    icon: const Icon(KunIcons.chevronDown, size: KunSpacing.unit * 4),
    iconPosition: KunIconPosition.right,
    child: Text(label),
  );
}

Widget dropdownBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'One tab stop. Down or Enter opens it on the first row, Up on the '
          'last; the arrow keys skip the disabled row, letters jump, and '
          'Escape or Tab closes it.',
        ),
        KunDropdown(items: _items, trigger: _trigger('Actions')),
      ],
    ),
  );
}

Widget dropdownPositions(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 10),
    child: Wrap(
      spacing: KunSpacing.unit * 3,
      runSpacing: KunSpacing.unit * 3,
      children: <Widget>[
        for (final KunPopoverPosition position in <KunPopoverPosition>[
          KunPopoverPosition.bottomStart,
          KunPopoverPosition.bottomEnd,
          KunPopoverPosition.topStart,
          KunPopoverPosition.rightStart,
          KunPopoverPosition.leftStart,
        ])
          KunDropdown(
            items: _items,
            position: position,
            trigger: _trigger(position.name),
          ),
      ],
    ),
  );
}

Widget dropdownWidth(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'The menu never narrows past minWidth, so a menu of short labels '
          'keeps its shape.',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 4,
          children: <Widget>[
            KunDropdown(
              items: const <KunDropdownItem>[
                KunDropdownItem(key: 'yes', label: 'Yes'),
                KunDropdownItem(key: 'no', label: 'No'),
              ],
              trigger: _trigger('192 (default)'),
            ),
            KunDropdown(
              items: const <KunDropdownItem>[
                KunDropdownItem(key: 'yes', label: 'Yes'),
                KunDropdownItem(key: 'no', label: 'No'),
              ],
              minWidth: 320,
              trigger: _trigger('320'),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget dropdownDisabled(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'A disabled trigger never opens, takes no keyboard focus, and says '
          'so to a screen reader.',
        ),
        KunDropdown(
          items: _items,
          disabled: true,
          trigger: _trigger('Actions'),
        ),
      ],
    ),
  );
}

Widget dropdownEvents(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _DropdownEvents(),
  );
}

class _DropdownEvents extends StatefulWidget {
  const _DropdownEvents();

  @override
  State<_DropdownEvents> createState() => _DropdownEventsState();
}

class _DropdownEventsState extends State<_DropdownEvents> {
  final List<String> _log = <String>[];

  void _record(String line) {
    setState(() {
      _log.insert(0, line);
      if (_log.length > 6) {
        _log.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(context, 'Newest first.'),
        KunDropdown(
          items: _items,
          trigger: _trigger('Actions'),
          onOpen: () => _record('open'),
          onClose: () => _record('close'),
          onSelected: (KunDropdownItem item) => _record('select: ${item.key}'),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final String line in _log)
              Text(
                line,
                style: KunText.sm.copyWith(color: scheme.neutral.shade600),
              ),
          ],
        ),
      ],
    );
  }
}
