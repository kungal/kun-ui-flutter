import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/anchored.dart';
import '../foundation/design.dart';
import '../foundation/dismiss_layers.dart';
import '../foundation/motion.dart';
import '../theme/theme.dart';

/// Which side of its trigger a [KunTooltip] sits on.
enum KunTooltipPosition {
  /// Above the trigger.
  top,

  /// To the right of the trigger.
  right,

  /// Below the trigger.
  bottom,

  /// To the left of the trigger.
  left;

  KunAnchorSide get _side => switch (this) {
        KunTooltipPosition.top => KunAnchorSide.top,
        KunTooltipPosition.right => KunAnchorSide.right,
        KunTooltipPosition.bottom => KunAnchorSide.bottom,
        KunTooltipPosition.left => KunAnchorSide.left,
      };
}

/// A hint that appears while its trigger is hovered or focused.
///
/// The panel is an overlay child anchored to the trigger, not a route — the
/// same portal the other KunUI popups use, so it paints above the page while
/// inheriting the trigger's theme, language and focus scope.
///
/// A tooltip is pointer-and-keyboard affordance: it opens on hover and on
/// focus, and there is no touch gesture that opens it. The web hides it
/// outright below the `sm` breakpoint ([hideOnMobile]), which this port
/// mirrors against [KunThemeData.breakpoints].
class KunTooltip extends StatefulWidget {
  /// Creates a tooltip around [child].
  const KunTooltip({
    required this.child,
    this.text = '',
    this.content,
    this.position = KunTooltipPosition.top,
    this.delayShow = const Duration(milliseconds: 100),
    this.delayHide = Duration.zero,
    this.hideOnMobile = true,
    this.rounded,
    this.showArrow = false,
    super.key,
  });

  /// The trigger. It keeps its own semantics; the tooltip only describes it.
  final Widget child;

  /// The hint, and the description assistive technology reads on [child].
  final String text;

  /// Replaces [text] in the panel, the web's `content` slot. Assistive
  /// technology still reads [text], so set both when the panel is a widget.
  final Widget? content;

  /// Which side of the trigger the panel sits on. It flips to the opposite
  /// side when there is no room.
  final KunTooltipPosition position;

  /// How long the pointer or the focus must rest before the panel appears.
  /// The web's `delayShow`, 100ms.
  final Duration delayShow;

  /// How long the panel lingers after the pointer or focus leaves. The web's
  /// `delayHide`, zero.
  final Duration delayHide;

  /// Whether to suppress the tooltip entirely on a view narrower than the
  /// `sm` breakpoint, as the web's `hidden sm:block` does.
  final bool hideOnMobile;

  /// Corner rounding; defaults to [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// Whether to draw a caret pointing at the trigger.
  final bool showArrow;

  @override
  State<KunTooltip> createState() => _KunTooltipState();
}

