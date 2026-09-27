/// Composer shortcuts ↔ entities. The composer is a plain textarea: what the
/// user types is parsed into `{ text, entities }` on send, and editing a sent
/// message formats it back. `formatKunChatMarkdown` is the inverse of
/// `parseKunChatMarkdown` — `parse(format(m))` returns `m` — for every message
/// except the few shapes the syntax cannot spell, listed on `format` below.
///
/// The syntax, all of it:
///
///   **bold**  __italic__  ++underline++  ~~strikethrough~~  ||spoiler||
///   `code`    ```lang⏎ pre ⏎```    [label](https://…)    [label](mention:42)
///   > quoted line (at the start of a line; consecutive lines form one quote)
///
/// Markers work inside words — Chinese has no spaces to anchor them to — and
/// only need non-empty content. A marker is exactly two characters: `***` is
/// text, as in TDLib's parser. A marker without a partner stays literal text.
///
/// Escaping. A run of k backslashes before a special character stands for
/// ⌊k/2⌋ backslashes, and escapes that character when k is odd. Before
/// anything else a backslash is literal. In text, ` [ ] are always special,
/// and * _ + ~ | are special only next to their own twin (backslashes in
/// between don't count) — a lone one can never be a marker, so `a\_b`,
/// `C:\Users` and `¯\_(ツ)_/¯` keep their backslashes. Inside `code` and a pre
/// block the only special character is `, inside a link target it is ). A line
/// whose text starts with backslashes and then `>` loses one backslash: `\>`
/// is how a line starts with a literal `>`.
library;

import 'types.dart';
import 'entities.dart';

const List<(String, KunChatEntityType)> _pairs = <(String, KunChatEntityType)>[
  ('**', KunChatEntityType.bold),
  ('__', KunChatEntityType.italic),
  ('++', KunChatEntityType.underline),
  ('~~', KunChatEntityType.strikethrough),
  ('||', KunChatEntityType.spoiler),
];

final Map<KunChatEntityType, String> _pairByType = <KunChatEntityType, String>{
  for (final (String m, KunChatEntityType t) in _pairs) t: m,
};

const Set<String> _pairChars = <String>{'*', '_', '+', '~', '|'};
const Set<String> _textSpecial = <String>{
  '*',
  '_',
  '+',
  '~',
  '|',
  '`',
  '[',
  ']',
};
final RegExp _language = RegExp(r'^[A-Za-z0-9_+#.-]*$');
final RegExp _mention = RegExp(r'^mention:(\d+)$');

String? _at(String s, int i) => i >= 0 && i < s.length ? s[i] : null;

int _backslashRun(String s, int i, int end) {
  int k = 0;
  while (i + k < end && _at(s, i + k) == r'\') {
    k++;
  }
  return k;
}

/// The nearest character from `i` in direction `step` that is not a
/// backslash — the whole source, not just the current range, so a marker's
/// neighbour counts.
String? _nonBackslash(String s, int i, int step) {
  while (i >= 0 && i < s.length && _at(s, i) == r'\') {
    i += step;
  }
  return _at(s, i);
}

class _Escape {
  const _Escape({required this.k, required this.c, required this.special});
  final int k;
  final String c;
  final bool special;
}

/// At the backslash run starting at `i`: its length, and whether it is
/// followed by a special character (and so escapes it when odd). The
/// character after the run is read past `end`: a run that ends a range sits
/// right before the range's closing marker, and the writer doubled it.
_Escape _escapeAt(String s, int i, int end) {
  final int k = _backslashRun(s, i, end);
  final int j = i + k;
  final String c = _at(s, j) ?? '';
  final bool special = c == '`' || c == '[' || c == ']'
      ? true
      : _pairChars.contains(c) &&
          (_nonBackslash(s, i - 1, -1) == c || _nonBackslash(s, j + 1, 1) == c);
  return _Escape(k: k, c: c, special: special);
}

/// Where scanning resumes after the backslash run at `i`.
int _skipEscape(String s, int i, int end) {
  final _Escape e = _escapeAt(s, i, end);
  return i + (e.special && e.k % 2 == 1 && i + e.k < end ? e.k + 1 : e.k);
}

class _RawSpan {
  const _RawSpan({
    required this.end,
    required this.contentStart,
    required this.contentEnd,
    this.language,
  });
  final int end;
  final int contentStart;
  final int contentEnd;
  final String? language;
}

