import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

const List<KunTabItem> _homeDocsSettings = <KunTabItem>[
  KunTabItem(value: 'home', textValue: 'Home'),
  KunTabItem(value: 'docs', textValue: 'Docs'),
  KunTabItem(value: 'settings', textValue: 'Settings'),
];

const List<KunTabItem> _homeDocsSettingsIcons = <KunTabItem>[
  KunTabItem(value: 'home', textValue: 'Home', icon: KunIcons.search),
  KunTabItem(value: 'docs', textValue: 'Docs', icon: KunIcons.calendar),
  KunTabItem(
    value: 'settings',
    textValue: 'Settings',
    icon: KunIcons.filter,
  ),
];

Widget _caption(BuildContext context, String text) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Text(
    text.toUpperCase(),
    style: KunText.xs.copyWith(color: scheme.neutral.shade500),
  );
}

Widget tabBasic(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabBasic(),
  );
}

Widget tabVariants(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabVariants(),
  );
}

Widget tabColors(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabColors(),
  );
}

Widget tabSizes(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabSizes(),
  );
}

Widget tabVertical(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabVertical(),
  );
}

Widget tabOverflow(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabOverflow(),
  );
}

Widget tabIcons(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 2,
      children: [
        _caption(
          context,
          'icons: search / calendar / filter (kun_ui_icons; web uses home / book-open / settings)',
        ),
        const _TabStrip(
          variant: KunTabVariant.light,
          color: KunUIColor.secondary,
          items: _homeDocsSettingsIcons,
        ),
      ],
    ),
  );
}

Widget tabAlign(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabAlign(),
  );
}

Widget tabFullWidth(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabFullWidth(),
  );
}

Widget tabDisabled(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabDisabled(),
  );
}

Widget tabLinks(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabLinks(),
  );
}

Widget tabCustom(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabCustom(),
  );
}

Widget tabScrollable(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _TabScrollable(),
  );
}

class _TabStrip extends StatefulWidget {
  const _TabStrip({
    required this.items,
    this.variant = KunTabVariant.underlined,
    this.color = KunUIColor.primary,
    this.disabled = false,
    this.iconSize,
  });

  final List<KunTabItem> items;
  final KunTabVariant variant;
  final KunUIColor color;
  final bool disabled;
  final double? iconSize;

  @override
  State<_TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<_TabStrip> {
  late String _value = widget.items.first.value;

  @override
  Widget build(BuildContext context) {
    return KunTab<KunTabItem>(
      items: widget.items,
      value: _value,
      onChanged: (String value) => setState(() => _value = value),
      variant: widget.variant,
      color: widget.color,
      disabled: widget.disabled,
      iconSize: widget.iconSize,
    );
  }
}

class _SharedTabs extends StatefulWidget {
  const _SharedTabs({required this.builder, this.initial = 'home'});

  final String initial;
  final Widget Function(String value, ValueChanged<String> onChanged) builder;

  @override
  State<_SharedTabs> createState() => _SharedTabsState();
}

class _SharedTabsState extends State<_SharedTabs> {
  late String _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      _value,
      (String value) => setState(() => _value = value),
    );
  }
}

class _TabBasic extends StatefulWidget {
  const _TabBasic();

  @override
  State<_TabBasic> createState() => _TabBasicState();
}

class _TabBasicState extends State<_TabBasic> {
  String _value = 'overview';

  static const List<KunTabItem> _items = <KunTabItem>[
    KunTabItem(value: 'overview', textValue: 'Overview'),
    KunTabItem(value: 'features', textValue: 'Features'),
    KunTabItem(value: 'pricing', textValue: 'Pricing'),
  ];

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KunTab(
          items: _items,
          value: _value,
          onChanged: (String value) => setState(() => _value = value),
        ),
        SizedBox(height: KunSpacing.unit * 3),
        Text(
          'Active tab: $_value',
          style: KunText.sm.copyWith(color: scheme.neutral.shade600),
        ),
      ],
    );
  }
}

class _TabVariants extends StatelessWidget {
  const _TabVariants();

