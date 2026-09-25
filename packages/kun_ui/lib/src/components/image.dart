import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/motion.dart';
import '../theme/theme.dart';
import 'pulse.dart';
import 'thumbhash_image.dart';

enum _ImageStatus { loading, loaded, error }

/// An image with the web `KunImage` loading machine: skeleton or ThumbHash
/// blur-up, a fallback swap, and `load` / `error` events.
///
/// [src] and [fallbackSrc] are resolved through
/// [KunUIConfigScope.of]'s [KunUIConfig.imageProvider], so an app brings its
/// own caching. A URL becomes a [NetworkImage] by default.
class KunImage extends StatefulWidget {
  /// Creates an image.
  const KunImage({
    super.key,
    required this.src,
    this.alt,
    this.semanticLabel,
    this.fallbackSrc,
    this.width,
    this.height,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.skeleton = true,
    this.thumbhash,
    this.onLoad,
    this.onError,
    this.cacheWidth,
    this.cacheHeight,
  });

  /// Image URL (web `src`).
  final String src;

  /// Alternative text (web `alt`).
  ///
  /// The semantics node is an image labelled [semanticLabel] ?? [alt]. With
  /// neither, it is an image with no label. With [alt] equal to the empty
  /// string and no [semanticLabel], the node is excluded from semantics —
  /// write the empty string for a decorative image so screen readers skip it.
  /// The web default `'image'` is not carried over: a Chinese app would read
  /// that English literal as the image's name.
  final String? alt;

  /// Accessible name when it has to differ from [alt] (web `ariaLabel`).
  final String? semanticLabel;

  /// Shown if [src] fails to load. Resets when [src] changes (web
  /// `fallbackSrc`).
  final String? fallbackSrc;

  /// Logical width (web `width`).
  final double? width;

  /// Logical height (web `height`).
  final double? height;

  /// Aspect ratio of the wrapper, e.g. `16 / 9` (web `aspectRatio`).
  ///
  /// When set, the box fills the available width and the image is
  /// positioned to fill it.
  final double? aspectRatio;

  /// How the image fills its box (web `objectFit`). Defaults to [BoxFit.cover].
  final BoxFit fit;

  /// Renders a sibling skeleton overlay while loading (web `skeleton`).
  ///
  /// Default true; set false for a bare image when [thumbhash] is also
  /// empty. A non-empty [thumbhash] still wraps.
  final bool skeleton;

  /// A base64 ThumbHash for the blur-up placeholder (web `thumbhash`).
  ///
  /// Decoded when the widget builds; an undecodable hash falls through to
  /// the skeleton layer.
  final String? thumbhash;

  /// Called with the src that loaded, at most once per src attempt (web
  /// `load`).
  final ValueChanged<String>? onLoad;

  /// Called with the src that failed, at most once per src attempt (web
  /// `error`).
  final ValueChanged<String>? onError;

  /// Decode width in physical pixels, for a thumbnail grid.
  ///
  /// The Flutter-side counterpart of the web's responsive `sizes` /
  /// `densities`, which the contract lists as web-only. Wraps the resolved
  /// provider in [ResizeImage.resizeIfNeeded].
  final int? cacheWidth;

  /// Decode height in physical pixels, for a thumbnail grid.
  ///
  /// See [cacheWidth].
  final int? cacheHeight;

  /// Key of the placeholder opacity widget, for tests.
  @visibleForTesting
  static const Key placeholderKey = ValueKey<String>('kunImagePlaceholder');

  /// Key of the picture fade widget, for tests.
  @visibleForTesting
  static const Key pictureFadeKey = ValueKey<String>('kunImagePictureFade');

  @override
  State<KunImage> createState() => _KunImageState();
}

class _KunImageState extends State<KunImage> {
  _ImageStatus _status = _ImageStatus.loading;
  bool _failed = false;
  bool _errorHandled = false;
  bool _fadePlaceholder = false;
  bool _dropPlaceholder = false;
  bool _syncLoaded = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Timer? _holdTimer;
  String? _reportedLoadSrc;
  String? _reportedErrorSrc;

  String get _effectiveSrc {
    if (_failed) {
      final String? fallback = widget.fallbackSrc;
      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
    }
    return widget.src;
  }

