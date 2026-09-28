/// Entities → a render tree. This file is the specification the Flutter port
/// copies line for line, so every rule is spelled out and none depends on a
/// JavaScript quirk: offsets are UTF-16 code units, which is what both
/// `String.prototype.slice` and Dart's `String.substring` index.
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'types.dart';

final Set<KunChatEntityType> _knownTypes = <KunChatEntityType>{
  KunChatEntityType.bold,
  KunChatEntityType.italic,
  KunChatEntityType.underline,
  KunChatEntityType.strikethrough,
  KunChatEntityType.spoiler,
  KunChatEntityType.code,
  KunChatEntityType.pre,
  KunChatEntityType.blockquote,
  KunChatEntityType.textLink,
  KunChatEntityType.mention,
  KunChatEntityType.url,
};

/// Types whose content is literal: nothing may nest inside them.
final Set<KunChatEntityType> _leafTypes = <KunChatEntityType>{
  KunChatEntityType.code,
  KunChatEntityType.pre,
};

/// Types rendered as links. A link inside a link is invalid HTML (`<a>` in
/// `<a>`), so the inner one is dropped.
final Set<KunChatEntityType> _linkTypes = <KunChatEntityType>{
  KunChatEntityType.textLink,
  KunChatEntityType.mention,
  KunChatEntityType.url,
};

/// Types that break the line around themselves.
const Set<KunChatEntityType> kunChatBlockEntityTypes = <KunChatEntityType>{
  KunChatEntityType.pre,
  KunChatEntityType.blockquote,
};

// Tie-break for entities covering the exact same range: the earlier type is
// the outer one. Blocks outermost, links outside formatting (a link keeps its
// whole styled label clickable), code innermost.
const List<KunChatEntityType> _nestingOrder = <KunChatEntityType>[
  KunChatEntityType.blockquote,
  KunChatEntityType.pre,
  KunChatEntityType.textLink,
  KunChatEntityType.mention,
  KunChatEntityType.url,
  KunChatEntityType.spoiler,
  KunChatEntityType.bold,
  KunChatEntityType.italic,
  KunChatEntityType.underline,
  KunChatEntityType.strikethrough,
  KunChatEntityType.code,
];

int _rank(KunChatEntityType type) => _nestingOrder.indexOf(type);

bool _isHighSurrogate(int code) => code >= 0xd800 && code <= 0xdbff;
bool _isLowSurrogate(int code) => code >= 0xdc00 && code <= 0xdfff;

/// Whether `index` falls between the two halves of a surrogate pair.
bool _splitsPair(String text, int index) =>
    index > 0 &&
    index < text.length &&
    _isHighSurrogate(text.codeUnitAt(index - 1)) &&
    _isLowSurrogate(text.codeUnitAt(index));

class _Range {
  _Range({required this.entity, required this.start, required this.end});

  final KunChatEntity entity;
  int start;
  int end;
}

int _compareRanges(_Range a, _Range b) => a.start - b.start != 0
    ? a.start - b.start
    : b.end - a.end != 0
        ? b.end - a.end
        : _rank(a.entity.type) - _rank(b.entity.type);

KunChatEntity _cleanEntity(KunChatEntity e, int offset, int length) {
  return KunChatEntity(
    type: e.type,
    offset: offset,
    length: length,
    userId: e.type == KunChatEntityType.mention ? e.userId : null,
    url: e.type == KunChatEntityType.textLink ? e.url : null,
    language: e.type == KunChatEntityType.pre &&
            e.language != null &&
            e.language!.isNotEmpty
        ? e.language
        : null,
  );
}

/// Inline formatting: no link, no block, no literal content. Touching runs of
/// one type are one run, and a line break at either end draws nothing.
final Set<KunChatEntityType> _formatTypes = <KunChatEntityType>{
  KunChatEntityType.bold,
  KunChatEntityType.italic,
  KunChatEntityType.underline,
  KunChatEntityType.strikethrough,
  KunChatEntityType.spoiler,
};

List<_Range> _mergeTouching(List<_Range> ranges) {
  final List<_Range> out = <_Range>[];
  final Map<KunChatEntityType, _Range> last = <KunChatEntityType, _Range>{};
  final List<_Range> sorted = List<_Range>.from(ranges)..sort(_compareRanges);
  for (final _Range r in sorted) {
    final _Range? prev =
        _formatTypes.contains(r.entity.type) ? last[r.entity.type] : null;
    if (prev != null && r.start <= prev.end) {
      prev.end = math.max(prev.end, r.end);
      continue;
    }
    out.add(r);
    if (_formatTypes.contains(r.entity.type)) last[r.entity.type] = r;
  }
  return out;
}

