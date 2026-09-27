import 'package:kun_ui/kun_ui.dart';

import '../avatar_pool.dart';

/// Demo viewer id, matching the web `ME`.
const String demoMe = '1001';

/// Users for the chat leaf demos, including the deleted account `1005`.
final List<KunChatUser> demoUsers = <KunChatUser>[
  KunChatUser(id: demoMe, name: '鲲', avatar: galleryAvatarPool[0]),
  KunChatUser(id: '1002', name: '雪之下小春', avatar: galleryAvatarPool[5]),
  KunChatUser(id: '1003', name: 'Ayase', avatar: galleryAvatarPool[9]),
  KunChatUser(id: '1004', name: '樱小路露娜', avatar: galleryAvatarPool[14]),
  const KunChatUser(id: '1005', name: '', avatar: '', deleted: true),
];

const List<(String, String, String)> _reactions = <(String, String, String)>[
  ('heart', '❤️', '爱心'),
  ('fire', '🔥', '火'),
  ('party', '🎉', '庆祝'),
  ('love', '🥰', '喜欢'),
  ('clap', '👏', '鼓掌'),
  ('thinking', '🤔', '思考'),
  ('mindblown', '🤯', '震惊'),
  ('scream', '😱', '尖叫'),
  ('cry', '😢', '哭'),
  ('pray', '🙏', '感谢'),
  ('eyes', '👀', '关注'),
  ('hundred', '💯', '满分'),
  ('partyface', '🥳', '派对'),
  ('starstruck', '🤩', '星星眼'),
  ('angry', '😠', '生气'),
  ('anxious', '😰', '紧张'),
  ('banana', '🍌', '香蕉'),
  ('eyebrow', '🤨', '挑眉'),
  ('voltage', '⚡', '闪电'),
  ('hotdog', '🌭', '热狗'),
  ('hot', '🥵', '热'),
  ('sob', '😭', '大哭'),
  ('moai', '🗿', '摩艾'),
  ('newmoon', '🌚', '黑月亮'),
  ('police', '🚓', '警车'),
  ('pouting', '😡', '怒'),
  ('salute', '🫡', '敬礼'),
  ('shrimp', '🦐', '虾'),
  ('halo', '😇', '天使'),
  ('sunglasses', '😎', '酷'),
  ('whale', '🐳', '鲸鱼'),
];

/// Source line the ChatMessageMenu docs demo long-presses.
const String demoMenuMessageSource = '周末的线下聚会你去吗?';

/// Forum reaction vocabulary with kungal.com art.
final List<KunChatReactionOption> demoReactions = <KunChatReactionOption>[
  for (final (String key, String emoji, String label) in _reactions)
    KunChatReactionOption(
      key: key,
      emoji: emoji,
      label: label,
      imageUrl: 'https://www.kungal.com/emoji/$key.webp',
    ),
];

/// Parse composer syntax and mark bare `http(s)` URLs, as the docs demos do.
KunChatFormattedText demoChatMarkup(String source) {
  final KunChatFormattedText parsed = parseKunChatMarkdown(source);
  final List<KunChatEntity> entities = List<KunChatEntity>.from(
    parsed.entities,
  );
  for (final RegExpMatch match in RegExp(
    r'https?:\/\/[^\s,，。]+',
  ).allMatches(parsed.text)) {
    entities.add(
      KunChatEntity(
        type: KunChatEntityType.url,
        offset: match.start,
        length: match.end - match.start,
      ),
    );
  }
  return KunChatFormattedText(text: parsed.text, entities: entities);
}

int _seq = 0;

/// A sample message written in composer syntax.
KunChatMessage demoMessage(
  String sender,
  DateTime when,
  String source, {
  List<KunChatReaction> reactions = const <KunChatReaction>[],
}) {
  _seq += 1;
  final KunChatFormattedText parsed = demoChatMarkup(source);
  return KunChatMessage(
    id: '${90000 + _seq}',
    conversationId: '77',
    seq: _seq,
    senderId: sender,
    createdAt: when,
    text: parsed.text,
    entities: parsed.entities,
    reactions: reactions,
    clientMessageId: sender == demoMe ? 'demo-$_seq' : null,
  );
}

