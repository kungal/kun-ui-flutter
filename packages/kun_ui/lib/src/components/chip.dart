import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/control_metrics.dart';
import '../foundation/design.dart';
import '../foundation/variant_style.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';

/// A small pill — labels, status markers, taxonomy tags.
///
/// Implements the web `KunChip` contract: the variant × color matrix at chip
/// scale, optional [start] and [end] widgets (a dot, an avatar, an icon) and
/// a removable × via [closable] + [onClose]. The corner radius is always a
/// pill; unlike a card or a button, a chip takes no `rounded`.
///
/// For a dot or count overlay use `KunBadge` instead (not ported yet).
class KunChip extends StatelessWidget {
  /// Creates a chip.
  const KunChip({
    super.key,
    this.child,
    this.start,
    this.end,
    this.onClose,
    this.variant = KunUIVariant.flat,
    this.color = KunUIColor.neutral,
    this.size = KunUISize.sm,
    this.closable = false,
    this.disabled = false,
  });

  /// The label (web slot `default`).
  final Widget? child;

  /// Rendered before the label (web slot `start`).
  final Widget? start;

  /// Rendered after the close button (web slot `end`).
  final Widget? end;

  /// Called when the × is pressed (web event `close`).
  ///
  /// As everywhere in KunUI, null does not gray the chip out — only
  /// [disabled] does.
  final VoidCallback? onClose;

  /// Visual style. A chip defaults to `flat`, not `solid` like a button.
  final KunUIVariant variant;

  /// Semantic color the variant is painted in.
  final KunUIColor color;

  /// Padding and font size — the chip scale, tighter than a form control's.
  final KunUISize size;

  /// Renders the removable ×.
  final bool closable;

  /// Dims the chip and blocks the ×.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = KunTheme.of(context);
    final metrics = KunChipMetrics.of(size);
    final style = KunVariantStyle.resolve(
      scheme: theme.colors,
      brightness: theme.brightness,
      variant: variant,
      color: color,
    );

    final row = <Widget>[];
    if (start != null) row.add(start!);
    if (child != null) {
      if (row.isNotEmpty) row.add(const SizedBox(width: KunSpacing.unit));
      row.add(
        Flexible(
          child: DefaultTextStyle(
            style: metrics.textStyle.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.w500,
            ),
            softWrap: false, // web whitespace-nowrap
            overflow: TextOverflow.fade,
            child: child!,
          ),
        ),
      );
    }
    if (closable) {
      // The web's gap-1 plus the button's own ml-0.5.
      if (row.isNotEmpty) {
        row.add(const SizedBox(width: KunSpacing.unit * (1 + 0.5)));
      }
      row.add(
        _KunChipClose(
          color: style.foreground,
          semanticLabel: KunMessagesScope.of(context).chip.remove,
          onPressed: disabled ? null : onClose,
        ),
      );
    }
    if (end != null) {
      // gap-1 again, less the close button's -mr-0.5 when there is one.
      if (row.isNotEmpty) {
        row.add(SizedBox(width: KunSpacing.unit * (closable ? 1 - 0.5 : 1)));
      }
      row.add(end!);
    }

    final Widget chip = Container(
      // The close button's -mr-0.5 pulls the pill's right edge in when the ×
      // is the last child — the web's usual case.
      padding: EdgeInsets.fromLTRB(
        metrics.horizontalPadding,
        metrics.verticalPadding,
        metrics.horizontalPadding -
            (closable && end == null ? KunSpacing.unit * 0.5 : 0),
        metrics.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: style.background,
        border: Border.all(color: style.border),
        borderRadius: BorderRadius.circular(KunRadius.full),
        boxShadow: style.shadows,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: style.foreground, size: metrics.fontSize),
        child: Row(mainAxisSize: MainAxisSize.min, children: row),
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.basic, // web cursor-default
      child: disabled
          ? Opacity(
              opacity: 0.5,
              child: IgnorePointer(child: chip),
            )
          : chip,
    );
  }
}

/// The × inside a [KunChip]: 70% opacity at rest, full under the pointer or
/// keyboard focus.
class _KunChipClose extends StatefulWidget {
  const _KunChipClose({
    required this.color,
    required this.semanticLabel,
    this.onPressed,
  });

  final Color color;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  State<_KunChipClose> createState() => _KunChipCloseState();
}

class _KunChipCloseState extends State<_KunChipClose> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: widget.onPressed != null,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        // Hover through a plain MouseRegion — see button.dart for why the
        // detector's own hover callback cannot be used.
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedOpacity(
              opacity: _hovered || _focused ? 1 : 0.7,
              duration: KunDurations.fast,
              curve: KunEasing.standard,
              child: Icon(
                KunIcons.x,
                size: KunSpacing.unit * 3.5,
                color: widget.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
