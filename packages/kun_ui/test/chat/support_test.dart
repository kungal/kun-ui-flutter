import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/chat/support.dart';

final DateTime now = DateTime(2026, 9, 27, 14, 5);

KunChatMessage msg({
  String text = '',
  List<KunChatEntity> entities = const <KunChatEntity>[],
  KunChatMedia? media,
  String senderId = '1001',
  KunChatServiceAction? action,
}) {
  return KunChatMessage(
    id: '1',
    conversationId: '2',
    seq: 1,
    senderId: senderId,
    createdAt: DateTime.utc(2026, 9, 27),
    text: text,
    entities: entities,
    media: media,
    kind: action == null
        ? KunChatMessageKind.message
        : KunChatMessageKind.service,
    serviceAction: action,
  );
}

void main() {
  test('kunChatUserMap and resolveKunChatUser', () {
    const KunChatUser alive = KunChatUser(
      id: '1001',
      name: '鲲',
      avatar: 'a.webp',
    );
    const KunChatUser gone = KunChatUser(
      id: '1005',
      name: '',
      avatar: '',
      deleted: true,
    );
    final Map<String, KunChatUser> users =
        kunChatUserMap(<KunChatUser>[alive, gone]);
    expect(users['1001'], alive);

    final KunChatResolvedUser me =
        resolveKunChatUser(users, '1001', KunMessages.en);
    expect(me.id, '1001');
    expect(me.name, '鲲');
    expect(me.avatar, 'a.webp');
    expect(me.deleted, isFalse);
    expect(me.avatarUser.id, 0);
    expect(me.avatarUser.name, '鲲');
    expect(me.avatarUser.avatar, 'a.webp');

    final KunChatResolvedUser deleted =
        resolveKunChatUser(users, '1005', KunMessages.en);
    expect(deleted.name, 'Deleted account');
    expect(deleted.avatar, isEmpty);
    expect(deleted.deleted, isTrue);
    expect(deleted.avatarUser.name, isEmpty);

    final KunChatResolvedUser missing =
        resolveKunChatUser(users, '9999', KunMessages.zhCN);
    expect(missing.name, '已注销用户');
    expect(missing.deleted, isTrue);

    final KunChatResolvedUser emptyId =
        resolveKunChatUser(users, null, KunMessages.en);
    expect(emptyId.id, isEmpty);
    expect(emptyId.deleted, isTrue);

    expect(kunChatUserMap(null), isEmpty);
    expect(kunChatUserMap(const <KunChatUser>[]), isEmpty);
  });

  test('formatKunChatTime matches Node 24 Intl timeStyle:short', () {
    final List<(DateTime, String, String)> rows = <(DateTime, String, String)>[
      (DateTime(2026, 9, 27, 9, 12), '9:12 AM', '09:12'),
      (DateTime(2026, 9, 26, 10, 32), '10:32 AM', '10:32'),
      (DateTime(2026, 9, 22, 15, 0), '3:00 PM', '15:00'),
      (DateTime(2026, 9, 20, 8, 0), '8:00 AM', '08:00'),
      (DateTime(2025, 12, 31, 21, 3), '9:03 PM', '21:03'),
      (DateTime(2026, 9, 27, 0, 0), '12:00 AM', '00:00'),
      (DateTime(2026, 9, 27, 12, 0), '12:00 PM', '12:00'),
      (DateTime(2026, 9, 27, 0, 5), '12:05 AM', '00:05'),
      (DateTime(2026, 9, 27, 12, 5), '12:05 PM', '12:05'),
      (DateTime(2026, 1, 5, 8, 3), '8:03 AM', '08:03'),
      (DateTime(2026, 11, 15, 16, 45), '4:45 PM', '16:45'),
      (DateTime(2026, 12, 31, 23, 59), '11:59 PM', '23:59'),
    ];
    for (final (DateTime value, String en, String zh) in rows) {
      expect(formatKunChatTime(value, 'en'), en, reason: '$value en');
      expect(formatKunChatTime(value, 'zh-CN'), zh, reason: '$value zh-CN');
      expect(formatKunChatTime(value, 'ja'), en, reason: '$value ja→en');
    }
  });

  test('formatKunChatFullTime matches Node 24 Intl medium+short', () {
    expect(
      formatKunChatFullTime(DateTime(2026, 9, 27, 9, 12), 'en'),
      'Sep 27, 2026, 9:12 AM',
    );
    expect(
      formatKunChatFullTime(DateTime(2026, 9, 27, 9, 12), 'zh-CN'),
      '2026年9月27日 09:12',
    );
    expect(
      formatKunChatFullTime(DateTime(2026, 1, 5, 8, 3), 'en'),
      'Jan 5, 2026, 8:03 AM',
    );
    expect(
      formatKunChatFullTime(DateTime(2026, 1, 5, 8, 3), 'zh-CN'),
      '2026年1月5日 08:03',
    );
    expect(
      formatKunChatFullTime(DateTime(2026, 11, 15, 16, 45), 'en'),
      'Nov 15, 2026, 4:45 PM',
    );
    expect(
      formatKunChatFullTime(DateTime(2026, 9, 27, 0, 0), 'en'),
      'Sep 27, 2026, 12:00 AM',
    );
    expect(
      formatKunChatFullTime(DateTime(2026, 9, 27, 12, 0), 'en'),
      'Sep 27, 2026, 12:00 PM',
    );
  });

  test('formatKunChatDay today, yesterday, month+day, year', () {
    expect(
      formatKunChatDay(DateTime(2026, 9, 27, 9, 12), 'en', KunMessages.en,
          now: now),
      'Today',
    );
    expect(
      formatKunChatDay(DateTime(2026, 9, 27, 9, 12), 'zh-CN', KunMessages.zhCN,
          now: now),
      '今天',
    );
    expect(
      formatKunChatDay(DateTime(2026, 9, 26, 10, 32), 'en', KunMessages.en,
          now: now),
      'Yesterday',
    );
    expect(
      formatKunChatDay(DateTime(2026, 9, 26, 10, 32), 'zh-CN', KunMessages.zhCN,
          now: now),
      '昨天',
    );
    expect(
      formatKunChatDay(DateTime(2026, 9, 22, 15, 0), 'en', KunMessages.en,
          now: now),
      'September 22',
    );
    expect(
      formatKunChatDay(DateTime(2026, 9, 22, 15, 0), 'zh-CN', KunMessages.zhCN,
          now: now),
      '9月22日',
    );
    expect(
      formatKunChatDay(DateTime(2025, 12, 31, 21, 3), 'en', KunMessages.en,
          now: now),
      'December 31, 2025',
    );
    expect(
      formatKunChatDay(DateTime(2025, 12, 31, 21, 3), 'zh-CN', KunMessages.zhCN,
          now: now),
      '2025年12月31日',
    );
    expect(
      formatKunChatDay(DateTime(2026, 1, 5, 8, 3), 'en', KunMessages.en,
          now: now),
      'January 5',
    );
    expect(
      formatKunChatDay(DateTime(2026, 1, 5, 8, 3), 'zh-CN', KunMessages.zhCN,
          now: now),
      '1月5日',
    );
  });

  test('formatKunChatListTime clock, weekday, numeric date', () {
    expect(
      formatKunChatListTime(DateTime(2026, 9, 27, 9, 12), 'en', now: now),
      '9:12 AM',
    );
    expect(
      formatKunChatListTime(DateTime(2026, 9, 27, 9, 12), 'zh-CN', now: now),
      '09:12',
    );
    expect(
      formatKunChatListTime(DateTime(2026, 9, 22, 15, 0), 'en', now: now),
      'Tue',
    );
    expect(
      formatKunChatListTime(DateTime(2026, 9, 22, 15, 0), 'zh-CN', now: now),
      '周二',
    );
    expect(
      formatKunChatListTime(DateTime(2026, 9, 20, 8, 0), 'en', now: now),
      '9/20',
    );
    expect(
      formatKunChatListTime(DateTime(2026, 9, 20, 8, 0), 'zh-CN', now: now),
      '9/20',
    );
    expect(
      formatKunChatListTime(DateTime(2025, 12, 31, 21, 3), 'en', now: now),
      '12/31/2025',
    );
    expect(
      formatKunChatListTime(DateTime(2025, 12, 31, 21, 3), 'zh-CN', now: now),
      '2025/12/31',
    );
    expect(
      formatKunChatListTime(DateTime(2026, 1, 5, 8, 3), 'en', now: now),
      '1/5',
    );
  });

  test('kunChatListJoin matches Node Intl.ListFormat conjunction', () {
    expect(kunChatListJoin(const <String>['A'], 'en'), 'A');
    expect(kunChatListJoin(const <String>['A', 'B'], 'en'), 'A and B');
    expect(
      kunChatListJoin(const <String>['A', 'B', 'C'], 'en'),
      'A, B, and C',
    );
    expect(
      kunChatListJoin(const <String>['A', 'B', 'C', 'D'], 'en'),
      'A, B, C, and D',
    );
    expect(kunChatListJoin(const <String>['A', 'B'], 'zh-CN'), 'A和B');
    expect(
      kunChatListJoin(const <String>['A', 'B', 'C'], 'zh-CN'),
      'A、B和C',
    );
    expect(
      kunChatListJoin(const <String>['A', 'B', 'C', 'D'], 'zh-CN'),
      'A、B、C和D',
    );
    expect(
      kunChatListJoin(
        const <String>['雪之下小春', 'Ayase', '樱小路露娜'],
        'en',
      ),
      '雪之下小春, Ayase, and 樱小路露娜',
    );
    expect(
      kunChatListJoin(
        const <String>['雪之下小春', 'Ayase', '樱小路露娜'],
        'zh-CN',
      ),
      '雪之下小春、Ayase和樱小路露娜',
    );
    expect(kunChatListJoin(const <String>[], 'en'), isEmpty);
    expect(kunChatListJoin(const <String>['A', 'B'], 'ja'), 'A and B');
  });

  test('kunChatSafeUrl matches Node URL.href where Uri can', () {
    const Map<String, String?> vectors = <String, String?>{
      'https://moyu.moe': 'https://moyu.moe/',
      'https://moyu.moe/': 'https://moyu.moe/',
      'http://moyu.moe': 'http://moyu.moe/',
      'https://Example.COM': 'https://example.com/',
      'HTTPS://EXAMPLE.COM/Path': 'https://example.com/Path',
      'https://example.com/foo/bar': 'https://example.com/foo/bar',
      'https://example.com/foo?q=1&b=2': 'https://example.com/foo?q=1&b=2',
      'https://example.com/foo#frag': 'https://example.com/foo#frag',
      'https://example.com/foo?q=1#frag': 'https://example.com/foo?q=1#frag',
      'https://user:pass@example.com:8080/x':
          'https://user:pass@example.com:8080/x',
      'http://localhost:3000/x': 'http://localhost:3000/x',
      'https://localhost:3000/x': 'https://localhost:3000/x',
      'localhost:3000/x': null,
      'moyu.moe:8080/x': null,
      'moyu.moe/x': 'https://moyu.moe/x',
      'moyu.moe': 'https://moyu.moe/',
      '  https://moyu.moe  ': 'https://moyu.moe/',
      'javascript:alert(1)': null,
      'data:text/html,hi': null,
      'ftp://files.example.com/a': null,
      'mailto:a@b.com': 'mailto:a@b.com',
      'MAILTO:a@b.com': 'mailto:a@b.com',
      'mailto:a@b.com?subject=hi': 'mailto:a@b.com?subject=hi',
      'file:///etc/passwd': null,
      'about:blank': null,
      '': null,
      '   ': null,
      '//example.com/x': 'https://example.com/x',
      'www.kungal.com/topic/1024': 'https://www.kungal.com/topic/1024',
      'https://www.kungal.com/topic/1024': 'https://www.kungal.com/topic/1024',
      'http://127.0.0.1:8080/x': 'http://127.0.0.1:8080/x',
      '127.0.0.1:8080/x': 'https://127.0.0.1:8080/x',
      'https://[::1]/': 'https://[::1]/',
      'https://[::1]:8080/x': 'https://[::1]:8080/x',
      'http://[2001:db8::1]/path': 'http://[2001:db8::1]/path',
      'https://xn--fsq.xn--0zwm56d': 'https://xn--fsq.xn--0zwm56d/',
      'https://example.com:443/': 'https://example.com/',
      'http://example.com:80/': 'http://example.com/',
      'https://example.com:80/x': 'https://example.com:80/x',
      'https://example.com/路径': 'https://example.com/%E8%B7%AF%E5%BE%84',
      'https://example.com/a b': 'https://example.com/a%20b',
      'not a url': null,
      'http://': null,
      'https://': null,
      'http://.': 'http://./',
      'https://example.com:99999': null,
      'https://example.com/#': 'https://example.com/#',
      'https://example.com?': 'https://example.com/?',
      'https://sub.domain.example.co.uk/a':
          'https://sub.domain.example.co.uk/a',
      'HTTP://ABC.COM': 'http://abc.com/',
      ' tel:+123': null,
      'https://例子.测试': 'https://xn--fsqu00a.xn--0zwm56d/',
      '例子.测试': 'https://xn--fsqu00a.xn--0zwm56d/',
      'https://ドメイン.テスト': 'https://xn--eckwd4c7c.xn--zckzah/',
      'https://日本語.jp': 'https://xn--wgv71a119e.jp/',
      'https://Bücher.de': 'https://xn--bcher-kva.de/',
      'https://bücher.de': 'https://xn--bcher-kva.de/',
      'https://faß.de': 'https://xn--fa-hia.de/',
      'https://😉.com': 'https://xn--n28h.com/',
      'https://www.例子.测试': 'https://www.xn--fsqu00a.xn--0zwm56d/',
      'https://例子.测试:8080/路径?q=1#frag':
          'https://xn--fsqu00a.xn--0zwm56d:8080/%E8%B7%AF%E5%BE%84?q=1#frag',
      'https://shop.münchen.de/a': 'https://shop.xn--mnchen-3ya.de/a',
      'https://яндекс.рф': 'https://xn--d1acpjx3f.xn--p1ai/',
      'https://스타벅스코리아.com': 'https://xn--oy2b35ckwhba574atvuzkc.com/',
      'http://例子.测试/foo': 'http://xn--fsqu00a.xn--0zwm56d/foo',
      'https://xn--fsqu00a.xn--0zwm56d/': 'https://xn--fsqu00a.xn--0zwm56d/',
      'https://münchen.example.com:443/': 'https://xn--mnchen-3ya.example.com/',
      'https://café.com': 'https://xn--caf-dma.com/',
      'https://foo.バー.baz': 'https://foo.xn--ndkue.baz/',
    };
    for (final MapEntry<String, String?> entry in vectors.entries) {
      expect(kunChatSafeUrl(entry.key), entry.value, reason: entry.key);
    }
  });

  test('IDN without NFC or UTS 46 mapping', () {
    expect(
      kunChatSafeUrl('https://cafe\u0301.com'),
      'https://xn--cafe-yvc.com/',
    );
    expect(
      kunChatSafeUrl('https://ＡＢＣ.ＣＯＭ'),
      'https://xn--mi7ccd.xn--oi7cuaf/',
    );
    expect(kunChatSafeUrl('https://İ.com'), 'https://i.com/');
    expect(
      kunChatSafeUrl('https://example。com'),
      'https://xn--examplecom-th3i/',
    );
  });

  test('kunChatMediaLabel and kunChatPlainText', () {
    expect(kunChatMediaLabel(null, KunMessages.en), 'Media');
    expect(
      kunChatMediaLabel(
        const KunChatPhoto(imageHash: 'h', width: 1, height: 1),
        KunMessages.en,
      ),
      'Photo',
    );
    expect(
      kunChatMediaLabel(
        const KunChatUnknownMedia(type: 'sticker'),
        KunMessages.en,
      ),
      'Media',
    );

    expect(kunChatPlainText(msg(), KunMessages.en), isEmpty);
    expect(
      kunChatPlainText(
        msg(
          media: const KunChatPhoto(imageHash: 'h', width: 1, height: 1),
        ),
        KunMessages.en,
      ),
      'Photo',
    );

    const String hidden = '列车长就是白本人';
    final KunChatMessage spoiler = msg(
      text: '原来$hidden',
      entities: <KunChatEntity>[
        KunChatEntity(
          type: KunChatEntityType.spoiler,
          offset: 2,
          length: hidden.length,
        ),
      ],
    );
    expect(kunChatPlainText(spoiler, KunMessages.en), '原来${'⠿' * 8}');

    expect(
      kunChatPlainText(
        msg(
          text: 'ab',
          entities: const <KunChatEntity>[
            KunChatEntity(
              type: KunChatEntityType.spoiler,
              offset: 0,
              length: 2,
            ),
          ],
        ),
        KunMessages.en,
      ),
      '⠿⠿⠿',
    );

    final String long = 'x' * 20;
    expect(
      kunChatPlainText(
        msg(
          text: long,
          entities: <KunChatEntity>[
            KunChatEntity(
              type: KunChatEntityType.spoiler,
              offset: 0,
              length: long.length,
            ),
          ],
        ),
        KunMessages.en,
      ),
      '⠿' * 12,
    );

    expect(
      kunChatPlainText(
        msg(
          text: 'hi 😀',
          entities: const <KunChatEntity>[
            KunChatEntity(
              type: KunChatEntityType.spoiler,
              offset: 3,
              length: 2,
            ),
          ],
        ),
        KunMessages.en,
      ),
      'hi ⠿⠿⠿',
    );
  });

  test('kunChatServiceText switches on the sealed action', () {
    final Map<String, KunChatUser> users = kunChatUserMap(const <KunChatUser>[
      KunChatUser(id: '1001', name: '鲲', avatar: ''),
      KunChatUser(id: '1002', name: '春', avatar: ''),
      KunChatUser(id: '1003', name: 'Ayase', avatar: ''),
    ]);
    final KunChatServiceContext ctx = KunChatServiceContext(
      users: users,
      currentUserId: '1001',
      messages: KunMessages.en,
    );

    expect(
      kunChatServiceText(
        msg(senderId: '1001', action: const KunChatGroupCreatedAction()),
        ctx,
      ),
      'You created the group',
    );
    expect(
      kunChatServiceText(
        msg(
          senderId: '1002',
          action: const KunChatGroupCreatedAction(title: 'Gal'),
        ),
        ctx,
      ),
      '春 created the group “Gal”',
    );
    expect(
      kunChatServiceText(
        msg(
          senderId: '1002',
          action: const KunChatMembersAddedAction(userIds: <String>['1002']),
        ),
        ctx,
      ),
      '春 joined the group',
    );
    expect(
      kunChatServiceText(
        msg(
          senderId: '1001',
          action: const KunChatMembersAddedAction(
            userIds: <String>['1002', '1003'],
          ),
        ),
        ctx,
      ),
      'You added 春 and Ayase',
    );
    expect(
      kunChatServiceText(
        msg(senderId: '1002', action: const KunChatMemberLeftAction()),
        ctx,
      ),
      '春 left the group',
    );
    expect(
      kunChatServiceText(
        msg(
          senderId: '1001',
          action: const KunChatMemberRemovedAction(userId: '1002'),
        ),
        ctx,
      ),
      'You removed 春',
    );
    expect(
      kunChatServiceText(
        msg(
          senderId: '1001',
          action: const KunChatTitleChangedAction(title: 'New'),
        ),
        ctx,
      ),
      'You renamed the group to “New”',
    );
    expect(
      kunChatServiceText(
        msg(senderId: '1001', action: const KunChatPhotoChangedAction()),
        ctx,
      ),
      'You changed the group photo',
    );
    expect(
      kunChatServiceText(
        msg(
          senderId: '1001',
          action: const KunChatMessagePinnedAction(seq: 9),
        ),
        ctx,
      ),
      'You pinned a message',
    );
    expect(
      kunChatServiceText(
        msg(
          senderId: '1001',
          action: const KunChatMessagePinnedAction(seq: 9),
        ),
        KunChatServiceContext(
          users: users,
          currentUserId: '1001',
          messages: KunMessages.en,
          resolveMessage: (int seq) =>
              seq == 9 ? msg(text: 'hello world') : null,
        ),
      ),
      'You pinned “hello world”',
    );
    expect(
      kunChatServiceText(
        msg(senderId: '1002', action: const KunChatJoinedByLinkAction()),
        ctx,
      ),
      '春 joined via invite link',
    );
    expect(
      kunChatServiceText(
        msg(
          text: 'fallback',
          action: const KunChatUnknownAction(type: 'future_thing'),
        ),
        ctx,
      ),
      'fallback',
    );
    expect(kunChatServiceText(msg(text: 'plain'), ctx), 'plain');
  });
}