/// Clock time for conversation-row demos, matching the docs' `demoTime`.
///
/// Today and yesterday are counted back from now; older days are a fixed
/// date in December 2025 so the weekday/date label does not drift.
DateTime demoChatTime(int daysAgo, String hhmm) {
  final List<String> parts = hhmm.split(':');
  final int hour = int.parse(parts[0]);
  final int minute = int.parse(parts[1]);
  if (daysAgo < 2) {
    final DateTime now = DateTime.now();
    final DateTime day = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysAgo));
    return DateTime(day.year, day.month, day.day, hour, minute);
  }
  final int day = 31 - daysAgo < 1 ? 1 : 31 - daysAgo;
  return DateTime(2025, 12, day, hour, minute);
}

/// ThumbHashes the docs compute from the kungal.com stills.
const Map<String, String> demoThumbhashes = <String, String>{
  'bg/bg12': 'qPgFJIhQhKZHq4fKmJrXgIpkBQ==',
  'ren/2339': 'NCiCAwA1SJY59IhKQFeEBQqFiWaDipg=',
  'bg/bg25': 'b9eFK4YPvJfAW5yZgHkIZzc3h4dwiAg=',
  'bg/bg36': 'KBkGHIRS1Jtfm1SKaIqsq6BARw==',
  'bg/bg1': 'NdcFDISQspq+e3M3pptAbESQJg==',
  'bg/bg4': 'JpoKHIYOc2tmd3iUaIdmToBveA==',
  'ren/2337': '9BeCAgA2RqcJp5kbib+S9QiIenWUeYg=',
  'bg/bg45': 'bfcFJYg5rHbwiYqXVpaYigeSaGCJ',
};

/// Docs `resolveDemoMedia`: `https://www.kungal.com/<image_hash>.webp`.
String resolveDemoMedia(KunChatMedia media, KunChatMediaVariant variant) {
  if (media is KunChatPhoto) {
    return 'https://www.kungal.com/${media.imageHash}.webp';
  }
  return '';
}

/// A photo payload for conversation-row demos (`demoPhoto` in chatDemo.ts).
KunChatPhoto demoChatPhoto(String path, int width, int height) {
  return KunChatPhoto(
    imageHash: path,
    width: width,
    height: height,
    thumbhash: demoThumbhashes[path],
  );
}

/// What the server embeds as `reply_to` for a reply to [message].
KunChatReplyTo demoReplyTo(KunChatMessage message) {
  return KunChatReplyTo(
    seq: message.seq,
    senderId: message.senderId,
    text: message.text.length > 120
        ? message.text.substring(0, 120)
        : message.text,
    entities: <KunChatEntity>[
      for (final KunChatEntity entity in message.entities)
        if (entity.offset + entity.length <= 120) entity,
    ],
    mediaType: message.media?.type,
    deleted: false,
  );
}

/// Sample messages the ChatText demos share; later chat dispatches extend this.
final List<KunChatMessage> demoSampleMessages = <KunChatMessage>[
  demoMessage('1002', DateTime.utc(2025, 12, 29, 13, 3), '在吗在吗'),
  demoMessage(
    demoMe,
    DateTime.utc(2025, 12, 29, 13, 8),
    '```shell\nLANG=ja_JP.UTF-8 wine "Game.exe"\n```',
  ),
  demoMessage(
    '1002',
    DateTime.utc(2025, 12, 30, 2, 32),
    '通关了!最后的反转是 ||列车长就是白本人||',
  ),
];