  bool get _hasThumbhash =>
      widget.thumbhash != null && widget.thumbhash!.isNotEmpty;

  bool get _wrap => widget.skeleton || _hasThumbhash;

  bool get _thumbDecodes =>
      _hasThumbhash && tryDecodeThumbHash(widget.thumbhash!) != null;

  bool get _showPlaceholder {
    if (!_wrap || _dropPlaceholder || _syncLoaded) {
      return false;
    }
    if (kunReducedMotion(context) && _status == _ImageStatus.loaded) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (widget.src.isEmpty) {
      _status = _ImageStatus.error;
      _dropPlaceholder = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
  }

  @override
  void didUpdateWidget(KunImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      _holdTimer?.cancel();
      _holdTimer = null;
      _failed = false;
      _errorHandled = false;
      _reportedLoadSrc = null;
      _reportedErrorSrc = null;
      _fadePlaceholder = false;
      _dropPlaceholder = widget.src.isEmpty;
      _syncLoaded = false;
      _status = widget.src.isEmpty ? _ImageStatus.error : _ImageStatus.loading;
    }
    _listen();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _unlisten();
    super.dispose();
  }

  void _reportLoad(String src) {
    if (src.isEmpty || _reportedLoadSrc == src) {
      return;
    }
    _reportedLoadSrc = src;
    widget.onLoad?.call(src);
  }

  void _reportError(String src) {
    if (src.isEmpty || _reportedErrorSrc == src) {
      return;
    }
    _reportedErrorSrc = src;
    widget.onError?.call(src);
  }

  ImageProvider _resolve(KunUIConfig config, String src) {
    return ResizeImage.resizeIfNeeded(
      widget.cacheWidth,
      widget.cacheHeight,
      config.imageProvider(src),
    );
  }

