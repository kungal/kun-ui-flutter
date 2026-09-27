import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

String show(List<KunChatTextNode> nodes) => nodes
    .map(
      (KunChatTextNode n) => n is KunChatTextLeaf
          ? n.text
          : '<${(n as KunChatEntityNode).entity.type.wireName}>${show(n.children)}</${n.entity.type.wireName}>',
    )
    .join();

KunChatEntity e(
  KunChatEntityType type,
  int offset,
  int length, {
  String? url,
  String? userId,
  String? language,
}) =>
    KunChatEntity(
      type: type,
      offset: offset,
      length: length,
      url: url,
      userId: userId,
      language: language,
    );

int _toInt32(double x) {
  if (x.isNaN || x.isInfinite) return 0;
  final int sign = x.isNegative ? -1 : 1;
  final double mag = x.abs().floorToDouble();
  int n = (mag % 4294967296.0).toInt();
  if (sign < 0 && n != 0) n = 4294967296 - n;
  if (n >= 2147483648) n -= 4294967296;
  return n;
}

double Function() rng(int seed) {
  int s = seed;
  return () {
    // JS `&` ToInt32s the IEEE-754 product. Dart `int` multiply is exact, so
    // without this the ported tests draw a different sequence.
    s = _toInt32(s.toDouble() * 1103515245.0 + 12345.0) & 0x7fffffff;
    return s / 0x7fffffff;
  };
}

