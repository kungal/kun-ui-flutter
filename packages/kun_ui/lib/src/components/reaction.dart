import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/focus_outline.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';

/// Web `kun-reaction-pop` `0.45s`.
const Duration _kPopDuration = Duration(milliseconds: 450);

/// Web `kun-reaction-ring` / `kun-reaction-spark` `0.5s`.
const Duration _kBurstDuration = Duration(milliseconds: 500);

/// Web count-roll `transform 0.25s` / `opacity 0.25s`.
const Duration _kCountRoll = KunDurations.base;

/// Web pop keyframe at 35%: `scale(1.35)`.
const double _kPopPeak = 1.35;

/// Web pop keyframe at 65%: `scale(0.9)`.
const double _kPopDip = 0.9;

/// Web pop keyframe weights: 0–35%, 35–65%, 65–100%.
const double _kPopPeakAt = 35;
const double _kPopDipAt = 65;

/// Web `sizeMap` `sm.icon` `1rem`.
const double _kIconSm = 16;

/// Web `sizeMap` `md.icon` `1.15rem`.
const double _kIconMd = 18.4;

/// Web `sizeMap` `lg.icon` `1.4rem`.
const double _kIconLg = 22.4;

/// Web `.kun-reaction-ring { inset: -2px }`.
const double _kRingInset = 2;

/// Web `.kun-reaction-ring` `border-2`.
const double _kRingBorder = 2;

/// Web ring keyframe 0%: `scale(0.2)`.
const double _kRingScaleFrom = 0.2;

/// Web ring keyframe 100%: `scale(2)`.
const double _kRingScaleTo = 2;

/// Web ring keyframe 0%: `opacity: 0.5`.
const double _kRingOpacityFrom = 0.5;

/// Web spark `width` / `height` `4px`.
const double _kSparkSize = 4;

/// Web spark keyframe 0%: `translateY(-2px)`.
const double _kSparkFrom = 2;

/// Web spark keyframe 100%: `translateY(-15px)`.
const double _kSparkTo = 15;

/// Web `--kun-spark-a: ${n * 60}deg`.
const double _kSparkStepDeg = 60;

/// Web spark opacity keyframe at 30%.
const double _kSparkFadePeakAt = 30;

/// Web `kun-reaction-count` `leading-[1.2]`.
const double _kCountLeading = 1.2;

/// Web `hover:bg-default-100/60` opacity modifier.
const double _kOnHoverOpacity = 0.6;

/// How compact the pill is (web `size`: `'sm' | 'md' | 'lg'`).
enum KunReactionSize {
  /// Web `sm`: `gap-1 px-1.5 py-0.5 text-xs`.
  sm,

  /// Web `md`: `gap-1.5 px-2 py-1 text-sm`.
  md,

  /// Web `lg`: `gap-2 px-2.5 py-1.5 text-base`.
  lg,
}

class _KunReactionMetrics {
  const _KunReactionMetrics({
    required this.gap,
    required this.padding,
    required this.text,
    required this.iconSize,
  });

  final double gap;
  final EdgeInsets padding;
  final TextStyle text;
  final double iconSize;

  static _KunReactionMetrics of(KunReactionSize size) => switch (size) {
        KunReactionSize.sm => const _KunReactionMetrics(
            gap: KunSpacing.unit * 1,
            padding: EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 1.5,
              vertical: KunSpacing.unit * 0.5,
            ),
            text: KunText.xs,
            iconSize: _kIconSm,
          ),
        KunReactionSize.md => const _KunReactionMetrics(
            gap: KunSpacing.unit * 1.5,
            padding: EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 2,
              vertical: KunSpacing.unit * 1,
            ),
            text: KunText.sm,
            iconSize: _kIconMd,
          ),
        KunReactionSize.lg => const _KunReactionMetrics(
            gap: KunSpacing.unit * 2,
            padding: EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 2.5,
              vertical: KunSpacing.unit * 1.5,
            ),
            text: KunText.base,
            iconSize: _kIconLg,
          ),
      };
}

/// A compact like / reaction pill, implementing the web `KunReaction` contract.
///
/// A toggle (`[toggle]` true) or a one-shot action (share / more) in the same
/// skin: icon, optional visible [child] label, optional [count]. The filled
/// colour follows [value] in both modes. Controlled: this widget paints
/// [value] and [count] as given and reports the next values through
/// [onChanged] / [onCountChanged].
///
/// The glyph defaults to the web's `lucide:heart`, which turns into
/// [KunIcons.heartFilled] while on.
class KunReaction extends StatefulWidget {
  /// Creates a reaction pill.
  const KunReaction({
    super.key,
    this.value = false,
    this.onChanged,
    this.count,
    this.onCountChanged,
    this.icon = KunIcons.heart,
    this.activeIcon,
    this.iconBuilder,
    this.label,
    this.child,
    this.color = KunUIColor.danger,
    this.activeColor,
    this.size = KunReactionSize.md,
    this.toggle = true,
    this.disabled = false,
    this.disableAnimation = false,
    this.onPressed,
  });

