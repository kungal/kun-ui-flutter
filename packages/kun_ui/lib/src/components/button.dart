import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/control_metrics.dart';
import '../foundation/design.dart';
import '../foundation/variant_style.dart';
import '../theme/theme.dart';
import 'spinner.dart';

/// Which side of the label the [KunButton.icon] sits on.
enum KunIconPosition {
  /// Before the label.
  left,

  /// After the label.
  right,
}

/// The KunUI button.
///
/// Implements the web `KunButton` contract: the variant × color matrix, the
/// shared control size scale (a button lines up with an input of the same
/// [size]), [loading] with the label kept in place, and [isIconOnly] fixed
/// squares that match the text button's height.
///
/// Web props that do not cross (`href`/`target`/`rel` link mode, `type`,
/// `className`) are excluded in the contract itself; navigation belongs to
/// the app's router — wrap the button or use [onPressed].
class KunButton extends StatefulWidget {
  /// Creates a button.
  const KunButton({
    super.key,
    this.onPressed,
    this.child,
    this.icon,
    this.iconPosition = KunIconPosition.left,
    this.variant = KunUIVariant.solid,
    this.color = KunUIColor.primary,
    this.size = KunUISize.md,
    this.rounded,
    this.disabled = false,
    this.loading = false,
    this.fullWidth = false,
    this.isIconOnly = false,
    this.semanticLabel,
  });

  /// Called on tap and on keyboard activation (web event `click`).
  ///
  /// Unlike Material buttons, null does not gray the button out — the web
  /// separates looks from listeners, so the disabled look comes only from
  /// [disabled] or [loading]; a null callback merely does nothing.
  final VoidCallback? onPressed;

  /// The label (web slot `default`). For [isIconOnly], put the icon here.
  final Widget? child;

  /// Rendered beside the label (web prop `icon` + slot `icon`: passing a
  /// widget here is the web's `icon: true` with the slot filled).
  final Widget? icon;

  /// Which side of the label [icon] sits on.
  final KunIconPosition iconPosition;

  /// Visual style.
  final KunUIVariant variant;

  /// Semantic color the variant is painted in.
  final KunUIColor color;

  /// Height, padding and font size — the shared form-control scale.
  final KunUISize size;

  /// Corner radius. Left null it follows [KunThemeData.rounded] (default
  /// `md`) so every KunUI surface shares one radius.
  final KunUIRounded? rounded;

  /// Blocks presses and dims the button.
  final bool disabled;

  /// Prepends a spinner and blocks presses. The label stays in place, so a
  /// row of buttons does not reflow mid-request.
  final bool loading;

  /// Stretch to the parent's full width.
  final bool fullWidth;

  /// A fixed square sized to the same-[size] text button's height, so icon
  /// and text buttons line up in a row. Give it a [semanticLabel] — it has
  /// no text of its own.
  final bool isIconOnly;

  /// Accessible name (web `ariaLabel`). When null, assistive technology
  /// reads the [child] text.
  final String? semanticLabel;

  @override
  State<KunButton> createState() => _KunButtonState();
}

