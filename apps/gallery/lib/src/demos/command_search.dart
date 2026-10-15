import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

enum _Kind { topic, galgame, user }

const List<({String label, String description})> _topics =
    <({String label, String description})>[
  (label: '千恋＊万花 全线攻略与结局顺序', description: '攻略 · 342 回复'),
  (label: '魔女的夜宴 汉化补丁更新到 1.2', description: '补丁 · 128 回复'),
  (label: 'Summer Pockets REFLECTION BLUE 值得补吗', description: '讨论 · 96 回复'),
  (label: '2026 年度 Galgame 投票结果出炉', description: '公告 · 1.1k 回复'),
];

const List<({String label, String description})> _galgames =
    <({String label, String description})>[
  (label: '千恋＊万花', description: 'ゆずソフト · 2016'),
  (label: '魔女的夜宴', description: 'ゆずソフト · 2015'),
  (label: 'Riddle Joker', description: 'ゆずソフト · 2018'),
  (label: 'Summer Pockets', description: 'Key · 2018'),
  (label: '樱之诗 —在樱花之森上飞舞—', description: '枕 · 2015'),
];

const List<({String label, String description})> _users =
    <({String label, String description})>[
  (label: '鲲', description: '@kun · 1.2k 话题'),
  (label: '樱花庄的千寻', description: '@chihiro · 86 话题'),
];

Widget _caption(BuildContext context, String text) {
  return Text(
    text,
    style: KunText.sm.copyWith(
      color: KunTheme.of(context).colors.foregroundMuted,
    ),
  );
}

Widget commandSearchBasic(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _CommandSearchBasic(),
  );
}

Widget commandSearchResponsive(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _CommandSearchResponsive(),
  );
}

class _CommandSearchBasic extends StatefulWidget {
  const _CommandSearchBasic();

  @override
  State<_CommandSearchBasic> createState() => _CommandSearchBasicState();
}

class _CommandSearchBasicState extends State<_CommandSearchBasic> {
  String _query = '';
  List<String> _recents = <String>['千恋万花', 'Summer Pockets 汉化', 'ゆずソフト'];
  String _last = '—';
  bool _loading = false;
  List<KunCommandGroup> _results = const <KunCommandGroup>[];
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<({String label, String description})> _match(
    String q,
    List<({String label, String description})> rows,
  ) {
    return rows
        .where(
          (({String label, String description}) row) =>
              '${row.label} ${row.description}'.toLowerCase().contains(q),
        )
        .toList();
  }

  void _onQuery(String raw) {
    setState(() => _query = raw);
    _timer?.cancel();
    final String q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _loading = false;
        _results = const <KunCommandGroup>[];
      });
      return;
    }
    setState(() => _loading = true);
    _timer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }
      final List<
          (
            String,
            _Kind,
            IconData,
            List<({String label, String description})>
          )> groups = <(
        String,
        _Kind,
        IconData,
        List<({String label, String description})>
      )>[
        ('话题', _Kind.topic, KunIcons.mail, _match(q, _topics)),
        ('Galgame', _Kind.galgame, KunIcons.copy, _match(q, _galgames)),
        ('用户', _Kind.user, KunIcons.atSign, _match(q, _users)),
      ];
      setState(() {
        _results = groups
            .where(
          (
            (
              String,
              _Kind,
              IconData,
              List<({String label, String description})>
            ) g,
          ) =>
              g.$4.isNotEmpty,
        )
            .map(
          (
            (
              String,
              _Kind,
              IconData,
              List<({String label, String description})>
            ) g,
          ) {
            final List<({String label, String description})> hits =
                g.$4.take(3).toList();
            return KunCommandGroup(
              label: '${g.$1} · ${hits.length}',
              items: <KunCommandItem>[
                for (final ({String label, String description}) h in hits)
                  KunCommandItem(
                    value: '${g.$2.name}:${h.label}',
                    label: h.label,
                    description: h.description,
                    icon: g.$3,
                  ),
              ],
            );
          },
        ).toList();
        _loading = false;
      });
    });
  }

  List<KunCommandGroup> get _items {
    final String q = _query.trim();
    if (q.isEmpty) {
      if (_recents.isEmpty) {
        return const <KunCommandGroup>[];
      }
      return <KunCommandGroup>[
        KunCommandGroup(
          label: '最近搜索',
          items: <KunCommandItem>[
            for (final String r in _recents)
              KunCommandItem(
                value: 'recent:$r',
                label: r,
                icon: KunIcons.clock,
                removable: true,
              ),
            const KunCommandItem(
              value: 'clear',
              label: '清空搜索记录',
              icon: KunIcons.trash2,
            ),
          ],
        ),
      ];
    }
    return <KunCommandGroup>[
      KunCommandGroup(
        items: <KunCommandItem>[
          KunCommandItem(
            value: 'search',
            label: '搜索「$q」',
            icon: KunIcons.search,
          ),
        ],
      ),
      ..._results,
    ];
  }

  void _goSearch(String q) {
    setState(() {
      _recents = <String>[
        q,
        ..._recents.where((String r) => r != q),
      ].take(5).toList();
      _last = '前往搜索页:$q';
    });
  }

  void _onSelect(KunCommandItem item) {
    final String value = '${item.resolvedValue}';
    if (value == 'clear') {
      setState(() => _recents = <String>[]);
      return;
    }
    if (value.startsWith('recent:')) {
      _goSearch(item.label);
      return;
    }
    if (value == 'search') {
      _goSearch(_query.trim());
      return;
    }
    final String kind = value.split(':').first;
    final String kindLabel = switch (kind) {
      'user' => '用户',
      'topic' => '话题',
      _ => 'Galgame',
    };
    setState(() => _last = '打开$kindLabel:${item.label}');
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: KunSpacing.unit * 3,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.content1,
            borderRadius: BorderRadius.circular(KunRadius.lg),
            border: Border.all(color: scheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 4,
              vertical: KunSpacing.unit * 2.5,
            ),
            child: Row(
              spacing: KunSpacing.unit * 4,
              children: <Widget>[
                Text(
                  'KunGalgame',
                  style: KunText.base.copyWith(
                    color: scheme.foreground,
                    fontWeight: KunFontWeights.semibold,
                  ),
                ),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: KunCommandSearch(
                      query: _query,
                      items: _items,
                      loading: _loading,
                      shortcut: KunCommandShortcut.none,
                      placeholder: '搜索话题、Galgame、用户…',
                      noResultText: '没有匹配的结果',
                      maxHeight: 420,
                      onQueryChanged: _onQuery,
                      onSelected: _onSelect,
                      onSubmitted: _goSearch,
                      onRemoved: (KunCommandItem item) {
                        setState(
                          () => _recents = _recents
                              .where((String r) => r != item.label)
                              .toList(),
                        );
                      },
                    ),
                  ),
                ),
                KunButton(
                  size: KunUISize.sm,
                  onPressed: () {},
                  child: const Text('发帖'),
                ),
              ],
            ),
          ),
        ),
        _caption(context, '最近一次:$_last'),
      ],
    );
  }
}

