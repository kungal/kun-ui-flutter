import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/field_ring.dart';
import '../foundation/motion.dart';
import '../foundation/selection_metrics.dart';
import '../theme/theme.dart';

/// What shape a [KunCheckBox]'s box takes.
enum KunCheckBoxType {
  /// A rounded square — one of several choices.
  multiple,

  /// A circle, for a checkbox standing in for a single choice.
  single,
}

/// A checkbox, with an optional label, helper text and error.
///
/// [indeterminate] is the "some but not all" state a select-all parent shows.
/// It is visual only, exactly as on the web: the box draws a dash instead of
/// a check while [value] stays as it is, and a toggle clears it by reporting
/// the new [value] to [onChanged].
class KunCheckBox extends StatefulWidget {
  /// Creates a checkbox.
  const KunCheckBox({
    this.value = false,
    this.onChanged,
    this.label,
    this.child,
    this.color = KunUIColor.neutral,
    this.size = KunUISize.md,
    this.type = KunCheckBoxType.multiple,
    this.indeterminate = false,
    this.disabled = false,
    this.description,
    this.error,
    super.key,
  });

  /// Whether the box is checked.
  final bool value;

  /// Called with the new state on a toggle. A null callback leaves the
  /// checkbox inert without greying it out — use [disabled] for that.
  final ValueChanged<bool>? onChanged;

  /// The text beside the box. It is part of the tap target, as the web's
  /// `<label for>` is.
  final String? label;

  /// A widget between the box and [label], the web's default slot.
  final Widget? child;

  /// The checked fill's hue.
  final KunUIColor color;

  /// The box, glyph and label scale, shared with the radio group.
  final KunUISize size;

  /// Whether the box is a rounded square or a circle.
  final KunCheckBoxType type;

  /// Whether to draw the "some but not all" dash in place of the check.
  final bool indeterminate;

  /// Whether the checkbox is inert and dimmed.
  final bool disabled;

  /// Helper text under the control; hidden while [error] is set.
  final String? description;

  /// An error under the control, which takes precedence over [description].
  final String? error;

  @override
  State<KunCheckBox> createState() => _KunCheckBoxState();
}

/// The web keeps the box a rounded square at every size with a percentage
/// radius: a token radius (12px) would round the small boxes into circles.
const double _kBoxRadiusFraction = 0.35;

/// The indeterminate dash's thickness, web `h-0.5`.
const double _kDashHeight = KunSpacing.unit * 0.5;

class _KunCheckBoxState extends State<KunCheckBox>
    with SingleTickerProviderStateMixin {
  final FocusNode _focus = FocusNode(debugLabel: 'KunCheckBox');
  late final AnimationController _mark;
  bool _hovered = false;
  bool _showRing = false;

  @override
  void initState() {
    super.initState();
    _mark = AnimationController(
      vsync: this,
      duration: KunDurations.fast,
      value: widget.value ? 1 : 0,
    );
    _focus
      ..canRequestFocus = !widget.disabled
      ..addListener(_syncRing);
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mark.duration = kunMotion(context, KunDurations.fast);
  }

  @override
  void didUpdateWidget(KunCheckBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    _focus.canRequestFocus = !widget.disabled;
    if (widget.disabled && _focus.hasFocus) {
      _focus.unfocus();
    }
    if (widget.value != oldWidget.value) {
      widget.value ? _mark.forward() : _mark.reverse();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _focus.removeListener(_syncRing);
    _focus.dispose();
    _mark.dispose();
    super.dispose();
  }

  void _handleHighlightMode(FocusHighlightMode mode) => _syncRing();

  void _syncRing() {
    final bool show = _focus.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (show != _showRing) {
      setState(() => _showRing = show);
    }
  }

  bool get _enabled => !widget.disabled && widget.onChanged != null;

  void _toggle() {
    if (!_enabled) {
      return;
    }
    widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunColorScale scale = widget.color.scaleOf(scheme);
    final KunSelectionMetrics metrics = KunSelectionMetrics.of(widget.size);
    final bool filled = widget.indeterminate || widget.value;
    final String? message = widget.error ?? widget.description;

    final BorderRadius radius = BorderRadius.circular(
      widget.type == KunCheckBoxType.single
          ? metrics.box / 2
          : metrics.box * _kBoxRadiusFraction,
    );

    final Widget box = AnimatedContainer(
      duration: kunMotion(context, KunDurations.fast),
      width: metrics.box,
      height: metrics.box,
      decoration: BoxDecoration(
        color: filled ? scale.solid : null,
        borderRadius: radius,
        border: Border.all(
          color: filled
              ? scale.solid
              : (_hovered && _enabled ? scale.solid : scale.shade300),
          // The web's `border-2`.
          width: 2,
        ),
        boxShadow: <BoxShadow>[
          kunFieldRing(scale.solid, visible: _showRing),
        ],
      ),
      child: Center(
        child: widget.indeterminate
            ? Container(
                width: metrics.dash,
                height: _kDashHeight,
                decoration: BoxDecoration(
                  color: scale.onSolid,
                  borderRadius: BorderRadius.circular(_kDashHeight / 2),
                ),
              )
            : ScaleTransition(
                // The web grows the check from 50% on `peer-checked`.
                scale: Tween<double>(begin: 0.5, end: 1).animate(
                  CurvedAnimation(
                    parent: _mark,
                    curve: KunEasing.emphasized,
                  ),
                ),
                child: FadeTransition(
                  opacity: _mark,
                  child: Icon(
                    KunIcons.check,
                    size: metrics.check,
                    color: scale.onSolid,
                  ),
                ),
              ),
      ),
    );

    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        box,
        if (widget.child != null) ...<Widget>[
          SizedBox(width: metrics.gap),
          widget.child!,
        ],
        if (widget.label != null) ...<Widget>[
          SizedBox(width: metrics.gap),
          Flexible(
            child: Text(
              widget.label!,
              style: metrics.textStyle.copyWith(
                color: scheme.neutral.shade700,
              ),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      checked: widget.value,
      mixed: widget.indeterminate,
      enabled: _enabled,
      label: widget.label,
      hint: message,
      onTap: _enabled ? _toggle : null,
      child: ExcludeSemantics(
        child: Focus(
          focusNode: _focus,
          onKeyEvent: (FocusNode node, KeyEvent event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.space) {
              _toggle();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            cursor:
                _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _enabled ? _toggle : null,
              child: Opacity(
                opacity: widget.disabled ? 0.5 : 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    row,
                    if (message != null && message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: KunSpacing.unit),
                        child: Text(
                          message,
                          style: KunText.sm.copyWith(
                            color: widget.error != null
                                ? scheme.danger.solid
                                : scheme.neutral.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
