/// The NextMoe chat wire shapes (`/v2/chat`). Fields are camelCase;
/// `fromJson` / `toJson` read and write the wire's snake_case keys, so a
/// payload matches the web's objects. Every constructor can express anything
/// the wire can, so an app may build these from its own API client instead.
///
/// Every id is a decimal string, as everywhere in `/v2` (they are 64-bit and
/// would not survive a JavaScript number); positions and counts are numbers.
library;

import 'package:flutter/foundation.dart';

Never _invalid(String key) =>
    throw FormatException('Missing or invalid "$key"');

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is double && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  return null;
}

Map<String, Object?>? _tryMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<dynamic, dynamic> e in value.entries)
        e.key as String: e.value as Object?,
    };
  }
  return null;
}

Map<String, Object?> _reqMap(Object? value, String key) {
  final Map<String, Object?>? map = _tryMap(value);
  if (map == null) _invalid(key);
  return map;
}

String _reqString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String) _invalid(key);
  return value;
}

int _reqInt(Map<String, Object?> json, String key) {
  final int? value = _asInt(json[key]);
  if (value == null) _invalid(key);
  return value;
}

bool _reqBool(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! bool) _invalid(key);
  return value;
}

DateTime _reqDate(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String) _invalid(key);
  return DateTime.parse(value);
}

DateTime? _optDate(Object? value, String key) {
  if (value == null) return null;
  if (value is! String) _invalid(key);
  return DateTime.parse(value);
}

String _dateJson(DateTime value) => value.toUtc().toIso8601String();

Object? _canonicalize(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<dynamic, dynamic> e in value.entries)
        e.key as String: _canonicalize(e.value),
    };
  }
  if (value is List) {
    return <Object?>[
      for (final dynamic e in value) _canonicalize(e),
    ];
  }
  return value;
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final Object? key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int _deepHash(Object? value) {
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map(
        (MapEntry<dynamic, dynamic> e) =>
            Object.hash(e.key, _deepHash(e.value)),
      ),
    );
  }
  if (value is List) {
    return Object.hashAll(value.map(_deepHash));
  }
  return value.hashCode;
}

bool _sameTime(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == b;
  return a.isAtSameMomentAs(b);
}

List<KunChatEntity> _entityList(Object? value, String key) {
  if (value is! List) _invalid(key);
  final List<KunChatEntity> out = <KunChatEntity>[];
  for (final dynamic raw in value) {
    final KunChatEntity? entity = KunChatEntity.tryFromJson(raw as Object?);
    if (entity != null) out.add(entity);
  }
  return out;
}

List<String> _reqStringList(Object? value, String key) {
  if (value is! List) _invalid(key);
  final List<String> out = <String>[];
  for (final dynamic raw in value) {
    if (raw is! String) _invalid(key);
    out.add(raw);
  }
  return out;
}

List<KunChatReaction> _reactionList(Object? value, String key) {
  if (value is! List) _invalid(key);
  return <KunChatReaction>[
    for (final dynamic raw in value)
      KunChatReaction.fromJson(_reqMap(raw as Object?, key)),
  ];
}

List<Map<String, Object?>> _jsonList(List<KunChatEntity> entities) =>
    <Map<String, Object?>>[
      for (final KunChatEntity e in entities) e.toJson(),
    ];

const _CopyWithSentinel _sentinel = _CopyWithSentinel();

class _CopyWithSentinel {
  const _CopyWithSentinel();
}

/// A formatting range over a message's text. `offset` and `length` count
/// UTF-16 code units, as JavaScript string indices and Dart strings do, so a
/// range is `text.substring(offset, offset + length)` on both platforms.
enum KunChatEntityType {
  /// Wire `bold`.
  bold('bold'),

  /// Wire `italic`.
  italic('italic'),

  /// Wire `underline`.
  underline('underline'),

  /// Wire `strikethrough`.
  strikethrough('strikethrough'),

  /// Wire `spoiler`.
  spoiler('spoiler'),

  /// Wire `code`.
  code('code'),

  /// Wire `pre`.
  pre('pre'),

  /// Wire `blockquote`.
  blockquote('blockquote'),

  /// Wire `text_link`.
  textLink('text_link'),

  /// Wire `mention`.
  mention('mention'),

  /// Wire `url`.
  url('url');

  /// Creates a value with this [wireName].
  const KunChatEntityType(this.wireName);

  /// The JSON string, e.g. `'text_link'`.
  final String wireName;

  /// The value whose [wireName] is [name], or null if [name] is unknown.
  static KunChatEntityType? fromWire(String name) {
    for (final KunChatEntityType value in values) {
      if (value.wireName == name) return value;
    }
    return null;
  }
}