const List<KunCommandItem> _pages = <KunCommandItem>[
  KunCommandItem(
    value: 'senren',
    label: '千恋＊万花',
    description: 'ゆずソフト · 2016',
    icon: KunIcons.copy,
  ),
  KunCommandItem(
    value: 'sabbat',
    label: '魔女的夜宴',
    description: 'ゆずソフト · 2015',
    icon: KunIcons.copy,
  ),
  KunCommandItem(
    value: 'pockets',
    label: 'Summer Pockets',
    description: 'Key · 2018',
    icon: KunIcons.copy,
  ),
  KunCommandItem(
    value: 'sakura',
    label: '樱之诗',
    description: '枕 · 2015',
    icon: KunIcons.copy,
  ),
];

class _CommandSearchResponsive extends StatefulWidget {
  const _CommandSearchResponsive();

  @override
  State<_CommandSearchResponsive> createState() =>
      _CommandSearchResponsiveState();
}

class _CommandSearchResponsiveState extends State<_CommandSearchResponsive> {
  String _query = '';
  bool _open = false;
  String _last = '—';

  List<KunCommandGroup> get _items {
    final String q = _query.trim().toLowerCase();
    final List<KunCommandItem> match = q.isEmpty
        ? const <KunCommandItem>[]
        : _pages
            .where(
              (KunCommandItem p) =>
                  '${p.label} ${p.description}'.toLowerCase().contains(q),
            )
            .toList();
    return <KunCommandGroup>[KunCommandGroup(items: match)];
  }

  void _onSelect(KunCommandItem item) =>
      setState(() => _last = '打开:${item.label}');

  void _onSubmit(String q) {
    setState(() {
      _last = '前往搜索页:$q';
      _open = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: KunSpacing.unit * 3,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.content1,
            borderRadius: BorderRadius.circular(KunRadius.lg),
            border: Border.all(color: scheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 4,
              vertical: KunSpacing.unit * 2.5,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide =
                    constraints.maxWidth >= KunBreakpointWidths.md;
                return Row(
                  spacing: KunSpacing.unit * 4,
                  children: <Widget>[
                    Text(
                      'KunGalgame',
                      style: KunText.base.copyWith(
                        color: scheme.foreground,
                        fontWeight: KunFontWeights.semibold,
                      ),
                    ),
                    if (wide)
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: KunCommandSearch(
                            query: _query,
                            items: _items,
                            shortcut: KunCommandShortcut.none,
                            size: KunUISize.md,
                            rounded: KunUIRounded.lg,
                            placeholder: '搜索 Galgame…',
                            empty: _caption(context, '输入名称开始搜索'),
                            footer: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                KunSpacing.unit * 3,
                                0,
                                KunSpacing.unit * 3,
                                KunSpacing.unit * 2,
                              ),
                              child: _caption(context, '↵ 前往搜索页'),
                            ),
                            onQueryChanged: (String value) =>
                                setState(() => _query = value),
                            onSelected: _onSelect,
                            onSubmitted: _onSubmit,
                          ),
                        ),
                      )
                    else ...<Widget>[
                      const Spacer(),
                      KunCommandPalette(
                        open: _open,
                        query: _query,
                        items: _items,
                        shortcut: KunCommandShortcut.none,
                        placeholder: '搜索 Galgame…',
                        onOpenChanged: (bool value) =>
                            setState(() => _open = value),
                        onQueryChanged: (String value) =>
                            setState(() => _query = value),
                        onSelected: _onSelect,
                        onSubmitted: _onSubmit,
                        trigger: (
                          BuildContext context,
                          VoidCallback open,
                          String shortcutLabel,
                          String keys,
                        ) {
                          return KunButton(
                            variant: KunUIVariant.light,
                            size: KunUISize.sm,
                            isIconOnly: true,
                            semanticLabel: '搜索',
                            onPressed: open,
                            child: const Icon(KunIcons.search),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        _caption(context, '最近一次:$_last'),
      ],
    );
  }
}
