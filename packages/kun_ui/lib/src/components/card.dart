import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/motion.dart';
import '../foundation/outer_shadow.dart';
import '../theme/theme.dart';

/// A card's inner padding (web type `KunCardPadding`).
enum KunCardPadding {
  /// Full-bleed — no padding.
  none,

  /// 12px, the old compact value.
  sm,

  /// 20px.
  md,

  /// 24px — the default, matching KunModal.
  lg;

  /// The padding in logical pixels.
  double get value => switch (this) {
        KunCardPadding.none => 0,
        KunCardPadding.sm => KunSpacing.unit * 3,
        KunCardPadding.md => KunSpacing.unit * 5,
        KunCardPadding.lg => KunSpacing.unit * 6,
      };
}

/// A raised surface — the elevated `content1` fill over the softer page
/// background plus a small shadow, so it reads as a card even without a
/// border.
///
/// Implements the web `KunCard` contract. The web renders as a link, a button
/// or a plain div; link mode is excluded by the contract (navigation belongs
/// to the app's router), so here [clickable] alone decides whether the card
/// is interactive. [onTap] fires in both modes, matching the web's `click`
/// event, which is emitted in all three.
///
/// The web wraps the default slot in a flex column so several children get a
/// gap; a Dart [child] is one widget and composes its own column, so that
/// wrapper has no equivalent here (the web's `contentClass` is excluded for
/// the same reason).
class KunCard extends StatefulWidget {
  /// Creates a card.
  const KunCard({
    super.key,
    this.child,
    this.header,
    this.cover,
    this.footer,
    this.onTap,
    this.color,
    this.padding = KunCardPadding.lg,
    this.rounded,
    this.bordered = true,
    this.clickable = false,
    this.isHoverable = false,
    this.isTransparent = false,
  });

  /// The card's body (web slot `default`).
  final Widget? child;

  /// Rendered above everything (web slot `header`).
  final Widget? header;

  /// A full-width image or media block under the header (web slot `cover`).
  final Widget? cover;

  /// Rendered last, spaced by the card's own gap — no separator line (web
  /// slot `footer`).
  final Widget? footer;

  /// Called on tap (web event `click`).
  ///
  /// Fires whether or not the card is [clickable] — the web emits `click` in
  /// every render mode. Only the interactive *looks* follow [clickable].
  final VoidCallback? onTap;

  /// The tint. Null is the web's `background`: no tint, just the raised
  /// `content1` surface. Any other value paints a 30% tint of that color's
  /// 100 shade and deepens the border to its 300 shade.
  final KunUIColor? color;

  /// Inner padding.
  final KunCardPadding padding;

  /// Corner radius. Left null it follows [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// Draws the 1px outline. A card is raised by its shadow, so the border is
  /// an addition, not the thing that makes it a card.
  final bool bordered;

  /// Makes the card interactive: pointer cursor, press scale, hover layer,
  /// and content clipped to the corners.
  final bool clickable;

  /// Opts a non-[clickable] card into the hover layer.
  final bool isHoverable;

  /// Drops the fill and the shadow, keeping the card see-through. The border
  /// still follows [bordered].
  final bool isTransparent;

  @override
  State<KunCard> createState() => _KunCardState();
}

class _KunCardState extends State<KunCard> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _showsHoverLayer => widget.clickable || widget.isHoverable;

  @override
  Widget build(BuildContext context) {
    final theme = KunTheme.of(context);
    final scheme = theme.colors;
    final radius = BorderRadius.circular(
      (widget.rounded ?? theme.rounded).radius,
    );

    // A tinted card deepens the border to its own 300 shade (web
    // `border-{color}-300`).
    final border = widget.color == null || widget.color == KunUIColor.neutral
        ? scheme.border
        : widget.color!.scaleOf(scheme).shade300;

    final Color? fill;
    if (widget.isTransparent) {
      fill = null;
    } else if (widget.color == null) {
      fill = scheme.content1;
    } else if (widget.color == KunUIColor.neutral) {
      // Web `bg-default-100/30`: the web's default-100 already carries the
      // global opacity, so the tint is thinner than the other colors'.
      fill = scheme.neutral.shade100.withValues(
        alpha: KunColors.globalOpacity * 0.3,
      );
    } else {
      fill = widget.color!.scaleOf(scheme).shade100.withValues(alpha: 0.3);
    }

    final blocks = <Widget>[
      if (widget.header != null) widget.header!,
      if (widget.cover != null)
        SizedBox(width: double.infinity, child: widget.cover!),
      if (widget.child != null) widget.child!,
      if (widget.footer != null) widget.footer!,
    ];

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: KunSpacing.unit * 4,
      children: blocks,
    );

    if (widget.clickable) {
      content =
          ClipRRect(borderRadius: radius, child: content); // overflow-hidden
    }

    final bool tinted = fill != null && fill.a < 1;
    Widget card = Container(
      padding: EdgeInsets.all(widget.padding.value),
      decoration: BoxDecoration(
        color: fill,
        border: widget.bordered ? Border.all(color: border) : null,
        borderRadius: radius,
        boxShadow: widget.isTransparent || tinted ? null : KunShadows.sm,
      ),
      child: content,
    );
    if (tinted) {
      card = DecoratedBox(
        decoration: KunOuterShadowDecoration(
          shadows: KunShadows.sm,
          borderRadius: radius,
        ),
        child: card,
      );
    }

    if (_showsHoverLayer) {
      card = Stack(
        children: [
          card,
          // Web: an ::after state layer in `foreground` at 3% — darkens in
          // light mode, lightens in dark, with no shadow change. Its
          // `duration-kun-fast` names no ease, so the curve is the default
          // transition's, not KunEasing.standard.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _hovered ? 0.03 : 0,
                duration: kunMotion(context, KunDurations.fast),
                curve: KunDefaultTransition.curve,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.foreground,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (widget.clickable) {
      card = AnimatedScale(
        scale: _pressed ? 0.97 : 1, // web active:scale-[0.97]
        duration: kunMotion(context, KunDurations.fast),
        curve: KunDefaultTransition.curve,
        child: card,
      );
    }

    // The web's clickable card is a <button>: focusable, activated by Space
    // and Enter, and — under base.css's `*:focus { outline: none }` — drawn
    // with no focus indicator, so none is drawn here either.
    return Semantics(
      button: widget.clickable,
      child: FocusableActionDetector(
        enabled: widget.clickable,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: widget.clickable
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.clickable
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapUp: widget.clickable
                ? (_) => setState(() => _pressed = false)
                : null,
            onTapCancel: widget.clickable
                ? () => setState(() => _pressed = false)
                : null,
            onTap: widget.onTap,
            child: card,
          ),
        ),
      ),
    );
  }
}
