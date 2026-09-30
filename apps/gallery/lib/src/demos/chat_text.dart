import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'chat_demo_data.dart';

Widget _frame(BuildContext context, {required Widget child, double? width}) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width ?? KunContainerWidths.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.content1,
          border: Border.all(
            color: scheme.neutral.solid.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(KunRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KunSpacing.unit * 4),
          child: child,
        ),
      ),
    ),
  );
}

Widget chatTextBasic(BuildContext context) {
  final KunChatFormattedText message = parseKunChatMarkdown(
    <String>[
      '**《星空鉄道とシロの旅》** 补丁更新了,__主线__ 已经 ++完整++ 汉化,~~番外还在路上~~ 番外下月补齐。',
      '安装说明见 [补丁页](https://www.moyu.moe/patch/3021/introduction),有问题 [@鲲](mention:$demoMe)。',
      '> 转区后再启动,不然会乱码。',
      '启动命令:',
      '```shell\nLANG=ja_JP.UTF-8 wine "Game.exe"\n```',
      '存档在 `%APPDATA%/StarRail` 下面。',
    ].join('\n'),
  );
  return _frame(
    context,
    child: KunChatText(text: message.text, entities: message.entities),
  );
}

Widget chatTextSpoiler(BuildContext context) {
  final KunChatFormattedText message = parseKunChatMarkdown(
    '通关了!最后的反转是 ||列车长就是白本人||,而且 ||第三章那封信|| 早就暗示过了。',
  );
  return _frame(
    context,
    child: KunChatText(text: message.text, entities: message.entities),
  );
}

Widget chatTextPreview(BuildContext context) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  final KunChatFormattedText message = parseKunChatMarkdown(
    '结局是 ||列车长就是白本人||!**强烈推荐**,攻略见 [论坛](https://www.kungal.com/topic/1024)\n```\nwine Game.exe\n```',
  );
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunContainerWidths.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.content1,
          border: Border.all(
            color: scheme.neutral.solid.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(KunRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KunSpacing.unit * 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '雪之下小春',
                style: KunText.sm.copyWith(fontWeight: KunFontWeights.semibold),
              ),
              const SizedBox(height: KunSpacing.unit),
              DefaultTextStyle.merge(
                style: KunText.sm.copyWith(color: scheme.foregroundMuted),
                child: KunChatText(
                  text: message.text,
                  entities: message.entities,
                  preview: true,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EventsDemo extends StatefulWidget {
  const _EventsDemo();

  @override
  State<_EventsDemo> createState() => _EventsDemoState();
}

class _EventsDemoState extends State<_EventsDemo> {
  String _log = '点一下链接或提及';

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunChatFormattedText parsed = parseKunChatMarkdown(
      '[@雪之下小春](mention:1002) 发了 [补丁页](https://www.moyu.moe/patch/3021/introduction),详见 https://www.kungal.com/topic/1024',
    );
    final int at = parsed.text.indexOf('https://www.kungal.com');
    final List<KunChatEntity> entities = <KunChatEntity>[
      ...parsed.entities,
      if (at >= 0)
        KunChatEntity(
          type: KunChatEntityType.url,
          offset: at,
          length: parsed.text.length - at,
        ),
    ];
    return _frame(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          KunChatText(
            text: parsed.text,
            entities: entities,
            onLink: (KunChatLinkEvent event) {
              event.preventDefault();
              setState(() => _log = 'link → ${event.url}');
            },
            onMention: (KunChatUserEvent event) {
              event.preventDefault();
              setState(() => _log = 'mention → 用户 ${event.userId}');
            },
          ),
          const SizedBox(height: KunSpacing.unit * 2),
          Text(
            _log,
            style: KunText.xs.copyWith(
              fontFamily: KunFontFamilies.mono,
              fontFamilyFallback: KunFontFamilies.monoFallback,
              color: scheme.foregroundMuted,
            ),
          ),
        ],
      ),
    );
  }
}

Widget chatTextEvents(BuildContext context) => const _EventsDemo();
