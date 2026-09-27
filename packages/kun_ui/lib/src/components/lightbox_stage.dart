part of 'lightbox.dart';

enum _SlideDir { next, prev }

@immutable
class _ViewXform {
  const _ViewXform({
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
  });

  static const _ViewXform identity = _ViewXform(
    x: 0,
    y: 0,
    scale: _minScale,
    rotation: 0,
  );

  final double x;
  final double y;
  final double scale;
  final double rotation;

  _ViewXform copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) =>
      _ViewXform(
        x: x ?? this.x,
        y: y ?? this.y,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
      );

  @override
  bool operator ==(Object other) =>
      other is _ViewXform &&
      other.x == x &&
      other.y == y &&
      other.scale == scale &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(x, y, scale, rotation);
}

class _ViewXformTween extends Tween<_ViewXform> {
  _ViewXformTween({super.end});

  @override
  _ViewXform lerp(double t) {
    final _ViewXform a = begin ?? end ?? _ViewXform.identity;
    final _ViewXform b = end ?? begin ?? _ViewXform.identity;
    return _ViewXform(
      x: a.x + (b.x - a.x) * t,
      y: a.y + (b.y - a.y) * t,
      scale: a.scale + (b.scale - a.scale) * t,
      rotation: a.rotation + (b.rotation - a.rotation) * t,
    );
  }
}

class _LightboxViewer extends StatefulWidget {
  const _LightboxViewer({required this.session});

  final _KunLightboxSession session;

  @override
  State<_LightboxViewer> createState() => _LightboxViewerState();
}

