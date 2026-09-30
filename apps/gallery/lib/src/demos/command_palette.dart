import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget _caption(BuildContext context, String text) {
  return Text(
    text,
    style: KunText.sm.copyWith(
      color: KunTheme.of(context).colors.foregroundMuted,
    ),
  );
}

const List<KunCommandItem> _commands = <KunCommandItem>[
  KunCommandItem(
    value: 'home',
    label: '首页',
    section: '导航',
    icon: KunIcons.search,
  ),
  KunCommandItem(
    value: 'docs',
    label: '文档',
    section: '导航',
    icon: KunIcons.mail,
  ),
  KunCommandItem(
    value: 'settings',
    label: '设置',
    section: '导航',
    icon: KunIcons.filter,
  ),
  KunCommandItem(
    value: 'new-file',
    label: '新建文件',
    section: '操作',
    icon: KunIcons.plus,
  ),
  KunCommandItem(
    value: 'copy-link',
    label: '复制链接',
    section: '操作',
    icon: KunIcons.copy,
  ),
  KunCommandItem(
    value: 'delete',
    label: '删除',
    section: '操作',
    icon: KunIcons.trash2,
  ),
];

List<KunCommandGroup> _filterCommands(String query) {
  final String q = query.trim().toLowerCase();
  final List<KunCommandItem> match = _commands
      .where(
        (KunCommandItem c) => q.isEmpty || c.label.toLowerCase().contains(q),
      )
      .toList();
  return <String>['导航', '操作']
      .map(
        (String s) => KunCommandGroup(
          label: s,
          items: match.where((KunCommandItem c) => c.section == s).toList(),
        ),
      )
      .where((KunCommandGroup g) => g.items.isNotEmpty)
      .toList();
}

Widget commandPaletteBasic(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _CommandPaletteBasic(),
  );
}

Widget commandPaletteRemote(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _CommandPaletteRemote(),
  );
}

Widget commandPaletteSubmit(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _CommandPaletteSubmit(),
  );
}

class _CommandPaletteBasic extends StatefulWidget {
  const _CommandPaletteBasic();

  @override
  State<_CommandPaletteBasic> createState() => _CommandPaletteBasicState();
}

class _CommandPaletteBasicState extends State<_CommandPaletteBasic> {
  bool _open = false;
  String _query = '';
  String _picked = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 3,
          children: <Widget>[
            KunCommandPalette(
              open: _open,
              query: _query,
              items: _filterCommands(_query),
              placeholder: '输入命令…',
              onOpenChanged: (bool value) => setState(() => _open = value),
              onQueryChanged: (String value) => setState(() => _query = value),
              onSelected: (KunCommandItem item) =>
                  setState(() => _picked = '${item.resolvedValue}'),
              trigger: (
                BuildContext context,
                VoidCallback open,
                String shortcutLabel,
                String keys,
              ) {
                return KunButton(
                  variant: KunUIVariant.bordered,
                  onPressed: open,
                  child: const Text('命令面板'),
                );
              },
            ),
            _caption(context, '选中:${_picked.isEmpty ? '—' : _picked}'),
          ],
        ),
      ],
    );
  }
}

const List<KunCommandItem> _cities = <KunCommandItem>[
  KunCommandItem(
    value: 'tokyo',
    label: '東京 Tokyo',
    description: 'Japan · Kantō',
    icon: KunIcons.pin,
  ),
  KunCommandItem(
    value: 'osaka',
    label: '大阪 Osaka',
    description: 'Japan · Kansai',
    icon: KunIcons.pin,
  ),
  KunCommandItem(
    value: 'kyoto',
    label: '京都 Kyoto',
    description: 'Japan · Kansai',
    icon: KunIcons.pin,
  ),
  KunCommandItem(
    value: 'sapporo',
    label: '札幌 Sapporo',
    description: 'Japan · Hokkaidō',
    icon: KunIcons.pin,
  ),
];

class _CommandPaletteRemote extends StatefulWidget {
  const _CommandPaletteRemote();

  @override
  State<_CommandPaletteRemote> createState() => _CommandPaletteRemoteState();
}

