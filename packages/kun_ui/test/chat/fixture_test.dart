import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Map<String, Object?>? treeJson(KunChatTextNode node) {
  if (node is KunChatTextLeaf) {
    return <String, Object?>{
      'kind': 'text',
      'text': node.text,
      'offset': node.offset,
    };
  }
  final KunChatEntityNode entity = node as KunChatEntityNode;
  return <String, Object?>{
    'kind': 'entity',
    'entity': entity.entity.toJson(),
    'children': <Object?>[
      for (final KunChatTextNode child in entity.children) treeJson(child),
    ],
  };
}

List<KunChatEntity> entitiesFromRaw(Object? raw) {
  if (raw is! List) return <KunChatEntity>[];
  final List<KunChatEntity> out = <KunChatEntity>[];
  for (final dynamic item in raw) {
    final KunChatEntity? entity = KunChatEntity.tryFromJson(item as Object?);
    if (entity != null) out.add(entity);
  }
  return out;
}

List<Map<String, Object?>> entitiesJson(List<KunChatEntity> entities) =>
    <Map<String, Object?>>[
      for (final KunChatEntity e in entities) e.toJson(),
    ];

bool closeNum(num a, num b) => a == b || (a - b).abs() <= 1e-9;

void main() {
  test('chat core golden fixture', () {
    final String body =
        File('test/chat/chat_core.fixture.json').readAsStringSync();
    final List<String> lines =
        body.split('\n').where((String l) => l.isNotEmpty).toList();
    expect(lines, isNotEmpty);

    int albumToleranceUsed = 0;
    final List<String> mismatches = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final Map<String, dynamic> caseMap =
          jsonDecode(lines[i]) as Map<String, dynamic>;
      final String fn = caseMap['fn'] as String;
      final Map<String, dynamic> input = caseMap['in'] as Map<String, dynamic>;
      final Object? expected = caseMap['out'];
      try {
        switch (fn) {
          case 'parse':
            final KunChatFormattedText got =
                parseKunChatMarkdown(input['source'] as String);
            expect(got.text, (expected as Map)['text']);
            expect(entitiesJson(got.entities), expected['entities']);
          case 'format':
            final String got = formatKunChatMarkdown(
              input['text'] as String,
              entitiesFromRaw(input['entities']),
            );
            expect(got, expected);
          case 'normalize':
            final List<KunChatEntity> got = normalizeKunChatEntities(
              input['text'] as String,
              entitiesFromRaw(input['entities']),
            );
            expect(entitiesJson(got), expected);
          case 'tree':
            final List<KunChatTextNode> got = buildKunChatEntityTree(
              input['text'] as String,
              entitiesFromRaw(input['entities']),
            );
            expect(
              <Object?>[for (final KunChatTextNode n in got) treeJson(n)],
              expected,
            );
          case 'slice':
            final KunChatFormattedText got = sliceKunChatEntities(
              input['text'] as String,
              entitiesFromRaw(input['entities']),
              input['start'] as int,
              input['end'] as int,
            );
            expect(got.text, (expected as Map)['text']);
            expect(entitiesJson(got.entities), expected['entities']);
          case 'album':
            final List<KunChatAlbumSize> sizes = <KunChatAlbumSize>[
              for (final dynamic s in input['sizes'] as List)
                KunChatAlbumSize(
                  width: (s['width'] as num).toDouble(),
                  height: (s['height'] as num).toDouble(),
                ),
            ];
            final Map<String, dynamic>? options =
                input['options'] as Map<String, dynamic>?;
            final KunChatAlbumLayout got = layoutKunChatAlbum(
              sizes,
              maxWidth: (options?['maxWidth'] as num?)?.toDouble() ?? 420,
              minWidth: (options?['minWidth'] as num?)?.toDouble() ?? 100,
              spacing: (options?['spacing'] as num?)?.toDouble() ?? 2,
            );
            final Map<String, dynamic> out = expected as Map<String, dynamic>;
            bool same = closeNum(got.width, out['width'] as num) &&
                closeNum(got.height, out['height'] as num);
            if (got.width != out['width'] || got.height != out['height']) {
              albumToleranceUsed++;
            }
            final List<dynamic> tiles = out['tiles'] as List<dynamic>;
            if (got.tiles.length != tiles.length) {
              same = false;
            } else {
              for (int t = 0; t < got.tiles.length; t++) {
                final KunChatAlbumTile tile = got.tiles[t];
                final Map<String, dynamic> exp =
                    tiles[t] as Map<String, dynamic>;
                final bool exact = tile.x == exp['x'] &&
                    tile.y == exp['y'] &&
                    tile.width == exp['width'] &&
                    tile.height == exp['height'] &&
                    tile.sides == exp['sides'];
                final bool near = closeNum(tile.x, exp['x'] as num) &&
                    closeNum(tile.y, exp['y'] as num) &&
                    closeNum(tile.width, exp['width'] as num) &&
                    closeNum(tile.height, exp['height'] as num) &&
                    tile.sides == exp['sides'];
                if (!exact && near) albumToleranceUsed++;
                if (!near) same = false;
              }
            }
            if (!same) {
              throw TestFailure(
                'album mismatch: expected $out actual '
                '${got.width}x${got.height} ${got.tiles}',
              );
            }
          default:
            throw StateError('unknown fn $fn');
        }
      } catch (error) {
        mismatches.add(
          'line ${i + 1} $fn\n  in: ${jsonEncode(input)}\n'
          '  expected: ${jsonEncode(expected)}\n  error: $error',
        );
        if (mismatches.length >= 5) break;
      }
    }

    if (mismatches.isNotEmpty) {
      fail(
        '${mismatches.length} fixture mismatch(es), first few:\n'
        '${mismatches.join('\n\n')}',
      );
    }
    // ignore: avoid_print
    print('album cases that used 1e-9 tolerance: $albumToleranceUsed');
  });
}