/// The next unescaped `closer` at or after `from`, in a raw context whose
/// only special character is `special`; -1 when there is none.
int _findRawCloser(
  String s,
  int from,
  int end,
  String closer,
  String special,
) {
  int p = from;
  while (p < end) {
    if (_at(s, p) == r'\') {
      final int k = _backslashRun(s, p, end);
      p += _at(s, p + k) == special && k % 2 == 1 ? k + 1 : k;
      continue;
    }
    if (p + closer.length <= end && s.startsWith(closer, p)) return p;
    p++;
  }
  return -1;
}

/// Undo raw-context escaping: backslash runs before `special` halve. A run
/// at the very end counts as before `special` when the closer follows it.
String _unescapeRaw(String s, String special, bool closerFollows) {
  String out = '';
  int p = 0;
  while (p < s.length) {
    if (_at(s, p) != r'\') {
      out += s[p];
      p++;
      continue;
    }
    final int k = _backslashRun(s, p, s.length);
    final String next =
        p + k < s.length ? s[p + k] : (closerFollows ? special : '');
    if (next != special) {
      out += r'\' * k;
      p += k;
    } else if (k % 2 == 1) {
      out += r'\' * ((k - 1) ~/ 2) + special;
      p += k + 1;
    } else {
      out += r'\' * (k ~/ 2);
      p += k;
    }
  }
  return out;
}

_RawSpan? _matchCode(String s, int i, int end) {
  // JS `s[i]` is undefined past the end; Dart `s[i]` throws.
  if (i < 0 || i >= s.length) return null;
  if (_at(s, i) != '`') return null;
  final int close = _findRawCloser(s, i + 1, end, '`', '`');
  if (close <= i + 1) return null;
  return _RawSpan(end: close + 1, contentStart: i + 1, contentEnd: close);
}

_RawSpan? _matchPre(String s, int i, int end) {
  // JS `startsWith` with an index past `length` is false; Dart throws.
  if (i < 0 || i > s.length) return null;
  if (!s.startsWith('```', i)) return null;
  final int open = i + 3;
  final int close = _findRawCloser(s, open, end, '```', '`');
  if (close < 0) return null;
  int trimEnd(int from) =>
      close > from && _at(s, close - 1) == '\n' ? close - 1 : close;
  final int nl = s.indexOf('\n', open);
  if (nl >= 0 && nl < close && _language.hasMatch(s.substring(open, nl))) {
    final int contentEnd = trimEnd(nl + 1);
    if (contentEnd > nl + 1) {
      final String languageSlice = s.substring(open, nl);
      final String? language = languageSlice.isEmpty ? null : languageSlice;
      return _RawSpan(
        end: close + 3,
        contentStart: nl + 1,
        contentEnd: contentEnd,
        language: language,
      );
    }
    // "```go⏎```" is a block whose one line is "go", not an empty Go block.
  }
  final int contentEnd = trimEnd(open);
  if (contentEnd <= open) return null;
  return _RawSpan(end: close + 3, contentStart: open, contentEnd: contentEnd);
}

class _LinkSpan {
  const _LinkSpan({
    required this.end,
    required this.labelStart,
    required this.labelEnd,
    required this.target,
  });
  final int end;
  final int labelStart;
  final int labelEnd;
  final String target;
}

_LinkSpan? _matchLink(String s, int i, int end) {
  if (i < 0 || i >= s.length) return null;
  if (_at(s, i) != '[') return null;
  int p = i + 1;
  while (p < end) {
    if (_at(s, p) == r'\') {
      p = _skipEscape(s, p, end);
      continue;
    }
    // A later `[` owns the `](` we would find: this one is literal text.
    if (_at(s, p) == '[') return null;
    if (_at(s, p) == ']' && _at(s, p + 1) == '(') {
      if (p == i + 1) return null;
      final int close = _findRawCloser(s, p + 2, end, ')', ')');
      if (close <= p + 2) return null;
      return _LinkSpan(
        end: close + 1,
        labelStart: i + 1,
        labelEnd: p,
        target: _unescapeRaw(s.substring(p + 2, close), ')', true),
      );
    }
    final _RawSpan? raw = _matchPre(s, p, end) ?? _matchCode(s, p, end);
    p = raw != null ? raw.end : p + 1;
  }
  return null;
}

