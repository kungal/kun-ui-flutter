import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/field_ring.dart';
import '../theme/theme.dart';

class _KunSwitchSize {
  const _KunSwitchSize({
    required this.trackHeight,
    required this.trackWidth,
    required this.thumb,
    required this.travel,
    required this.gap,
    required this.text,
  });

  final double trackHeight;
  final double trackWidth;
  final double thumb;
  final double travel;
  final double gap;
  final TextStyle text;

  static _KunSwitchSize of(KunUISize size) => switch (size) {
        KunUISize.xs => const _KunSwitchSize(
            trackHeight: KunSpacing.unit * 4,
            trackWidth: KunSpacing.unit * 7,
            thumb: KunSpacing.unit * 3,
            travel: KunSpacing.unit * 3,
            gap: KunSpacing.unit * 2,
            text: KunText.xs,
          ),
        KunUISize.sm => const _KunSwitchSize(
            trackHeight: KunSpacing.unit * 5,
            trackWidth: KunSpacing.unit * 9,
            thumb: KunSpacing.unit * 4,
            travel: KunSpacing.unit * 4,
            gap: KunSpacing.unit * 2.5,
            text: KunText.sm,
          ),
        KunUISize.md => const _KunSwitchSize(
            trackHeight: KunSpacing.unit * 6,
            trackWidth: KunSpacing.unit * 11,
            thumb: KunSpacing.unit * 5,
            travel: KunSpacing.unit * 5,
            gap: KunSpacing.unit * 3,
            text: KunText.sm,
          ),
        KunUISize.lg => const _KunSwitchSize(
            trackHeight: KunSpacing.unit * 7,
            trackWidth: KunSpacing.unit * 14,
            thumb: KunSpacing.unit * 6,
            travel: KunSpacing.unit * 7,
            gap: KunSpacing.unit * 3,
            text: KunText.base,
          ),
        KunUISize.xl => const _KunSwitchSize(
            trackHeight: KunSpacing.unit * 8,
            trackWidth: KunSpacing.unit * 16,
            thumb: KunSpacing.unit * 7,
            travel: KunSpacing.unit * 8,
            gap: KunSpacing.unit * 3.5,
            text: KunText.lg,
          ),
      };
}

/// A toggle implementing the web `KunSwitch` contract.
///
/// The value is controlled: pass [value], rebuild with what [onChanged]
/// gives. The label row is the tap target. Space toggles it when focused,
/// and so does Enter except on the web, where Flutter — like a browser
/// checkbox — leaves Enter to buttons.
class KunSwitch extends StatefulWidget {
  /// Creates a switch.
  const KunSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.description,
    this.error,
    this.size = KunUISize.md,
    this.disabled = false,
  });

  /// The current on/off value (web `modelValue`).
  final bool value;

  /// Called when the value should change (web event `update:modelValue`).
  ///
  /// Null does nothing but does not gray the switch out — only [disabled]
  /// does.
  final ValueChanged<bool>? onChanged;

  /// Text beside the track. The whole label row is the tap target.
  final String? label;

  /// Helper text below the row. Hidden while [error] is set.
  final String? description;

  /// Error text below the row, in the danger color.
  final String? error;

  /// The switch's own scale, not [KunControlMetrics].
  final KunUISize size;

  /// Dims the track and blocks toggling.
  final bool disabled;

  @override
  State<KunSwitch> createState() => _KunSwitchState();
}

class _KunSwitchState extends State<KunSwitch> {
  bool _focused = false;

  bool get _canToggle => !widget.disabled && widget.onChanged != null;

  void _toggle() {
    if (!_canToggle) return;
    widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = KunTheme.of(context).colors;
    final primary = KunUIColor.primary.scaleOf(scheme);
    final danger = KunUIColor.danger.scaleOf(scheme);
    final sizeRow = _KunSwitchSize.of(widget.size);
    const inset = KunSpacing.unit * 0.5;
    final Color trackColor = widget.value
        ? (widget.disabled ? primary.shade300 : primary.solid)
        : scheme.neutral.shade500;

    Widget trackFill = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: trackColor),
      duration: KunDurations.fast,
      curve: KunEasing.standard,
      builder: (context, animatedColor, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: animatedColor,
            borderRadius: BorderRadius.circular(KunRadius.full),
            boxShadow:
                _focused ? [kunFieldRing(primary.solid, visible: true)] : null,
          ),
        );
      },
    );
    if (widget.disabled) {
      trackFill = Opacity(opacity: 0.5, child: trackFill);
    }

    final Widget track = SizedBox(
      width: sizeRow.trackWidth,
      height: sizeRow.trackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: trackFill),
          AnimatedPositioned(
            duration: KunDurations.fast,
            curve: KunEasing.emphasized,
            top: inset,
            left: inset + (widget.value ? sizeRow.travel : 0),
            width: sizeRow.thumb,
            height: sizeRow.thumb,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: KunColors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );

    final Widget row = MergeSemantics(
      child: Semantics(
        toggled: widget.value,
        enabled: !widget.disabled,
        onTap: _canToggle ? _toggle : null,
        child: FocusableActionDetector(
          enabled: _canToggle,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _toggle();
                return null;
              },
            ),
          },
          child: MouseRegion(
            cursor: widget.disabled
                ? SystemMouseCursors.forbidden
                : (_canToggle ? SystemMouseCursors.click : MouseCursor.defer),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: _canToggle ? _toggle : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  track,
                  if (widget.label?.isNotEmpty ?? false) ...[
                    SizedBox(width: sizeRow.gap),
                    Text(
                      widget.label!,
                      style: sizeRow.text.copyWith(
                        fontWeight: FontWeight.w500,
                        color: widget.disabled
                            ? scheme.neutral.shade400
                            : scheme.foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        if (widget.error?.isNotEmpty ?? false) ...[
          const SizedBox(height: KunSpacing.unit),
          Text(
            widget.error!,
            style: KunText.sm.copyWith(color: danger.solid),
          ),
        ] else if (widget.description?.isNotEmpty ?? false) ...[
          const SizedBox(height: KunSpacing.unit),
          Text(
            widget.description!,
            style: KunText.sm.copyWith(color: scheme.neutral.shade500),
          ),
        ],
      ],
    );
  }
}
