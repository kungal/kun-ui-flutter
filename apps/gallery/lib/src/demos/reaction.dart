import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget _emoji(String off, String on, bool active) {
  return Text(
    active ? on : off,
    style: const TextStyle(
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
    ),
  );
}

class _Pill extends StatefulWidget {
  const _Pill({
    required this.builder,
    this.initial = false,
    this.initialCount,
  });

  final bool initial;
  final int? initialCount;
  final Widget Function(
    bool value,
    int? count,
    ValueChanged<bool> onChanged,
    ValueChanged<int> onCountChanged,
  ) builder;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  late bool _value = widget.initial;
  late int? _count = widget.initialCount;

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      _value,
      _count,
      (bool value) => setState(() => _value = value),
      (int count) => setState(() => _count = count),
    );
  }
}

Widget reactionBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _Pill(
      initialCount: 128,
      builder: (
        bool value,
        int? count,
        ValueChanged<bool> onChanged,
        ValueChanged<int> onCountChanged,
      ) {
        return KunReaction(
          value: value,
          count: count,
          onChanged: onChanged,
          onCountChanged: onCountChanged,
        );
      },
    ),
  );
}

Widget reactionSizes(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _Pill(
          initialCount: 3,
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              count: count,
              size: KunReactionSize.sm,
              onChanged: onChanged,
              onCountChanged: onCountChanged,
            );
          },
        ),
        _Pill(
          initial: true,
          initialCount: 88,
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              count: count,
              onChanged: onChanged,
              onCountChanged: onCountChanged,
            );
          },
        ),
        _Pill(
          initialCount: 1024,
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              count: count,
              size: KunReactionSize.lg,
              onChanged: onChanged,
              onCountChanged: onCountChanged,
            );
          },
        ),
      ],
    ),
  );
}

Widget reactionVariants(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _Pill(
          initialCount: 42,
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              count: count,
              color: KunUIColor.danger,
              label: '点赞',
              onChanged: onChanged,
              onCountChanged: onCountChanged,
            );
          },
        ),
        _Pill(
          initial: true,
          initialCount: 7,
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              count: count,
              color: KunUIColor.primary,
              label: '顶',
              onChanged: onChanged,
              onCountChanged: onCountChanged,
            );
          },
        ),
        _Pill(
          initialCount: 15,
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              count: count,
              color: KunUIColor.warning,
              label: '收藏',
              onChanged: onChanged,
              onCountChanged: onCountChanged,
            );
          },
        ),
      ],
    ),
  );
}

Widget reactionToggleOnly(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _Pill(
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              label: '喜欢',
              onChanged: onChanged,
            );
          },
        ),
        _Pill(
          initial: true,
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              color: KunUIColor.primary,
              label: '收藏',
              onChanged: onChanged,
              icon: KunIcons.check,
            );
          },
        ),
        const KunReaction(
          value: true,
          disabled: true,
          label: '禁用',
        ),
      ],
    ),
  );
}

Widget reactionActionRow(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ActionRow(),
  );
}

class _ActionRow extends StatefulWidget {
  const _ActionRow();

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _liked = false;
  int _likes = 128;
  int _shares = 12;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit,
      children: <Widget>[
        KunReaction(
          value: _liked,
          count: _likes,
          label: '点赞',
          onChanged: (bool value) => setState(() => _liked = value),
          onCountChanged: (int count) => setState(() => _likes = count),
        ),
        KunReaction(
          toggle: false,
          count: 34,
          label: '转发',
          icon: KunIcons.refreshCcw,
        ),
        KunReaction(
          toggle: false,
          count: _shares,
          label: '分享',
          onPressed: () => setState(() => _shares++),
          icon: KunIcons.externalLink,
        ),
        KunReaction(
          toggle: false,
          label: '更多',
          icon: KunIcons.chevronDown,
        ),
      ],
    );
  }
}

Widget reactionLabeled(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Wrap(
      spacing: KunSpacing.unit * 4,
      runSpacing: KunSpacing.unit * 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _Pill(
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              color: KunUIColor.warning,
              onChanged: onChanged,
              child: Text(value ? '已收藏' : '收藏游戏'),
            );
          },
        ),
        _Pill(
          initial: true,
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              color: KunUIColor.primary,
              onChanged: onChanged,
              icon: KunIcons.check,
              child: Text(value ? '已收藏' : '收藏资源'),
            );
          },
        ),
        _Pill(
          initialCount: 128,
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              count: count,
              onChanged: onChanged,
              onCountChanged: onCountChanged,
              child: const Text('点赞'),
            );
          },
        ),
      ],
    ),
  );
}

Widget reactionCustom(BuildContext context) {
  const Color orange = Color.from(alpha: 1, red: 1, green: 106 / 255, blue: 0);
  const Color purple = Color.from(
    alpha: 1,
    red: 139 / 255,
    green: 92 / 255,
    blue: 246 / 255,
  );
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 5,
      children: <Widget>[
        _Pill(
          initialCount: 233,
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              count: count,
              activeColor: orange,
              label: '推',
              onChanged: onChanged,
              onCountChanged: onCountChanged,
              iconBuilder: (BuildContext context, bool active) =>
                  _emoji('➕', '🔥', active),
            );
          },
        ),
        _Pill(
          initial: true,
          initialCount: 66,
          builder: (
            bool value,
            int? count,
            ValueChanged<bool> onChanged,
            ValueChanged<int> onCountChanged,
          ) {
            return KunReaction(
              value: value,
              count: count,
              activeColor: purple,
              label: '紫心',
              onChanged: onChanged,
              onCountChanged: onCountChanged,
            );
          },
        ),
      ],
    ),
  );
}