/// Length of the run of `s[i]` starting at `i`.
int _charRun(String s, int i, int end) {
  int k = 1;
  while (i + k < end && _at(s, i + k) == _at(s, i)) {
    k++;
  }
  return k;
}

int _findPairCloser(String s, int from, int end, String marker) {
  int p = from;
  while (p < end) {
    if (_at(s, p) == r'\') {
      p = _skipEscape(s, p, end);
      continue;
    }
    if (_pairChars.contains(_at(s, p))) {
      final int run = _charRun(s, p, end);
      if (run == 2 && p > from && s.startsWith(marker, p)) return p;
      p += run;
      continue;
    }
    // Code, pre blocks and links are opaque: a marker inside one of them
    // cannot close a pair that started outside.
    final Object? atom =
        _matchPre(s, p, end) ?? _matchCode(s, p, end) ?? _matchLink(s, p, end);
    if (atom is _RawSpan) {
      p = atom.end;
    } else if (atom is _LinkSpan) {
      p = atom.end;
    } else {
      p = p + 1;
    }
  }
  return -1;
}

/// Parse composer input into message text and entities. Never throws: input
/// that is not valid shortcut syntax stays literal text.
KunChatFormattedText parseKunChatMarkdown(String source) {
  String text = '';
  final List<KunChatEntity> entities = <KunChatEntity>[];
  final List<(int, int)> quotedLines = <(int, int)>[];
  bool atLineStart = true;
  bool lineQuoted = false;
  int lineOffset = 0;

  void endLine() {
    if (lineQuoted) quotedLines.add((lineOffset, text.length));
  }

  void parseRange(int start, int end) {
    int i = start;
    while (i < end) {
      if (atLineStart) {
        atLineStart = false;
        lineOffset = text.length;
        lineQuoted = false;
        if (i + 2 <= end && source.startsWith('> ', i)) {
          lineQuoted = true;
          i += 2;
        } else if (_at(source, i) == '>' &&
            (i + 1 == end || _at(source, i + 1) == '\n')) {
          lineQuoted = true;
          i += 1;
        }
        if (_at(source, i) == r'\' &&
            _at(source, i + _backslashRun(source, i, end)) == '>') {
          i += 1;
        }
        continue;
      }

      final String c = source[i];
      if (c == r'\') {
        final _Escape e = _escapeAt(source, i, end);
        if (!e.special) {
          text += r'\' * e.k;
          i += e.k;
        } else if (e.k % 2 == 1 && i + e.k < end) {
          text += r'\' * ((e.k - 1) ~/ 2) + e.c;
          i += e.k + 1;
        } else {
          text += r'\' * (e.k ~/ 2);
          i += e.k;
        }
        continue;
      }

      if (c == '\n') {
        endLine();
        text += '\n';
        atLineStart = true;
        i++;
        continue;
      }

      final _RawSpan? raw = _matchPre(source, i, end);
      final _RawSpan? code = raw != null ? null : _matchCode(source, i, end);
      final _RawSpan? span = raw ?? code;
      if (span != null) {
        final int offset = text.length;
        text += _unescapeRaw(
          source.substring(span.contentStart, span.contentEnd),
          '`',
          _at(source, span.contentEnd) == '`',
        );
        entities.add(
          KunChatEntity(
            type: raw != null ? KunChatEntityType.pre : KunChatEntityType.code,
            offset: offset,
            length: text.length - offset,
            language: span.language != null && span.language!.isNotEmpty
                ? span.language
                : null,
          ),
        );
        i = span.end;
        continue;
      }

      final _LinkSpan? link = _matchLink(source, i, end);
      if (link != null) {
        final int offset = text.length;
        parseRange(link.labelStart, link.labelEnd);
        final int length = text.length - offset;
        final Match? mention = _mention.firstMatch(link.target);
        if (length > 0) {
          entities.add(
            mention != null
                ? KunChatEntity(
                    type: KunChatEntityType.mention,
                    offset: offset,
                    length: length,
                    userId: mention.group(1),
                  )
                : KunChatEntity(
                    type: KunChatEntityType.textLink,
                    offset: offset,
                    length: length,
                    url: link.target,
                  ),
          );
        }
        i = link.end;
        continue;
      }

      if (_pairChars.contains(c)) {
        // Exactly two: `***` or `****` is not a marker, it is text.
        final int run = _charRun(source, i, end);
        if (run != 2) {
          text += c * run;
          i += run;
          continue;
        }
        final (String marker, KunChatEntityType type) = _pairs.firstWhere(
          ((String, KunChatEntityType) p) => p.$1[0] == c,
        );
        final int close = _findPairCloser(source, i + 2, end, marker);
        if (close > i + 2) {
          final int offset = text.length;
          parseRange(i + 2, close);
          final int length = text.length - offset;
          if (length > 0) {
            entities.add(
              KunChatEntity(type: type, offset: offset, length: length),
            );
          }
          i = close + 2;
        } else {
          text += marker;
          i += 2;
        }
        continue;
      }

      text += c;
      i++;
    }
  }

  parseRange(0, source.length);
  endLine();

  // Consecutive quoted lines form one quote, the line breaks between included.
  for (int q = 0; q < quotedLines.length; q++) {
    final int start = quotedLines[q].$1;
    int end = quotedLines[q].$2;
    while (q + 1 < quotedLines.length && quotedLines[q + 1].$1 == end + 1) {
      q++;
      end = quotedLines[q].$2;
    }
    if (end > start) {
      entities.add(
        KunChatEntity(
          type: KunChatEntityType.blockquote,
          offset: start,
          length: end - start,
        ),
      );
    }
  }

  return KunChatFormattedText(
    text: text,
    entities: normalizeKunChatEntities(text, entities),
  );
}

