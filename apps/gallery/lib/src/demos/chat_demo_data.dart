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
