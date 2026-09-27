import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Map<String, Object?> jsonMap(Map<String, Object?> map) => map;

void main() {
  final DateTime created = DateTime.parse('2026-09-27T02:00:00.000Z');
  final DateTime pinned = DateTime.parse('2026-09-27T03:00:00.000Z');
  final DateTime edited = DateTime.parse('2026-09-27T04:00:00.000Z');

  final KunChatMessage full = KunChatMessage(
    id: '10',
    conversationId: '20',
    seq: 7,
    senderId: '30',
    createdAt: created,
    kind: KunChatMessageKind.message,
    text: 'hello',
    entities: const <KunChatEntity>[
      KunChatEntity(type: KunChatEntityType.bold, offset: 0, length: 5),
    ],
    media: const KunChatPhoto(
      imageHash: 'img',
      width: 640,
      height: 480,
      thumbhash: 'th',
    ),
    mediaGroupId: 'g1',
    replyTo: const KunChatReplyTo(
      seq: 3,
      senderId: '40',
      text: 'prior',
      entities: <KunChatEntity>[
        KunChatEntity(type: KunChatEntityType.italic, offset: 0, length: 5),
      ],
      mediaType: 'photo',
      deleted: false,
    ),
    replyQuote: const KunChatReplyQuote(
      text: 'pri',
      entities: <KunChatEntity>[
        KunChatEntity(type: KunChatEntityType.italic, offset: 0, length: 3),
      ],
      offset: 0,
    ),
    context: const KunChatContext(
      site: 'moyu',
      kind: 'patch',
      id: '9',
      title: 'patch nine',
      url: 'https://moyu.moe/p/9',
    ),
    reactions: const <KunChatReaction>[
      KunChatReaction(reaction: 'heart', count: 2, reacted: true),
    ],
    silent: true,
    pinnedAt: pinned,
    editedAt: edited,
    clientMessageId: 'c-1',
    status: KunChatSendStatus.sending,
  );

  final KunChatMessage service = KunChatMessage(
    id: '11',
    conversationId: '20',
    seq: 8,
    senderId: '30',
    createdAt: created,
    kind: KunChatMessageKind.service,
    serviceAction: const KunChatMembersAddedAction(userIds: <String>['1', '2']),
  );

  test('a full KunChatMessage JSON round trip', () {
    expect(KunChatMessage.fromJson(full.toJson()), full);
    expect(KunChatMessage.fromJson(service.toJson()), service);
  });

  test('unknown media and service-action variants survive fromJson → toJson',
      () {
    const KunChatUnknownMedia media = KunChatUnknownMedia(
      type: 'sticker',
      data: <String, Object?>{'file_id': 'f', 'w': 1},
    );
    expect(KunChatMedia.fromJson(media.toJson()), media);

    const KunChatUnknownAction action = KunChatUnknownAction(
      type: 'topic_created',
      data: <String, Object?>{
        'title': 'hi',
        'nested': <String, Object?>{'n': 1}
      },
    );
    expect(KunChatServiceAction.fromJson(action.toJson()), action);
  });

  test('every entity drop rule of tryFromJson', () {
    expect(KunChatEntity.tryFromJson(null), isNull);
    expect(KunChatEntity.tryFromJson('nope'), isNull);
    expect(
      KunChatEntity.tryFromJson(<String, Object?>{
        'type': 'marquee',
        'offset': 0,
        'length': 1,
      }),
      isNull,
    );
    expect(
      KunChatEntity.tryFromJson(<String, Object?>{
        'type': 'bold',
        'offset': 1.5,
        'length': 1,
      }),
      isNull,
    );
    expect(
      KunChatEntity.tryFromJson(<String, Object?>{
        'type': 'bold',
        'offset': 0,
        'length': true,
      }),
      isNull,
    );
    expect(
      KunChatEntity.tryFromJson(<String, Object?>{
        'type': 'mention',
        'offset': 0,
        'length': 1,
        'user_id': 7,
      }),
      isNull,
    );
    expect(
      KunChatEntity.tryFromJson(<String, Object?>{
        'type': 'bold',
        'offset': 3.0,
        'length': 1.0,
      }),
      const KunChatEntity(type: KunChatEntityType.bold, offset: 3, length: 1),
    );
    expect(
      KunChatEntity.tryFromJson(<String, Object?>{
        'type': 'bold',
        'offset': -1,
        'length': 0,
      }),
      const KunChatEntity(type: KunChatEntityType.bold, offset: -1, length: 0),
    );
    expect(
      KunChatEntity.tryFromJson(<String, Object?>{
        'type': 'text_link',
        'offset': 0,
        'length': 1,
      }),
      const KunChatEntity(
        type: KunChatEntityType.textLink,
        offset: 0,
        length: 1,
      ),
    );
  });

  test('FormatException for a missing required field and for a numeric id', () {
    final Map<String, Object?> base = <String, Object?>{
      'id': '1',
      'conversation_id': '2',
      'seq': 1,
      'sender_id': '3',
      'kind': 'message',
      'text': '',
      'entities': <Object?>[],
      'media': null,
      'media_group_id': null,
      'reply_to': null,
      'reply_quote': null,
      'service_action': null,
      'context': null,
      'reactions': <Object?>[],
      'silent': false,
      'pinned_at': null,
      'edited_at': null,
      'created_at': '2026-09-27T00:00:00.000Z',
    };
    expect(
      () => KunChatMessage.fromJson(
        jsonMap(Map<String, Object?>.from(base)..remove('id')),
      ),
      throwsA(
        isA<FormatException>().having(
          (FormatException e) => e.message,
          'message',
          contains('id'),
        ),
      ),
    );
    expect(
      () => KunChatMessage.fromJson(
        jsonMap(Map<String, Object?>.from(base)..['id'] = 1),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('copyWith clearing status with an explicit null', () {
    expect(full.status, KunChatSendStatus.sending);
    expect(full.copyWith(status: null).status, isNull);
    expect(full.copyWith().status, KunChatSendStatus.sending);
  });

  test('value equality', () {
    expect(full, KunChatMessage.fromJson(full.toJson()));
    expect(full == full.copyWith(id: 'other'), isFalse);
    expect(
      const KunChatEntity(type: KunChatEntityType.bold, offset: 0, length: 1),
      const KunChatEntity(type: KunChatEntityType.bold, offset: 0, length: 1),
    );
  });
}