// A quote is a block, so it must sit outside every inline entity: anything
// that straddles a quote boundary is cut there. `quotes` must be the quotes
// that survive nesting: cutting at one that is later dropped leaves a cut
// with no cause, which the next pass merges away.
List<_Range> _splitAtQuotes(List<_Range> ranges, List<_Range> quotes) {
  final List<int> cuts =
      quotes.expand((_Range r) => <int>[r.start, r.end]).toList();
  return ranges.expand((_Range r) {
    final List<int> inner = cuts
        .where((int c) => c > r.start && c < r.end)
        .toList()
      ..sort((int a, int b) => a - b);
    final List<int> points = <int>[
      r.start,
      ...LinkedHashSet<int>.from(inner),
      r.end,
    ];
    return <_Range>[
      for (int i = 0; i < points.length - 1; i++)
        _Range(entity: r.entity, start: points[i], end: points[i + 1]),
    ];
  }).toList();
}

String? _at(String text, int index) =>
    index >= 0 && index < text.length ? text[index] : null;

/// Make an entity list safe to render, without ever changing `text`:
///
/// 1. Drop unknown types, non-integer or negative positions, empty ranges, a
///    `text_link` without a `url` and a `mention` without a `user_id`; clamp
///    the end to the text. Widen a range that would cut a surrogate pair (an
///    emoji) in half. Pull a blockquote's end in over trailing line breaks.
/// 2. Merge touching or overlapping runs of one inline format (bold, italic,
///    underline, strikethrough, spoiler).
/// 3. Settle the blockquotes among themselves (steps 5 and 6, quotes only),
///    then cut every other entity at the boundaries of a quote that survived,
///    so quotes are always outermost.
/// 4. Pull the ends of an inline format in over line breaks, which draw
///    nothing there (a blockquote's end, before step 3).
/// 5. Order by start, then longer first, then by nesting order; split an
///    entity that partially crosses another at the boundary, so every pair
///    nests or is disjoint.
/// 6. Drop what cannot nest: anything inside `code`/`pre`, a type inside the
///    same type, a link inside a link.
///
/// The result is a fixed point: normalizing it again changes nothing. The
/// server already guarantees most of this; the client does it anyway so a bad
/// row renders instead of throwing.
List<KunChatEntity> normalizeKunChatEntities(
  String text,
  List<KunChatEntity>? entities,
) {
  if (entities == null || entities.isEmpty || text.isEmpty) {
    return <KunChatEntity>[];
  }

  final List<_Range> ranges = <_Range>[];
  for (final KunChatEntity e in entities) {
    if (!_knownTypes.contains(e.type)) continue;
    if (e.offset < 0 || e.length <= 0) continue;
    if (e.type == KunChatEntityType.textLink &&
        (e.url == null || e.url!.isEmpty)) {
      continue;
    }
    if (e.type == KunChatEntityType.mention &&
        (e.userId == null || e.userId!.isEmpty)) {
      continue;
    }
    int start = e.offset;
    int end = math.min(e.offset + e.length, text.length);
    if (start >= end) continue;
    if (_splitsPair(text, start)) start -= 1;
    if (_splitsPair(text, end)) end += 1;
    // Before the cuts below, which must see the quote's final boundaries.
    if (e.type == KunChatEntityType.blockquote) {
      while (end > start && _at(text, end - 1) == '\n') {
        end--;
      }
    }
    if (start < end) ranges.add(_Range(entity: e, start: start, end: end));
  }

  // Every piece made from here on, the crossing splits included, is trimmed,
  // or normalizing twice would trim what the first pass left.
  bool trimmed(_Range r) {
    if (_formatTypes.contains(r.entity.type)) {
      while (r.start < r.end && _at(text, r.start) == '\n') {
        r.start++;
      }
      while (r.end > r.start && _at(text, r.end - 1) == '\n') {
        r.end--;
      }
    }
    return r.start < r.end;
  }

  List<_Range> nest(List<_Range> ranges) {
    final List<_Range> queue = ranges.where(trimmed).toList()
      ..sort(_compareRanges);
    void enqueue(_Range r) {
      int i = 0;
      while (i < queue.length && _compareRanges(queue[i], r) <= 0) {
        i++;
      }
      queue.insert(i, r);
    }

    final List<_Range> out = <_Range>[];
    final List<_Range> stack = <_Range>[];
    while (queue.isNotEmpty) {
      final _Range r = queue.removeAt(0);
      while (stack.isNotEmpty && stack[stack.length - 1].end <= r.start) {
        stack.removeLast();
      }
      final _Range? parent = stack.isEmpty ? null : stack[stack.length - 1];
      if (parent != null && r.end > parent.end) {
        // Crosses the parent's end: keep the part inside, requeue the rest.
        final _Range rest =
            _Range(entity: r.entity, start: parent.end, end: r.end);
        if (trimmed(rest)) enqueue(rest);
        r.end = parent.end;
        if (!trimmed(r)) continue;
        // Shorter now, it may sort after entities still waiting.
        if (queue.isNotEmpty && _compareRanges(r, queue[0]) > 0) {
          enqueue(r);
          continue;
        }
      }
      final bool blocked = stack.any(
        (_Range a) =>
            _leafTypes.contains(a.entity.type) ||
            a.entity.type == r.entity.type ||
            (_linkTypes.contains(a.entity.type) &&
                _linkTypes.contains(r.entity.type)),
      );
      if (blocked) continue;
      stack.add(r);
      out.add(r);
    }
    return out;
  }

  // Everything else is cut at the quotes' boundaries, so only a quote can
  // hold a quote: nesting the quotes alone settles which ones survive.
  final List<_Range> quotes = nest(
    ranges
        .where((_Range r) => r.entity.type == KunChatEntityType.blockquote)
        .toList(),
  );
  final List<_Range> inline = _mergeTouching(
    ranges
        .where((_Range r) => r.entity.type != KunChatEntityType.blockquote)
        .toList(),
  );
  final List<_Range> out =
      nest(<_Range>[...quotes, ..._splitAtQuotes(inline, quotes)]);

  return out
      .map((_Range r) => _cleanEntity(r.entity, r.start, r.end - r.start))
      .toList();
}