  /// Whether the "on" skin is showing (web `modelValue` / `active`).
  ///
  /// In toggle mode a press flips this; in action mode the consumer drives
  /// it (a favourite used as a popover trigger stays "collected" while in
  /// any list).
  final bool value;

  /// Called with the next on/off value (web `update:modelValue` and
  /// `change`, which fire together). Null does nothing and does not dim.
  final ValueChanged<bool>? onChanged;

  /// The count beside the icon (web `count`). Null hides the count.
  final int? count;

  /// Called with the next count (web `update:count`).
  final ValueChanged<int>? onCountChanged;

  /// The glyph (web `icon`). Defaults to [KunIcons.heart], the web's
  /// `lucide:heart`.
  final IconData icon;

  /// The glyph while [value] is true. Flutter-only.
  ///
  /// The web fills [icon] with `fill-current` while on. A font glyph is a
  /// traced stroke and cannot be filled, so the filled shape is a glyph of
  /// its own. Null means [KunIcons.heartFilled] when [icon] is the default
  /// [KunIcons.heart], and [icon] itself otherwise, recoloured.
  final IconData? activeIcon;

  /// Replaces the glyph (web `#icon` slot). Receives the current [value] as
  /// `active`. Use this for an emoji, an image, or anything that is not a
  /// font glyph; for a glyph pair, [icon] and [activeIcon] are enough.
  final Widget Function(BuildContext context, bool active)? iconBuilder;

  /// Accessible name base (web `label`). Null resolves
  /// [KunMessagesScope.of] `.reaction.label`. With no [child], a count is
  /// appended as `'$label,$count'` (ASCII comma, no space).
  final String? label;

  /// Visible label inside the pill (web default slot). Clicking it presses
  /// the reaction. When set it names the control; [label] is then unused
  /// for semantics.
  final Widget? child;

  /// Palette half of web `color`. Ignored while [activeColor] is set.
  /// [KunUIColor.neutral] (web `default`) paints `scheme.foreground`
  /// (`text-foreground`); every other key paints that scale's `solid`.
  final KunUIColor color;

  /// Any-colour half of web `color`. When set, this is the on-state colour
  /// for the icon, the count, the [child], the burst ring and the sparks.
  final Color? activeColor;

  /// Compact / medium / large (web `size`).
  final KunReactionSize size;

  /// `true` (default): a press toggles [value], steps [count], and bursts
  /// when turning on. `false`: action mode — [onPressed] and the pop only.
  final bool toggle;

  /// Dims the pill and ignores presses (web `disabled`).
  final bool disabled;

  /// Skip the pop, the burst and the count-roll (web `disableAnimation`).
  /// Also skipped under [kunReducedMotion].
  final bool disableAnimation;

  /// Called on every enabled press in both modes (the web's native
  /// `@click`). In action mode this is the handler; in toggle mode it
  /// fires after the model updates.
  final VoidCallback? onPressed;

  @override
  State<KunReaction> createState() => _KunReactionState();
}