class _LightboxViewerState extends State<_LightboxViewer>
    with TickerProviderStateMixin {
  final GlobalKey _stageKey = GlobalKey();
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _transformKey = GlobalKey();
  final ScrollController _thumbScroll = ScrollController();
  final Map<int, Offset> _pointers = <int, Offset>{};

  late int _index;
  late int _sessionInitial;
  _ViewXform _xform = _ViewXform.identity;
  _SlideDir _slideDir = _SlideDir.next;
  int? _outgoingIndex;
  late final AnimationController _slide;

  bool _dragging = false;
  bool _pinching = false;
  bool _pointerMoved = false;
  Offset _dragStart = Offset.zero;
  Offset _initialDrag = Offset.zero;
  DateTime _dragStartTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTouchTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
  Offset _lastTap = Offset.zero;
  double _lastTouchDistance = 0;
  Offset _lastPinchCenter = Offset.zero;

  _KunLightboxSession get session => widget.session;

  List<KunLightboxImage> get _images => session.images;

  @override
  void initState() {
    super.initState();
    _sessionInitial = session.initialIndex;
    _index = _clampIndex(session.initialIndex, _images.length);
    _slide = AnimationController(
      vsync: this,
      duration: Duration.zero,
      value: 1,
    );
    session.prev = _prev;
    session.next = _next;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerThumb(false));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slide.duration = kunMotion(context, KunDurations.slow);
  }

  @override
  void didUpdateWidget(covariant _LightboxViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    session.prev = _prev;
    session.next = _next;
    if (session.initialIndex != _sessionInitial) {
      _sessionInitial = session.initialIndex;
      _index = _clampIndex(session.initialIndex, _images.length);
      _resetXform();
      _centerThumb(false);
    } else if (_images.isNotEmpty && _index >= _images.length) {
      _index = _images.length - 1;
    }
  }

  @override
  void dispose() {
    if (session.prev == _prev) {
      session.prev = null;
    }
    if (session.next == _next) {
      session.next = null;
    }
    _slide.dispose();
    _thumbScroll.dispose();
    super.dispose();
  }

  int _clampIndex(int index, int length) {
    if (length <= 0) {
      return 0;
    }
    return index.clamp(0, length - 1);
  }

  void _resetXform() {
    _xform = _ViewXform(
      x: 0,
      y: 0,
      scale: _minScale,
      rotation: (_xform.rotation / 360).round() * 360.0,
    );
  }

  _ViewXform _constrain(_ViewXform next) {
    if (next.scale <= _minScale) {
      return next.copyWith(x: 0, y: 0);
    }
    final RenderBox? stage = _stageBox();
    final RenderBox? image = _imageBox();
    if (stage == null || image == null) {
      return next;
    }
    final double scaledW = image.size.width * next.scale;
    final double scaledH = image.size.height * next.scale;
    final double maxX = math.max(0, (scaledW - stage.size.width) / 2);
    final double maxY = math.max(0, (scaledH - stage.size.height) / 2);
    return next.copyWith(
      x: next.x.clamp(-maxX, maxX),
      y: next.y.clamp(-maxY, maxY),
    );
  }

  RenderBox? _stageBox() {
    final RenderObject? object = _stageKey.currentContext?.findRenderObject();
    if (object is RenderBox && object.hasSize) {
      return object;
    }
    return null;
  }

  RenderBox? _imageBox() {
    final RenderObject? object = _imageKey.currentContext?.findRenderObject();
    if (object is RenderBox && object.hasSize) {
      return object;
    }
    return null;
  }

  bool _hitImage(Offset global) {
    final RenderBox? image = _imageBox();
    if (image == null || !image.hasSize || image.size.isEmpty) {
      return false;
    }
    return (Offset.zero & image.size).contains(image.globalToLocal(global));
  }

  bool _isGhostMouse(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse) {
      return false;
    }
    return DateTime.now().difference(_lastTouchTime).inMilliseconds <
        _ghostMouseMs;
  }

  void _markTouch() {
    _lastTouchTime = DateTime.now();
  }

  void _prev() {
    if (_images.length <= 1) {
      return;
    }
    _goTo((_index - 1 + _images.length) % _images.length, _SlideDir.prev);
  }

  void _next() {
    if (_images.length <= 1) {
      return;
    }
    _goTo((_index + 1) % _images.length, _SlideDir.next);
  }

  void _goTo(int next, _SlideDir dir, {bool animate = true}) {
    if (next == _index || next < 0 || next >= _images.length) {
      return;
    }
    setState(() {
      _outgoingIndex = _index;
      _index = next;
      _slideDir = dir;
      _resetXform();
    });
    _centerThumb(animate);
    if (!animate || kunReducedMotion(context)) {
      _slide.value = 1;
      setState(() => _outgoingIndex = null);
      return;
    }
    unawaited(
      _slide.forward(from: 0).whenComplete(() {
        if (mounted) {
          setState(() => _outgoingIndex = null);
        }
      }),
    );
  }

  void _centerThumb(bool animate) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_thumbScroll.hasClients) {
        return;
      }
      final bool wide = _isWide(context);
      final double thumb = _thumbSize(wide);
      final double gap = _thumbGap(wide);
      final double viewport = _thumbScroll.position.viewportDimension;
      final double target = _index * (thumb + gap) - (viewport - thumb) / 2;
      final double clamped = target.clamp(
        _thumbScroll.position.minScrollExtent,
        _thumbScroll.position.maxScrollExtent,
      );
      if (animate && !kunReducedMotion(context)) {
        unawaited(
          _thumbScroll.animateTo(
            clamped,
            duration: kunMotion(context, KunDurations.base),
            curve: KunEasing.standard,
          ),
        );
      } else {
        _thumbScroll.jumpTo(clamped);
      }
    });
  }

  void _zoomBy(double delta) {
    final double next = (_xform.scale + delta).clamp(_minScale, _maxScale);
    if (next == _xform.scale) {
      return;
    }
    setState(() => _xform = _constrain(_xform.copyWith(scale: next)));
  }

  void _rotateBy(double degrees) {
    setState(
      () => _xform = _xform.copyWith(rotation: _xform.rotation + degrees),
    );
  }

  void _onReset() {
    setState(_resetXform);
  }

  void _doubleTapAt(Offset global) {
    final RenderBox? stage = _stageBox();
    if (stage == null) {
      return;
    }
    if (_xform.scale > _minScale) {
      setState(_resetXform);
      return;
    }
    final Offset local = stage.globalToLocal(global);
    setState(() {
      _xform = _constrain(
        _ViewXform(
          x: local.dx - stage.size.width / 2,
          y: local.dy - stage.size.height / 2,
          scale: 2,
          rotation: _xform.rotation,
        ),
      );
    });
  }

  void _startDrag(Offset global) {
    _dragging = true;
    _pointerMoved = false;
    _dragStartTime = DateTime.now();
    _dragStart = Offset(global.dx - _xform.x, global.dy - _xform.y);
    _initialDrag = global;
  }

  void _onDrag(Offset global) {
    if (!_dragging) {
      return;
    }
    if ((global.dx - _initialDrag.dx).abs() > _dragMovePx ||
        (global.dy - _initialDrag.dy).abs() > _dragMovePx) {
      _pointerMoved = true;
    }
    if (_xform.scale <= _minScale) {
      setState(() {
        _xform = _xform.copyWith(x: global.dx - _initialDrag.dx, y: 0);
      });
      return;
    }
    setState(() {
      _xform = _constrain(
        _xform.copyWith(
          x: global.dx - _dragStart.dx,
          y: global.dy - _dragStart.dy,
        ),
      );
    });
  }

  void _stopDrag(Offset global) {
    if (!_dragging) {
      return;
    }
    final double deltaX = global.dx - _initialDrag.dx;
    final int deltaMs = math.max(
      1,
      DateTime.now().difference(_dragStartTime).inMilliseconds,
    );
    final double velocity = deltaX.abs() / deltaMs;
    if (_xform.scale <= _minScale &&
        deltaX.abs() > _swipeThreshold &&
        velocity > _swipeVelocityPxPerMs) {
      if (deltaX > 0) {
        _prev();
      } else {
        _next();
      }
      setState(() => _xform = _xform.copyWith(x: 0, y: 0));
    } else if (_xform.scale <= _minScale) {
      setState(() => _xform = _xform.copyWith(x: 0, y: 0));
    }
    _dragging = false;
  }

  void _considerTap(Offset global) {
    final double moved = math.max(
      (global.dx - _initialDrag.dx).abs(),
      (global.dy - _initialDrag.dy).abs(),
    );
    if (moved > _doubleTapPx) {
      _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
      return;
    }
    final DateTime now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < _doubleTapMs &&
        (global.dx - _lastTap.dx).abs() < _doubleTapPx &&
        (global.dy - _lastTap.dy).abs() < _doubleTapPx) {
      _doubleTapAt(global);
      _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
    } else {
      _lastTapTime = now;
      _lastTap = global;
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.stylus) {
      _markTouch();
    } else if (_isGhostMouse(event)) {
      return;
    }
    if (event.buttons != 0 && event.buttons & kPrimaryButton == 0) {
      return;
    }
    _pointers[event.pointer] = event.position;
    if (_pointers.length >= 2) {
      _dragging = false;
      _pinching = true;
      final List<Offset> points = _pointers.values.toList();
      _lastTouchDistance = (points[0] - points[1]).distance;
      _lastPinchCenter = Offset(
        (points[0].dx + points[1].dx) / 2,
        (points[0].dy + points[1].dy) / 2,
      );
    } else if (_pointers.length == 1 && !_pinching) {
      _startDrag(event.position);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.stylus) {
      _markTouch();
    } else if (_isGhostMouse(event)) {
      return;
    }
    if (!_pointers.containsKey(event.pointer)) {
      return;
    }
    _pointers[event.pointer] = event.position;
    if (_pointers.length >= 2 && _pinching) {
      _onPinch();
    } else if (_pointers.length == 1 && _dragging) {
      _onDrag(event.position);
    }
  }

  void _onPinch() {
    final List<Offset> points = _pointers.values.toList();
    if (points.length < 2) {
      return;
    }
    final double distance = (points[0] - points[1]).distance;
    final Offset center = Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
    final double ratio =
        distance / (_lastTouchDistance == 0 ? 1 : _lastTouchDistance);
    final double next = (_xform.scale * ratio).clamp(_minScale, _maxScale);
    final RenderBox? stage = _stageBox();
    if (stage != null) {
      final Offset local = stage.globalToLocal(center);
      final double ax = local.dx - stage.size.width / 2;
      final double ay = local.dy - stage.size.height / 2;
      final double sc = next / _xform.scale;
      final double zoomedX = ax - (ax - _xform.x) * sc;
      final double zoomedY = ay - (ay - _xform.y) * sc;
      final double dx = center.dx - _lastPinchCenter.dx;
      final double dy = center.dy - _lastPinchCenter.dy;
      setState(() {
        _xform = _constrain(
          _xform.copyWith(scale: next, x: zoomedX + dx, y: zoomedY + dy),
        );
      });
    } else {
      setState(() => _xform = _xform.copyWith(scale: next));
    }
    _lastTouchDistance = distance;
    _lastPinchCenter = center;
  }

  void _onPointerUp(PointerUpEvent event) => _finishPointer(event);

  void _onPointerCancel(PointerCancelEvent event) => _finishPointer(event);

  void _finishPointer(PointerEvent event) {
    if (event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.stylus) {
      _markTouch();
    } else if (_isGhostMouse(event)) {
      _pointers.remove(event.pointer);
      return;
    }
    _pointers.remove(event.pointer);
    if (_pinching) {
      if (_pointers.length >= 2) {
        return;
      }
      _pinching = false;
      if (_pointers.length == 1) {
        final Offset point = _pointers.values.first;
        _startDrag(point);
      }
      return;
    }
    final Offset up = event.position;
    _stopDrag(up);
    if (_pointers.isNotEmpty) {
      return;
    }
    _considerTap(up);
    if (!_pointerMoved && !_hitImage(up)) {
      session.dismiss();
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    final RenderBox? stage = _stageBox();
    if (stage == null) {
      return;
    }
    final double delta = -event.scrollDelta.dy;
    if (delta == 0) {
      return;
    }
    final double next =
        (_xform.scale + (delta > 0 ? _wheelZoomFactor : -_wheelZoomFactor))
            .clamp(_minScale, _maxScale);
    if (next == _xform.scale) {
      return;
    }
    final Offset local = stage.globalToLocal(event.position);
    final double change = next / _xform.scale;
    setState(() {
      _xform = _constrain(
        _xform.copyWith(
          scale: next,
          x: local.dx - (local.dx - _xform.x) * change,
          y: local.dy - (local.dy - _xform.y) * change,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<KunLightboxImage> images = _images;
    final KunLightboxImage? current =
        images.isEmpty ? null : images[_index.clamp(0, images.length - 1)];
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Listener(
          key: KunLightbox.stageKey,
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          onPointerSignal: _onPointerSignal,
          child: KeyedSubtree(
            key: _stageKey,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (_outgoingIndex != null &&
                    _outgoingIndex! >= 0 &&
                    _outgoingIndex! < images.length)
                  _slideLayer(
                    index: _outgoingIndex!,
                    incoming: false,
                    image: images[_outgoingIndex!],
                  ),
                if (current != null)
                  _slideLayer(index: _index, incoming: true, image: current),
              ],
            ),
          ),
        ),
        _LightboxChrome(
          images: images,
          index: _index,
          scale: _xform.scale,
          thumbScroll: _thumbScroll,
          onClose: session.dismiss,
          onPrev: _prev,
          onNext: _next,
          onGoto: (int i) =>
              _goTo(i, i > _index ? _SlideDir.next : _SlideDir.prev),
          onZoomIn: () => _zoomBy(_zoomStep),
          onZoomOut: () => _zoomBy(-_zoomStep),
          onRotateLeft: () => _rotateBy(-90),
          onRotateRight: () => _rotateBy(90),
          onReset: _onReset,
          onThumbsWheel: _onThumbsWheel,
        ),
      ],
    );
  }

  void _onThumbsWheel(PointerScrollEvent event) {
    if (!_thumbScroll.hasClients) {
      return;
    }
    final ScrollPosition position = _thumbScroll.position;
    final double max = position.maxScrollExtent;
    if (max <= 0) {
      return;
    }
    final double delta =
        event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
    if (delta == 0) {
      return;
    }
    final double from = position.pixels;
    if ((delta < 0 && from <= 0) || (delta > 0 && from >= max - 1)) {
      return;
    }
    _thumbScroll.jumpTo((from + delta).clamp(0, max));
  }

  Widget _slideLayer({
    required int index,
    required bool incoming,
    required KunLightboxImage image,
  }) {
    final bool reduce = kunReducedMotion(context);
    final Animation<double> t = reduce
        ? const AlwaysStoppedAnimation<double>(1)
        : CurvedAnimation(parent: _slide, curve: KunDefaultTransition.curve);
    final bool next = _slideDir == _SlideDir.next;
    final Offset enterFrom = next ? const Offset(1, 0) : const Offset(-1, 0);
    final Offset leaveTo = next ? const Offset(-1, 0) : const Offset(1, 0);
    return AnimatedBuilder(
      animation: t,
      builder: (BuildContext context, Widget? child) {
        final double v = t.value;
        final Offset offset;
        final double opacity;
        if (incoming) {
          offset = Offset.lerp(enterFrom, Offset.zero, v)!;
          opacity = v;
        } else {
          offset = Offset.lerp(Offset.zero, leaveTo, v)!;
          opacity = 1 - v;
        }
        return FractionalTranslation(
          translation: offset,
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Center(child: _photo(image, interactive: incoming)),
    );
  }

  Widget _photo(KunLightboxImage image, {required bool interactive}) {
    final Widget photo = _FittedPhoto(src: image.src, alt: image.alt);
    if (!interactive) {
      return photo;
    }
    final Duration duration = (_dragging || _pinching)
        ? Duration.zero
        : kunMotion(context, _transformDuration);
    return TweenAnimationBuilder<_ViewXform>(
      duration: duration,
      curve: _transformEase,
      tween: _ViewXformTween(end: _xform),
      builder: (BuildContext context, _ViewXform value, Widget? child) {
        return KeyedSubtree(
          key: KunLightbox.imageTransformKey,
          child: Transform(
            key: _transformKey,
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(value.x, value.y, 0, 1)
              ..scaleByDouble(value.scale, value.scale, value.scale, 1)
              ..rotateZ(value.rotation * math.pi / 180),
            child: KeyedSubtree(key: _imageKey, child: child!),
          ),
        );
      },
      child: photo,
    );
  }
}

class _FittedPhoto extends StatefulWidget {
  const _FittedPhoto({required this.src, this.alt});

  final String src;
  final String? alt;

  @override
  State<_FittedPhoto> createState() => _FittedPhotoState();
}

class _FittedPhotoState extends State<_FittedPhoto> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
  }

  @override
  void didUpdateWidget(covariant _FittedPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      _listen();
    }
  }

  @override
  void dispose() {
    _unlisten();
    _info?.dispose();
    super.dispose();
  }

  ImageProvider _provider() {
    return KunUIConfigScope.of(context).imageProvider(widget.src);
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
    if (widget.src.isEmpty) {
      _unlisten();
      _info?.dispose();
      _info = null;
      return;
    }
    final ImageStream stream = _provider().resolve(
      createLocalImageConfiguration(context),
    );
    if (identical(stream, _stream) && _listener != null) {
      return;
    }
    _unlisten();
    _stream = stream;
    _listener = ImageStreamListener(_onImage, onError: _onError);
    stream.addListener(_listener!);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    _info?.dispose();
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() => _info = info);
  }

  void _onError(Object error, StackTrace? stackTrace) {
    if (!mounted) {
      return;
    }
    setState(() {
      _info?.dispose();
      _info = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ImageInfo? info = _info;
    final Widget photo;
    if (info == null) {
      photo = const SizedBox.shrink();
    } else {
      photo = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size intrinsic = Size(
            info.image.width / info.scale,
            info.image.height / info.scale,
          );
          final Size box = _containSize(intrinsic, constraints.biggest);
          return SizedBox(
            width: box.width,
            height: box.height,
            child: RawImage(
              image: info.image,
              scale: info.scale,
              fit: BoxFit.fill,
            ),
          );
        },
      );
    }
    if (widget.alt == '') {
      return ExcludeSemantics(child: photo);
    }
    return Semantics(
      image: true,
      label: widget.alt,
      excludeSemantics: true,
      child: photo,
    );
  }
}

Size _containSize(Size child, Size max) {
  if (child.width <= 0 ||
      child.height <= 0 ||
      max.width <= 0 ||
      max.height <= 0) {
    return Size.zero;
  }
  // The web class is `max-h-full max-w-full`: a small image stays at its
  // intrinsic size. Scaling up here made a 1×1 MemoryImage fill the stage.
  if (child.width <= max.width && child.height <= max.height) {
    return child;
  }
  final double scale = math.min(
    max.width / child.width,
    max.height / child.height,
  );
  return Size(child.width * scale, child.height * scale);
}

bool _isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= KunTheme.of(context).breakpoints.md;

double _thumbSize(bool wide) => KunSpacing.unit * (wide ? 14 : 12);

double _thumbGap(bool wide) => KunSpacing.unit * (wide ? 1.5 : 1);
