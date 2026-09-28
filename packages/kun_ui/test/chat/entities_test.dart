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

int _toInt32(int x) {
  final int u = x & 0xFFFFFFFF;
  return u >= 0x80000000 ? u - 0x100000000 : u;
}

int _imul(int a, int b) => _toInt32(_toInt32(a) * _toInt32(b));

// mulberry32. The LCG this replaced, `seed * 1103515245 + 12345` in doubles,
// overflowed the 53-bit mantissa and cycled after about 10,000 draws, so the
// random tests replayed the same few hundred cases.
double Function() rng(int seed) {
  int s = _toInt32(seed);
  return () {
    s = _toInt32(s + 0x6d2b79f5);
    int t = _imul(s ^ ((s & 0xFFFFFFFF) >> 15), 1 | s);
    t = _toInt32(t + _imul(t ^ ((t & 0xFFFFFFFF) >> 7), 61 | t)) ^ t;
    return ((t ^ ((t & 0xFFFFFFFF) >> 14)) & 0xFFFFFFFF) / 4294967296;
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

  test('a quote that does not survive nesting cuts nothing', () {
    // The quote at 5 is inside the one at 2 and is dropped, so the spoiler must
    // not keep a cut at 5: a second pass would have merged it away.
    const String text = '中中b*bab';
    final List<KunChatEntity> once =
        normalizeKunChatEntities(text, <KunChatEntity>[
      e(KunChatEntityType.blockquote, 2, 8),
      e(KunChatEntityType.url, 6, 2),
      e(KunChatEntityType.blockquote, 5, 5),
      e(KunChatEntityType.spoiler, 1, 6),
    ]);
    expect(once, <KunChatEntity>[
      e(KunChatEntityType.spoiler, 1, 1),
      e(KunChatEntityType.blockquote, 2, 5),
      e(KunChatEntityType.spoiler, 2, 5),
      e(KunChatEntityType.url, 6, 1),
    ]);
    expect(normalizeKunChatEntities(text, once), once);
    // Crossing quotes: the second keeps only its part past the first.
    expect(
      normalizeKunChatEntities('abcdefgh', <KunChatEntity>[
        e(KunChatEntityType.blockquote, 0, 5),
        e(KunChatEntityType.blockquote, 3, 5),
        e(KunChatEntityType.bold, 1, 6),
      ]),
      <KunChatEntity>[
        e(KunChatEntityType.blockquote, 0, 5),
        e(KunChatEntityType.bold, 1, 4),
        e(KunChatEntityType.blockquote, 5, 3),
        e(KunChatEntityType.bold, 5, 2),
      ],
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

    for (int round = 0; round < 20000; round++) {
      final String text = List<String>.generate(
        (r() * 16).floor(),
        (_) => pick(chars),
      ).join();
      final List<KunChatEntity> entities = List<KunChatEntity>.generate(
        (r() * 8).floor(),
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