/// A formatting range over a message's text. `offset` and `length` count
/// UTF-16 code units, as JavaScript string indices and Dart strings do, so a
/// range is `text.substring(offset, offset + length)` on both platforms.
@immutable
class KunChatEntity {
  /// Creates an entity. Positions may be empty, negative, or lack `url` /
  /// `userId`; `normalizeKunChatEntities` drops those, as upstream does.
  const KunChatEntity({
    required this.type,
    required this.offset,
    required this.length,
    this.userId,
    this.url,
    this.language,
  });

  /// The formatting kind.
  final KunChatEntityType type;

  /// Start in the message text, in UTF-16 code units.
  final int offset;

  /// Length in UTF-16 code units.
  final int length;

  /// `mention` only: the mentioned user.
  final String? userId;

  /// `text_link` only: the link target.
  final String? url;

  /// `pre` only: the code block's language, e.g. `go`.
  final String? language;

  /// Reads one entity. Returns null for an unknown type, a non-integral
  /// offset or length, a wrongly typed field, or a non-map — the web's
  /// `normalizeKunChatEntities` drops those rather than throwing.
  static KunChatEntity? tryFromJson(Object? json) {
    final Map<String, Object?>? map = _tryMap(json);
    if (map == null) return null;
    final Object? typeRaw = map['type'];
    if (typeRaw is! String) return null;
    final KunChatEntityType? type = KunChatEntityType.fromWire(typeRaw);
    if (type == null) return null;
    final int? offset = _asInt(map['offset']);
    final int? length = _asInt(map['length']);
    if (offset == null || length == null) return null;
    final Object? userId = map['user_id'];
    if (userId != null && userId is! String) return null;
    final Object? url = map['url'];
    if (url != null && url is! String) return null;
    final Object? language = map['language'];
    if (language != null && language is! String) return null;
    return KunChatEntity(
      type: type,
      offset: offset,
      length: length,
      userId: userId as String?,
      url: url as String?,
      language: language as String?,
    );
  }

  /// Snake-case wire JSON. Optional fields whose value is null are omitted.
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type.wireName,
        'offset': offset,
        'length': length,
        if (userId != null) 'user_id': userId,
        if (url != null) 'url': url,
        if (language != null) 'language': language,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatEntity &&
      other.type == type &&
      other.offset == offset &&
      other.length == length &&
      other.userId == userId &&
      other.url == url &&
      other.language == language;

  @override
  int get hashCode => Object.hash(type, offset, length, userId, url, language);

  @override
  String toString() => 'KunChatEntity(${type.wireName}, $offset+$length'
      '${userId != null ? ', userId: $userId' : ''}'
      '${url != null ? ', url: $url' : ''}'
      '${language != null ? ', language: $language' : ''})';
}

/// Media attached to a message. Only `photo` exists today; sticker and file
/// arrive later, and every consumer switches on [type].
@immutable
sealed class KunChatMedia {
  /// Creates a media value.
  const KunChatMedia();

  /// Wire `type`.
  String get type;

  /// Snake-case wire JSON.
  Map<String, Object?> toJson();

  /// Reads a media object. `type == 'photo'` is [KunChatPhoto]; any other
  /// type is [KunChatUnknownMedia].
  factory KunChatMedia.fromJson(Map<String, Object?> json) {
    final String type = _reqString(json, 'type');
    if (type == 'photo') return KunChatPhoto.fromJson(json);
    return KunChatUnknownMedia(
      type: type,
      data: <String, Object?>{
        for (final MapEntry<String, Object?> e in json.entries)
          if (e.key != 'type') e.key: _canonicalize(e.value),
      },
    );
  }
}

/// A photo attached to a message.
@immutable
class KunChatPhoto extends KunChatMedia {
  /// Creates a photo.
  const KunChatPhoto({
    required this.imageHash,
    required this.width,
    required this.height,
    this.thumbhash,
    this.url,
  });

  /// Image-service hash. KunUI never builds a URL from it.
  final String imageHash;

  /// Pixel width.
  final int width;

  /// Pixel height.
  final int height;

  /// ThumbHash payload, when the server sent one.
  final String? thumbhash;

  /// Where the image is served, as the server sends it (chat spec 1.1.0).
  /// Shown when no `resolveMediaUrl` is passed. Optional so payloads from
  /// before 1.1.0 still parse.
  final String? url;

  @override
  String get type => 'photo';