enum _Context { text, code, pre, url }

sealed class _Atom {}

class _LitAtom extends _Atom {
  _LitAtom({required this.ch, required this.ctx, required this.inLabel});
  final String ch;
  final _Context ctx;
  final bool inLabel;
  bool escape = false;
}

class _MarkAtom extends _Atom {
  _MarkAtom(this.s);
  final String s;
}

class _FormatNode {
  _FormatNode({
    required this.entity,
    required this.start,
    required this.end,
  });
  final KunChatEntity? entity;
  final int start;
  final int end;
  final List<_FormatNode> children = <_FormatNode>[];
}

/// Turn message text + entities back into composer input — for editing a sent
/// message, or restoring a draft. Parsing the result gives back the same text
/// and (normalized) entities, except for what the syntax cannot spell:
///
/// - `url` entities are dropped; the server detects links again on save.
/// - A blockquote is dropped unless it starts and ends at line breaks that
///   are text — not inside a code span or pre block.
/// - Blockquotes on consecutive lines are written, and come back, as one.
/// - A `pre` language with characters outside `A-Z a-z 0-9 _ + # . -` is
///   dropped, as is a `text_link` whose URL is itself `mention:<digits>`.
String formatKunChatMarkdown(String text, List<KunChatEntity>? entities) {
  // A quote is spelled as `> ` lines, so it needs a line break on each side
  // that the parser reads as text — not one inside a code span or pre block.
  // Quotes that cannot be spelled go, and the rest is normalized again from
  // the original entities, so whatever those quotes had cut apart joins up.
  final List<KunChatEntity> withoutUrls = (entities ?? const <KunChatEntity>[])
      .where((KunChatEntity e) => e.type != KunChatEntityType.url)
      .toList();
  final List<KunChatEntity> first = normalizeKunChatEntities(text, withoutUrls);
  bool inRaw(int i) => first.any(
        (KunChatEntity r) =>
            (r.type == KunChatEntityType.code ||
                r.type == KunChatEntityType.pre) &&
            r.offset <= i &&
            i < r.offset + r.length,
      );
  bool breakAt(int i) => _at(text, i) == '\n' && !inRaw(i);
  final List<KunChatEntity> quotes = <KunChatEntity>[];
  for (final KunChatEntity q in first) {
    if (q.type != KunChatEntityType.blockquote) continue;
    final int end = q.offset + q.length;
    if (!(q.offset == 0 || breakAt(q.offset - 1)) ||
        !(end == text.length || breakAt(end))) {
      continue;
    }
    final KunChatEntity? prev =
        quotes.isEmpty ? null : quotes[quotes.length - 1];
    if (prev != null && prev.offset + prev.length + 1 == q.offset) {
      quotes[quotes.length - 1] = KunChatEntity(
        type: prev.type,
        offset: prev.offset,
        length: end - prev.offset,
        userId: prev.userId,
        url: prev.url,
        language: prev.language,
      );
    } else {
      quotes.add(q);
    }
  }
  final List<KunChatEntity> list =
      normalizeKunChatEntities(text, <KunChatEntity>[
    ...withoutUrls.where(
      (KunChatEntity e) => e.type != KunChatEntityType.blockquote,
    ),
    ...quotes,
  ]);

  final _FormatNode root =
      _FormatNode(entity: null, start: 0, end: text.length);
  final List<_FormatNode> stack = <_FormatNode>[root];
  for (final KunChatEntity entity in list) {
    final _FormatNode node = _FormatNode(
      entity: entity,
      start: entity.offset,
      end: entity.offset + entity.length,
    );
    while (stack.length > 1 && stack[stack.length - 1].end <= node.start) {
      stack.removeLast();
    }
    stack[stack.length - 1].children.add(node);
    stack.add(node);
  }

  final List<_Atom> atoms = <_Atom>[];
  void mark(String s) => atoms.add(_MarkAtom(s));
  void lit(String ch, _Context ctx, bool inLabel) =>
      atoms.add(_LitAtom(ch: ch, ctx: ctx, inLabel: inLabel));
  int quoteDepth = 0;

  void emitText(int from, int to, bool inLabel) {
    for (int i = from; i < to; i++) {
      lit(text[i], _Context.text, inLabel);
      // A normalized quote never ends in a line break, so every break inside
      // one is followed by another quoted line.
      if (_at(text, i) == '\n' && quoteDepth > 0) mark('> ');
    }
  }

  void emitRaw(int from, int to, _Context ctx) {
    for (int i = from; i < to; i++) {
      lit(text[i], ctx, false);
    }
  }

  late final void Function(_FormatNode node, bool inLabel) walk;
  late final void Function(_FormatNode node, bool inLabel) emitEntity;

  walk = (_FormatNode node, bool inLabel) {
    int cursor = node.start;
    for (final _FormatNode child in node.children) {
      emitText(cursor, child.start, inLabel);
      emitEntity(child, inLabel);
      cursor = child.end;
    }
    emitText(cursor, node.end, inLabel);
  };

  emitEntity = (_FormatNode node, bool inLabel) {
    final KunChatEntity e = node.entity!;
    final String? pair = _pairByType[e.type];
    if (pair != null) {
      mark(pair);
      walk(node, inLabel);
      mark(pair);
    } else if (e.type == KunChatEntityType.code) {
      mark('`');
      emitRaw(node.start, node.end, _Context.code);
      mark('`');
    } else if (e.type == KunChatEntityType.pre) {
      final String language = e.language != null &&
              e.language!.isNotEmpty &&
              _language.hasMatch(e.language!)
          ? e.language!
          : '';
      mark('```$language\n');
      emitRaw(node.start, node.end, _Context.pre);
      mark('\n```');
    } else if (e.type == KunChatEntityType.textLink ||
        e.type == KunChatEntityType.mention) {
      mark('[');
      walk(node, true);
      mark('](');
      final String target =
          e.type == KunChatEntityType.mention ? 'mention:${e.userId}' : e.url!;
      // JS `for (const ch of target)` yields Unicode code points, not UTF-16
      // units, so a surrogate-pair emoji in a URL is one literal.
      for (final int rune in target.runes) {
        lit(String.fromCharCode(rune), _Context.url, false);
      }
      mark(')');
    } else if (e.type == KunChatEntityType.blockquote) {
      mark('> ');
      quoteDepth++;
      walk(node, inLabel);
      quoteDepth--;
    } else {
      walk(node, inLabel);
    }
  };

  walk(root, false);
  return _serialize(atoms);
}