/// A direct conversation between 鲲 and 雪之下小春 over three days.
List<KunChatMessage> makeDirectConversation() {
  _seq = 0;
  const String her = '1002';
  final List<KunChatMessage> messages = <KunChatMessage>[];
  KunChatMessage push(KunChatMessage message) {
    messages.add(message);
    return message;
  }

  push(demoMessage(her, demoChatTime(2, '21:03'), '在吗在吗'));
  push(
    demoMessage(
      her,
      demoChatTime(2, '21:03'),
      '你之前说的那个补丁我装上了,但是一进游戏就乱码',
    ),
  );
  final KunChatMessage tip = push(
    demoMessage(
      demoMe,
      demoChatTime(2, '21:07'),
      '十有八九是区域设置的问题。用 Locale Emulator 转区再开试试,或者直接这样启动:',
    ),
  );
  push(
    demoMessage(
      demoMe,
      demoChatTime(2, '21:08'),
      '```shell\nLANG=ja_JP.UTF-8 wine "Game.exe"\n```',
    ),
  );
  push(
    demoMessage(her, demoChatTime(2, '21:15'), '好了!!转区之后正常了').copyWith(
      replyTo: demoReplyTo(tip),
      reactions: const <KunChatReaction>[
        KunChatReaction(reaction: 'party', count: 1, reacted: true),
      ],
    ),
  );
  push(
    demoMessage(
      her,
      demoChatTime(2, '21:16'),
      '顺便问一下,这个补丁的汉化是完整的吗?moyu 上写的是 0.9 版',
    ).copyWith(
      context: const KunChatContext(
        site: 'moyu',
        kind: 'patch',
        id: '3021',
        title: '《星空鉄道とシロの旅》汉化补丁 v0.9',
        url: 'https://www.moyu.moe/patch/3021/introduction',
      ),
    ),
  );
  push(
    demoMessage(
      demoMe,
      demoChatTime(2, '21:20'),
      '**主线是完整的**,只有两个番外还没翻。作者说下个月会补上',
    ),
  );

  push(demoMessage(her, demoChatTime(1, '10:32'), '通关了!!!给你看我最喜欢的几张 CG'));
  const String album = '5001';
  push(
    demoMessage(her, demoChatTime(1, '10:33'), '').copyWith(
      media: demoChatPhoto('bg/bg12', 1920, 1080),
      mediaGroupId: album,
    ),
  );
  push(
    demoMessage(her, demoChatTime(1, '10:33'), '').copyWith(
      media: demoChatPhoto('ren/2339', 367, 602),
      mediaGroupId: album,
    ),
  );
  push(
    demoMessage(her, demoChatTime(1, '10:33'), '海边那段真的哭死我了').copyWith(
      media: demoChatPhoto('bg/bg25', 1920, 1239),
      mediaGroupId: album,
      reactions: const <KunChatReaction>[
        KunChatReaction(reaction: 'cry', count: 1, reacted: true),
        KunChatReaction(reaction: 'heart', count: 1, reacted: false),
      ],
    ),
  );
  final KunChatMessage spoiler = push(
    demoMessage(
      her,
      demoChatTime(1, '10:35'),
      '最后那个反转你猜到了吗?原来||列车长就是白本人||',
    ),
  );
  push(
    demoMessage(
      demoMe,
      demoChatTime(1, '10:41'),
      '猜到一半,第三章那封信就有暗示了',
    ).copyWith(
      replyTo: demoReplyTo(spoiler),
      replyQuote: const KunChatReplyQuote(
        text: '列车长就是白本人',
        offset: 14,
      ),
    ),
  );
  push(
    demoMessage(
      demoMe,
      demoChatTime(1, '10:42'),
      '推荐你接着玩同社的前作,世界观是连着的。论坛有人写过详细的考据:https://www.kungal.com/topic/1024',
    ).copyWith(editedAt: demoChatTime(1, '10:44')),
  );
  push(
    demoMessage(
      demoMe,
      demoChatTime(1, '10:42'),
      '不过前作的__系统__有点老,存档记得~~一个位~~多开几个位',
    ),
  );

  push(demoMessage(her, demoChatTime(0, '09:12'), '早上好~'));
  push(
    demoMessage(
      her,
      demoChatTime(0, '09:13'),
      '昨天你说的前作我下好了,片头曲好好听',
    ).copyWith(media: demoChatPhoto('bg/bg36', 1920, 1080)),
  );
  push(
    demoMessage(
      her,
      demoChatTime(0, '09:14'),
      '对了,[@鲲](mention:$demoMe) 周末的线下聚会你去吗?',
    ),
  );
  return messages;
}

