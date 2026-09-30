import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

const List<KunContextMenuItem> _basicItems = <KunContextMenuItem>[
  KunContextMenuItem(key: 'copy', label: 'Copy', icon: KunIcons.copy),
  KunContextMenuItem(
    key: 'download',
    label: 'Download',
    icon: KunIcons.download,
  ),
  KunContextMenuItem(
    key: 'delete',
    label: 'Delete',
    icon: KunIcons.x,
    color: KunUIColor.danger,
  ),
];

const List<KunContextMenuItem> _iconItems = <KunContextMenuItem>[
  KunContextMenuItem(key: 'view', label: 'View', icon: KunIcons.eye),
  KunContextMenuItem(key: 'copy', label: 'Copy', icon: KunIcons.copy),
  KunContextMenuItem(
    key: 'download',
    label: 'Download',
    icon: KunIcons.download,
  ),
  KunContextMenuItem(key: 'refresh', label: 'Refresh', icon: KunIcons.rotateCw),
];

const List<KunContextMenuItem> _disabledItems = <KunContextMenuItem>[
  KunContextMenuItem(key: 'back', label: 'Back', icon: KunIcons.arrowLeft),
  KunContextMenuItem(
    key: 'forward',
    label: 'Forward',
    icon: KunIcons.arrowRight,
    disabled: true,
  ),
  KunContextMenuItem(key: 'reload', label: 'Reload', icon: KunIcons.rotateCw),
  KunContextMenuItem(
    key: 'save',
    label: 'Save as…',
    icon: KunIcons.download,
    disabled: true,
  ),
];

const List<KunContextMenuItem> _colorItems = <KunContextMenuItem>[
  KunContextMenuItem(
    key: 'open',
    label: 'Open',
    icon: KunIcons.externalLink,
    color: KunUIColor.primary,
  ),
  KunContextMenuItem(
    key: 'approve',
    label: 'Approve',
    icon: KunIcons.circleCheck,
    color: KunUIColor.success,
  ),
  KunContextMenuItem(
    key: 'report',
    label: 'Report',
    icon: KunIcons.triangleAlert,
    color: KunUIColor.warning,
  ),
  KunContextMenuItem(
    key: 'delete',
    label: 'Delete',
    icon: KunIcons.circleX,
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

class _Area extends StatefulWidget {
  const _Area({
    required this.items,
    required this.hint,
    this.fill = false,
    this.padding = 12,
    this.width = 192,
  });

  final List<KunMenuEntry> items;
  final String hint;
  final bool fill;
  final double padding;
  final double width;

  @override
  State<_Area> createState() => _AreaState();
}

class _AreaState extends State<_Area> {
  bool _visible = false;
  Offset _position = Offset.zero;
  String? _lastKey;

  void _openAt(Offset global) {
    setState(() {
      _position = global;
      _visible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final Widget box = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onSecondaryTapUp: (TapUpDetails details) =>
          _openAt(details.globalPosition),
      onLongPressStart: (LongPressStartDetails details) =>
          _openAt(details.globalPosition),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KunRadius.lg),
          border: Border.all(
            color: scheme.neutral.shade200,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(KunSpacing.unit * 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.hint,
                  textAlign: TextAlign.center,
                  style: KunText.sm.copyWith(color: scheme.foregroundMuted),
                ),
                if (_lastKey != null)
                  Text(
                    'Last selected: $_lastKey',
                    style: KunText.sm.copyWith(color: scheme.neutral.shade600),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final Widget area = KunContextMenu(
      visible: _visible,
      items: widget.items,
      position: _position,
      padding: widget.padding,
      width: widget.width,
      onClose: () => setState(() => _visible = false),
      onSelected: (KunContextMenuItem item) =>
          setState(() => _lastKey = item.key),
      child: box,
    );

    if (!widget.fill) {
      return SizedBox(
        width: KunSpacing.unit * 112,
        height: KunSpacing.unit * 28,
        child: area,
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : KunSpacing.unit * 160;
        final double height = constraints.maxHeight.isFinite &&
                constraints.maxHeight > KunSpacing.unit * 40
            ? constraints.maxHeight
            : KunSpacing.unit * 100;
        return SizedBox(width: width, height: height, child: area);
      },
    );
  }
}

Widget contextMenuBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'Right-click or long-press inside the area. The menu opens at the '
          'pointer and shows the last selected key.',
        ),
        const _Area(
          items: _basicItems,
          hint: 'Right-click or long-press inside this box',
          fill: true,
        ),
      ],
    ),
  );
}

Widget contextMenuIcons(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(context, 'Each row can carry an icon from the app\'s set.'),
        const _Area(
          items: _iconItems,
          hint: 'Right-click or long-press inside this box',
        ),
      ],
    ),
  );
}

Widget contextMenuDisabled(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'A disabled row is dimmed, skipped by the arrow keys, and never '
          'emits.',
        ),
        const _Area(
          items: _disabledItems,
          hint: 'Right-click or long-press inside this box',
        ),
      ],
    ),
  );
}

Widget contextMenuColors(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'color tints the row through the light variant, so a destructive '
          'action reads as danger.',
        ),
        const _Area(
          items: _colorItems,
          hint: 'Right-click or long-press inside this box',
        ),
      ],
    ),
  );
}

Widget contextMenuSize(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'width is a min-width floor (320 here). padding is the margin the '
          'clamp keeps from the view edge (24).',
        ),
        const _Area(
          items: _basicItems,
          hint: 'Right-click or long-press near an edge',
          fill: true,
          width: 320,
          padding: 24,
        ),
      ],
    ),
  );
}

const List<KunMenuEntry> _commandItems = <KunMenuEntry>[
  KunContextMenuItem(
    key: 'reply',
    label: 'Reply',
    icon: KunIcons.reply,
    shortcut: 'R',
  ),
  KunContextMenuItem(
    key: 'quote',
    label: 'Quote',
    icon: KunIcons.quote,
    shortcut: 'Q',
  ),
  KunContextMenuItem(
    key: 'copy',
    label: 'Copy text',
    icon: KunIcons.copy,
    shortcut: 'Mod+C',
  ),
  KunContextMenuItem(
    key: 'share',
    label: 'Share',
    icon: KunIcons.externalLink,
    children: <KunMenuEntry>[
      KunContextMenuItem(
        key: 'share-link',
        label: 'Copy post link',
        shortcut: 'Mod+Shift+C',
      ),
      KunContextMenuItem(key: 'share-image', label: 'Make a share image'),
    ],
  ),
  KunMenuSeparator(),
  KunContextMenuItem(
    key: 'report',
    label: 'Report',
    icon: KunIcons.flag,
    color: KunUIColor.warning,
  ),
  KunContextMenuItem(
    key: 'delete',
    label: 'Delete',
    icon: KunIcons.trash2,
    color: KunUIColor.danger,
    shortcut: 'Mod+Backspace',
  ),
];

Widget contextMenuCommands(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'Separators, shortcut hints, and one level of submenu. Hover Share, '
          'or press →, to open the submenu.',
        ),
        const _Area(
          items: _commandItems,
          hint: 'Right-click or long-press inside this box',
          fill: true,
        ),
      ],
    ),
  );
}