void main() {
  test('no entities: one text leaf, or nothing for empty text', () {
    expect(buildKunChatEntityTree('hello', null), <KunChatTextNode>[
      const KunChatTextLeaf(text: 'hello', offset: 0),
    ]);
    expect(
        buildKunChatEntityTree('hello', <KunChatEntity>[]), <KunChatTextNode>[
      const KunChatTextLeaf(text: 'hello', offset: 0),
    ]);
    expect(
        buildKunChatEntityTree(
            '', <KunChatEntity>[e(KunChatEntityType.bold, 0, 3)]),
        isEmpty);
  });

  test('flat, nested and adjacent entities', () {
    expect(
      show(buildKunChatEntityTree(
          'abcdef', <KunChatEntity>[e(KunChatEntityType.bold, 1, 2)])),
      'a<bold>bc</bold>def',
    );
    expect(
      show(
        buildKunChatEntityTree('abcdef', <KunChatEntity>[
          e(KunChatEntityType.italic, 2, 1),
          e(KunChatEntityType.bold, 0, 4),
        ]),
      ),
      '<bold>ab<italic>c</italic>d</bold>ef',
    );
    expect(
      show(
        buildKunChatEntityTree('abcdef', <KunChatEntity>[
          e(KunChatEntityType.bold, 0, 3),
          e(KunChatEntityType.italic, 3, 3),
        ]),
      ),
      '<bold>abc</bold><italic>def</italic>',
    );
  });

  test('text leaves carry their offset into the message text', () {
    final List<KunChatTextNode> tree = buildKunChatEntityTree(
      'ab cd',
      <KunChatEntity>[e(KunChatEntityType.bold, 3, 2)],
    );
    expect(tree[0], const KunChatTextLeaf(text: 'ab ', offset: 0));
    final KunChatTextNode bold = tree[1];
    expect(bold, isA<KunChatEntityNode>());
    expect(
      (bold as KunChatEntityNode).children[0],
      const KunChatTextLeaf(text: 'cd', offset: 3),
    );
  });

  test('identical ranges nest by a fixed order: links outside formatting', () {
    final List<KunChatTextNode> tree =
        buildKunChatEntityTree('link', <KunChatEntity>[
      e(KunChatEntityType.bold, 0, 4),
      e(KunChatEntityType.textLink, 0, 4, url: 'https://moyu.moe'),
    ]);
    expect(show(tree), '<text_link><bold>link</bold></text_link>');
  });

  test('offsets are UTF-16 code units; a cut surrogate pair is widened', () {
    const String text = 'a😀b';
    expect(
      show(buildKunChatEntityTree(
          text, <KunChatEntity>[e(KunChatEntityType.bold, 1, 2)])),
      'a<bold>😀</bold>b',
    );
    expect(
      show(buildKunChatEntityTree(
          text, <KunChatEntity>[e(KunChatEntityType.bold, 2, 1)])),
      'a<bold>😀</bold>b',
    );
    expect(
      show(buildKunChatEntityTree(
          text, <KunChatEntity>[e(KunChatEntityType.bold, 0, 2)])),
      '<bold>a😀</bold>b',
    );
  });

  test('invalid entities are dropped or clamped, never thrown on', () {
    const String text = 'abc';
    expect(
      normalizeKunChatEntities(text, <KunChatEntity>[
        e(KunChatEntityType.bold, -1, 2),
        e(KunChatEntityType.bold, 1, 0),
        e(KunChatEntityType.bold, 5, 1),
        e(KunChatEntityType.textLink, 0, 1),
        e(KunChatEntityType.mention, 0, 1),
      ]),
      isEmpty,
    );
    expect(
      normalizeKunChatEntities(
          text, <KunChatEntity>[e(KunChatEntityType.italic, 1, 99)]),
      <KunChatEntity>[e(KunChatEntityType.italic, 1, 2)],
    );
  });

  test('a crossing entity is split at the boundary it crosses', () {
    expect(
      normalizeKunChatEntities('abcdefgh', <KunChatEntity>[
        e(KunChatEntityType.bold, 0, 5),
        e(KunChatEntityType.italic, 3, 5),
      ]),
      <KunChatEntity>[
        e(KunChatEntityType.bold, 0, 5),
        e(KunChatEntityType.italic, 3, 2),
        e(KunChatEntityType.italic, 5, 3),
      ],
    );
    expect(
      show(
        buildKunChatEntityTree('abcdefgh', <KunChatEntity>[
          e(KunChatEntityType.bold, 0, 5),
          e(KunChatEntityType.italic, 3, 5),
        ]),
      ),
      '<bold>abc<italic>de</italic></bold><italic>fgh</italic>',
    );
  });

  test('what cannot nest is dropped', () {
    expect(
      normalizeKunChatEntities('abcd', <KunChatEntity>[
        e(KunChatEntityType.code, 0, 4),
        e(KunChatEntityType.bold, 1, 2),
      ]),
      <KunChatEntity>[e(KunChatEntityType.code, 0, 4)],
    );
    expect(
      normalizeKunChatEntities('abcd', <KunChatEntity>[
        e(KunChatEntityType.textLink, 0, 4, url: 'https://a'),
        e(KunChatEntityType.mention, 1, 2, userId: '7'),
      ]),
      <KunChatEntity>[e(KunChatEntityType.textLink, 0, 4, url: 'https://a')],
    );
    expect(
      normalizeKunChatEntities('abcd', <KunChatEntity>[
        e(KunChatEntityType.blockquote, 0, 4),
        e(KunChatEntityType.blockquote, 1, 2),
      ]),
      <KunChatEntity>[e(KunChatEntityType.blockquote, 0, 4)],
    );
  });

  test('touching or overlapping runs of one format merge', () {
    expect(
      normalizeKunChatEntities('abcdef', <KunChatEntity>[
        e(KunChatEntityType.bold, 0, 3),
        e(KunChatEntityType.bold, 3, 3),
      ]),
      <KunChatEntity>[e(KunChatEntityType.bold, 0, 6)],
    );
    expect(
      normalizeKunChatEntities('abcdef', <KunChatEntity>[
        e(KunChatEntityType.bold, 0, 4),
        e(KunChatEntityType.bold, 2, 4),
      ]),
      <KunChatEntity>[e(KunChatEntityType.bold, 0, 6)],
    );
    expect(
      normalizeKunChatEntities('abcd', <KunChatEntity>[
        e(KunChatEntityType.textLink, 0, 2, url: 'https://a'),
        e(KunChatEntityType.textLink, 2, 2, url: 'https://a'),
      ]).length,
      2,
    );
  });

  test('quotes stay outermost; formats lose line breaks at their ends', () {
    const String text = 'ab\ncd';
    expect(
      normalizeKunChatEntities(text, <KunChatEntity>[
        e(KunChatEntityType.bold, 0, 5),
        e(KunChatEntityType.blockquote, 3, 2),
      ]),
      <KunChatEntity>[
        e(KunChatEntityType.bold, 0, 2),
        e(KunChatEntityType.blockquote, 3, 2),
        e(KunChatEntityType.bold, 3, 2),
      ],
    );
    expect(
      normalizeKunChatEntities('ab\n', <KunChatEntity>[
        e(KunChatEntityType.blockquote, 0, 3),
      ]),
      <KunChatEntity>[e(KunChatEntityType.blockquote, 0, 2)],
    );
    expect(
      normalizeKunChatEntities('\nab\n', <KunChatEntity>[
        e(KunChatEntityType.spoiler, 0, 4),
      ]),
      <KunChatEntity>[e(KunChatEntityType.spoiler, 1, 2)],
    );
  });

  test('one line break on each side of a block is left out of the tree', () {
    const String text = 'look:\ncode\nok';
    final List<KunChatTextNode> tree = buildKunChatEntityTree(
      text,
      <KunChatEntity>[e(KunChatEntityType.pre, 6, 4, language: 'go')],
    );
    expect(show(tree), 'look:<pre>code</pre>ok');
    expect(tree[2], const KunChatTextLeaf(text: 'ok', offset: 11));
    expect(
      show(
        buildKunChatEntityTree('a\n\nq', <KunChatEntity>[
          e(KunChatEntityType.blockquote, 3, 1),
        ]),
      ),
      'a\n<blockquote>q</blockquote>',
    );
    expect(kunChatTreeText(tree), 'look:codeok');
  });

  test('normalize is idempotent and the tree reproduces the text (random)', () {
    const List<KunChatEntityType> types = KunChatEntityType.values;
    const List<String> chars = <String>['a', 'b', ' ', '\n', '中', '😀', '*'];
    final double Function() r = rng(42);
    T pick<T>(List<T> xs) {
      final int i = (r() * xs.length).floor();
      return xs[i < xs.length ? i : xs.length - 1];
    }

    for (int round = 0; round < 3000; round++) {
      final String text = List<String>.generate(
        (r() * 16).floor(),
        (_) => pick(chars),
      ).join();
      final List<KunChatEntity> entities = List<KunChatEntity>.generate(
        (r() * 6).floor(),
        (_) {
          final KunChatEntityType type = pick(types);
          return e(
            type,
            (r() * 18).floor() - 1,
            (r() * 10).floor(),
            url: 'https://x',
            userId: '1',
            language: 'go',
          );
        },
      );
      final List<KunChatEntity> once = normalizeKunChatEntities(text, entities);
      expect(
        normalizeKunChatEntities(text, once),
        once,
        reason: '$text $entities',
      );

      void walk(List<KunChatTextNode> nodes) {
        for (final KunChatTextNode n in nodes) {
          if (n is KunChatTextLeaf) {
            expect(
              text.substring(n.offset, n.offset + n.text.length),
              n.text,
            );
          } else {
            walk((n as KunChatEntityNode).children);
          }
        }
      }

      walk(buildKunChatEntityTree(text, entities));
    }
  });

  test('a slice keeps the entities inside it, clipped and shifted', () {
    const String text = 'say hi there';
    final List<KunChatEntity> entities = <KunChatEntity>[
      e(KunChatEntityType.bold, 4, 2),
      e(KunChatEntityType.italic, 0, 12),
    ];
    expect(
      sliceKunChatEntities(text, entities, 4, 12),
      KunChatFormattedText(
        text: 'hi there',
        entities: <KunChatEntity>[
          e(KunChatEntityType.italic, 0, 8),
          e(KunChatEntityType.bold, 0, 2),
        ],
      ),
    );
    expect(sliceKunChatEntities('a😀b', <KunChatEntity>[], 2, 4).text, '😀b');
  });
}