/// A group with service messages and a pinned message.
List<KunChatMessage> makeGroupConversation() {
  _seq = 200;
  final List<KunChatMessage> messages = <KunChatMessage>[];
  KunChatMessage push(KunChatMessage message) {
    messages.add(message);
    return message;
  }

  push(
    demoMessage(demoMe, demoChatTime(1, '19:00'), '').copyWith(
      kind: KunChatMessageKind.service,
      serviceAction: const KunChatGroupCreatedAction(title: 'Galgame 汉化交流'),
    ),
  );
  push(
    demoMessage(demoMe, demoChatTime(1, '19:01'), '').copyWith(
      kind: KunChatMessageKind.service,
      serviceAction: const KunChatMembersAddedAction(
        userIds: <String>['1002', '1003', '1004'],
      ),
    ),
  );
  final KunChatMessage rules = push(
    demoMessage(
      demoMe,
      demoChatTime(1, '19:02'),
      '欢迎各位!群规就两条:聊剧情请把关键内容用剧透遮起来,比如||凶手是管家||;求资源去论坛发帖。',
    ).copyWith(pinnedAt: demoChatTime(1, '19:03')),
  );
  push(
    demoMessage(demoMe, demoChatTime(1, '19:03'), '').copyWith(
      kind: KunChatMessageKind.service,
      serviceAction: KunChatMessagePinnedAction(seq: rules.seq),
    ),
  );
  push(
    demoMessage('1003', demoChatTime(1, '19:10'), '来了来了').copyWith(
      reactions: const <KunChatReaction>[
        KunChatReaction(reaction: 'salute', count: 2, reacted: true),
      ],
    ),
  );
  push(demoMessage('1003', demoChatTime(1, '19:10'), '先问个问题:这周的机翻组进度怎么样了'));
  push(demoMessage('1004', demoChatTime(1, '19:12'), '第二章校对完了,第三章还在润色'));
  final KunChatMessage ask = push(
    demoMessage('1004', demoChatTime(1, '19:12'), '有兴趣帮忙校对的私聊我'),
  );
  push(
    demoMessage(
      '1002',
      demoChatTime(0, '08:40'),
      '我可以帮忙!日语 N2 水平够吗',
    ).copyWith(replyTo: demoReplyTo(ask)),
  );
  push(
    demoMessage('1004', demoChatTime(0, '08:45'), '够的,欢迎~').copyWith(
      reactions: const <KunChatReaction>[
        KunChatReaction(reaction: 'heart', count: 3, reacted: false),
        KunChatReaction(reaction: 'clap', count: 1, reacted: true),
      ],
    ),
  );
  push(
    demoMessage('1004', demoChatTime(0, '08:47'), '').copyWith(
      kind: KunChatMessageKind.service,
      serviceAction: const KunChatTitleChangedAction(
        title: 'Galgame 汉化交流 · 校对组',
      ),
    ),
  );
  return messages;
}

const List<String> _smallTalk = <String>[
  '今天的活动你抽到了吗',
  '还没,十连全是重复的 **五星**',
  '下周末有空一起去漫展吗?',
  '可以啊,几点集合',
  '上午十点地铁站 B 口',
  '好,我带上那本设定集',
  '昨天那集动画作画崩得有点厉害 ||最后一幕还是很感人||',
  '论坛那篇攻略写得太细了,连隐藏选项都标出来了',
  '`Ctrl` 键按住可以快进已读文本,记得在设置里打开',
  '这个补丁我试过了,Win11 下要装一下日文字体',
  '哈哈哈哈哈',
  '收到',
  '你先玩,我晚上回来继续',
  '存档记得多开几个位,这作的分支很多',
];

const List<(String, int, int)> _historyPhotos = <(String, int, int)>[
  ('bg/bg1', 1920, 1080),
  ('bg/bg4', 1920, 1200),
  ('ren/2337', 290, 599),
  ('bg/bg45', 1920, 1268),
];

/// [count] messages of back-and-forth, oldest first, ending now.
List<KunChatMessage> makeHistory(int count, {String peer = '1002'}) {
  _seq = 0;
  final List<KunChatMessage> out = <KunChatMessage>[];
  final DateTime now = DateTime.now();
  for (int i = 0; i < count; i++) {
    final DateTime at = now.subtract(Duration(minutes: (count - i) * 23));
    final String sender = i % 7 < 3 ? demoMe : peer;
    final (String, int, int)? photo =
        i % 37 == 11 ? _historyPhotos[i % _historyPhotos.length] : null;
    out.add(
      demoMessage(
        sender,
        at,
        photo == null ? _smallTalk[i % _smallTalk.length] : '',
      ).copyWith(
        media:
            photo == null ? null : demoChatPhoto(photo.$1, photo.$2, photo.$3),
        reactions: i % 13 == 5
            ? <KunChatReaction>[
                KunChatReaction(
                  reaction: 'heart',
                  count: 1 + (i % 3),
                  reacted: i % 2 == 0,
                ),
              ]
            : const <KunChatReaction>[],
      ),
    );
  }
  return out;
}
