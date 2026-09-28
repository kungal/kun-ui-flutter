import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

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

void parses(
  String source,
  String text, [
  List<KunChatEntity> entities = const <KunChatEntity>[],
]) {
  expect(
    parseKunChatMarkdown(source),
    KunChatFormattedText(text: text, entities: entities),
    reason: source,
  );
}

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

const List<String> _chars = <String>[
  'a',
  'b',
  ' ',
  '\n',
  '\n',
  '中',
  '😀',
  '*',
  '_',
  '+',
  '~',
  '|',
  '`',
  '[',
  ']',
  '(',
  ')',
  '>',
  r'\',
  r'\',
  '#',
];
const List<KunChatEntityType> _inline = <KunChatEntityType>[
  KunChatEntityType.bold,
  KunChatEntityType.italic,
  KunChatEntityType.underline,
  KunChatEntityType.strikethrough,
  KunChatEntityType.spoiler,
  KunChatEntityType.code,
  KunChatEntityType.pre,
  KunChatEntityType.textLink,
  KunChatEntityType.mention,
];
const List<String> _urls = <String>[
  'https://a',
  'https://x/(y)',
  r'https://x/a\)b',
  r'x)\\',
];
const List<String?> _languages = <String?>[null, 'go', 'c++', 'objective-c'];

KunChatFormattedText randomMessage(double Function() r) {
  T pick<T>(List<T> xs) {
    final int i = (r() * xs.length).floor();
    return xs[i < xs.length ? i : xs.length - 1];
  }

  final String text = List<String>.generate(
    (r() * 24).floor(),
    (_) => pick(_chars),
  ).join();
  final List<KunChatEntity> entities = <KunChatEntity>[];
  for (int n = (r() * 7).floor(); n > 0; n--) {
    final int offset = (r() * (text.length + 1)).floor();
    final int length = 1 + (r() * 8).floor();
    final KunChatEntityType type = pick(_inline);
    entities.add(
      e(
        type,
        offset,
        length,
        url: type == KunChatEntityType.textLink ? pick(_urls) : null,
        userId: type == KunChatEntityType.mention
            ? '${1 + (r() * 99).floor()}'
            : null,
        language: type == KunChatEntityType.pre && pick(_languages) != null
            ? pick(const <String>['go', 'c++', 'objective-c'])
            : null,
      ),
    );
  }
  final List<String> lines = text.split('\n');
  int at = 0;
  int lastQuoted = -2;
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    if (line.isNotEmpty && i - lastQuoted > 1 && r() < 0.3) {
      entities.add(e(KunChatEntityType.blockquote, at, line.length));
      lastQuoted = i;
    }
    at += line.length + 1;
  }
  return KunChatFormattedText(text: text, entities: entities);
}