class _KunTooltipState extends State<KunTooltip>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  late final AnimationController _fade;
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _visible = false;
  final ValueNotifier<KunAnchorResolution> _resolved =
      ValueNotifier<KunAnchorResolution>(
    const KunAnchorResolution(side: KunAnchorSide.top, arrowCross: 0),
  );

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: KunDurations.base,
      reverseDuration: KunDurations.exit,
    );
    _fade.addStatusListener(_hidePortalIfDismissed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fade.duration = kunMotion(context, KunDurations.base);
    _fade.reverseDuration = kunMotion(context, KunDurations.exit);
  }

  @override
  void dispose() {
    KunDismissLayers.remove(this);
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _fade.removeStatusListener(_hidePortalIfDismissed);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _fade.dispose();
    _resolved.dispose();
    super.dispose();
  }

  void _hidePortalIfDismissed(AnimationStatus status) {
    if (!_visible && _fade.value == 0 && _portal.isShowing) {
      _portal.hide();
    }
  }

  bool get _suppressed {
    if (!widget.hideOnMobile) {
      return false;
    }
    return MediaQuery.sizeOf(context).width <
        KunTheme.of(context).breakpoints.sm;
  }

  void _clearTimers() {
    _showTimer?.cancel();
    _showTimer = null;
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _show() {
    _clearTimers();
    if (_suppressed || _visible) {
      return;
    }
    if (widget.delayShow > Duration.zero) {
      _showTimer = Timer(widget.delayShow, _showNow);
    } else {
      _showNow();
    }
  }

  void _showNow() {
    _showTimer = null;
    if (!mounted || _visible) {
      return;
    }
    KunDismissLayers.add(this);
    setState(() => _visible = true);
    _portal.show();
    _fade.forward();
  }

  void _hide() {
    _clearTimers();
    if (!_visible) {
      return;
    }
    if (widget.delayHide > Duration.zero) {
      _hideTimer = Timer(widget.delayHide, _hideNow);
    } else {
      _hideNow();
    }
  }

  void _hideNow() {
    _hideTimer = null;
    if (!mounted || !_visible) {
      return;
    }
    KunDismissLayers.remove(this);
    setState(() => _visible = false);
    _fade.reverse();
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _visible) {
      _hide();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunUIRounded rounded = widget.rounded ?? theme.rounded;
    final Rect anchor = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );

    final Widget panel = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: KunContainerWidths.xs),
          child: DecoratedBox(
            key: const ValueKey<String>('KunTooltip.panel'),
            decoration: BoxDecoration(
              color: scheme.content1,
              borderRadius: BorderRadius.circular(rounded.radius),
              boxShadow: KunShadows.md,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KunSpacing.unit * 3,
                vertical: KunSpacing.unit * 2,
              ),
              child: DefaultTextStyle.merge(
                style: KunText.sm.copyWith(
                  color: scheme.foreground,
                  fontWeight: KunFontWeights.medium,
                ),
                child: widget.content ?? Text(widget.text),
              ),
            ),
          ),
        ),
        if (widget.showArrow)
          ValueListenableBuilder<KunAnchorResolution>(
            valueListenable: _resolved,
            builder: (BuildContext context, KunAnchorResolution resolved, _) =>
                KunAnchorArrow(
              side: resolved.side,
              cross: resolved.arrowCross,
              color: scheme.content1,
            ),
          ),
      ],
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: CustomSingleChildLayout(
            delegate: KunAnchoredLayout(
              anchor: anchor,
              viewport: kunAnchorViewport(context, info.overlaySize),
              side: widget.position._side,
              align: KunAnchorAlign.center,
              arrowSize: widget.showArrow ? kKunArrowSize : 0,
              onResolved: _onResolved,
            ),
            child: FadeTransition(opacity: _fade, child: panel),
          ),
        ),
      ),
    );
  }

  void _onResolved(KunAnchorResolution resolution) {
    if (_resolved.value == resolution) {
      return;
    }
    // This runs inside layout, where notifying a listener would rebuild
    // mid-layout, so the placement reaches the caret on the next frame. The
    // panel's first frame paints at opacity 0, so the frame drawn from the
    // default placement is never seen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resolved.value = resolution;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget trigger = widget.text.isEmpty
        ? widget.child
        : MergeSemantics(
            child: Semantics(tooltip: widget.text, child: widget.child),
          );
    return PopScope(
      canPop: !_visible,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && KunDismissLayers.isTop(this)) {
          _hideNow();
        }
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: (FocusNode node, KeyEvent event) => _onKey(event),
        onFocusChange: (bool focused) => focused ? _show() : _hide(),
        child: MouseRegion(
          onEnter: (_) => _show(),
          onExit: (_) => _hide(),
          child: OverlayPortal.overlayChildLayoutBuilder(
            controller: _portal,
            overlayLocation: OverlayChildLocation.rootOverlay,
            overlayChildBuilder: _buildOverlay,
            child: trigger,
          ),
        ),
      ),
    );
  }
}