/// A run of unformatted text in the render tree.
@immutable
class KunChatTextLeaf extends KunChatTextNode {
  /// Creates a text leaf.
  const KunChatTextLeaf({required this.text, required this.offset});

  /// The slice of the message text.
  final String text;

  /// Where [text] starts in the message text, in UTF-16 code units.
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is KunChatTextLeaf && other.text == text && other.offset == offset;

  @override
  int get hashCode => Object.hash(text, offset);

  @override
  String toString() => 'KunChatTextLeaf($offset, $text)';
}

/// An entity wrapping nested text and entity nodes.
@immutable
class KunChatEntityNode extends KunChatTextNode {
  /// Creates an entity node.
  const KunChatEntityNode({required this.entity, required this.children});

  /// The entity this node renders.
  final KunChatEntity entity;

  /// Nested leaves and entities, in document order.
  final List<KunChatTextNode> children;

  @override
  bool operator ==(Object other) =>
      other is KunChatEntityNode &&
      other.entity == entity &&
      listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(entity, Object.hashAll(children));

  @override
  String toString() => 'KunChatEntityNode(${entity.type.wireName}, $children)';
}

/// A node in the entity render tree: a text leaf or an entity wrapping
/// children.
@immutable
sealed class KunChatTextNode {
  /// Creates a tree node.
  const KunChatTextNode();
}

bool _isBlock(KunChatTextNode? node) =>
    node is KunChatEntityNode &&
    kunChatBlockEntityTypes.contains(node.entity.type);

