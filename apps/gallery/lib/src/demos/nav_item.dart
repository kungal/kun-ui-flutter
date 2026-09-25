import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

class _Dest {
  const _Dest(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

const List<_Dest> _destinations = <_Dest>[
  _Dest('search', 'Search', KunIcons.search),
  _Dest('calendar', 'Calendar', KunIcons.calendar),
  _Dest('uploads', 'Uploads', KunIcons.upload),
  _Dest('downloads', 'Downloads', KunIcons.download),
];

Widget navItemRail(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _NavRail(),
  );
}

Widget navItemSidebar(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _NavSidebar(),
  );
}

Widget navItemBadge(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _NavBadge(),
  );
}

class _NavRail extends StatefulWidget {
  const _NavRail();

  @override
  State<_NavRail> createState() => _NavRailState();
}

class _NavRailState extends State<_NavRail> {
  String _current = 'search';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: KunSpacing.unit * 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: KunSpacing.unit,
        children: [
          for (final _Dest dest in _destinations)
            KunNavItem(
              label: dest.label,
              icon: Icon(dest.icon),
              stacked: true,
              current: _current == dest.key,
              onPressed: () => setState(() => _current = dest.key),
            ),
        ],
      ),
    );
  }
}

class _NavSidebar extends StatefulWidget {
  const _NavSidebar();

  @override
  State<_NavSidebar> createState() => _NavSidebarState();
}

class _NavSidebarState extends State<_NavSidebar> {
  String _current = 'calendar';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: KunSpacing.unit * 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: KunSpacing.unit,
        children: [
          for (final _Dest dest in _destinations)
            KunNavItem(
              label: dest.label,
              icon: Icon(dest.icon),
              current: _current == dest.key,
              onPressed: () => setState(() => _current = dest.key),
            ),
          const KunNavItem(
            label: 'Filter',
            icon: Icon(KunIcons.filter),
            disabled: true,
          ),
        ],
      ),
    );
  }
}

class _NavBadge extends StatefulWidget {
  const _NavBadge();

  @override
  State<_NavBadge> createState() => _NavBadgeState();
}

class _NavBadgeState extends State<_NavBadge> {
  String _current = 'search';
  int _unread = 3;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: KunSpacing.unit * 96),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.content1,
          border: Border.all(color: scheme.border),
          borderRadius: BorderRadius.circular(KunRounded.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KunSpacing.unit),
          child: Row(
            children: [
              for (final _Dest dest in _destinations)
                Expanded(
                  child: KunNavItem(
                    label: dest.label,
                    stacked: true,
                    current: _current == dest.key,
                    icon: dest.key == 'uploads'
                        ? KunBadge(
                            count: _unread,
                            size: KunBadgeSize.sm,
                            child: Icon(dest.icon),
                          )
                        : Icon(dest.icon),
                    onPressed: () {
                      setState(() {
                        _current = dest.key;
                        if (dest.key == 'uploads') {
                          _unread = 0;
                        }
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
