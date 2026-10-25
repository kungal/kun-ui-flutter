import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../theme/theme.dart';
import 'motion.dart';
import 'outer_shadow.dart';

/// The floating chevron `KunTab` and `KunScrollShadow` put on an edge that
/// can still scroll (web internal `KunScrollEdgeButton`).
///
/// A redundant affordance: swipe, wheel and keyboard scroll as well, so it
/// stays out of the semantics tree and the focus order. Place it in a
/// [Stack]; it positions itself on its side, centred across the strip.
/// Not a supported public API.
class KunScrollEdgeButton extends StatefulWidget {
  /// Creates the chevron on the physical [left] or right edge.
  const KunScrollEdgeButton({
    super.key,
    required this.left,
    required this.onPressed,
    this.buttonKey,
  });

  /// Whether it sits on the left edge and points left.
  final bool left;

  /// Scrolls the strip by a step.
  final VoidCallback onPressed;

  /// Key on the tap target, for tests.
  final Key? buttonKey;

  @override
  State<KunScrollEdgeButton> createState() => _KunScrollEdgeButtonState();
}

class _KunScrollEdgeButtonState extends State<KunScrollEdgeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final bool left = widget.left;
    final Duration duration = kunMotion(
      context,
      KunDefaultTransition.duration,
    );
    final double iconSize =
        DefaultTextStyle.of(context).style.fontSize ?? KunText.base.fontSize!;
    return Positioned(
      left: left ? KunSpacing.unit * 0.5 : null,
      right: left ? null : KunSpacing.unit * 0.5,
      top: 0,
      bottom: 0,
      child: ExcludeSemantics(
        child: Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              key: widget.buttonKey,
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: AnimatedOpacity(
                opacity: _hovered ? 1 : 0.8,
                duration: duration,
                curve: KunDefaultTransition.curve,
                child: DecoratedBox(
                  decoration: const KunOuterShadowDecoration(
                    shadows: KunShadows.sm,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: KunBlur.sm,
                        sigmaY: KunBlur.sm,
                      ),
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(
                          end: _hovered
                              ? scheme.foreground
                              : scheme.neutral.shade600,
                        ),
                        duration: duration,
                        curve: KunDefaultTransition.curve,
                        builder: (
                          BuildContext context,
                          Color? color,
                          Widget? child,
                        ) {
                          return Container(
                            width: KunSpacing.unit * 7,
                            height: KunSpacing.unit * 7,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.background.withValues(
                                alpha: KunColors.globalOpacity * 0.8,
                              ),
                              border: Border.all(color: scheme.border),
                            ),
                            child: Icon(
                              left
                                  ? KunIcons.chevronLeft
                                  : KunIcons.chevronRight,
                              size: iconSize,
                              color: color ?? scheme.neutral.shade600,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
