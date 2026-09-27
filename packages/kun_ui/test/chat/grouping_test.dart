import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

int nextId = 1;

KunChatMessage msg(
  String sender,
  DateTime createdAt, {
  KunChatMessageKind kind = KunChatMessageKind.message,
  String text = 'hi',
  KunChatMedia? media,
  String? mediaGroupId,
  KunChatServiceAction? serviceAction,
  int? seq,
  String? clientMessageId,
  KunChatSendStatus? status,
}) {
  final int id = nextId++;
  return KunChatMessage(
    id: '$id',
    conversationId: '1',
    seq: seq ?? id,
    senderId: sender,
    createdAt: createdAt,
    kind: kind,
    text: text,
    media: media,
    mediaGroupId: mediaGroupId,
    serviceAction: serviceAction,
    clientMessageId: clientMessageId,
    status: status,
  );
}

List<List<String>> outline(
  List<KunChatMessage> messages, {
  int? lastReadSeq,
}) =>
    groupKunChatMessages(
      messages,
      currentUserId: '1',
      lastReadSeq: lastReadSeq,
    )
        .map(
          (KunChatDaySection day) => <String>[
            day.key,
            ...day.rows.map((KunChatListRow r) {
              if (r is KunChatMessageRow) {
                return '${r.own ? 'me' : r.message.senderId}'
                    '${r.groupStart ? ' start' : ''}'
                    '${r.groupEnd ? ' end' : ''}'
                    '${r.messages.length > 1 ? ' album×${r.messages.length}' : ''}';
              }
              if (r is KunChatUnreadRow) return 'unread';
              return 'service';
            }),
          ],
        )
        .toList();

void main() {
  setUp(() => nextId = 1);

  test('consecutive messages from one sender form one group', () {
    expect(
      outline(<KunChatMessage>[
        msg('2', DateTime(2026, 9, 27, 10)),
        msg('2', DateTime(2026, 9, 27, 10, 1)),
        msg('2', DateTime(2026, 9, 27, 10, 2)),
        msg('1', DateTime(2026, 9, 27, 10, 3)),
      ]),
      <List<String>>[
        <String>['2026-09-27', '2 start', '2', '2 end', 'me start end'],
      ],
    );
  });

  test('a gap over the window, a service message and a new day break a group',
      () {
    expect(
      outline(<KunChatMessage>[
        msg('2', DateTime(2026, 9, 27, 10)),
        msg('2', DateTime(2026, 9, 27, 10, 11)),
        msg(
          '2',
          DateTime(2026, 9, 27, 10, 12),
          kind: KunChatMessageKind.service,
          serviceAction: const KunChatMemberLeftAction(),
        ),
        msg('2', DateTime(2026, 9, 27, 10, 13)),
        msg('2', DateTime(2026, 9, 28, 0, 0, 1)),
      ]),
      <List<String>>[
        <String>[
          '2026-09-27',
          '2 start end',
          '2 start end',
          'service',
          '2 start end'
        ],
        <String>['2026-09-28', '2 start end'],
      ],
    );
  });

  test(
      'the unread divider goes above the first later message from someone else',
      () {
    expect(
      outline(
        <KunChatMessage>[
          msg('2', DateTime(2026, 9, 27, 10), seq: 10),
          msg('1', DateTime(2026, 9, 27, 10, 1), seq: 11),
          msg('2', DateTime(2026, 9, 27, 10, 2), seq: 12),
          msg('2', DateTime(2026, 9, 27, 10, 3), seq: 13),
        ],
        lastReadSeq: 11,
      ),
      <List<String>>[
        <String>[
          '2026-09-27',
          '2 start end',
          'me start end',
          'unread',
          '2 start',
          '2 end',
        ],
      ],
    );
  });

  test('photos sharing a media_group_id become one album row', () {
    const KunChatPhoto photo = KunChatPhoto(
      imageHash: 'h',
      width: 1,
      height: 1,
    );
    final List<KunChatListRow> rows = groupKunChatMessages(
      <KunChatMessage>[
        msg(
          '2',
          DateTime(2026, 9, 27, 10),
          media: photo,
          mediaGroupId: '7',
          text: '',
        ),
        msg(
          '2',
          DateTime(2026, 9, 27, 10),
          media: photo,
          mediaGroupId: '7',
          text: 'caption',
        ),
        msg(
          '2',
          DateTime(2026, 9, 27, 10),
          media: photo,
          mediaGroupId: '7',
          text: '',
        ),
        msg('2', DateTime(2026, 9, 27, 10, 0, 1)),
      ],
      currentUserId: '1',
    )[0]
        .rows;
    expect(rows.length, 2);
    final KunChatListRow album = rows[0];
    expect(album, isA<KunChatMessageRow>());
    final KunChatMessageRow row = album as KunChatMessageRow;
    expect(row.messages.length, 3);
    expect(row.message.text, 'caption');
    expect(row.groupStart, isTrue);
  });

  test('a pending message keeps its key when the server confirms it', () {
    final KunChatMessage pending = msg(
      '1',
      DateTime(2026, 9, 27, 10),
      clientMessageId: 'u-1',
      status: KunChatSendStatus.sending,
    );
    final KunChatMessage confirmed = pending.copyWith(
      id: '999',
      status: null,
    );
    expect(kunChatMessageKey(pending), kunChatMessageKey(confirmed));
    expect(
      kunChatMessageKey(msg('2', DateTime(2026, 9, 27, 10))),
      isNot(kunChatMessageKey(msg('2', DateTime(2026, 9, 27, 10)))),
    );
  });

  test('days never go backwards', () {
    expect(
      outline(<KunChatMessage>[
        msg('2', DateTime(2026, 9, 28, 9)),
        msg(
          '1',
          DateTime(2026, 9, 27, 23, 59),
          status: KunChatSendStatus.sending,
        ),
      ]).map((List<String> d) => d[0]).toList(),
      <String>['2026-09-28'],
    );
  });

  test('day keys follow the requested time zone', () {
    expect(kunChatDayKey(DateTime(2026, 9, 27, 17, 30)), '2026-09-27');
    final DateTime utc = DateTime.utc(2026, 9, 27, 17, 30);
    final DateTime local = utc.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    expect(
      kunChatDayKey(utc),
      '${local.year}-${pad(local.month)}-${pad(local.day)}',
    );
  });

  test('an album holds at most KUN_CHAT_ALBUM_LIMIT photos', () {
    const KunChatPhoto photo = KunChatPhoto(
      imageHash: 'h',
      width: 1,
      height: 1,
    );
    final List<KunChatListRow> rows = groupKunChatMessages(
      List<KunChatMessage>.generate(
        12,
        (_) => msg(
          '2',
          DateTime(2026, 9, 27, 10),
          media: photo,
          mediaGroupId: '9',
          text: '',
        ),
      ),
      currentUserId: '1',
    )[0]
        .rows;
    expect(
      rows
          .map(
            (KunChatListRow r) =>
                r is KunChatMessageRow ? r.messages.length : 0,
          )
          .toList(),
      <int>[10, 2],
    );
  });
}