class _KunReactionState extends State<KunReaction>
    with TickerProviderStateMixin {
  late final AnimationController _pop;
  late final AnimationController _burst;
  late final Animation<double> _popScale;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;
  late final Animation<double> _sparkTravel;
  late final Animation<double> _sparkOpacity;

  bool _hovered = false;
  bool _focused = false;

  bool get _animate => !widget.disableAnimation && !kunReducedMotion(context);

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(vsync: this, duration: _kPopDuration);
    _burst = AnimationController(vsync: this, duration: _kBurstDuration);
    _popScale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: _kPopPeak)
            .chain(CurveTween(curve: KunEasing.standard)),
        weight: _kPopPeakAt,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: _kPopPeak, end: _kPopDip)
            .chain(CurveTween(curve: KunEasing.standard)),
        weight: _kPopDipAt - _kPopPeakAt,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: _kPopDip, end: 1)
            .chain(CurveTween(curve: KunEasing.standard)),
        weight: 100 - _kPopDipAt,
      ),
    ]).animate(_pop);
    _ringScale = Tween<double>(begin: _kRingScaleFrom, end: _kRingScaleTo)
        .animate(CurvedAnimation(parent: _burst, curve: Curves.easeOut));
    _ringOpacity = Tween<double>(begin: _kRingOpacityFrom, end: 0)
        .animate(CurvedAnimation(parent: _burst, curve: Curves.easeOut));
    _sparkTravel = Tween<double>(begin: _kSparkFrom, end: _kSparkTo)
        .animate(CurvedAnimation(parent: _burst, curve: Curves.easeOut));
    _sparkOpacity = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: _kSparkFadePeakAt,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 100 - _kSparkFadePeakAt,
      ),
    ]).animate(_burst);
  }

  @override
  void dispose() {
    _pop.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _popNow() {
    if (!_animate) {
      return;
    }
    _pop.forward(from: 0);
  }

  void _burstNow() {
    if (!_animate) {
      return;
    }
    _burst.forward(from: 0);
  }

  void _press() {
    if (widget.disabled) {
      return;
    }
    if (!widget.toggle) {
      widget.onPressed?.call();
      _popNow();
      return;
    }
    final bool next = !widget.value;
    if (widget.count != null) {
      widget.onCountChanged?.call(math.max(0, widget.count! + (next ? 1 : -1)));
    }
    widget.onChanged?.call(next);
    widget.onPressed?.call();
    _popNow();
    if (next) {
      _burstNow();
    }
  }

  Color _onColor(KunColorScheme scheme) {
    if (widget.activeColor != null) {
      return widget.activeColor!;
    }
    if (widget.color == KunUIColor.neutral) {
      return scheme.foreground;
    }
    return widget.color.scaleOf(scheme).solid;
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final _KunReactionMetrics metrics = _KunReactionMetrics.of(widget.size);
    final Color target =
        widget.value ? _onColor(scheme) : scheme.neutral.shade500;
    final String resolvedLabel =
        widget.label ?? KunMessagesScope.of(context).reaction.label;
    final String accessibleName =
        widget.count != null ? '$resolvedLabel,${widget.count}' : resolvedLabel;
    final Color? hoverFill = (!widget.disabled && _hovered)
        ? scheme.neutral.shade100.withValues(
            alpha: widget.value
                ? KunColors.globalOpacity * _kOnHoverOpacity
                : KunColors.globalOpacity,
          )
        : null;

    Widget glyph = widget.iconBuilder != null
        ? widget.iconBuilder!(context, widget.value)
        : Icon(
            widget.value
                ? widget.activeIcon ??
                    (widget.icon == KunIcons.heart
                        ? KunIcons.heartFilled
                        : widget.icon)
                : widget.icon,
            size: metrics.iconSize,
          );
    glyph = DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: metrics.iconSize,
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      child: glyph,
    );

    Widget iconGroup = AnimatedBuilder(
      animation: _burst,
      builder: (BuildContext context, Widget? child) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            child!,
            // AnimationController treats isDone as elapsed > duration, so
            // at exactly 500ms value is 1 while status is still forward.
            // The web removes the burst at animationend (100%).
            if (_burst.isAnimating && _burst.value < 1)
              Positioned.fill(
                child: _KunReactionBurst(
                  color: DefaultTextStyle.of(context).style.color ?? target,
                  ringScale: _ringScale.value,
                  ringOpacity: _ringOpacity.value,
                  sparkTravel: _sparkTravel.value,
                  sparkOpacity: _sparkOpacity.value,
                ),
              ),
          ],
        );
      },
      child: glyph,
    );
    iconGroup = ScaleTransition(scale: _popScale, child: iconGroup);
    iconGroup = ExcludeSemantics(child: iconGroup);

    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: metrics.gap,
      children: <Widget>[
        iconGroup,
        if (widget.child != null)
          DefaultTextStyle.merge(
            maxLines: 1,
            softWrap: false,
            child: widget.child!,
          ),
        if (widget.count != null)
          ExcludeSemantics(
            child: _KunReactionCount(
              count: widget.count!,
              animate: _animate,
              style: metrics.text.copyWith(
                height: _kCountLeading,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );

    Widget pill = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: kunMotion(context, KunDefaultTransition.duration),
      curve: KunDefaultTransition.curve,
      builder: (BuildContext context, Color? animated, Widget? child) {
        final Color resolved = animated ?? target;
        return DefaultTextStyle(
          style: metrics.text.copyWith(color: resolved),
          maxLines: 1,
          softWrap: false,
          child: IconTheme.merge(
            data: IconThemeData(color: resolved, size: metrics.iconSize),
            child: child!,
          ),
        );
      },
      child: row,
    );

    pill = AnimatedContainer(
      duration: kunMotion(context, KunDefaultTransition.duration),
      curve: KunDefaultTransition.curve,
      padding: metrics.padding,
      decoration: BoxDecoration(
        color: hoverFill,
        borderRadius: BorderRadius.circular(KunRadius.full),
      ),
      child: pill,
    );

    pill = Opacity(
      opacity: widget.disabled ? 0.5 : 1,
      child: pill,
    );

    pill = KunFocusOutline(
      visible: _focused,
      color: target.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(KunRadius.full),
      child: pill,
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: !widget.disabled,
        toggled: widget.toggle ? widget.value : null,
        label: widget.child == null ? accessibleName : null,
        onTap: widget.disabled ? null : _press,
        child: FocusableActionDetector(
          enabled: !widget.disabled,
          onShowFocusHighlight: (bool value) =>
              setState(() => _focused = value),
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _press();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (_) {
                _press();
                return null;
              },
            ),
          },
          child: MouseRegion(
            cursor: widget.disabled
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: widget.disabled ? null : _press,
              child: pill,
            ),
          ),
        ),
      ),
    );
  }
}

