import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/field_ring.dart';
import '../foundation/motion.dart';
import '../foundation/selection_metrics.dart';
import '../theme/theme.dart';

/// One choice in a [KunCheckBoxGroup].
@immutable
class KunCheckBoxGroupOption<T> {
  /// Creates an option.
  const KunCheckBoxGroupOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.disabled = false,
  });

  /// What lands in the group's selection when this option is chosen.
  final T value;

  /// The option's text.
  final String label;

  /// A second line under [label]. Ignored by
  /// [KunCheckBoxGroupVariant.pill], which has room for one line.
  final String? description;

  /// Drawn beside the label by [KunCheckBoxGroupVariant.pill] and
  /// [KunCheckBoxGroupVariant.card]. `kun_ui_icons` carries only the glyphs
  /// the components draw themselves, so this comes from the app's own set.
  final IconData? icon;

  /// Whether this one option is inert.
  final bool disabled;

  @override
  bool operator ==(Object other) =>
      other is KunCheckBoxGroupOption<T> &&
      other.value == value &&
      other.label == label &&
      other.description == description &&
      other.icon == icon &&
      other.disabled == disabled;

  @override
  int get hashCode => Object.hash(value, label, description, icon, disabled);
}

/// Why a [KunCheckBoxGroup] refused a toggle.
enum KunCheckBoxGroupInvalidReason {
  /// The selection is already [KunCheckBoxGroup.max] long.
  maxReached,
}

/// How a [KunCheckBoxGroup] presents its options.
enum KunCheckBoxGroupVariant {
  /// A box and a label.
  classic,

  /// Filter chips.
  pill,

  /// Bordered cards that tint when chosen.
  card,
}

/// Which way a [KunCheckBoxGroup] stacks its options.
enum KunCheckBoxGroupOrientation {
  /// One per line.
  vertical,

  /// In a row that wraps.
  horizontal,
}

/// Several choices out of many, in one of three presentations.
///
/// The keyboard is the WAI-ARIA checkbox pattern, not the radio one: every
/// box is its own tab stop and Space or Enter toggles it. The arrow keys do
/// not move between boxes, because for checkboxes they do not select.
class KunCheckBoxGroup<T> extends StatefulWidget {
  /// Creates a checkbox group.
  const KunCheckBoxGroup({
    required this.values,
    required this.options,
    this.onChanged,
    this.onInvalid,
    this.variant = KunCheckBoxGroupVariant.classic,
    this.orientation = KunCheckBoxGroupOrientation.vertical,
    this.color = KunUIColor.primary,
    this.size = KunUISize.md,
    this.rounded,
    this.max,
    this.hideIndicator = false,
    this.disabled = false,
    this.label,
    this.semanticLabel,
    this.error,
    super.key,
  });

  /// The chosen values.
  final List<T> values;

  /// The choices, in order.
  final List<KunCheckBoxGroupOption<T>> options;

  /// Called with the new selection after a user toggle. It carries the new
  /// list rather than a read-back, so the value is never a click behind.
  final ValueChanged<List<T>>? onChanged;

  /// Called when a toggle was refused, the web's `invalid`.
  final ValueChanged<KunCheckBoxGroupInvalidReason>? onInvalid;

  /// How the options are presented.
  final KunCheckBoxGroupVariant variant;

  /// How the options are stacked.
  final KunCheckBoxGroupOrientation orientation;

  /// The chosen state's hue.
  final KunUIColor color;

  /// The box, glyph and text scale, shared with [KunCheckBox].
  final KunUISize size;

  /// Corner rounding, [KunCheckBoxGroupVariant.card] only — the other two
  /// have no surface of their own to round. Defaults to
  /// [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// A cap on how many options may be chosen. At the cap an unchosen option
  /// dims and refuses, calling [onInvalid]; a chosen one still toggles off.
  final int? max;

  /// [KunCheckBoxGroupVariant.card] only: drop the box and let the tinted
  /// border and fill carry the selection, the icon-card look.
  final bool hideIndicator;

  /// Whether the whole group is inert and dimmed. One option is disabled
  /// through its own [KunCheckBoxGroupOption.disabled].
  final bool disabled;

  /// A heading above the group, which also names it to assistive technology.
  final String? label;

  /// The group's accessible name when it has no visible [label].
  final String? semanticLabel;

  /// An error under the group.
  final String? error;

  @override
  State<KunCheckBoxGroup<T>> createState() => _KunCheckBoxGroupState<T>();
}

/// The web's `min-w-[8rem]` on a horizontal card.
const double _kCardMinWidth = KunSpacing.unit * 32;

/// The web keeps a selection box a rounded square at every size with a
/// percentage radius, as `KunCheckBox` does.
const double _kBoxRadiusFraction = 0.35;

/// The web's `opacity-60` on an option the cap has closed off.
const double _kBlockedOpacity = 0.6;

class _KunCheckBoxGroupState<T> extends State<KunCheckBoxGroup<T>> {
  Set<T> get _selected => widget.values.toSet();

  bool _optionDisabled(KunCheckBoxGroupOption<T> option) =>
      widget.disabled || option.disabled;