class _KunButtonState extends State<KunButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _inactive => widget.disabled || widget.loading;
  bool get _canPress => !_inactive && widget.onPressed != null;

  void _handleActivate() {
    if (!_canPress) return;
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final theme = KunTheme.of(context);
    final metrics = KunControlMetrics.of(widget.size);
    final style = KunVariantStyle.resolve(
      scheme: theme.colors,
      brightness: theme.brightness,
      variant: widget.variant,
      color: widget.color,
    );
    final radius = BorderRadius.circular(
      (widget.rounded ?? theme.rounded).radius,
    );

    final background = _hovered && style.hoverOverlay != null
        ? style.hoverOverlay!
        : style.background;

    Widget? icon = widget.icon;
    if (icon != null) {
      icon = IconTheme.merge(
        data: IconThemeData(color: style.foreground, size: metrics.fontSize),
        child: icon,
      );
    }

    final Widget content;
    if (widget.isIconOnly) {
      content = IconTheme.merge(
        data: IconThemeData(color: style.foreground, size: metrics.fontSize),
        child: widget.loading
            ? KunSpinner(size: KunText.sm.fontSize!, color: style.foreground)
            : (widget.child ?? icon ?? const SizedBox.shrink()),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: KunSpacing.unit,
        children: [
          if (widget.loading)
            KunSpinner(size: KunText.sm.fontSize!, color: style.foreground),
          if (icon != null && widget.iconPosition == KunIconPosition.left)
            Padding(
              padding: const EdgeInsets.only(right: KunSpacing.unit * 2),
              child: icon,
            ),
          Flexible(
            child: DefaultTextStyle(
              style: metrics.textStyle.copyWith(
                color: style.foreground,
                fontWeight: FontWeight.w500,
              ),
              softWrap: false, // web: a label is one atomic action, one line
              overflow: TextOverflow.fade,
              child: widget.child ?? const SizedBox.shrink(),
            ),
          ),
          if (icon != null && widget.iconPosition == KunIconPosition.right)
            Padding(
              padding: const EdgeInsets.only(left: KunSpacing.unit * 2),
              child: icon,
            ),
        ],
      );
    }

    final box = Container(
      width: widget.isIconOnly
          ? metrics.square
          : (widget.fullWidth ? double.infinity : null),
      height: widget.isIconOnly ? metrics.square : null,
      alignment:
          widget.isIconOnly || widget.fullWidth ? Alignment.center : null,
      // Every variant carries the 1px border (transparent on filled ones) so
      // switching variants never shifts the box — Container folds the border
      // into the content padding, matching the web's border-box heights.
      padding: widget.isIconOnly ? EdgeInsets.zero : metrics.padding,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: style.border),
        borderRadius: radius,
        boxShadow: style.shadows,
      ),
      child: content,
    );

    // The keyboard-focus ring: 2px in the semantic color at 50%, floated 2px
    // off the edge (web ring-offset-2 — the page shows through the gap), in
    // a Stack overlay so its appearance never shifts layout.
    final ring = widget.color.scaleOf(theme.colors).solid.withValues(
          alpha: 0.5,
        );
    final withRing = Stack(
      clipBehavior: Clip.none,
      children: [
        box,
        if (_focused)
          Positioned(
            left: -4,
            top: -4,
            right: -4,
            bottom: -4,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: ring, width: 2),
                  borderRadius: BorderRadius.circular(
                    (widget.rounded ?? theme.rounded).radius + 4,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      enabled: !_inactive,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _canPress,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _handleActivate();
              return null;
            },
          ),
          // Flutter web binds Enter to ButtonActivateIntent alone, so with
          // only ActivateIntent a focused button ignored Enter in a browser.
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              _handleActivate();
              return null;
            },
          ),
        },
        // Hover through a plain MouseRegion, NOT the detector's
        // onShowHoverHighlight: that callback is gated on the focus highlight
        // mode (suppressed entirely under touch), while the web's `:hover`
        // has no such coupling — a touch device simply never hovers.
        child: MouseRegion(
          cursor: _inactive
              ? SystemMouseCursors.forbidden
              : (_canPress ? SystemMouseCursors.click : MouseCursor.defer),
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown:
                _canPress ? (_) => setState(() => _pressed = true) : null,
            onTapUp: _canPress ? (_) => setState(() => _pressed = false) : null,
            onTapCancel:
                _canPress ? () => setState(() => _pressed = false) : null,
            onTap: _canPress ? _handleActivate : null,
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1, // web active:scale-[0.97]
              duration: KunDefaultTransition.duration,
              curve: KunDefaultTransition.curve,
              child: AnimatedOpacity(
                // Web: hover:opacity-80 on every variant; disabled/loading
                // opacity-50.
                opacity: _inactive ? 0.5 : (_hovered ? 0.8 : 1),
                duration: KunDefaultTransition.duration,
                curve: KunDefaultTransition.curve,
                child: withRing,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