class _KunReactionBurst extends StatelessWidget {
  const _KunReactionBurst({
    required this.color,
    required this.ringScale,
    required this.ringOpacity,
    required this.sparkTravel,
    required this.sparkOpacity,
  });

  final Color color;
  final double ringScale;
  final double ringOpacity;
  final double sparkTravel;
  final double sparkOpacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      key: const ValueKey<String>('KunReaction.burst'),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            left: -_kRingInset,
            top: -_kRingInset,
            right: -_kRingInset,
            bottom: -_kRingInset,
            child: Transform.scale(
              scale: ringScale,
              child: Opacity(
                opacity: ringOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: _kRingBorder),
                  ),
                ),
              ),
            ),
          ),
          for (int n = 0; n < 6; n++)
            Transform.rotate(
              angle: n * _kSparkStepDeg * math.pi / 180,
              child: Transform.translate(
                offset: Offset(0, -sparkTravel),
                child: Opacity(
                  opacity: sparkOpacity,
                  child: SizedBox(
                    width: _kSparkSize,
                    height: _kSparkSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(KunRadius.full),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KunReactionCount extends StatefulWidget {
  const _KunReactionCount({
    required this.count,
    required this.animate,
    required this.style,
  });

  final int count;
  final bool animate;
  final TextStyle style;

  @override
  State<_KunReactionCount> createState() => _KunReactionCountState();
}

class _KunReactionCountState extends State<_KunReactionCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll;
  late final Animation<double> _slide;
  late final Animation<double> _fade;
  late int _incoming;
  int? _outgoing;
  bool _up = true;

  @override
  void initState() {
    super.initState();
    _incoming = widget.count;
    _roll = AnimationController(vsync: this, duration: _kCountRoll);
    _slide = CurvedAnimation(parent: _roll, curve: KunEasing.standard);
    _fade = CurvedAnimation(parent: _roll, curve: Curves.ease);
    _roll.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didUpdateWidget(covariant _KunReactionCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count == widget.count) {
      if (oldWidget.animate && !widget.animate) {
        _roll.stop();
        _incoming = widget.count;
        _outgoing = null;
      }
      return;
    }
    if (!widget.animate) {
      _roll.stop();
      _incoming = widget.count;
      _outgoing = null;
      return;
    }
    _outgoing = oldWidget.count;
    _incoming = widget.count;
    _up = widget.count >= oldWidget.count;
    _roll.forward(from: 0);
  }

  @override
  void dispose() {
    _roll.removeStatusListener(_onStatus);
    _roll.dispose();
    super.dispose();
  }

  Widget _num(int value) {
    return Text(
      '$value',
      textAlign: TextAlign.center,
      style: widget.style,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_outgoing == null) {
      return _num(_incoming);
    }
    return ClipRect(
      child: AnimatedBuilder(
        animation: _roll,
        builder: (BuildContext context, Widget? child) {
          final double slide = _slide.value;
          final double fade = _fade.value;
          final double enteringDy = _up ? 1 - slide : slide - 1;
          final double leavingDy = _up ? -slide : slide;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              FractionalTranslation(
                translation: Offset(0, enteringDy),
                child: Opacity(
                  opacity: fade,
                  child: _num(_incoming),
                ),
              ),
              Positioned.fill(
                child: FractionalTranslation(
                  translation: Offset(0, leavingDy),
                  child: Opacity(
                    opacity: 1 - fade,
                    child: _num(_outgoing!),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
