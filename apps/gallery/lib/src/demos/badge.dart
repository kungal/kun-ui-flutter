import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

void _press() {}

Widget _searchBox(BuildContext context) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Container(
    width: KunSpacing.unit * 10,
    height: KunSpacing.unit * 10,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: scheme.neutral.shade100),
      borderRadius: BorderRadius.circular(KunRadius.lg),
    ),
    child: Icon(KunIcons.search, color: scheme.foreground),
  );
}

KunUISize _buttonSize(KunBadgeSize size) => switch (size) {
      KunBadgeSize.sm => KunUISize.sm,
      KunBadgeSize.md => KunUISize.md,
      KunBadgeSize.lg => KunUISize.lg,
    };

Widget badgeBasic(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: [
        KunBadge(
          count: 5,
          child: KunButton(
            variant: KunUIVariant.bordered,
            onPressed: _press,
            child: Text('收件箱'),
          ),
        ),
        KunBadge(
          count: 12,
          child: KunButton(
            variant: KunUIVariant.bordered,
            onPressed: _press,
            child: Text('消息'),
          ),
        ),
      ],
    ),
  );
}

Widget badgeDot(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: [
        const KunBadge(
          variant: KunBadgeVariant.dot,
          color: KunUIColor.success,
          child: KunButton(
            variant: KunUIVariant.bordered,
            onPressed: _press,
            child: Text('状态'),
          ),
        ),
        KunBadge(
          variant: KunBadgeVariant.dot,
          color: KunUIColor.danger,
          child: _searchBox(context),
        ),
      ],
    ),
  );
}

Widget badgeMax(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: [
        KunBadge(
          count: 8,
          child: KunButton(
            variant: KunUIVariant.bordered,
            onPressed: _press,
            child: Text('8'),
          ),
        ),
        KunBadge(
          count: 120,
          child: KunButton(
            variant: KunUIVariant.bordered,
            onPressed: _press,
            child: Text('120 → 99+'),
          ),
        ),
        KunBadge(
          count: 2000,
          max: 999,
          color: KunUIColor.primary,
          child: KunButton(
            variant: KunUIVariant.bordered,
            onPressed: _press,
            child: Text('2000 → 999+'),
          ),
        ),
      ],
    ),
  );
}

Widget badgeColors(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: KunSpacing.unit * 3,
        children: [
          for (final KunUIColor color in KunUIColor.values)
            KunBadge(
              count: 5,
              color: color,
              child: KunButton(
                variant: KunUIVariant.bordered,
                onPressed: _press,
                child: Text(color.name),
              ),
            ),
        ],
      ),
    ),
  );
}

Widget badgeStandalone(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 2,
          children: [
            Text('未读'),
            KunBadge(count: 3, semanticLabel: '3 条未读'),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 2,
          children: [
            Text('在线'),
            KunBadge(
              variant: KunBadgeVariant.dot,
              color: KunUIColor.success,
              semanticLabel: '在线',
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 2,
          children: [
            Text('通知'),
            KunBadge(
              count: 120,
              color: KunUIColor.primary,
              semanticLabel: '120 条通知',
            ),
          ],
        ),
      ],
    ),
  );
}

Widget badgeSizes(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: [
        for (final KunBadgeSize size in KunBadgeSize.values)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 2,
            children: [
              Text(size.name),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: KunSpacing.unit * 4,
                children: [
                  KunBadge(count: 5, size: size),
                  KunBadge(count: 120, size: size),
                  KunBadge(
                    variant: KunBadgeVariant.dot,
                    size: size,
                  ),
                  KunBadge(
                    count: 5,
                    size: size,
                    child: KunButton(
                      variant: KunUIVariant.bordered,
                      size: _buttonSize(size),
                      onPressed: _press,
                      child: Text(size.name),
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

Widget badgePlacement(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: KunSpacing.unit * 8,
        children: [
          for (final KunBadgePlacement placement in KunBadgePlacement.values)
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: KunSpacing.unit * 2,
              children: [
                Text(placement.name),
                KunBadge(
                  count: 5,
                  placement: placement,
                  child: _searchBox(context),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

Widget badgeCount(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _BadgeCount(),
  );
}

class _BadgeCount extends StatefulWidget {
  const _BadgeCount();

  @override
  State<_BadgeCount> createState() => _BadgeCountState();
}

class _BadgeCountState extends State<_BadgeCount> {
  int _count = 0;
  bool _showZero = false;
  bool _show = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 5,
      children: [
        KunBadge(
          count: _count,
          showZero: _showZero,
          show: _show,
          child: const KunButton(
            variant: KunUIVariant.bordered,
            onPressed: _press,
            child: Text('通知'),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 3,
          children: [
            KunButton(
              onPressed: () => setState(() => _count += 1),
              child: const Text('+1'),
            ),
            KunButton(
              onPressed: () => setState(() => _count += 50),
              child: const Text('+50'),
            ),
            KunButton(
              onPressed: () => setState(() => _count = 0),
              child: const Text('清零'),
            ),
          ],
        ),
        KunSwitch(
          value: _showZero,
          onChanged: (bool value) => setState(() => _showZero = value),
          label: 'showZero',
        ),
        KunSwitch(
          value: _show,
          onChanged: (bool value) => setState(() => _show = value),
          label: 'show',
        ),
      ],
    );
  }
}