_Atom? _atomAt(List<_Atom> atoms, int i) =>
    i >= 0 && i < atoms.length ? atoms[i] : null;

bool _isLit(_Atom? a, String ch, _Context ctx) =>
    a is _LitAtom && a.ch == ch && a.ctx == ctx;

String? _firstChar(_Atom? a) {
  if (a == null) return null;
  return a is _MarkAtom ? (a.s.isEmpty ? null : a.s[0]) : (a as _LitAtom).ch;
}

/// The first character after atom `from` that is not a backslash, as it
/// will be written.
String? _rawCharFrom(List<_Atom> atoms, int from) {
  for (int i = from; i < atoms.length; i++) {
    final _Atom a = atoms[i];
    if (a is _MarkAtom) {
      // JS `[...a.s]` spreads code points.
      for (final int rune in a.s.runes) {
        final String ch = String.fromCharCode(rune);
        if (ch != r'\') return ch;
      }
    } else if (a is _LitAtom && (a.escape || a.ch != r'\')) {
      return a.ch;
    }
  }
  return null;
}

String? _lastNonBackslash(String out) {
  int i = out.length - 1;
  while (i >= 0 && _at(out, i) == r'\') {
    i--;
  }
  return _at(out, i);
}

/// Whether a backslash run written before atom `j` would be read as an
/// escape — mirrors the parser's `escapeAt` — in which case it is doubled.
bool _beforeSpecial(
  List<_Atom> atoms,
  int j,
  _Context ctx,
  String out,
) {
  final _Atom? next = _atomAt(atoms, j);
  if (next == null) return false;
  if (next is _LitAtom && next.escape) return true;
  final String c = next is _MarkAtom ? next.s[0] : (next as _LitAtom).ch;
  if (ctx != _Context.text) {
    return c == (ctx == _Context.url ? ')' : '`');
  }
  if (next is _MarkAtom) return _textSpecial.contains(c);
  if (c == '`' || c == '[' || c == ']') return true;
  return _pairChars.contains(c) &&
      (_lastNonBackslash(out) == c || _rawCharFrom(atoms, j + 1) == c);
}

/// Where the parser checks for a quote prefix and a leading `>`.
bool _atTextLineStart(String out) =>
    out.isEmpty || out.endsWith('\n') || out == '> ' || out.endsWith('\n> ');

String _serialize(List<_Atom> atoms) {
  // Which literals need a backslash.
  for (int i = 0; i < atoms.length; i++) {
    final _Atom a = atoms[i];
    if (a is! _LitAtom) continue;
    final _Atom? prev = _atomAt(atoms, i - 1);
    final _Atom? next = _atomAt(atoms, i + 1);
    if (a.ctx == _Context.text) {
      if (_pairChars.contains(a.ch)) {
        // No two active copies of a pair character may touch, or they would
        // read as a marker.
        final bool prevActive = prev is _MarkAtom
            ? prev.s.endsWith(a.ch)
            : prev is _LitAtom && !prev.escape && prev.ch == a.ch;
        a.escape = prevActive || _firstChar(next) == a.ch;
      } else if (a.ch == '`') {
        a.escape = true;
      } else if (a.ch == '[') {
        a.escape = a.inLabel;
      } else if (a.ch == ']') {
        a.escape = next is _LitAtom && next.ch == '(';
      }
    } else if (a.ctx == _Context.code) {
      a.escape = a.ch == '`';
    } else if (a.ctx == _Context.url) {
      a.escape = a.ch == ')';
    } else if (a.ch == '`') {
      // In a pre block only three backticks in a row can close it.
      int s = i;
      while (_isLit(_atomAt(atoms, s - 1), '`', _Context.pre)) {
        s--;
      }
      int e = i;
      while (_isLit(_atomAt(atoms, e + 1), '`', _Context.pre)) {
        e++;
      }
      a.escape = e - s + 1 >= 3;
    }
  }

  String out = '';
  int i = 0;
  while (i < atoms.length) {
    final _Atom a = atoms[i];
    if (a is _MarkAtom) {
      out += a.s;
      i++;
      continue;
    }
    final _LitAtom lit = a as _LitAtom;
    if (lit.ctx == _Context.text && _atTextLineStart(out)) {
      int j = i;
      while (_isLit(_atomAt(atoms, j), r'\', _Context.text)) {
        j++;
      }
      if (_isLit(_atomAt(atoms, j), '>', _Context.text)) out += r'\';
    }
    if (lit.ch == r'\') {
      int j = i;
      while (_isLit(_atomAt(atoms, j), r'\', lit.ctx)) {
        j++;
      }
      out +=
          r'\' * (_beforeSpecial(atoms, j, lit.ctx, out) ? 2 * (j - i) : j - i);
      i = j;
      continue;
    }
    out += lit.escape ? '\\${lit.ch}' : lit.ch;
    i++;
  }
  return out;
}
