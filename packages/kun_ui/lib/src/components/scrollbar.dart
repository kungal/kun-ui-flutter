import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../theme/theme.dart';

// The web's `.kun-scroll-thin::-webkit-scrollbar { width: 8px }`.
const double _kThickness = 8;

/// The web's thin KunUI scrollbar (`KunScrollShadow`'s `scrollbar="thin"`,
/// the `kun-scroll-thin` class).
///
/// A fully rounded 8px thumb in the neutral 300 shade, 400 while the pointer
/// is over it or dragging it, with no track. Visibility, fading and dragging
/// are [RawScrollbar]'s.
class KunScrollbar extends RawScrollbar {
  /// Creates a thin KunUI scrollbar around [child].
  const KunScrollbar({
    super.key,
    required super.child,
    super.controller,
    super.thumbVisibility,
    super.interactive,
    super.notificationPredicate,
    super.scrollbarOrientation,
  }) : super(
          thickness: _kThickness,
          radius: const Radius.circular(_kThickness / 2),
        );

  @override
  RawScrollbarState<KunScrollbar> createState() => _KunScrollbarState();
}

class _KunScrollbarState extends RawScrollbarState<KunScrollbar> {
  bool _hovered = false;
  bool _dragged = false;

  @override
  void updateScrollbarPainter() {
    super.updateScrollbarPainter();
    final KunColorScheme scheme = KunTheme.of(context).colors;
    scrollbarPainter.color = _hovered || _dragged
        ? scheme.neutral.shade400
        : scheme.neutral.shade300;
  }

  @override
  void handleThumbPressStart(Offset localPosition) {
    super.handleThumbPressStart(localPosition);
    setState(() => _dragged = true);
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    super.handleThumbPressEnd(localPosition, velocity);
    setState(() => _dragged = false);
  }

  @override
  void handleHover(PointerHoverEvent event) {
    super.handleHover(event);
    final bool over = isPointerOverThumb(event.position, event.kind);
    if (over != _hovered) {
      setState(() => _hovered = over);
    }
  }

  @override
  void handleHoverExit(PointerExitEvent event) {
    super.handleHoverExit(event);
    if (_hovered) {
      setState(() => _hovered = false);
    }
  }
}
