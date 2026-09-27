import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

const Map<String, (List<List<int>>, List<List<num>>)> fixtures =
    <String, (List<List<int>>, List<List<num>>)>{
  'twoWide': (
    <List<int>>[
      <int>[1600, 900],
      <int>[1600, 900],
    ],
    <List<num>>[
      <num>[0, 0, 420, 209, 11],
      <num>[0, 211, 420, 209, 14],
    ],
  ),
  'twoMixed': (
    <List<int>>[
      <int>[900, 1600],
      <int>[1600, 900],
    ],
    <List<num>>[
      <num>[0, 0, 150, 151, 13],
      <num>[152, 0, 268, 151, 7],
    ],
  ),
  'threeNarrowFirst': (
    <List<int>>[
      <int>[600, 1200],
      <int>[1200, 900],
      <int>[1000, 1000],
    ],
    <List<num>>[
      <num>[0, 0, 209, 420, 13],
      <num>[211, 0, 209, 209, 3],
      <num>[211, 211, 209, 209, 6],
    ],
  ),
  'fourWideFirst': (
    <List<int>>[
      <int>[2000, 1000],
      <int>[800, 1000],
      <int>[1000, 1000],
      <int>[1200, 900],
    ],
    <List<num>>[
      <num>[0, 0, 420, 210, 11],
      <num>[0, 212, 106, 133, 12],
      <num>[108, 212, 133, 133, 4],
      <num>[243, 212, 177, 133, 6],
    ],
  ),
  'fiveMixed': (
    <List<int>>[
      <int>[1330, 1000],
      <int>[750, 1000],
      <int>[1000, 1000],
      <int>[1500, 1000],
      <int>[660, 1000],
    ],
    <List<num>>[
      <num>[0, 0, 420, 316, 11],
      <num>[0, 318, 209, 209, 8],
      <num>[211, 318, 209, 209, 2],
      <num>[0, 529, 251, 167, 12],
      <num>[253, 529, 167, 167, 6],
    ],
  ),
};

void main() {
  test('matches tweb / Telegram Desktop tile for tile', () {
    for (final MapEntry<String, (List<List<int>>, List<List<num>>)> entry
        in fixtures.entries) {
      final List<List<int>> sizes = entry.value.$1;
      final List<List<num>> tiles = entry.value.$2;
      final KunChatAlbumLayout layout = layoutKunChatAlbum(
        sizes
            .map(
              (List<int> s) => KunChatAlbumSize(
                width: s[0].toDouble(),
                height: s[1].toDouble(),
              ),
            )
            .toList(),
      );
      expect(
        layout.tiles
            .map(
              (KunChatAlbumTile t) =>
                  <num>[t.x, t.y, t.width, t.height, t.sides],
            )
            .toList(),
        tiles,
        reason: entry.key,
      );
    }
  });

  test('the bounding box encloses every tile', () {
    final KunChatAlbumLayout layout = layoutKunChatAlbum(
      fixtures['fiveMixed']!
          .$1
          .map(
            (List<int> s) => KunChatAlbumSize(
              width: s[0].toDouble(),
              height: s[1].toDouble(),
            ),
          )
          .toList(),
    );
    expect(layout.width, 420);
    expect(layout.height, 696);
  });

  test('degenerate sizes are squares, and an empty album is empty', () {
    final KunChatAlbumLayout layout =
        layoutKunChatAlbum(const <KunChatAlbumSize>[
      KunChatAlbumSize(width: 0, height: 0),
      KunChatAlbumSize(width: 100, height: 100),
    ]);
    expect(layout.tiles.length, 2);
    expect(
      layout.tiles.every(
        (KunChatAlbumTile t) => t.width.isFinite && t.height.isFinite,
      ),
      isTrue,
    );
    expect(
      layoutKunChatAlbum(const <KunChatAlbumSize>[]),
      const KunChatAlbumLayout(
        width: 0,
        height: 0,
        tiles: <KunChatAlbumTile>[],
      ),
    );
  });

  test('ten photos: every tile has positive size and stays inside the width',
      () {
    final List<KunChatAlbumSize> sizes = List<KunChatAlbumSize>.generate(
      10,
      (int i) => KunChatAlbumSize(width: 800 + i * 150, height: 1000),
    );
    final KunChatAlbumLayout layout = layoutKunChatAlbum(sizes);
    expect(layout.tiles.length, 10);
    for (final KunChatAlbumTile t in layout.tiles) {
      expect(t.width > 0 && t.height > 0, isTrue);
      expect(t.x + t.width <= 420, isTrue);
    }
  });

  test('more photos than any row split allows still lays out', () {
    final KunChatAlbumLayout layout = layoutKunChatAlbum(
      List<KunChatAlbumSize>.generate(
        13,
        (_) => const KunChatAlbumSize(width: 1000, height: 800),
      ),
    );
    expect(layout.tiles.length, 13);
    expect(
      layout.tiles.every(
        (KunChatAlbumTile t) => t.width > 0 && t.height > 0,
      ),
      isTrue,
    );
  });
}