  /// Reads a `type: 'photo'` object.
  factory KunChatPhoto.fromJson(Map<String, Object?> json) {
    return KunChatPhoto(
      imageHash: _reqString(json, 'image_hash'),
      width: _reqInt(json, 'width'),
      height: _reqInt(json, 'height'),
      thumbhash: json['thumbhash'] == null
          ? null
          : (json['thumbhash'] is String
              ? json['thumbhash'] as String
              : _invalid('thumbhash')),
      url: json['url'] == null
          ? null
          : (json['url'] is String ? json['url'] as String : _invalid('url')),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'image_hash': imageHash,
        'width': width,
        'height': height,
        if (thumbhash != null) 'thumbhash': thumbhash,
        if (url != null) 'url': url,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatPhoto &&
      other.imageHash == imageHash &&
      other.width == width &&
      other.height == height &&
      other.thumbhash == thumbhash &&
      other.url == url;

  @override
  int get hashCode => Object.hash(imageHash, width, height, thumbhash, url);

  @override
  String toString() => 'KunChatPhoto(imageHash: $imageHash, ${width}x$height)';
}

/// Media whose wire `type` this port does not yet model.
@immutable
class KunChatUnknownMedia extends KunChatMedia {
  /// Creates an unknown variant. [data] holds the wire object's other fields
  /// verbatim, so this can express anything the wire can.
  const KunChatUnknownMedia({required this.type, this.data = const {}});

  @override
  final String type;

  /// Wire fields other than `type`.
  final Map<String, Object?> data;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        ...data,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatUnknownMedia &&
      other.type == type &&
      _deepEquals(other.data, data);

  @override
  int get hashCode => Object.hash(type, _deepHash(data));

  @override
  String toString() => 'KunChatUnknownMedia(type: $type, data: $data)';
}

/// The message a reply points at, embedded by the server so a reply renders
/// without fetching its target.
@immutable
class KunChatReplyTo {
  /// Creates a reply target.
  const KunChatReplyTo({
    required this.seq,
    required this.senderId,
    required this.text,
    this.entities = const <KunChatEntity>[],
    this.mediaType,
    required this.deleted,
  });

  /// Position of the target in its conversation.
  final int seq;

  /// Sender of the target.
  final String senderId;

  /// Target text.
  final String text;

  /// Target entities.
  final List<KunChatEntity> entities;

  /// The replied-to message's `media.type`, or null.
  final String? mediaType;

  /// The target was deleted for everyone; render "message deleted".
  final bool deleted;

  /// Reads a reply-to object.
  factory KunChatReplyTo.fromJson(Map<String, Object?> json) {
    final Object? mediaType = json['media_type'];
    if (mediaType != null && mediaType is! String) _invalid('media_type');
    return KunChatReplyTo(
      seq: _reqInt(json, 'seq'),
      senderId: _reqString(json, 'sender_id'),
      text: _reqString(json, 'text'),
      entities: _entityList(json['entities'], 'entities'),
      mediaType: mediaType as String?,
      deleted: _reqBool(json, 'deleted'),
    );
  }

  /// Snake-case wire JSON. `media_type` is written even when null.
  Map<String, Object?> toJson() => <String, Object?>{
        'seq': seq,
        'sender_id': senderId,
        'text': text,
        'entities': _jsonList(entities),
        'media_type': mediaType,
        'deleted': deleted,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatReplyTo &&
      other.seq == seq &&
      other.senderId == senderId &&
      other.text == text &&
      listEquals(other.entities, entities) &&
      other.mediaType == mediaType &&
      other.deleted == deleted;

  @override
  int get hashCode => Object.hash(
        seq,
        senderId,
        text,
        Object.hashAll(entities),
        mediaType,
        deleted,
      );

  @override
  String toString() =>
      'KunChatReplyTo(seq: $seq, senderId: $senderId, deleted: $deleted)';
}

/// A reply that quotes only part of its target. `offset` is where the quote
/// starts in the target's text, in UTF-16 code units.
@immutable
class KunChatReplyQuote {
  /// Creates a partial quote.
  const KunChatReplyQuote({
    required this.text,
    this.entities = const <KunChatEntity>[],
    required this.offset,
  });

  /// Quoted text.
  final String text;

  /// Entities clipped to the quote.
  final List<KunChatEntity> entities;

  /// Where the quote starts in the target's text, in UTF-16 code units.
  final int offset;

  /// Reads a reply-quote object.
  factory KunChatReplyQuote.fromJson(Map<String, Object?> json) {
    return KunChatReplyQuote(
      text: _reqString(json, 'text'),
      entities: _entityList(json['entities'], 'entities'),
      offset: _reqInt(json, 'offset'),
    );
  }

  /// Snake-case wire JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'text': text,
        'entities': _jsonList(entities),
        'offset': offset,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatReplyQuote &&
      other.text == text &&
      listEquals(other.entities, entities) &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(text, Object.hashAll(entities), offset);

  @override
  String toString() => 'KunChatReplyQuote(offset: $offset, text: $text)';
}

/// A service-message action. Unknown wire types become [KunChatUnknownAction].
@immutable
sealed class KunChatServiceAction {
  /// Creates an action.
  const KunChatServiceAction();

  /// Wire `type`.
  String get type;

  /// Snake-case wire JSON.
  Map<String, Object?> toJson();

  /// Reads an action. The eight known types become their classes; any other
  /// type is [KunChatUnknownAction].
  factory KunChatServiceAction.fromJson(Map<String, Object?> json) {
    final String type = _reqString(json, 'type');
    switch (type) {
      case 'group_created':
        final Object? title = json['title'];
        if (title != null && title is! String) _invalid('title');
        return KunChatGroupCreatedAction(title: title as String?);
      case 'members_added':
        return KunChatMembersAddedAction(
          userIds: _reqStringList(json['user_ids'], 'user_ids'),
        );
      case 'member_left':
        return const KunChatMemberLeftAction();
      case 'member_removed':
        return KunChatMemberRemovedAction(userId: _reqString(json, 'user_id'));
      case 'title_changed':
        return KunChatTitleChangedAction(title: _reqString(json, 'title'));
      case 'photo_changed':
        return const KunChatPhotoChangedAction();
      case 'message_pinned':
        return KunChatMessagePinnedAction(seq: _reqInt(json, 'seq'));
      case 'joined_by_link':
        return const KunChatJoinedByLinkAction();
      default:
        return KunChatUnknownAction(
          type: type,
          data: <String, Object?>{
            for (final MapEntry<String, Object?> e in json.entries)
              if (e.key != 'type') e.key: _canonicalize(e.value),
          },
        );
    }
  }
}

/// Wire `group_created`.
@immutable
class KunChatGroupCreatedAction extends KunChatServiceAction {
  /// Creates a group-created action.
  const KunChatGroupCreatedAction({this.title});

  /// Optional title the group was created with.
  final String? title;

  @override
  String get type => 'group_created';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        if (title != null) 'title': title,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatGroupCreatedAction && other.title == title;

  @override
  int get hashCode => title.hashCode;

  @override
  String toString() => 'KunChatGroupCreatedAction(title: $title)';
}

/// Wire `members_added`.
@immutable
class KunChatMembersAddedAction extends KunChatServiceAction {
  /// Creates a members-added action.
  const KunChatMembersAddedAction({required this.userIds});

  /// Users that were added.
  final List<String> userIds;

  @override
  String get type => 'members_added';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'user_ids': userIds,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatMembersAddedAction && listEquals(other.userIds, userIds);

  @override
  int get hashCode => Object.hashAll(userIds);

  @override
  String toString() => 'KunChatMembersAddedAction(userIds: $userIds)';
}

/// Wire `member_left`.
@immutable
class KunChatMemberLeftAction extends KunChatServiceAction {
  /// Creates a member-left action.
  const KunChatMemberLeftAction();

  @override
  String get type => 'member_left';

  @override
  Map<String, Object?> toJson() =>
      const <String, Object?>{'type': 'member_left'};

  @override
  bool operator ==(Object other) => other is KunChatMemberLeftAction;

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() => 'KunChatMemberLeftAction()';
}

/// Wire `member_removed`.
@immutable
class KunChatMemberRemovedAction extends KunChatServiceAction {
  /// Creates a member-removed action.
  const KunChatMemberRemovedAction({required this.userId});

  /// The removed user.
  final String userId;

  @override
  String get type => 'member_removed';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'user_id': userId,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatMemberRemovedAction && other.userId == userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() => 'KunChatMemberRemovedAction(userId: $userId)';
}

/// Wire `title_changed`.
@immutable
class KunChatTitleChangedAction extends KunChatServiceAction {
  /// Creates a title-changed action.
  const KunChatTitleChangedAction({required this.title});

  /// The new title.
  final String title;

  @override
  String get type => 'title_changed';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'title': title,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatTitleChangedAction && other.title == title;

  @override
  int get hashCode => title.hashCode;

  @override
  String toString() => 'KunChatTitleChangedAction(title: $title)';
}

/// Wire `photo_changed`.
@immutable
class KunChatPhotoChangedAction extends KunChatServiceAction {
  /// Creates a photo-changed action.
  const KunChatPhotoChangedAction();

  @override
  String get type => 'photo_changed';

  @override
  Map<String, Object?> toJson() =>
      const <String, Object?>{'type': 'photo_changed'};

  @override
  bool operator ==(Object other) => other is KunChatPhotoChangedAction;

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() => 'KunChatPhotoChangedAction()';
}

/// Wire `message_pinned`.
@immutable
class KunChatMessagePinnedAction extends KunChatServiceAction {
  /// Creates a message-pinned action.
  const KunChatMessagePinnedAction({required this.seq});

  /// Sequence of the pinned message.
  final int seq;

  @override
  String get type => 'message_pinned';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'seq': seq,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatMessagePinnedAction && other.seq == seq;

  @override
  int get hashCode => seq.hashCode;

  @override
  String toString() => 'KunChatMessagePinnedAction(seq: $seq)';
}

/// Wire `joined_by_link`.
@immutable
class KunChatJoinedByLinkAction extends KunChatServiceAction {
  /// Creates a joined-by-link action.
  const KunChatJoinedByLinkAction();

  @override
  String get type => 'joined_by_link';

  @override
  Map<String, Object?> toJson() =>
      const <String, Object?>{'type': 'joined_by_link'};

  @override
  bool operator ==(Object other) => other is KunChatJoinedByLinkAction;

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() => 'KunChatJoinedByLinkAction()';
}

/// An action whose wire `type` this port does not yet model.
@immutable
class KunChatUnknownAction extends KunChatServiceAction {
  /// Creates an unknown variant. [data] holds the wire object's other fields
  /// verbatim, so this can express anything the wire can.
  const KunChatUnknownAction({required this.type, this.data = const {}});

  @override
  final String type;

  /// Wire fields other than `type`.
  final Map<String, Object?> data;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        ...data,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatUnknownAction &&
      other.type == type &&
      _deepEquals(other.data, data);

  @override
  int get hashCode => Object.hash(type, _deepHash(data));

  @override
  String toString() => 'KunChatUnknownAction(type: $type, data: $data)';
}

/// A cross-site context card, e.g. "sent from the moyu page of patch X".
@immutable
class KunChatContext {
  /// Creates a context card.
  const KunChatContext({
    required this.site,
    required this.kind,
    required this.id,
    required this.title,
    required this.url,
  });

  /// Site the context belongs to.
  final String site;

  /// Kind of context object.
  final String kind;

  /// Id of the context object.
  final String id;

  /// Display title.
  final String title;

  /// Link to the context.
  final String url;

  /// Reads a context object.
  factory KunChatContext.fromJson(Map<String, Object?> json) {
    return KunChatContext(
      site: _reqString(json, 'site'),
      kind: _reqString(json, 'kind'),
      id: _reqString(json, 'id'),
      title: _reqString(json, 'title'),
      url: _reqString(json, 'url'),
    );
  }

  /// Snake-case wire JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'site': site,
        'kind': kind,
        'id': id,
        'title': title,
        'url': url,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatContext &&
      other.site == site &&
      other.kind == kind &&
      other.id == id &&
      other.title == title &&
      other.url == url;

  @override
  int get hashCode => Object.hash(site, kind, id, title, url);

  @override
  String toString() =>
      'KunChatContext(site: $site, kind: $kind, id: $id, title: $title)';
}

/// One reaction tally on a message.
@immutable
class KunChatReaction {
  /// Creates a reaction tally.
  const KunChatReaction({
    required this.reaction,
    required this.count,
    required this.reacted,
  });

  /// A key from the reaction vocabulary, never an emoji character.
  final String reaction;

  /// How many users chose this reaction.
  final int count;

  /// Whether the viewer is one of [count].
  final bool reacted;

  /// Reads a reaction tally.
  factory KunChatReaction.fromJson(Map<String, Object?> json) {
    return KunChatReaction(
      reaction: _reqString(json, 'reaction'),
      count: _reqInt(json, 'count'),
      reacted: _reqBool(json, 'reacted'),
    );
  }

  /// Snake-case wire JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'reaction': reaction,
        'count': count,
        'reacted': reacted,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatReaction &&
      other.reaction == reaction &&
      other.count == count &&
      other.reacted == reacted;

  @override
  int get hashCode => Object.hash(reaction, count, reacted);

  @override
  String toString() =>
      'KunChatReaction(reaction: $reaction, count: $count, reacted: $reacted)';
}

/// One entry of the reaction vocabulary served by `GET /v2/chat/reactions`.
@immutable
class KunChatReactionOption {
  /// Creates a vocabulary entry.
  const KunChatReactionOption({
    required this.key,
    required this.emoji,
    required this.label,
    this.imageUrl,
  });

  /// Stable key.
  final String key;

  /// Native emoji, shown when there is no [imageUrl].
  final String emoji;

  /// Accessible name, e.g. "爱心".
  final String label;

  /// Animated image to draw instead of the emoji.
  final String? imageUrl;

  /// Reads a vocabulary entry.
  factory KunChatReactionOption.fromJson(Map<String, Object?> json) {
    final Object? imageUrl = json['image_url'];
    if (imageUrl != null && imageUrl is! String) _invalid('image_url');
    return KunChatReactionOption(
      key: _reqString(json, 'key'),
      emoji: _reqString(json, 'emoji'),
      label: _reqString(json, 'label'),
      imageUrl: imageUrl as String?,
    );
  }

  /// Snake-case wire JSON. `image_url` is omitted when null.
  Map<String, Object?> toJson() => <String, Object?>{
        'key': key,
        'emoji': emoji,
        'label': label,
        if (imageUrl != null) 'image_url': imageUrl,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatReactionOption &&
      other.key == key &&
      other.emoji == emoji &&
      other.label == label &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(key, emoji, label, imageUrl);

  @override
  String toString() =>
      'KunChatReactionOption(key: $key, emoji: $emoji, label: $label)';
}

/// Client-side delivery state of a message the viewer sent.
enum KunChatSendStatus {
  /// Wire `sending`.
  sending('sending'),

  /// Wire `sent`.
  sent('sent'),

  /// Wire `read`.
  read('read'),

  /// Wire `failed`.
  failed('failed');

  /// Creates a value with this [wireName].
  const KunChatSendStatus(this.wireName);

  /// The JSON string.
  final String wireName;

  /// The value whose [wireName] is [name], or null if [name] is unknown.
  static KunChatSendStatus? fromWire(String name) {
    for (final KunChatSendStatus value in values) {
      if (value.wireName == name) return value;
    }
    return null;
  }
}

/// Whether a message is ordinary or a service event.
enum KunChatMessageKind {
  /// Wire `message`.
  message('message'),

  /// Wire `service`.
  service('service');

  /// Creates a value with this [wireName].
  const KunChatMessageKind(this.wireName);

  /// The JSON string.
  final String wireName;

  /// The value whose [wireName] is [name], or null if [name] is unknown.
  static KunChatMessageKind? fromWire(String name) {
    for (final KunChatMessageKind value in values) {
      if (value.wireName == name) return value;
    }
    return null;
  }
}

/// A chat message, service or ordinary.
@immutable
class KunChatMessage {
  /// Creates a message.
  const KunChatMessage({
    required this.id,
    required this.conversationId,
    required this.seq,
    required this.senderId,
    required this.createdAt,
    this.kind = KunChatMessageKind.message,
    this.text = '',
    this.entities = const <KunChatEntity>[],
    this.media,
    this.mediaGroupId,
    this.replyTo,
    this.replyQuote,
    this.serviceAction,
    this.context,
    this.reactions = const <KunChatReaction>[],
    this.silent = false,
    this.pinnedAt,
    this.editedAt,
    this.clientMessageId,
    this.status,
  });

  /// Message id, a decimal string.
  final String id;

  /// Conversation id, a decimal string.
  final String conversationId;

  /// Position in the conversation, from 1, gap-free.
  final int seq;

  /// Sender id, a decimal string.
  final String senderId;

  /// Ordinary message or service event. Anything but wire `service` is
  /// [KunChatMessageKind.message].
  final KunChatMessageKind kind;

  /// Message text.
  final String text;

  /// Formatting ranges over [text].
  final List<KunChatEntity> entities;

  /// Attached media, if any.
  final KunChatMedia? media;

  /// Photos sent together share one value; each photo is its own message.
  final String? mediaGroupId;

  /// The message this one replies to, or null.
  final KunChatReplyTo? replyTo;

  /// A partial quote of the reply target, or null.
  final KunChatReplyQuote? replyQuote;

  /// Service payload when [kind] is [KunChatMessageKind.service].
  final KunChatServiceAction? serviceAction;

  /// Cross-site context card, or null.
  final KunChatContext? context;

  /// Reaction tallies.
  final List<KunChatReaction> reactions;

  /// Whether the message was sent silently.
  final bool silent;

  /// When the message was pinned, or null.
  final DateTime? pinnedAt;

  /// When the message was last edited, or null.
  final DateTime? editedAt;

  /// When the message was created.
  final DateTime createdAt;

  /// Local only: the idempotency key a pending message was sent with. Kept on
  /// the confirmed message, it keeps the row's identity across confirmation.
  final String? clientMessageId;

  /// Local only: the delivery state of the viewer's own message. When absent
  /// it is derived — `read` at or below the peer's read cursor, else `sent`.
  final KunChatSendStatus? status;

  /// Reads a message object. The TS `object?: 'message'` tag is ignored.
  factory KunChatMessage.fromJson(Map<String, Object?> json) {
    if (!json.containsKey('id')) _invalid('id');
    if (json['id'] is num) _invalid('id');
    if (!json.containsKey('conversation_id')) _invalid('conversation_id');
    if (json['conversation_id'] is num) _invalid('conversation_id');
    if (!json.containsKey('sender_id')) _invalid('sender_id');
    if (json['sender_id'] is num) _invalid('sender_id');
    final Object? kindRaw = json['kind'];
    if (kindRaw is! String) _invalid('kind');
    final Object? statusRaw = json['status'];
    KunChatSendStatus? status;
    if (statusRaw != null) {
      if (statusRaw is! String) _invalid('status');
      status = KunChatSendStatus.fromWire(statusRaw);
      if (status == null) _invalid('status');
    }
    final Object? clientMessageId = json['client_message_id'];
    if (clientMessageId != null && clientMessageId is! String) {
      _invalid('client_message_id');
    }
    final Object? mediaRaw = json['media'];
    final Object? replyToRaw = json['reply_to'];
    final Object? replyQuoteRaw = json['reply_quote'];
    final Object? serviceRaw = json['service_action'];
    final Object? contextRaw = json['context'];
    return KunChatMessage(
      id: _reqString(json, 'id'),
      conversationId: _reqString(json, 'conversation_id'),
      seq: _reqInt(json, 'seq'),
      senderId: _reqString(json, 'sender_id'),
      kind: kindRaw == 'service'
          ? KunChatMessageKind.service
          : KunChatMessageKind.message,
      text: _reqString(json, 'text'),
      entities: _entityList(json['entities'], 'entities'),
      media: mediaRaw == null
          ? null
          : KunChatMedia.fromJson(_reqMap(mediaRaw, 'media')),
      mediaGroupId: json['media_group_id'] == null
          ? null
          : (json['media_group_id'] is String
              ? json['media_group_id'] as String
              : _invalid('media_group_id')),
      replyTo: replyToRaw == null
          ? null
          : KunChatReplyTo.fromJson(_reqMap(replyToRaw, 'reply_to')),
      replyQuote: replyQuoteRaw == null
          ? null
          : KunChatReplyQuote.fromJson(_reqMap(replyQuoteRaw, 'reply_quote')),
      serviceAction: serviceRaw == null
          ? null
          : KunChatServiceAction.fromJson(
              _reqMap(serviceRaw, 'service_action'),
            ),
      context: contextRaw == null
          ? null
          : KunChatContext.fromJson(_reqMap(contextRaw, 'context')),
      reactions: _reactionList(json['reactions'], 'reactions'),
      silent: _reqBool(json, 'silent'),
      pinnedAt: _optDate(json['pinned_at'], 'pinned_at'),
      editedAt: _optDate(json['edited_at'], 'edited_at'),
      createdAt: _reqDate(json, 'created_at'),
      clientMessageId: clientMessageId as String?,
      status: status,
    );
  }

  /// Snake-case wire JSON. Optional (`?:`) keys whose value is null are
  /// omitted; `| null` keys are written as JSON null. The `object` tag is
  /// not written.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'conversation_id': conversationId,
        'seq': seq,
        'sender_id': senderId,
        'kind': kind.wireName,
        'text': text,
        'entities': _jsonList(entities),
        'media': media?.toJson(),
        'media_group_id': mediaGroupId,
        'reply_to': replyTo?.toJson(),
        'reply_quote': replyQuote?.toJson(),
        'service_action': serviceAction?.toJson(),
        'context': context?.toJson(),
        'reactions': <Map<String, Object?>>[
          for (final KunChatReaction r in reactions) r.toJson(),
        ],
        'silent': silent,
        'pinned_at': pinnedAt == null ? null : _dateJson(pinnedAt!),
        'edited_at': editedAt == null ? null : _dateJson(editedAt!),
        'created_at': _dateJson(createdAt),
        if (clientMessageId != null) 'client_message_id': clientMessageId,
        if (status != null) 'status': status!.wireName,
      };

  /// Copies this message. Passing `null` explicitly for a nullable field
  /// clears it, for example to move [status] back to derived.
  KunChatMessage copyWith({
    String? id,
    String? conversationId,
    int? seq,
    String? senderId,
    DateTime? createdAt,
    KunChatMessageKind? kind,
    String? text,
    List<KunChatEntity>? entities,
    Object? media = _sentinel,
    Object? mediaGroupId = _sentinel,
    Object? replyTo = _sentinel,
    Object? replyQuote = _sentinel,
    Object? serviceAction = _sentinel,
    Object? context = _sentinel,
    List<KunChatReaction>? reactions,
    bool? silent,
    Object? pinnedAt = _sentinel,
    Object? editedAt = _sentinel,
    Object? clientMessageId = _sentinel,
    Object? status = _sentinel,
  }) {
    return KunChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      seq: seq ?? this.seq,
      senderId: senderId ?? this.senderId,
      createdAt: createdAt ?? this.createdAt,
      kind: kind ?? this.kind,
      text: text ?? this.text,
      entities: entities ?? this.entities,
      media: identical(media, _sentinel) ? this.media : media as KunChatMedia?,
      mediaGroupId: identical(mediaGroupId, _sentinel)
          ? this.mediaGroupId
          : mediaGroupId as String?,
      replyTo: identical(replyTo, _sentinel)
          ? this.replyTo
          : replyTo as KunChatReplyTo?,
      replyQuote: identical(replyQuote, _sentinel)
          ? this.replyQuote
          : replyQuote as KunChatReplyQuote?,
      serviceAction: identical(serviceAction, _sentinel)
          ? this.serviceAction
          : serviceAction as KunChatServiceAction?,
      context: identical(context, _sentinel)
          ? this.context
          : context as KunChatContext?,
      reactions: reactions ?? this.reactions,
      silent: silent ?? this.silent,
      pinnedAt: identical(pinnedAt, _sentinel)
          ? this.pinnedAt
          : pinnedAt as DateTime?,
      editedAt: identical(editedAt, _sentinel)
          ? this.editedAt
          : editedAt as DateTime?,
      clientMessageId: identical(clientMessageId, _sentinel)
          ? this.clientMessageId
          : clientMessageId as String?,
      status: identical(status, _sentinel)
          ? this.status
          : status as KunChatSendStatus?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KunChatMessage &&
      other.id == id &&
      other.conversationId == conversationId &&
      other.seq == seq &&
      other.senderId == senderId &&
      other.kind == kind &&
      other.text == text &&
      listEquals(other.entities, entities) &&
      other.media == media &&
      other.mediaGroupId == mediaGroupId &&
      other.replyTo == replyTo &&
      other.replyQuote == replyQuote &&
      other.serviceAction == serviceAction &&
      other.context == context &&
      listEquals(other.reactions, reactions) &&
      other.silent == silent &&
      _sameTime(other.pinnedAt, pinnedAt) &&
      _sameTime(other.editedAt, editedAt) &&
      _sameTime(other.createdAt, createdAt) &&
      other.clientMessageId == clientMessageId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(
        id,
        conversationId,
        seq,
        senderId,
        kind,
        text,
        Object.hashAll(entities),
        media,
        mediaGroupId,
        replyTo,
        replyQuote,
        serviceAction,
        context,
        Object.hashAll(reactions),
        silent,
        Object.hash(
          pinnedAt?.microsecondsSinceEpoch,
          editedAt?.microsecondsSinceEpoch,
          createdAt.microsecondsSinceEpoch,
          clientMessageId,
          status,
        ),
      );

  @override
  String toString() =>
      'KunChatMessage(id: $id, seq: $seq, kind: ${kind.wireName})';
}

/// The result of parsing composer input, and what a send carries.
@immutable
class KunChatFormattedText {
  /// Creates parsed composer output.
  const KunChatFormattedText({
    required this.text,
    this.entities = const <KunChatEntity>[],
  });

  /// Message text, with markers stripped.
  final String text;

  /// Formatting ranges over [text].
  final List<KunChatEntity> entities;

  @override
  bool operator ==(Object other) =>
      other is KunChatFormattedText &&
      other.text == text &&
      listEquals(other.entities, entities);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(entities));

  @override
  String toString() => 'KunChatFormattedText(text: $text, entities: $entities)';
}

/// A member of the `users` array chat responses carry. A deleted account keeps
/// its id with an empty name and `deleted: true`; the components render it as
/// "deleted account" with the fallback avatar. Not a `KunUser`: that one's id
/// is a number, this one's a string.
@immutable
class KunChatUser {
  /// Creates a chat user. The TS `object?: 'user'` tag is not modelled.
  const KunChatUser({
    required this.id,
    required this.name,
    required this.avatar,
    this.deleted,
  });

  /// User id, a decimal string.
  final String id;

  /// Display name.
  final String name;

  /// Avatar URL or hash as the wire sent it.
  final String avatar;

  /// Whether the account is deleted.
  final bool? deleted;

  /// Reads a user object. The `object` tag is ignored.
  factory KunChatUser.fromJson(Map<String, Object?> json) {
    if (json['id'] is num) _invalid('id');
    final Object? deleted = json['deleted'];
    if (deleted != null && deleted is! bool) _invalid('deleted');
    return KunChatUser(
      id: _reqString(json, 'id'),
      name: _reqString(json, 'name'),
      avatar: _reqString(json, 'avatar'),
      deleted: deleted as bool?,
    );
  }

  /// Snake-case wire JSON. `deleted` is omitted when null. The `object` tag
  /// is not written.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'avatar': avatar,
        if (deleted != null) 'deleted': deleted,
      };

  @override
  bool operator ==(Object other) =>
      other is KunChatUser &&
      other.id == id &&
      other.name == name &&
      other.avatar == avatar &&
      other.deleted == deleted;

  @override
  int get hashCode => Object.hash(id, name, avatar, deleted);

  @override
  String toString() => 'KunChatUser(id: $id, name: $name, deleted: $deleted)';
}

/// A typing notification as the site received it. [at] is the receiving
/// client's own clock, never the server's, so the 6-second expiry is immune
/// to clock skew. Not a wire object: no JSON.
@immutable
class KunChatTypingEvent {
  /// Creates a typing event. [at] is from the receiving device's clock.
  const KunChatTypingEvent({required this.userId, required this.at});

  /// Who is typing.
  final String userId;

  /// When the notification was received, on this device.
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is KunChatTypingEvent &&
      other.userId == userId &&
      _sameTime(other.at, at);

  @override
  int get hashCode => Object.hash(userId, at.microsecondsSinceEpoch);

  @override
  String toString() => 'KunChatTypingEvent(userId: $userId, at: $at)';
}
