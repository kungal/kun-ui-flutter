import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

class _Rating {
  const _Rating(this.user, this.score);
  final String user;
  final double score;
}

const List<_Rating> _ratings = <_Rating>[
  _Rating('空想科学', 9.2),
  _Rating('月色真美', 8.7),
  _Rating('雨声', 9.5),
  _Rating('夏目', 8.1),
  _Rating('星之卡比', 7.9),
  _Rating('银河铁道', 9.0),
  _Rating('紫罗兰', 9.8),
  _Rating('凉宫', 8.4),
  _Rating('秒速五厘米', 8.8),
  _Rating('言叶之庭', 9.1),
  _Rating('你的名字', 9.6),
  _Rating('天气之子', 8.5),
];

Widget _page(Widget child) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: child,
  );
}

Widget scrollShadowBasic(BuildContext context) {
  return _page(
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.md),
      child: KunScrollShadow(
        semanticLabel: '标签列表',
        children: <Widget>[
          for (int n = 1; n <= 16; n++)
            KunChip(
              color: KunUIColor.primary,
              child: Text('标签 $n'),
            ),
        ],
      ),
    ),
  );
}

Widget scrollShadowInteractive(BuildContext context) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return _page(
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.md),
      child: KunScrollShadow(
        semanticLabel: '用户评分',
        wheel: KunScrollShadowWheel.contain,
        draggable: true,
        scrollbar: KunScrollShadowScrollbar.thin,
        children: <Widget>[
          for (final _Rating rating in _ratings)
            SizedBox(
              width: KunSpacing.unit * 28,
              height: KunSpacing.unit * 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.content1,
                  border: Border.all(color: scheme.border),
                  borderRadius: BorderRadius.circular(KunRadius.lg),
                  boxShadow: KunShadows.sm,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KunSpacing.unit * 2,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: KunSpacing.unit,
                    children: <Widget>[
                      Text(
                        rating.score.toStringAsFixed(1),
                        style: KunText.xl2.copyWith(
                          color: scheme.primary.solid,
                          fontWeight: KunFontWeights.bold,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      Text(
                        rating.user,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KunText.xs.copyWith(
                          color: scheme.neutral.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

Widget scrollShadowVertical(BuildContext context) {
  return _page(
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.md),
      child: SizedBox(
        height: KunSpacing.unit * 48,
        child: KunScrollShadow(
          axis: Axis.vertical,
          semanticLabel: '可滚动的卡片列表',
          children: <Widget>[
            for (int n = 1; n <= 10; n++)
              KunCard(
                color: KunUIColor.neutral,
                child: Text('第 $n 行内容'),
              ),
          ],
        ),
      ),
    ),
  );
}

Widget scrollShadowLazy(BuildContext context) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return _page(
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.md),
      child: SizedBox(
        height: KunSpacing.unit * 24,
        child: KunScrollShadow.builder(
          semanticLabel: '角色列表',
          wheel: KunScrollShadowWheel.on,
          draggable: true,
          itemCount: 200,
          itemBuilder: (BuildContext context, int index) {
            return SizedBox(
              width: KunSpacing.unit * 28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.content1,
                  border: Border.all(color: scheme.border),
                  borderRadius: BorderRadius.circular(KunRadius.lg),
                ),
                child: Center(
                  child: Text(
                    '角色 ${index + 1}',
                    style: KunText.sm.copyWith(color: scheme.foreground),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