  void _unlisten() {
    final ImageStream? stream = _stream;
    final ImageStreamListener? listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  void _listen() {
    final String src = _effectiveSrc;
    if (src.isEmpty) {
      _unlisten();
      return;
    }
    final ImageProvider provider = _resolve(KunUIConfigScope.of(context), src);
    final ImageStream stream =
        provider.resolve(createLocalImageConfiguration(context));
    if (identical(stream, _stream) && _listener != null) {
      return;
    }
    _unlisten();
    _stream = stream;
    _listener = ImageStreamListener(_onImage, onError: _onStreamError);
    stream.addListener(_listener!);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    if (!mounted) {
      return;
    }
    if (_status == _ImageStatus.loaded) {
      _reportLoad(_effectiveSrc);
      return;
    }
    _reportLoad(_effectiveSrc);
    setState(() {
      _status = _ImageStatus.loaded;
      if (synchronousCall) {
        _syncLoaded = true;
        _dropPlaceholder = true;
        _fadePlaceholder = true;
      }
    });
    if (!synchronousCall) {
      if (_animationsDisabled) {
        return;
      }
      _holdTimer?.cancel();
      _holdTimer = Timer(KunDurations.slow, () {
        if (!mounted || _status != _ImageStatus.loaded) {
          return;
        }
        setState(() => _fadePlaceholder = true);
      });
    }
  }

  bool get _animationsDisabled =>
      context
          .findAncestorWidgetOfExactType<MediaQuery>()
          ?.data
          .disableAnimations ??
      false;

  void _onStreamError(Object error, StackTrace? stackTrace) {
    if (!mounted || _errorHandled) {
      return;
    }
    _errorHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleError();
      }
    });
  }

  void _handleError() {
    _holdTimer?.cancel();
    _holdTimer = null;
    final String src = _effectiveSrc;
    _reportError(src);
    final String? fallback = widget.fallbackSrc;
    if (!_failed &&
        fallback != null &&
        fallback.isNotEmpty &&
        fallback != src) {
      setState(() {
        _failed = true;
        _errorHandled = false;
        _fadePlaceholder = false;
        _dropPlaceholder = false;
        _syncLoaded = false;
        _status = _ImageStatus.loading;
      });
      _listen();
      return;
    }
    setState(() {
      _status = _ImageStatus.error;
      _fadePlaceholder = true;
      if (_animationsDisabled) {
        _dropPlaceholder = true;
      }
    });
  }

  void _onPictureFadeEnd() {
    if (!mounted || _fadePlaceholder || _status != _ImageStatus.loaded) {
      return;
    }
    setState(() {
      _fadePlaceholder = true;
      if (_animationsDisabled) {
        _dropPlaceholder = true;
      }
    });
  }

  Widget _semantics({required Widget child}) {
    if (widget.semanticLabel == null && widget.alt == '') {
      return ExcludeSemantics(child: child);
    }
    return Semantics(
      image: true,
      label: widget.semanticLabel ?? widget.alt,
      excludeSemantics: true,
      child: child,
    );
  }

  Widget _placeholder({required Color shade200}) {
    final Widget inner;
    if (_thumbDecodes) {
      inner = Image(
        image: KunThumbHashImage(widget.thumbhash!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        excludeFromSemantics: true,
      );
    } else if (_status == _ImageStatus.error) {
      inner = const SizedBox.expand();
    } else {
      final Widget fill = ColoredBox(color: shade200);
      inner =
          _status == _ImageStatus.loading ? KunPulseLayer(child: fill) : fill;
    }
    return ExcludeSemantics(
      child: KeyedSubtree(
        key: KunImage.placeholderKey,
        child: AnimatedOpacity(
          key: ValueKey<String>('ph:$_effectiveSrc'),
          opacity: _fadePlaceholder ? 0 : 1,
          duration: kunMotion(context, KunDurations.slow),
          curve: KunDefaultTransition.curve,
          onEnd: () {
            if (_fadePlaceholder && mounted) {
              setState(() => _dropPlaceholder = true);
            }
          },
          child: inner,
        ),
      ),
    );
  }

  Widget _picture(ImageProvider provider) {
    return Image(
      key: ValueKey<ImageProvider>(provider),
      image: provider,
      width: widget.aspectRatio == null ? widget.width : null,
      height: widget.aspectRatio == null ? widget.height : null,
      fit: widget.fit,
      excludeFromSemantics: true,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return SizedBox(
          width: widget.aspectRatio == null ? widget.width : null,
          height: widget.aspectRatio == null ? widget.height : null,
        );
      },
    );
  }

  Widget _fadedPicture(Widget picture) {
    if (_syncLoaded ||
        (kunReducedMotion(context) && _status == _ImageStatus.loaded)) {
      return picture;
    }
    return KeyedSubtree(
      key: KunImage.pictureFadeKey,
      child: AnimatedOpacity(
        opacity: _status == _ImageStatus.loaded ? 1 : 0,
        duration: kunMotion(context, KunDurations.slow),
        curve: KunDefaultTransition.curve,
        onEnd: _onPictureFadeEnd,
        child: picture,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color shade200 = KunTheme.of(context).colors.neutral.shade200;
    final String src = _effectiveSrc;
    if (src.isEmpty) {
      Widget empty = SizedBox(width: widget.width, height: widget.height);
      if (widget.aspectRatio != null) {
        empty = AspectRatio(aspectRatio: widget.aspectRatio!, child: empty);
      }
      return _semantics(child: empty);
    }

    final ImageProvider provider = _resolve(KunUIConfigScope.of(context), src);
    final Widget picture = _picture(provider);
    if (!_wrap) {
      return _semantics(child: picture);
    }

    final Widget faded = _fadedPicture(picture);
    final bool showPlaceholder = _showPlaceholder;
    Widget body;
    if (widget.aspectRatio != null) {
      body = AspectRatio(
        aspectRatio: widget.aspectRatio!,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (showPlaceholder)
              Positioned.fill(child: _placeholder(shade200: shade200)),
            Positioned.fill(child: faded),
          ],
        ),
      );
    } else {
      // The web's img is `size-full` inside the wrapper, so a wrapper the
      // parent sizes is filled per `objectFit`. The default loose fit let a
      // 150x214 SizedBox lay a 792x1000 picture out at 150x189, top-left,
      // with the placeholder showing below it; measured on a Pixel 10 Pro.
      body = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          if (showPlaceholder)
            Positioned.fill(child: _placeholder(shade200: shade200)),
          faded,
        ],
      );
    }
    return _semantics(child: ClipRect(child: body));
  }
}