  @override
  Widget build(BuildContext context) {
    return _SharedTabs(
      builder: (String value, ValueChanged<String> onChanged) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KunSpacing.unit * 4,
          children: [
            for (final KunTabVariant variant in KunTabVariant.values)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KunSpacing.unit * 1,
                children: [
                  _caption(context, variant.name),
                  KunTab(
                    items: _homeDocsSettings,
                    value: value,
                    onChanged: onChanged,
                    variant: variant,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TabColors extends StatelessWidget {
  const _TabColors();

  static const List<KunUIColor> _order = <KunUIColor>[
    KunUIColor.primary,
    KunUIColor.secondary,
    KunUIColor.success,
    KunUIColor.warning,
    KunUIColor.danger,
    KunUIColor.info,
    KunUIColor.neutral,
  ];

  @override
  Widget build(BuildContext context) {
    return _SharedTabs(
      builder: (String value, ValueChanged<String> onChanged) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KunSpacing.unit * 4,
          children: [
            for (final KunUIColor color in _order)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KunSpacing.unit * 1,
                children: [
                  _caption(
                    context,
                    color == KunUIColor.neutral ? 'default' : color.name,
                  ),
                  KunTab(
                    items: _homeDocsSettings,
                    value: value,
                    onChanged: onChanged,
                    variant: KunTabVariant.pills,
                    color: color,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TabSizes extends StatelessWidget {
  const _TabSizes();

  @override
  Widget build(BuildContext context) {
    return _SharedTabs(
      builder: (String value, ValueChanged<String> onChanged) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KunSpacing.unit * 4,
          children: [
            for (final KunTabSize size in KunTabSize.values)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KunSpacing.unit * 1,
                children: [
                  _caption(context, size.name),
                  KunTab(
                    items: _homeDocsSettings,
                    value: value,
                    onChanged: onChanged,
                    variant: KunTabVariant.solid,
                    size: size,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TabVertical extends StatelessWidget {
  const _TabVertical();

  @override
  Widget build(BuildContext context) {
    return _SharedTabs(
      builder: (String value, ValueChanged<String> onChanged) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KunSpacing.unit * 2,
          children: [
            _caption(
              context,
              'icons: search / calendar / filter (kun_ui_icons; web uses home / book-open / settings)',
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: KunSpacing.unit * 10,
              children: [
                KunTab(
                  items: _homeDocsSettingsIcons,
                  value: value,
                  onChanged: onChanged,
                  orientation: KunTabOrientation.vertical,
                  variant: KunTabVariant.underlined,
                  color: KunUIColor.primary,
                ),
                KunTab(
                  items: _homeDocsSettingsIcons,
                  value: value,
                  onChanged: onChanged,
                  orientation: KunTabOrientation.vertical,
                  variant: KunTabVariant.light,
                  color: KunUIColor.secondary,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TabOverflow extends StatelessWidget {
  const _TabOverflow();

  static final List<KunTabItem> _items = <KunTabItem>[
    for (int i = 1; i <= 12; i++) KunTabItem(value: 's$i', textValue: '分区 $i'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SharedTabs(
      initial: 's1',
      builder: (String value, ValueChanged<String> onChanged) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: KunContainerWidths.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 4,
            children: [
              KunTab(
                items: _items,
                value: value,
                onChanged: onChanged,
                variant: KunTabVariant.underlined,
              ),
              KunTab(
                items: _items,
                value: value,
                onChanged: onChanged,
                variant: KunTabVariant.light,
                color: KunUIColor.secondary,
                scrollButtons: false,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabAlign extends StatelessWidget {
  const _TabAlign();

  @override
  Widget build(BuildContext context) {
    return _SharedTabs(
      builder: (String value, ValueChanged<String> onChanged) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KunSpacing.unit * 4,
          children: [
            for (final KunTabAlign align in KunTabAlign.values)
              SizedBox(
                width: KunSpacing.unit * 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: KunSpacing.unit * 1,
                  children: [
                    _caption(context, align.name),
                    KunTab(
                      items: _homeDocsSettingsIcons,
                      value: value,
                      onChanged: onChanged,
                      orientation: KunTabOrientation.vertical,
                      variant: KunTabVariant.light,
                      fullWidth: true,
                      align: align,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TabFullWidth extends StatelessWidget {
  const _TabFullWidth();

  static const List<KunTabItem> _longMiddle = <KunTabItem>[
    KunTabItem(value: 'home', textValue: 'Home'),
    KunTabItem(value: 'docs', textValue: 'A much longer label'),
    KunTabItem(value: 'settings', textValue: 'Settings'),
  ];

  static final List<KunTabItem> _eight = <KunTabItem>[
    for (int i = 1; i <= 8; i++)
      KunTabItem(value: 's$i', textValue: 'Section $i'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: [
        _SharedTabs(
          builder: (String value, ValueChanged<String> onChanged) {
            return SizedBox(
              width: KunSpacing.unit * 112,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KunSpacing.unit * 4,
                children: [
                  for (final KunTabVariant variant in KunTabVariant.values)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: KunSpacing.unit * 1,
                      children: [
                        _caption(context, variant.name),
                        KunTab(
                          items: _homeDocsSettings,
                          value: value,
                          onChanged: onChanged,
                          variant: variant,
                          fullWidth: true,
                        ),
                      ],
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: KunSpacing.unit * 1,
                    children: [
                      _caption(context, 'solid, a much longer label'),
                      KunTab(
                        items: _longMiddle,
                        value: value,
                        onChanged: onChanged,
                        variant: KunTabVariant.solid,
                        fullWidth: true,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        _SharedTabs(
          initial: 's1',
          builder: (String value, ValueChanged<String> onChanged) {
            return SizedBox(
              width: KunSpacing.unit * 112,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KunSpacing.unit * 1,
                children: [
                  _caption(context, 'underlined, eight items'),
                  KunTab(
                    items: _eight,
                    value: value,
                    onChanged: onChanged,
                    variant: KunTabVariant.underlined,
                    fullWidth: true,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TabDisabled extends StatelessWidget {
  const _TabDisabled();

  static const List<KunTabItem> _items = <KunTabItem>[
    KunTabItem(value: 'home', textValue: 'Home'),
    KunTabItem(value: 'docs', textValue: 'Docs'),
    KunTabItem(value: 'settings', textValue: 'Settings', disabled: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KunSpacing.unit * 1,
          children: [
            _caption(context, 'item disabled'),
            const _TabStrip(
              items: _items,
              variant: KunTabVariant.solid,
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KunSpacing.unit * 1,
          children: [
            _caption(context, 'group disabled'),
            const _TabStrip(
              items: _items,
              variant: KunTabVariant.solid,
              disabled: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _TabLinks extends StatefulWidget {
  const _TabLinks();

  @override
  State<_TabLinks> createState() => _TabLinksState();
}

class _TabLinksState extends State<_TabLinks> {
  String _value = 'home';
  String _navigated = '';

  static const List<KunTabItem> _items = <KunTabItem>[
    KunTabItem(value: 'home', textValue: 'Home', href: '/'),
    KunTabItem(value: 'docs', textValue: 'Docs', href: '/docs'),
    KunTabItem(value: 'settings', textValue: 'Settings', href: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return KunUIConfigScope(
      config: KunUIConfig(
        navigate: (BuildContext context, String href) {
          setState(() => _navigated = href);
        },
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 2,
        children: [
          _caption(
            context,
            'every item links, so the strip is navigation, not a tablist: '
            'each link is its own tab stop, the arrow keys stay put, and a '
            'click on the current one navigates again',
          ),
          KunTab(
            items: _items,
            value: _value,
            onChanged: (String value) => setState(() => _value = value),
          ),
          Text(
            'Navigated to: $_navigated',
            style: KunText.sm.copyWith(color: scheme.neutral.shade600),
          ),
        ],
      ),
    );
  }
}

class _CountItem extends KunTabItem {
  const _CountItem({
    required super.value,
    required super.textValue,
    required this.unread,
  });

  final int unread;
}

class _TabCustom extends StatelessWidget {
  const _TabCustom();

  static const List<_CountItem> _items = <_CountItem>[
    _CountItem(value: 'home', textValue: 'Home', unread: 3),
    _CountItem(value: 'docs', textValue: 'Docs', unread: 0),
    _CountItem(value: 'settings', textValue: 'Settings', unread: 12),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: [
        _SharedTabs(
          builder: (String value, ValueChanged<String> onChanged) {
            return KunTab<_CountItem>(
              items: _items,
              value: value,
              onChanged: onChanged,
              variant: KunTabVariant.light,
              tabBuilder: (BuildContext context, _CountItem item, int index,
                  bool active) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: KunSpacing.unit * 1.5,
                  children: [
                    Text(item.textValue!),
                    if (item.unread > 0) KunBadge(count: item.unread),
                  ],
                );
              },
            );
          },
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KunSpacing.unit * 1,
          children: [
            _caption(context, 'iconSize 20'),
            const _TabStrip(
              items: _homeDocsSettingsIcons,
              iconSize: 20,
            ),
          ],
        ),
      ],
    );
  }
}

class _TabScrollable extends StatelessWidget {
  const _TabScrollable();

  static final List<KunTabItem> _items = <KunTabItem>[
    for (int i = 1; i <= 12; i++) KunTabItem(value: 's$i', textValue: '分区 $i'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SharedTabs(
      initial: 's1',
      builder: (String value, ValueChanged<String> onChanged) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KunSpacing.unit * 10,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: KunSpacing.unit * 1,
              children: [
                _caption(context, 'scrollable'),
                SizedBox(
                  height: KunSpacing.unit * 40,
                  child: KunTab(
                    items: _items,
                    value: value,
                    onChanged: onChanged,
                    orientation: KunTabOrientation.vertical,
                    scrollable: true,
                  ),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: KunSpacing.unit * 1,
              children: [
                _caption(context, 'disableAnimation'),
                SizedBox(
                  height: KunSpacing.unit * 40,
                  child: KunTab(
                    items: _items,
                    value: value,
                    onChanged: onChanged,
                    orientation: KunTabOrientation.vertical,
                    scrollable: true,
                    disableAnimation: true,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