  bool _blocked(KunCheckBoxGroupOption<T> option) =>
      !_selected.contains(option.value) &&
      widget.max != null &&
      widget.values.length >= widget.max!;

  void _toggle(KunCheckBoxGroupOption<T> option) {
    if (_optionDisabled(option)) {
      return;
    }
    if (_selected.contains(option.value)) {
      widget.onChanged?.call(
        <T>[
          for (final T value in widget.values)
            if (value != option.value) value,
        ],
      );
      return;
    }
    if (widget.max != null && widget.values.length >= widget.max!) {
      widget.onInvalid?.call(KunCheckBoxGroupInvalidReason.maxReached);
      return;
    }
    widget.onChanged?.call(<T>[...widget.values, option.value]);
  }

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final bool horizontal =
        widget.orientation == KunCheckBoxGroupOrientation.horizontal;

    final List<Widget> items = <Widget>[
      for (final KunCheckBoxGroupOption<T> option in widget.options)
        _KunCheckBoxGroupItem<T>(
          key: ValueKey<String>('KunCheckBoxGroup.option.${option.value}'),
          option: option,
          state: this,
          theme: theme,
        ),
    ];

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.label ?? widget.semanticLabel ?? 'checkbox group',
      enabled: !widget.disabled,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: KunSpacing.unit * 2),
              child: Text(
                widget.label!,
                style: KunText.sm.copyWith(
                  color: scheme.neutral.shade700,
                  fontWeight: KunFontWeights.medium,
                ),
              ),
            ),
          if (horizontal)
            Wrap(
              spacing: KunSpacing.unit * 3,
              runSpacing: KunSpacing.unit * 3,
              children: items,
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              // A column of cards stretches, because the web's `flex-col`
              // container aligns its children `stretch` by default and a card
              // is a block. The other two variants are `inline-flex`, so they
              // shrink-wrap their content.
              crossAxisAlignment: widget.variant == KunCheckBoxGroupVariant.card
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
              spacing: KunSpacing.unit * 2,
              children: items,
            ),
          if (widget.error != null && widget.error!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: KunSpacing.unit),
              child: Text(
                widget.error!,
                style: KunText.sm.copyWith(color: scheme.danger.solid),
              ),
            ),
        ],
      ),
    );
  }
}

class _KunCheckBoxGroupItem<T> extends StatefulWidget {
  const _KunCheckBoxGroupItem({
    required this.option,
    required this.state,
    required this.theme,
    super.key,
  });

  final KunCheckBoxGroupOption<T> option;
  final _KunCheckBoxGroupState<T> state;
  final KunThemeData theme;

  @override
  State<_KunCheckBoxGroupItem<T>> createState() =>
      _KunCheckBoxGroupItemState<T>();
}

