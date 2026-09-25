import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

const String _bannerThumbhash = 'eBeCA4AmyAaYeIcLy20KVwg3inaCelc=';
const String _bannerAsset = 'assets/banner.webp';
const String _bannerSrc = 'asset:$_bannerAsset';

const Duration _kBlurUpDelay = Duration(milliseconds: 1500);

ImageProvider _demoImageProvider(String url) {
  if (url.startsWith('asset:')) {
    return AssetImage(url.substring('asset:'.length));
  }
  return NetworkImage(
    url,
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
  );
}

Widget _scope({required Widget child, KunImageResolver? imageProvider}) {
  return KunUIConfigScope(
    config: KunUIConfig(
      imageProvider: imageProvider ?? _demoImageProvider,
    ),
    child: child,
  );
}

Widget _caption(BuildContext context, String text) {
  return Text(
    text,
    style: KunText.sm.copyWith(
      color: KunTheme.of(context).colors.neutral.shade500,
    ),
  );
}

Widget imageBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(
      child: const KunImage(
        src: _bannerSrc,
        alt: 'Example image',
        width: 240,
        height: 180,
      ),
    ),
  );
}

Widget imageAspectRatio(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 4,
            children: [
              SizedBox(
                width: KunSpacing.unit * 56,
                child: const KunImage(
                  src: _bannerSrc,
                  alt: '16:9',
                  aspectRatio: 16 / 9,
                ),
              ),
              SizedBox(
                width: KunSpacing.unit * 40,
                child: const KunImage(
                  src: _bannerSrc,
                  alt: '1:1',
                  aspectRatio: 1,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunSpacing.unit * 6,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: KunSpacing.unit * 2,
                children: [
                  SizedBox(
                    width: KunSpacing.unit * 40,
                    child: const KunImage(
                      src: _bannerSrc,
                      alt: 'cover',
                      fit: BoxFit.cover,
                      aspectRatio: 1,
                    ),
                  ),
                  _caption(context, 'cover'),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: KunSpacing.unit * 2,
                children: [
                  SizedBox(
                    width: KunSpacing.unit * 40,
                    child: const KunImage(
                      src: _bannerSrc,
                      alt: 'contain',
                      fit: BoxFit.contain,
                      aspectRatio: 1,
                    ),
                  ),
                  _caption(context, 'contain'),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget imageBlurUp(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _BlurUpDemo(),
  );
}

Widget imageSkeleton(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _SkeletonDemo(),
  );
}

Widget imageFallback(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _FallbackDemo(),
  );
}

Widget imageThumbhashImage(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: SizedBox(
      width: KunSpacing.unit * 72,
      child: const AspectRatio(
        aspectRatio: 16 / 9,
        child: Image(
          image: KunThumbHashImage(_bannerThumbhash),
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}

class _DelayedAssetImage extends ImageProvider<_DelayedAssetImage> {
  const _DelayedAssetImage({
    required this.asset,
    required this.delay,
    required this.generation,
  });

  final String asset;
  final Duration delay;
  final int generation;

  @override
  Future<_DelayedAssetImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_DelayedAssetImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _DelayedAssetImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_load(key, decode));
  }

  Future<ImageInfo> _load(
    _DelayedAssetImage key,
    ImageDecoderCallback decode,
  ) async {
    await Future<void>.delayed(key.delay);
    final ByteData data = await rootBundle.load(key.asset);
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final ui.Codec codec = await decode(buffer);
    final ui.FrameInfo frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      other is _DelayedAssetImage &&
      other.asset == asset &&
      other.delay == delay &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(asset, delay, generation);
}

class _BlurUpDemo extends StatefulWidget {
  const _BlurUpDemo();

  @override
  State<_BlurUpDemo> createState() => _BlurUpDemoState();
}

class _BlurUpDemoState extends State<_BlurUpDemo> {
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    return _scope(
      imageProvider: (String url) {
        if (url.startsWith('asset:')) {
          return _DelayedAssetImage(
            asset: url.substring('asset:'.length),
            delay: _kBlurUpDelay,
            generation: _generation,
          );
        }
        return NetworkImage(
          url,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 3,
        children: [
          KunButton(
            size: KunUISize.sm,
            variant: KunUIVariant.bordered,
            onPressed: () => setState(() => _generation += 1),
            child: const Text('Reload'),
          ),
          SizedBox(
            width: KunSpacing.unit * 72,
            child: KunImage(
              key: ValueKey<int>(_generation),
              src: _bannerSrc,
              alt: 'ThumbHash blur-up',
              aspectRatio: 16 / 9,
              thumbhash: _bannerThumbhash,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonDemo extends StatefulWidget {
  const _SkeletonDemo();

  @override
  State<_SkeletonDemo> createState() => _SkeletonDemoState();
}

class _SkeletonDemoState extends State<_SkeletonDemo> {
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    return _scope(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 3,
        children: [
          KunButton(
            size: KunUISize.sm,
            variant: KunUIVariant.bordered,
            onPressed: () {
              imageCache.evict(const AssetImage(_bannerAsset));
              setState(() => _generation += 1);
            },
            child: const Text('Reload'),
          ),
          SizedBox(
            width: KunSpacing.unit * 56,
            child: KunImage(
              key: ValueKey<int>(_generation),
              src: _bannerSrc,
              alt: 'Skeleton',
              aspectRatio: 4 / 3,
              skeleton: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackDemo extends StatefulWidget {
  const _FallbackDemo();

  @override
  State<_FallbackDemo> createState() => _FallbackDemoState();
}

class _FallbackDemoState extends State<_FallbackDemo> {
  final List<String> _log = <String>[];

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return _scope(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 3,
        children: [
          SizedBox(
            width: KunSpacing.unit * 56,
            child: KunImage(
              src: 'asset:assets/does-not-exist.webp',
              fallbackSrc: _bannerSrc,
              alt: 'Fallback',
              aspectRatio: 4 / 3,
              onError: (String src) {
                setState(() => _log.add('error: $src'));
              },
              onLoad: (String src) {
                setState(() => _log.add('load: $src'));
              },
            ),
          ),
          Text(
            _log.isEmpty ? 'waiting…' : _log.join('\n'),
            style: KunText.xs.copyWith(color: scheme.neutral.shade500),
          ),
        ],
      ),
    );
  }
}
