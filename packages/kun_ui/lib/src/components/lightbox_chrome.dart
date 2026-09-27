part of 'lightbox.dart';

class _LightboxChrome extends StatelessWidget {
  const _LightboxChrome({
    required this.images,
    required this.index,
    required this.scale,
    required this.thumbScroll,
    required this.onClose,
    required this.onPrev,
    required this.onNext,
    required this.onGoto,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onReset,
    required this.onThumbsWheel,
  });

  final List<KunLightboxImage> images;
  final int index;
  final double scale;
  final ScrollController thumbScroll;
  final VoidCallback onClose;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onGoto;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onReset;
  final ValueChanged<PointerScrollEvent> onThumbsWheel;

  @override
  Widget build(BuildContext context) {
    final KunLightboxStrings strings = KunMessagesScope.of(context).lightbox;
    final KunThemeData theme = KunTheme.of(context);
    final bool wide = _isWide(context);
    final bool many = images.length > 1;
    // The web dialog lives inside the browser's viewport; here the route
    // covers the status and navigation bars, which hid the close button and
    // the toolbar on a phone.
    final EdgeInsets bars = MediaQuery.viewPaddingOf(context);
    return _PassThroughStack(
      children: <Widget>[
        if (many)
          Positioned(
            top: bars.top + KunSpacing.unit * 4,
            left: bars.left + KunSpacing.unit * 4,
            child: _glass(
              radius: BorderRadius.circular(KunRounded.lg),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KunSpacing.unit * 3,
                  vertical: KunSpacing.unit * 1.5,
                ),
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Text(
                    '${index + 1} / ${images.length}',
                    key: KunLightbox.counterKey,
                    style: KunText.sm.copyWith(
                      fontWeight: KunFontWeights.medium,
                      color: KunColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: bars.top + KunSpacing.unit * 4,
          right: bars.right + KunSpacing.unit * 4,
          child: _iconButton(
            size: KunUISize.lg,
            rounded: KunUIRounded.lg,
            glass: true,
            label: strings.close,
            icon: KunIcons.x,
            onPressed: onClose,
          ),
        ),
        if (many && wide) ...<Widget>[
          Positioned(
            left: bars.left + KunSpacing.unit * 4,
            top: _navTop(context),
            child: _iconButton(
              size: KunUISize.xl,
              rounded: KunUIRounded.lg,
              glass: true,
              label: strings.prev,
              icon: KunIcons.chevronLeft,
              onPressed: onPrev,
            ),
          ),
          Positioned(
            right: bars.right + KunSpacing.unit * 4,
            top: _navTop(context),
            child: _iconButton(
              size: KunUISize.xl,
              rounded: KunUIRounded.lg,
              glass: true,
              label: strings.next,
              icon: KunIcons.chevronRight,
              onPressed: onNext,
            ),
          ),
        ],
        Positioned(
          left: bars.left,
          right: bars.right,
          bottom: bars.bottom + KunSpacing.unit * 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (many)
                Padding(
                  padding: const EdgeInsets.only(bottom: KunSpacing.unit * 2),
                  child: _thumbs(context, theme, strings, wide),
                ),
              _toolbar(context, strings, theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thumbs(
    BuildContext context,
    KunThemeData theme,
    KunLightboxStrings strings,
    bool wide,
  ) {
    final double thumb = _thumbSize(wide);
    final double gap = _thumbGap(wide);
    final double pad = KunSpacing.unit * (wide ? 2 : 1.5);
    final double maxW = MediaQuery.sizeOf(context).width *
        (wide ? _thumbsMaxFractionMd : _thumbsMaxFraction);
    final int cache = (thumb * MediaQuery.devicePixelRatioOf(context)).round();
    return _glass(
      radius: BorderRadius.circular(KunRounded.xl),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Listener(
          onPointerSignal: (PointerSignalEvent event) {
            if (event is PointerScrollEvent) {
              onThumbsWheel(event);
            }
          },
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false, overscroll: false),
            child: SingleChildScrollView(
              key: KunLightbox.thumbsKey,
              controller: thumbScroll,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.all(pad),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < images.length; i++) ...<Widget>[
                    if (i > 0) SizedBox(width: gap),
                    _thumb(
                      context: context,
                      theme: theme,
                      strings: strings,
                      image: images[i],
                      i: i,
                      selected: i == index,
                      size: thumb,
                      cache: cache,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb({
    required BuildContext context,
    required KunThemeData theme,
    required KunLightboxStrings strings,
    required KunLightboxImage image,
    required int i,
    required bool selected,
    required double size,
    required int cache,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: strings.goto(index: i + 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onGoto(i),
          child: AnimatedOpacity(
            opacity: selected ? 1 : 0.6,
            duration: kunMotion(context, KunDefaultTransition.duration),
            curve: KunDefaultTransition.curve,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KunRounded.md),
                border: Border.all(
                  width: _borderWidth2,
                  color: selected
                      ? theme.colors.primary.shade500
                      : const Color.from(alpha: 0, red: 0, green: 0, blue: 0),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  KunRounded.md - _borderWidth2,
                ),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Image(
                    image: ResizeImage.resizeIfNeeded(
                      cache,
                      cache,
                      KunUIConfigScope.of(context).imageProvider(image.src),
                    ),
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    gaplessPlayback: true,
                    errorBuilder: _emptyOnError,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar(
    BuildContext context,
    KunLightboxStrings strings,
    KunThemeData theme,
  ) {
    return _glass(
      radius: BorderRadius.circular(KunRadius.full),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 2,
          vertical: KunSpacing.unit * 1.5,
        ),
        child: Row(
          key: KunLightbox.toolbarKey,
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit,
          children: <Widget>[
            _iconButton(
              size: KunUISize.lg,
              rounded: KunUIRounded.full,
              glass: false,
              label: strings.zoomOut,
              icon: KunIcons.zoomOut,
              onPressed: onZoomOut,
            ),
            Semantics(
              container: true,
              liveRegion: true,
              child: SizedBox(
                width: _zoomPercentMinWidth,
                child: Text(
                  '${(scale * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: KunText.sm.copyWith(
                    fontWeight: KunFontWeights.medium,
                    color: KunColors.white,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            ),
            _iconButton(
              size: KunUISize.lg,
              rounded: KunUIRounded.full,
              glass: false,
              label: strings.zoomIn,
              icon: KunIcons.zoomIn,
              onPressed: onZoomIn,
            ),
            _toolbarRule(theme),
            _iconButton(
              size: KunUISize.lg,
              rounded: KunUIRounded.full,
              glass: false,
              label: strings.rotateLeft,
              icon: KunIcons.rotateCcw,
              onPressed: onRotateLeft,
            ),
            _iconButton(
              size: KunUISize.lg,
              rounded: KunUIRounded.full,
              glass: false,
              label: strings.rotateRight,
              icon: KunIcons.rotateCw,
              onPressed: onRotateRight,
            ),
            _toolbarRule(theme),
            _iconButton(
              size: KunUISize.lg,
              rounded: KunUIRounded.full,
              glass: false,
              label: strings.reset,
              icon: KunIcons.refreshCcw,
              onPressed: onReset,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarRule(KunThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KunSpacing.unit),
      child: ExcludeSemantics(
        child: ColoredBox(
          color: theme.colors.neutral.shade200.withValues(alpha: 0.3),
          child: const SizedBox(width: _hairline, height: KunSpacing.unit * 5),
        ),
      ),
    );
  }

  Widget _iconButton({
    required KunUISize size,
    required KunUIRounded rounded,
    required bool glass,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final Widget button = KunButton(
      isIconOnly: true,
      color: KunUIColor.neutral,
      variant: KunUIVariant.light,
      size: size,
      rounded: rounded,
      semanticLabel: label,
      onPressed: onPressed,
      child: Icon(icon, color: KunColors.white),
    );
    if (!glass) {
      return button;
    }
    return _glass(radius: BorderRadius.circular(rounded.radius), child: button);
  }
}

double _navTop(BuildContext context) {
  final double square = KunControlMetrics.of(KunUISize.xl).square;
  return (MediaQuery.sizeOf(context).height - square) / 2;
}

class _PassThroughStack extends Stack {
  const _PassThroughStack({required super.children});

  // A Stack of only Positioned chrome is as big as the viewer. The default
  // hitTest would swallow letterbox taps and the backdrop would never close.

  @override
  RenderStack createRenderObject(BuildContext context) {
    return _RenderPassThroughStack(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
    );
  }
}

class _RenderPassThroughStack extends RenderStack {
  _RenderPassThroughStack({
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return hitTestChildren(result, position: position);
  }
}

Widget _glass({required BorderRadius radius, required Widget child}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: radius,
      border: Border.all(color: KunColors.white.withValues(alpha: 0.1)),
      boxShadow: KunShadows.lg,
    ),
    child: ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: KunBlur.md, sigmaY: KunBlur.md),
        child: ColoredBox(
          color: KunColors.black.withValues(alpha: 0.7),
          child: child,
        ),
      ),
    ),
  );
}

// excludeFromSemantics does not cover Image's debug error box: Image.build
// returns it in place of the image, exception text and all.
Widget _emptyOnError(BuildContext context, Object error, StackTrace? stack) =>
    const SizedBox.shrink();
