import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

class _DemoSrc {
  const _DemoSrc({
    required this.hex,
    required this.width,
    required this.height,
  });

  final String hex;
  final int width;
  final int height;
}

final Map<String, _DemoSrc> _srcMeta = <String, _DemoSrc>{};

String _svgSrc(String hex, {int width = 320, int height = 240}) {
  final String svg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height">'
      '<rect width="$width" height="$height" fill="%23$hex"/></svg>';
  final String src = 'data:image/svg+xml;utf8,${Uri.encodeComponent(svg)}';
  _srcMeta[src] = _DemoSrc(hex: hex, width: width, height: height);
  return src;
}

int _hexByte(String hex, int index) =>
    int.parse(hex.substring(index, index + 2), radix: 16);

final Map<String, MemoryImage> _memory = <String, MemoryImage>{};

ImageProvider _demoImageProvider(String src) {
  return _memory.putIfAbsent(src, () {
    final _DemoSrc meta =
        _srcMeta[src] ?? const _DemoSrc(hex: '000000', width: 320, height: 240);
    return MemoryImage(
      _solidPng(
        _hexByte(meta.hex, 0),
        _hexByte(meta.hex, 2),
        _hexByte(meta.hex, 4),
        width: meta.width,
        height: meta.height,
      ),
    );
  });
}

Widget _scope({required Widget child}) {
  return KunUIConfigScope(
    config: KunUIConfig(imageProvider: _demoImageProvider),
    child: child,
  );
}

final List<KunLightboxImage> _basicImages = <KunLightboxImage>[
  for (final (int i, String hex) in <String>[
    '7c3aed',
    '22c55e',
    'f59e0b',
  ].indexed)
    KunLightboxImage(src: _svgSrc(hex), alt: 'Image ${i + 1}'),
];

final List<KunLightboxImage> _standaloneImages = <KunLightboxImage>[
  for (final (int i, String hex) in <String>[
    '0ea5e9',
    'f97316',
    '8b5cf6',
  ].indexed)
    KunLightboxImage(
      src: _svgSrc(hex, width: 600, height: 400),
      alt: 'Slide ${i + 1}',
    ),
];

Widget lightboxBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(child: const _LightboxBasic()),
  );
}

Widget lightboxStandalone(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(child: const _LightboxStandalone()),
  );
}

class _LightboxBasic extends StatefulWidget {
  const _LightboxBasic();

  @override
  State<_LightboxBasic> createState() => _LightboxBasicState();
}

class _LightboxBasicState extends State<_LightboxBasic> {
  bool _open = false;
  int _index = 0;

  void _openAt(int index) {
    setState(() {
      _index = index;
      _open = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: KunSpacing.unit * 3,
          children: <Widget>[
            for (int i = 0; i < _basicImages.length; i++)
              GestureDetector(
                onTap: () => _openAt(i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(KunRounded.lg),
                  child: SizedBox(
                    width: KunSpacing.unit * 24,
                    height: KunSpacing.unit * 24,
                    child: Image(
                      image: _demoImageProvider(_basicImages[i].src),
                      fit: BoxFit.cover,
                      semanticLabel: _basicImages[i].alt,
                    ),
                  ),
                ),
              ),
          ],
        ),
        KunLightbox(
          images: _basicImages,
          isOpen: _open,
          initialIndex: _index,
          onOpenChanged: (bool open) => setState(() => _open = open),
        ),
      ],
    );
  }
}

class _LightboxStandalone extends StatefulWidget {
  const _LightboxStandalone();

  @override
  State<_LightboxStandalone> createState() => _LightboxStandaloneState();
}

class _LightboxStandaloneState extends State<_LightboxStandalone> {
  bool _open = false;
  int _index = 0;

  void _openAt(int index) {
    setState(() {
      _index = index;
      _open = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: KunSpacing.unit * 3,
          runSpacing: KunSpacing.unit * 3,
          children: <Widget>[
            KunButton(
              color: KunUIColor.primary,
              onPressed: () => _openAt(0),
              child: const Text('打开查看器'),
            ),
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => _openAt(2),
              child: const Text('从第 3 张打开'),
            ),
          ],
        ),
        KunLightbox(
          images: _standaloneImages,
          isOpen: _open,
          initialIndex: _index,
          onOpenChanged: (bool open) => setState(() => _open = open),
        ),
      ],
    );
  }
}

int _crc32(List<int> data) {
  int crc = 0xffffffff;
  for (final int byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      final bool bit = crc & 1 == 1;
      crc >>= 1;
      if (bit) {
        crc ^= 0xEDB88320;
      }
    }
  }
  return crc ^ 0xffffffff;
}

int _adler32(List<int> data) {
  int a = 1;
  int b = 0;
  for (final int byte in data) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  return (b << 16) | a;
}

Uint8List _u32(int value) {
  final ByteData data = ByteData(4)..setUint32(0, value);
  return data.buffer.asUint8List();
}

Uint8List _chunk(List<int> type, List<int> payload) {
  final BytesBuilder body = BytesBuilder()
    ..add(type)
    ..add(payload);
  final Uint8List bytes = body.toBytes();
  return Uint8List.fromList(<int>[
    ..._u32(payload.length),
    ...bytes,
    ..._u32(_crc32(bytes)),
  ]);
}

Uint8List _solidPng(int r, int g, int b, {int width = 1, int height = 1}) {
  final BytesBuilder raw = BytesBuilder(copy: false);
  for (int y = 0; y < height; y++) {
    raw.addByte(0);
    for (int x = 0; x < width; x++) {
      raw
        ..addByte(r)
        ..addByte(g)
        ..addByte(b);
    }
  }
  final Uint8List pixels = raw.toBytes();
  final ByteData ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  return Uint8List.fromList(<int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    ..._chunk(<int>[0x49, 0x48, 0x44, 0x52], ihdr.buffer.asUint8List()),
    ..._chunk(<int>[0x49, 0x44, 0x41, 0x54], _zlibStore(pixels)),
    ..._chunk(<int>[0x49, 0x45, 0x4E, 0x44], const <int>[]),
  ]);
}

Uint8List _zlibStore(Uint8List raw) {
  final BytesBuilder out = BytesBuilder()
    ..addByte(0x78)
    ..addByte(0x01);
  const int maxBlock = 65535;
  int offset = 0;
  while (offset < raw.length) {
    final int remaining = raw.length - offset;
    final int n = remaining > maxBlock ? maxBlock : remaining;
    final bool last = offset + n >= raw.length;
    out
      ..addByte(last ? 1 : 0)
      ..addByte(n & 0xff)
      ..addByte((n >> 8) & 0xff)
      ..addByte((~n) & 0xff)
      ..addByte(((~n) >> 8) & 0xff)
      ..add(raw.sublist(offset, offset + n));
    offset += n;
  }
  out.add(_u32(_adler32(raw)));
  return out.toBytes();
}