void main() {
  test('every marker', () {
    parses('**b**', 'b', <KunChatEntity>[e(KunChatEntityType.bold, 0, 1)]);
    parses('__i__', 'i', <KunChatEntity>[e(KunChatEntityType.italic, 0, 1)]);
    parses('++u++', 'u', <KunChatEntity>[e(KunChatEntityType.underline, 0, 1)]);
    parses('~~s~~', 's',
        <KunChatEntity>[e(KunChatEntityType.strikethrough, 0, 1)]);
    parses('||x||', 'x', <KunChatEntity>[e(KunChatEntityType.spoiler, 0, 1)]);
    parses('`c`', 'c', <KunChatEntity>[e(KunChatEntityType.code, 0, 1)]);
    parses('```go\nfmt.Println()\n```', 'fmt.Println()', <KunChatEntity>[
      e(KunChatEntityType.pre, 0, 13, language: 'go'),
    ]);
    parses('[moyu](https://moyu.moe)', 'moyu', <KunChatEntity>[
      e(KunChatEntityType.textLink, 0, 4, url: 'https://moyu.moe'),
    ]);
    parses('[@鲲](mention:42)', '@鲲', <KunChatEntity>[
      e(KunChatEntityType.mention, 0, 2, userId: '42'),
    ]);
    parses('> quoted', 'quoted', <KunChatEntity>[
      e(KunChatEntityType.blockquote, 0, 6),
    ]);
  });

  test('markers work inside words, which Chinese needs', () {
    parses('这是**粗体**文字', '这是粗体文字', <KunChatEntity>[
      e(KunChatEntityType.bold, 2, 2),
    ]);
    parses(
        'a__b__c', 'abc', <KunChatEntity>[e(KunChatEntityType.italic, 1, 1)]);
  });

  test('nesting, and markers inside code staying literal', () {
    parses('**a __b__ c**', 'a b c', <KunChatEntity>[
      e(KunChatEntityType.bold, 0, 5),
      e(KunChatEntityType.italic, 2, 1),
    ]);
    parses('`a **b** c`', 'a **b** c', <KunChatEntity>[
      e(KunChatEntityType.code, 0, 9),
    ]);
    parses('**a `**` b**', 'a ** b', <KunChatEntity>[
      e(KunChatEntityType.bold, 0, 6),
      e(KunChatEntityType.code, 2, 2),
    ]);
    parses('||[x](https://a)||', 'x', <KunChatEntity>[
      e(KunChatEntityType.textLink, 0, 1, url: 'https://a'),
      e(KunChatEntityType.spoiler, 0, 1),
    ]);
  });

  test('what does not close stays text', () {
    parses('**open', '**open');
    parses('a ** b', 'a ** b');
    parses('****', '****');
    parses('``', '``');
    parses('[no link]', '[no link]');
    parses('[x]()', '[x]()');
  });

  test('a marker is exactly two characters', () {
    parses('***a***', '***a***');
    parses('~~~', '~~~');
  });

  test('pre blocks: language line, no language, and a one-line block', () {
    parses('```\nplain\n```', 'plain', <KunChatEntity>[
      e(KunChatEntityType.pre, 0, 5),
    ]);
    parses('```inline```', 'inline', <KunChatEntity>[
      e(KunChatEntityType.pre, 0, 6),
    ]);
    parses('```hello world\ncode```', 'hello world\ncode', <KunChatEntity>[
      e(KunChatEntityType.pre, 0, 16),
    ]);
    parses('```go\n```', 'go', <KunChatEntity>[e(KunChatEntityType.pre, 0, 2)]);
    parses('see\n```js\nx\n```\nok', 'see\nx\nok', <KunChatEntity>[
      e(KunChatEntityType.pre, 4, 1, language: 'js'),
    ]);
  });

  test('quote lines: consecutive lines are one quote', () {
    parses('> a\n> b\nc', 'a\nb\nc', <KunChatEntity>[
      e(KunChatEntityType.blockquote, 0, 3),
    ]);
    parses('> a\n\n> b', 'a\n\nb', <KunChatEntity>[
      e(KunChatEntityType.blockquote, 0, 1),
      e(KunChatEntityType.blockquote, 3, 1),
    ]);
    parses('> **a**', 'a', <KunChatEntity>[
      e(KunChatEntityType.blockquote, 0, 1),
      e(KunChatEntityType.bold, 0, 1),
    ]);
    parses(r'\> not a quote', '> not a quote');
    parses('a > b', 'a > b');
  });

  test('backslashes escape only what could be markup', () {
    parses(r'\*\*not bold\*\*', '**not bold**');
    parses(r'C:\Users\kun', r'C:\Users\kun');
    parses(r'¯\_(ツ)_/¯', r'¯\_(ツ)_/¯');
    parses(r'a\_b', r'a\_b');
    parses(r'\`tick\`', '`tick`');
    parses(r'\\**b**', r'\b', <KunChatEntity>[e(KunChatEntityType.bold, 1, 1)]);
  });

  test('format writes back what parse reads', () {
    final List<(String, List<KunChatEntity>)> cases =
        <(String, List<KunChatEntity>)>[
      ('plain', <KunChatEntity>[]),
      ('a*b', <KunChatEntity>[]),
      ('2**10', <KunChatEntity>[]),
      ('snake__case__name', <KunChatEntity>[]),
      (r'C:\Users', <KunChatEntity>[]),
      (r'¯\_(ツ)_/¯', <KunChatEntity>[]),
      ('> not a quote', <KunChatEntity>[]),
      ('[1] citation', <KunChatEntity>[]),
      ('bold', <KunChatEntity>[e(KunChatEntityType.bold, 0, 4)]),
      ('*star*', <KunChatEntity>[e(KunChatEntityType.bold, 1, 4)]),
      ('a`b', <KunChatEntity>[e(KunChatEntityType.code, 0, 3)]),
      (r'x\', <KunChatEntity>[e(KunChatEntityType.code, 0, 2)]),
      (
        'one\ntwo',
        <KunChatEntity>[
          e(KunChatEntityType.blockquote, 0, 7),
          e(KunChatEntityType.bold, 4, 3),
        ],
      ),
      (
        'func() {}',
        <KunChatEntity>[e(KunChatEntityType.pre, 0, 9, language: 'go')],
      ),
      ('```', <KunChatEntity>[e(KunChatEntityType.pre, 0, 3)]),
      (
        'a)b',
        <KunChatEntity>[
          e(KunChatEntityType.textLink, 0, 3, url: 'https://x.com/a_(b)'),
        ],
      ),
      (
        '@kun',
        <KunChatEntity>[e(KunChatEntityType.mention, 0, 4, userId: '9')],
      ),
      (
        '[x]',
        <KunChatEntity>[e(KunChatEntityType.textLink, 0, 3, url: 'https://a')],
      ),
    ];
    for (final (String text, List<KunChatEntity> entities) in cases) {
      final String source = formatKunChatMarkdown(text, entities);
      expect(
        parseKunChatMarkdown(source),
        KunChatFormattedText(
          text: text,
          entities: normalizeKunChatEntities(text, entities),
        ),
        reason: '$text → $source',
      );
    }
    expect(formatKunChatMarkdown('plain', <KunChatEntity>[]), 'plain');
    expect(
      formatKunChatMarkdown(
          'bold', <KunChatEntity>[e(KunChatEntityType.bold, 0, 4)]),
      '**bold**',
    );
  });

  test('a link label ending in a line break leaves the next line to the parser',
      () {
    // The parser checks for `> ` and `\\>` after the label's `](…)`, where the
    // new line's text begins, so the writer escapes there too.
    final List<(String, List<KunChatEntity>, String)> cases =
        <(String, List<KunChatEntity>, String)>[
      (
        'a\n\\>b',
        <KunChatEntity>[e(KunChatEntityType.mention, 1, 1, userId: '12')],
        'a[\n](mention:12)\\\\>b',
      ),
      (
        ')\n>',
        <KunChatEntity>[
          e(KunChatEntityType.blockquote, 0, 1),
          e(KunChatEntityType.blockquote, 1, 2),
          e(KunChatEntityType.mention, 1, 1, userId: '12'),
        ],
        '> )[\n](mention:12)\\>',
      ),
      (
        'a\n> b',
        <KunChatEntity>[
          e(KunChatEntityType.textLink, 0, 2, url: 'https://a'),
        ],
        '[a\n](https://a)\\> b',
      ),
      // a quote that starts there is read as one
      (
        'a\nb',
        <KunChatEntity>[
          e(KunChatEntityType.mention, 0, 2, userId: '1'),
          e(KunChatEntityType.blockquote, 2, 1),
        ],
        '[a\n](mention:1)> b',
      ),
      // inside a quote the `> ` prefix sits in the label, and the check is spent
      (
        'x\n\\>y',
        <KunChatEntity>[
          e(KunChatEntityType.blockquote, 0, 5),
          e(KunChatEntityType.mention, 0, 2, userId: '1'),
        ],
        '> [x\n> ](mention:1)\\>y',
      ),
    ];
    for (final (String text, List<KunChatEntity> entities, String source)
        in cases) {
      expect(formatKunChatMarkdown(text, entities), source);
      final List<KunChatEntity> kept = normalizeKunChatEntities(text, entities)
          .where(
            (KunChatEntity x) =>
                !(x.type == KunChatEntityType.blockquote && x.offset == 1),
          )
          .toList();
      expect(
        parseKunChatMarkdown(source),
        KunChatFormattedText(text: text, entities: kept),
        reason: source,
      );
    }
  });

  test('format drops url entities and quotes that are not whole lines', () {
    expect(
      formatKunChatMarkdown('https://a.b', <KunChatEntity>[
        e(KunChatEntityType.url, 0, 11),
      ]),
      'https://a.b',
    );
    expect(
      formatKunChatMarkdown('a b', <KunChatEntity>[
        e(KunChatEntityType.blockquote, 2, 1),
      ]),
      'a b',
    );
  });

  test('parse(format(m)) returns m, normalized (random)', () {
    final double Function() r = rng(20260927);
    for (int round = 0; round < 20000; round++) {
      final KunChatFormattedText m = randomMessage(r);
      final List<KunChatEntity> expected =
          normalizeKunChatEntities(m.text, m.entities);
      final List<KunChatEntity> quotes = expected
          .where((KunChatEntity q) => q.type == KunChatEntityType.blockquote)
          .toList();
      final List<KunChatEntity> raw = expected
          .where(
            (KunChatEntity x) =>
                x.type == KunChatEntityType.code ||
                x.type == KunChatEntityType.pre,
          )
          .toList();
      bool textBreak(int i) =>
          i >= 0 &&
          i < m.text.length &&
          m.text[i] == '\n' &&
          !raw.any(
            (KunChatEntity x) => x.offset <= i && i < x.offset + x.length,
          );
      final bool spellable = quotes.asMap().entries.every((
        MapEntry<int, KunChatEntity> entry,
      ) {
        final KunChatEntity q = entry.value;
        final int end = q.offset + q.length;
        final bool aligned = (q.offset == 0 || textBreak(q.offset - 1)) &&
            (end == m.text.length || textBreak(end));
        final KunChatEntity? prev =
            entry.key > 0 ? quotes[entry.key - 1] : null;
        return aligned &&
            !(prev != null && prev.offset + prev.length + 1 == q.offset);
      });
      if (!spellable) continue;
      final String source = formatKunChatMarkdown(m.text, m.entities);
      expect(
        parseKunChatMarkdown(source),
        KunChatFormattedText(text: m.text, entities: expected),
        reason: '${m.text} ${m.entities} → $source',
      );
    }
  });

  test('format is stable over its own output (random)', () {
    final double Function() r = rng(7);
    for (int round = 0; round < 5000; round++) {
      final KunChatFormattedText m = randomMessage(r);
      final KunChatFormattedText once = parseKunChatMarkdown(
        formatKunChatMarkdown(m.text, m.entities),
      );
      final KunChatFormattedText twice = parseKunChatMarkdown(
        formatKunChatMarkdown(once.text, once.entities),
      );
      expect(twice, once, reason: '${m.text} ${m.entities}');
    }
  });

  test('pathological input stays fast', () {
    final String nasty = '**`[' * 1024;
    final Stopwatch watch = Stopwatch()..start();
    parseKunChatMarkdown(nasty);
    expect(watch.elapsedMilliseconds, lessThan(1000));
  });
}