class _KunCheckBoxGroupItemState<T> extends State<_KunCheckBoxGroupItem<T>> {
  final FocusNode _focus = FocusNode(debugLabel: 'KunCheckBoxGroup.option');
  bool _hovered = false;
  bool _showRing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_syncRing);
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _focus.removeListener(_syncRing);
    _focus.dispose();
    super.dispose();
  }

  void _handleHighlightMode(FocusHighlightMode mode) => _syncRing();

  void _syncRing() {
    final bool show = _focus.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (show != _showRing && mounted) {
      setState(() => _showRing = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    final KunCheckBoxGroup<T> group = widget.state.widget;
    final KunColorScheme scheme = widget.theme.colors;
    final KunColorScale scale = group.color.scaleOf(scheme);
    final KunSelectionMetrics metrics = KunSelectionMetrics.of(group.size);
    final bool chosen = widget.state._selected.contains(widget.option.value);
    final bool disabled = widget.state._optionDisabled(widget.option);
    final bool blocked = widget.state._blocked(widget.option);

    final Widget body = switch (group.variant) {
      KunCheckBoxGroupVariant.classic =>
        _classic(scheme, scale, metrics, chosen),
      KunCheckBoxGroupVariant.pill => _pill(scheme, scale, metrics, chosen),
      KunCheckBoxGroupVariant.card => _card(scheme, scale, metrics, chosen),
    };

    return Semantics(
      checked: chosen,
      enabled: !disabled,
      label: widget.option.label,
      hint: widget.option.description,
      onTap: disabled ? null : () => widget.state._toggle(widget.option),
      child: ExcludeSemantics(
        child: Focus(
          focusNode: _focus,
          canRequestFocus: !disabled,
          onKeyEvent: (FocusNode node, KeyEvent event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.space ||
                    event.logicalKey == LogicalKeyboardKey.enter)) {
              widget.state._toggle(widget.option);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            cursor:
                disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:
                  disabled ? null : () => widget.state._toggle(widget.option),
              child: Opacity(
                opacity: disabled ? 0.5 : (blocked ? _kBlockedOpacity : 1),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(
    KunColorScheme scheme,
    KunColorScale scale,
    KunSelectionMetrics metrics,
    bool chosen, {
    required bool hoverable,
  }) {
    return AnimatedContainer(
      duration: kunMotion(context, KunDefaultTransition.duration),
      width: metrics.box,
      height: metrics.box,
      decoration: BoxDecoration(
        color: chosen ? scale.solid : null,
        borderRadius: BorderRadius.circular(metrics.box * _kBoxRadiusFraction),
        border: Border.all(
          color: chosen
              ? scale.solid
              : (hoverable && _hovered
                  ? scheme.neutral.shade400
                  : scheme.neutral.shade300),
          width: 2,
        ),
      ),
      child: chosen
          ? Center(
              child: Icon(
                KunIcons.check,
                size: metrics.check,
                color: scale.onSolid,
              ),
            )
          : null,
    );
  }

  Widget _ringed({
    required Widget child,
    required Color color,
    required BorderRadius radius,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[kunFieldRing(color, visible: _showRing)],
      ),
      child: child,
    );
  }

  Widget _labelColumn(
    KunColorScheme scheme,
    KunSelectionMetrics metrics, {
    required bool bold,
    double descriptionGap = 0,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.option.label,
          style: metrics.textStyle.copyWith(
            color: scheme.foreground,
            fontWeight: bold ? KunFontWeights.medium : null,
          ),
        ),
        if (widget.option.description != null)
          Padding(
            padding: EdgeInsets.only(top: descriptionGap),
            child: Text(
              widget.option.description!,
              style: KunText.xs.copyWith(color: scheme.neutral.shade500),
            ),
          ),
      ],
    );
  }

  Widget _classic(
    KunColorScheme scheme,
    KunColorScale scale,
    KunSelectionMetrics metrics,
    bool chosen,
  ) {
    final BorderRadius radius = BorderRadius.circular(KunRadius.md);
    return _ringed(
      color: scale.solid,
      radius: radius,
      child: Padding(
        padding: const EdgeInsets.all(KunSpacing.unit),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: metrics.gap,
          children: <Widget>[
            _box(scheme, scale, metrics, chosen, hoverable: true),
            Flexible(child: _labelColumn(scheme, metrics, bold: false)),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    KunColorScheme scheme,
    KunColorScale scale,
    KunSelectionMetrics metrics,
    bool chosen,
  ) {
    final Color background = chosen
        ? scale.solid
        : scheme.neutral.solid.withValues(alpha: _hovered ? 0.3 : 0.2);
    final Color foreground = chosen ? scale.onSolid : scheme.neutral.shade700;
    final BorderRadius radius = BorderRadius.circular(9999);
    return _ringed(
      color: scale.solid,
      radius: radius,
      child: AnimatedContainer(
        duration: kunMotion(context, KunDefaultTransition.duration),
        padding: const EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 3,
          vertical: KunSpacing.unit * 1.5,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          // A 2px transparent border keeps the pill the same size chosen or
          // not, as the web's `border-2 border-transparent` does.
          border: Border.all(color: const Color(0x00000000), width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 1.5,
          children: <Widget>[
            if (widget.option.icon != null)
              Icon(
                widget.option.icon,
                size: KunSpacing.unit * 4,
                color: foreground,
              ),
            Text(
              widget.option.label,
              style: metrics.textStyle.copyWith(
                color: foreground,
                fontWeight: KunFontWeights.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    KunColorScheme scheme,
    KunColorScale scale,
    KunSelectionMetrics metrics,
    bool chosen,
  ) {
    final KunCheckBoxGroup<T> group = widget.state.widget;
    final KunUIRounded rounded = group.rounded ?? widget.theme.rounded;
    final BorderRadius radius = BorderRadius.circular(rounded.radius);
    final bool horizontal =
        group.orientation == KunCheckBoxGroupOrientation.horizontal;

    Widget card = AnimatedContainer(
      duration: kunMotion(context, KunDefaultTransition.duration),
      padding: const EdgeInsets.all(KunSpacing.unit * 3),
      decoration: BoxDecoration(
        color: chosen ? scale.solid.withValues(alpha: 0.05) : scheme.content1,
        borderRadius: radius,
        border: Border.all(
          color: chosen
              ? scale.solid
              : (_hovered ? scheme.neutral.shade300 : scheme.border),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: horizontal ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: metrics.gap,
        children: <Widget>[
          if (!group.hideIndicator)
            Padding(
              padding: const EdgeInsets.only(top: KunSpacing.unit * 0.5),
              child: _box(scheme, scale, metrics, chosen, hoverable: false),
            ),
          if (widget.option.icon != null)
            Icon(
              widget.option.icon,
              size: KunSpacing.unit * 6,
              color: chosen ? scale.solid : scheme.neutral.shade500,
            ),
          Flexible(
            child: _labelColumn(
              scheme,
              metrics,
              bold: true,
              descriptionGap: KunSpacing.unit * 0.5,
            ),
          ),
        ],
      ),
    );

    if (horizontal) {
      card = ConstrainedBox(
        constraints: const BoxConstraints(minWidth: _kCardMinWidth),
        child: card,
      );
    }
    return _ringed(color: scale.solid, radius: radius, child: card);
  }
}