// A block (pre, blockquote) already starts and ends a line, so the `\n` that
// separates it from the surrounding text would render as an extra blank line.
// Drop exactly one line break on each side — the text keeps it; only the tree
// omits it.
List<KunChatTextNode> _trimAroundBlocks(List<KunChatTextNode> nodes) {
  final List<KunChatTextNode> out = <KunChatTextNode>[];
  for (int i = 0; i < nodes.length; i++) {
    final KunChatTextNode node = nodes[i];
    if (node is KunChatEntityNode) {
      out.add(
        KunChatEntityNode(
          entity: node.entity,
          children: _trimAroundBlocks(node.children),
        ),
      );
      continue;
    }
    final KunChatTextLeaf leaf = node as KunChatTextLeaf;
    String text = leaf.text;
    int offset = leaf.offset;
    if (_isBlock(i > 0 ? nodes[i - 1] : null) && text.startsWith('\n')) {
      text = text.substring(1);
      offset += 1;
    }
    if (_isBlock(i + 1 < nodes.length ? nodes[i + 1] : null) &&
        text.endsWith('\n')) {
      // Dart substring throws on a negative end; JS `slice(0, -1)` drops the
      // last UTF-16 code unit.
      text = text.substring(0, text.length - 1);
    }
    if (text.isNotEmpty) {
      out.add(KunChatTextLeaf(text: text, offset: offset));
    }
  }
  return out;
}

class _Frame {
  _Frame({required this.node, required this.end, required this.cursor});

  final KunChatEntityNode node;
  final int end;
  int cursor;
}

/// Turn `text` + `entities` into a tree: entity nodes whose children are text
/// leaves and nested entity nodes, in document order. The entities are
/// normalized first (see [normalizeKunChatEntities]), so any input renders.
List<KunChatTextNode> buildKunChatEntityTree(
  String text,
  List<KunChatEntity>? entities,
) {
  final KunChatEntityNode root = KunChatEntityNode(
    entity: KunChatEntity(
      type: KunChatEntityType.bold,
      offset: 0,
      length: text.length,
    ),
    children: <KunChatTextNode>[],
  );
  final List<_Frame> stack = <_Frame>[
    _Frame(node: root, end: text.length, cursor: 0),
  ];
  void flushTo(_Frame frame, int to) {
    if (to > frame.cursor) {
      frame.node.children.add(
        KunChatTextLeaf(
          text: text.substring(frame.cursor, to),
          offset: frame.cursor,
        ),
      );
    }
    frame.cursor = math.max(frame.cursor, to);
  }

  void close() {
    final _Frame frame = stack.removeLast();
    flushTo(frame, frame.end);
    stack[stack.length - 1].cursor = frame.end;
  }

  for (final KunChatEntity entity in normalizeKunChatEntities(text, entities)) {
    final int start = entity.offset;
    while (stack.length > 1 && stack[stack.length - 1].end <= start) {
      close();
    }
    final _Frame parent = stack[stack.length - 1];
    flushTo(parent, start);
    final KunChatEntityNode node = KunChatEntityNode(
      entity: entity,
      children: <KunChatTextNode>[],
    );
    parent.node.children.add(node);
    stack.add(_Frame(node: node, end: start + entity.length, cursor: start));
  }
  while (stack.length > 1) {
    close();
  }
  flushTo(stack[0], text.length);

  return _trimAroundBlocks(root.children);
}

/// The plain text of a subtree, as rendered (block-adjacent breaks omitted).
String kunChatTreeText(List<KunChatTextNode> nodes) => nodes
    .map(
      (KunChatTextNode n) => n is KunChatTextLeaf
          ? n.text
          : kunChatTreeText((n as KunChatEntityNode).children),
    )
    .join();

/// The part of a message from `start` to `end` (UTF-16 code units), with the
/// entities clipped to it and shifted to start at 0 — what a partial quote
/// carries. The range is widened rather than split through an emoji.
KunChatFormattedText sliceKunChatEntities(
  String text,
  List<KunChatEntity>? entities,
  int start,
  int end,
) {
  int from = math.max(0, math.min(start, text.length));
  int to = math.max(from, math.min(end, text.length));
  if (_splitsPair(text, from)) from -= 1;
  if (_splitsPair(text, to)) to += 1;
  final List<KunChatEntity> clipped =
      normalizeKunChatEntities(text, entities).expand((KunChatEntity e) {
    final int s = math.max(e.offset, from);
    final int t = math.min(e.offset + e.length, to);
    if (t > s) {
      return <KunChatEntity>[
        KunChatEntity(
          type: e.type,
          offset: s - from,
          length: t - s,
          userId: e.userId,
          url: e.url,
          language: e.language,
        ),
      ];
    }
    return const <KunChatEntity>[];
  }).toList();
  final String sliced = text.substring(from, to);
  return KunChatFormattedText(
    text: sliced,
    entities: normalizeKunChatEntities(sliced, clipped),
  );
}
