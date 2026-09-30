import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

class _Topic {
  const _Topic({
    required this.title,
    required this.author,
    required this.replies,
  });

  final String title;
  final String author;
  final int replies;
}

const List<_Topic> _topics = <_Topic>[
  _Topic(
    title: '《星空列车与白的旅行》通关感想',
    author: '鲲',
    replies: 42,
  ),
  _Topic(
    title: '求推荐和《白色相簿 2》气质相近的作品',
    author: '雪之下小春',
    replies: 128,
  ),
  _Topic(
    title: '2026 年秋季新作发售表（持续更新）',
    author: '坂上智代',
    replies: 67,
  ),
  _Topic(
    title: '汉化补丁 1.2 更新说明',
    author: '鲲',
    replies: 15,
  ),
];

class _ListDetailDemo extends StatefulWidget {
  const _ListDetailDemo();

  @override
  State<_ListDetailDemo> createState() => _ListDetailDemoState();
}

class _ListDetailDemoState extends State<_ListDetailDemo> {
  double _size = 360;
  double? _saved;
  _Topic _current = _topics.first;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: KunSpacing.unit * 2,
        children: <Widget>[
          SizedBox(
            height: KunSpacing.unit * 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.neutral.shade200),
                borderRadius: BorderRadius.circular(KunRadius.lg),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KunRadius.lg),
                child: KunSplitPane(
                  size: _size,
                  onSizeChanged: (double value) =>
                      setState(() => _size = value),
                  onResizeEnd: (double value) => setState(() => _saved = value),
                  snapPoints: const <double>[360, 412],
                  start: ColoredBox(
                    color: scheme.content1,
                    child: ListView(
                      padding: const EdgeInsets.all(KunSpacing.unit * 1.5),
                      children: <Widget>[
                        for (final _Topic topic in _topics)
                          KunPressable(
                            onTap: () => setState(() => _current = topic),
                            builder: (
                              BuildContext context,
                              KunPressableState state,
                            ) {
                              final bool selected = identical(topic, _current);
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? KunUIColor.primary
                                          .scaleOf(scheme)
                                          .solid
                                          .withValues(alpha: 0.1)
                                      : (state.hovered
                                          ? scheme.neutral.solid
                                              .withValues(alpha: 0.2)
                                          : null),
                                  borderRadius: BorderRadius.circular(
                                    KunRadius.md,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: KunSpacing.unit * 3,
                                    vertical: KunSpacing.unit * 2,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        topic.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: KunText.sm.copyWith(
                                          fontWeight: KunFontWeights.medium,
                                        ),
                                      ),
                                      Text(
                                        '${topic.author} · ${topic.replies} 回复',
                                        style: KunText.xs.copyWith(
                                          color: scheme.foregroundMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  end: ColoredBox(
                    color: scheme.content1,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(KunSpacing.unit * 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _current.title,
                            style: KunText.lg.copyWith(
                              fontWeight: KunFontWeights.semibold,
                            ),
                          ),
                          const SizedBox(height: KunSpacing.unit),
                          Text(
                            '${_current.author} · ${_current.replies} 回复',
                            style: KunText.xs.copyWith(
                              color: scheme.foregroundMuted,
                            ),
                          ),
                          const SizedBox(height: KunSpacing.unit * 3),
                          Text(
                            'Drag the divider to resize the left pane. It '
                            'snaps near 360 or 412; any width in between stays '
                            'reachable. Focus the divider and use the arrow '
                            'keys; Shift moves five steps; Home and End jump '
                            'to the ends.',
                            style: KunText.sm.copyWith(
                              color: scheme.neutral.shade700,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            'Current ${_size.toInt()}px · last saved ${_saved?.toInt() ?? '—'}',
            style: KunText.xs.copyWith(color: scheme.foregroundMuted),
          ),
        ],
      ),
    );
  }
}

Widget splitPaneBasic(BuildContext context) => const _ListDetailDemo();

Widget splitPaneAside(BuildContext context) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: SizedBox(
      height: KunSpacing.unit * 72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.neutral.shade200),
          borderRadius: BorderRadius.circular(KunRadius.lg),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KunRadius.lg),
          child: KunSplitPane(
            primary: KunSplitSide.end,
            size: 280,
            minSize: 220,
            maxSize: 360,
            start: SingleChildScrollView(
              padding: const EdgeInsets.all(KunSpacing.unit * 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '千恋＊万花',
                    style: KunText.lg.copyWith(
                      fontWeight: KunFontWeights.semibold,
                    ),
                  ),
                  const SizedBox(height: KunSpacing.unit * 3),
                  Text(
                    '穗织是一座被山环绕的温泉小镇。主角有地将臣在帮忙整理神社时，意外拔出了供奉在那里的神刀「丛雨丸」，从此被卷入与神刀之灵、巫女和小镇诅咒相关的一连串事件。',
                    style: KunText.sm.copyWith(
                      color: scheme.neutral.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            end: ColoredBox(
              color: scheme.content1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(KunSpacing.unit * 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: KunSpacing.unit * 3,
                  children: <Widget>[
                    Text(
                      '标签',
                      style: KunText.sm.copyWith(
                        fontWeight: KunFontWeights.semibold,
                      ),
                    ),
                    const Wrap(
                      spacing: KunSpacing.unit * 1.5,
                      runSpacing: KunSpacing.unit * 1.5,
                      children: <Widget>[
                        KunChip(
                          size: KunUISize.sm,
                          variant: KunUIVariant.flat,
                          child: Text('纯爱'),
                        ),
                        KunChip(
                          size: KunUISize.sm,
                          variant: KunUIVariant.flat,
                          child: Text('和风'),
                        ),
                        KunChip(
                          size: KunUISize.sm,
                          variant: KunUIVariant.flat,
                          child: Text('神社'),
                        ),
                        KunChip(
                          size: KunUISize.sm,
                          variant: KunUIVariant.flat,
                          child: Text('温泉'),
                        ),
                      ],
                    ),
                    Text(
                      '同社作品',
                      style: KunText.sm.copyWith(
                        fontWeight: KunFontWeights.semibold,
                      ),
                    ),
                    Text(
                      '天使☆騒々 RE-BOOT!',
                      style: KunText.sm.copyWith(
                        color: scheme.neutral.shade700,
                      ),
                    ),
                    Text(
                      '喫茶ステラと死神の蝶',
                      style: KunText.sm.copyWith(
                        color: scheme.neutral.shade700,
                      ),
                    ),
                    Text(
                      'サノバウィッチ',
                      style: KunText.sm.copyWith(
                        color: scheme.neutral.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _StackedDemo extends StatefulWidget {
  const _StackedDemo();

  @override
  State<_StackedDemo> createState() => _StackedDemoState();
}

class _StackedDemoState extends State<_StackedDemo> {
  KunSplitSide _pane = KunSplitSide.start;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: KunContainerWidths.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: KunSpacing.unit * 2,
          children: <Widget>[
            Row(
              spacing: KunSpacing.unit * 2,
              children: <Widget>[
                KunButton(
                  size: KunUISize.sm,
                  variant: _pane == KunSplitSide.start
                      ? KunUIVariant.solid
                      : KunUIVariant.bordered,
                  onPressed: () => setState(() => _pane = KunSplitSide.start),
                  child: const Text('列表'),
                ),
                KunButton(
                  size: KunUISize.sm,
                  variant: _pane == KunSplitSide.end
                      ? KunUIVariant.solid
                      : KunUIVariant.bordered,
                  onPressed: () => setState(() => _pane = KunSplitSide.end),
                  child: const Text('详情'),
                ),
              ],
            ),
            SizedBox(
              height: KunSpacing.unit * 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.neutral.shade200),
                  borderRadius: BorderRadius.circular(KunRadius.lg),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(KunRadius.lg),
                  child: KunSplitPane(
                    showPane: _pane,
                    start: ColoredBox(
                      color: scheme.content1,
                      child: Padding(
                        padding: const EdgeInsets.all(KunSpacing.unit * 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: KunSpacing.unit,
                          children: <Widget>[
                            Text(
                              '《星空列车与白的旅行》通关感想',
                              style: KunText.sm,
                            ),
                            Text(
                              '求推荐和《白色相簿 2》气质相近的作品',
                              style: KunText.sm,
                            ),
                            Text('2026 年秋季新作发售表', style: KunText.sm),
                          ],
                        ),
                      ),
                    ),
                    end: Padding(
                      padding: const EdgeInsets.all(KunSpacing.unit * 3),
                      child: Text(
                        '窄于 48rem 时只显示一栏，分隔线也会隐藏。',
                        style: KunText.sm.copyWith(
                          color: scheme.neutral.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget splitPaneStacked(BuildContext context) => const _StackedDemo();