class _CommandPaletteRemoteState extends State<_CommandPaletteRemote> {
  bool _open = false;
  String _query = '';
  String _picked = '';
  List<KunCommandItem> _items = const <KunCommandItem>[];
  bool _loading = false;
  int _reqId = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onQuery(String q) {
    setState(() => _query = q);
    final String term = q.trim().toLowerCase();
    _timer?.cancel();
    if (term.isEmpty) {
      setState(() {
        _items = const <KunCommandItem>[];
        _loading = false;
      });
      return;
    }
    final int mine = ++_reqId;
    setState(() => _loading = true);
    _timer = Timer(const Duration(milliseconds: 600), () {
      if (mine != _reqId || !mounted) {
        return;
      }
      setState(() {
        _items = _cities
            .where((KunCommandItem c) => c.label.toLowerCase().contains(term))
            .toList();
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: <Widget>[
        KunCommandPalette(
          open: _open,
          query: _query,
          items: <KunCommandGroup>[
            KunCommandGroup(items: _items),
          ],
          loading: _loading,
          placeholder: '搜索城市…(远程)',
          emptyText: '输入城市名开始搜索',
          onOpenChanged: (bool value) => setState(() => _open = value),
          onQueryChanged: _onQuery,
          onSelected: (KunCommandItem item) =>
              setState(() => _picked = '${item.resolvedValue}'),
          trigger: (
            BuildContext context,
            VoidCallback open,
            String shortcutLabel,
            String keys,
          ) {
            return KunButton(
              variant: KunUIVariant.bordered,
              onPressed: open,
              child: const Text('远程搜索'),
            );
          },
        ),
        _caption(context, '选中:${_picked.isEmpty ? '—' : _picked}'),
      ],
    );
  }
}

const List<KunCommandItem> _pages = <KunCommandItem>[
  KunCommandItem(
    value: '/components/button',
    label: 'KunButton',
    section: '组件',
    description: '按钮:七种变体、五档尺寸、加载态与图标位',
    icon: KunIcons.copy,
  ),
  KunCommandItem(
    value: '/components/modal',
    label: 'KunModal',
    section: '组件',
    description: '模态框:焦点陷阱、滚动锁、size 决定宽度',
    icon: KunIcons.copy,
  ),
  KunCommandItem(
    value: '/guide/install',
    label: '安装与接入',
    section: '指南',
    description: 'Tailwind v4 @source 配置、Nuxt layer、按需引入',
    icon: KunIcons.plus,
  ),
];

class _CommandPaletteSubmit extends StatefulWidget {
  const _CommandPaletteSubmit();

  @override
  State<_CommandPaletteSubmit> createState() => _CommandPaletteSubmitState();
}

class _CommandPaletteSubmitState extends State<_CommandPaletteSubmit> {
  bool _open = false;
  String _query = '';
  String _last = '';

  List<KunCommandGroup> get _items {
    final String q = _query.trim().toLowerCase();
    final List<KunCommandItem> match = q.isEmpty
        ? _pages
        : _pages
            .where(
              (KunCommandItem p) =>
                  p.label.toLowerCase().contains(q) ||
                  (p.description ?? '').toLowerCase().contains(q),
            )
            .toList();
    return <KunCommandGroup>[KunCommandGroup(items: match)];
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: <Widget>[
        KunCommandPalette(
          open: _open,
          query: _query,
          items: _items,
          placeholder: '搜索文档…',
          noResultText: '没有匹配的页面',
          onOpenChanged: (bool value) => setState(() => _open = value),
          onQueryChanged: (String value) => setState(() => _query = value),
          onSelected: (KunCommandItem item) =>
              setState(() => _last = '${item.resolvedValue}'),
          onSubmitted: (String q) {
            setState(() {
              _last = q;
              _open = false;
            });
          },
          noResult: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 3,
              vertical: KunSpacing.unit * 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '没有匹配的页面',
                  style: KunText.sm.copyWith(color: scheme.neutral.shade500),
                ),
                SizedBox(height: KunSpacing.unit * 1.5),
                Text(
                  '按 ↵ 全站搜索「$_query」',
                  style: KunText.xs.copyWith(color: scheme.neutral.shade400),
                ),
              ],
            ),
          ),
          trigger: (
            BuildContext context,
            VoidCallback open,
            String shortcutLabel,
            String keys,
          ) {
            return KunButton(
              variant: KunUIVariant.bordered,
              onPressed: open,
              child: const Text('搜索文档'),
            );
          },
        ),
        _caption(context, '最近一次:${_last.isEmpty ? '—' : _last}'),
      ],
    );
  }
}
