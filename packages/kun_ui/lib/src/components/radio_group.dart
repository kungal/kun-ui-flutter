import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/field_ring.dart';
import '../foundation/motion.dart';
import '../foundation/selection_metrics.dart';
import '../theme/theme.dart';

/// One choice in a [KunRadioGroup].
@immutable
class KunRadioOption<T> {
  /// Creates an option.
  const KunRadioOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.disabled = false,
  });

  /// What lands in the group's value when this option is chosen.
  final T value;

  /// The option's text.
  final String label;

  /// A second line under [label]. Ignored by
  /// [KunRadioVariant.pill], which has room for one line.
  final String? description;

  /// Drawn beside the label by [KunRadioVariant.pill] and
  /// [KunRadioVariant.card]. `kun_ui_icons` carries only the glyphs the
  /// components draw themselves, so this comes from the app's own set.
  final IconData? icon;

  /// Whether this one option is inert.
  final bool disabled;

  @override
  bool operator ==(Object other) =>
      other is KunRadioOption<T> &&
      other.value == value &&
      other.label == label &&
      other.description == description &&
      other.icon == icon &&
      other.disabled == disabled;

  @override
  int get hashCode => Object.hash(value, label, description, icon, disabled);
}

/// How a [KunRadioGroup] presents its options.
enum KunRadioVariant {
  /// A dot and a label.
  classic,

  /// Choice chips.
  pill,

  /// Bordered cards that tint when chosen.
  card,
}

/// Which way a [KunRadioGroup] stacks its options.
enum KunRadioOrientation {
  /// One per line.
  vertical,

  /// In a row that wraps.
  horizontal,
}

/// A single choice out of several, in one of three presentations.
///
/// The keyboard is the WAI-ARIA radio-group pattern, which differs from a
/// menu's: the whole group is one tab stop, and the arrow keys *move and
/// choose* in one step rather than only moving. Tab lands on the chosen
/// option, or on the first enabled one when nothing is chosen.
class KunRadioGroup<T> extends StatefulWidget {
  /// Creates a radio group.
  const KunRadioGroup({
    required this.value,
    required this.options,
    this.onChanged,
    this.onSelected,
    this.variant = KunRadioVariant.classic,
    this.orientation = KunRadioOrientation.vertical,
    this.color = KunUIColor.primary,
    this.size = KunUISize.md,
    this.rounded,
    this.hideIndicator = false,
    this.disabled = false,
    this.label,
    this.semanticLabel,
    this.error,
    super.key,
  });

  /// The chosen option's value.
  final T? value;

  /// The choices, in order.
  final List<KunRadioOption<T>> options;

  /// Called with the newly chosen value. Choosing the current one is not a
  /// change and calls nothing.
  final ValueChanged<T>? onChanged;

  /// Called with the newly chosen value and its index, the web's `change`.
  /// It fires with [onChanged], never on its own.
  final void Function(T value, int index)? onSelected;

  /// How the options are presented.
  final KunRadioVariant variant;

  /// How the options are stacked.
  final KunRadioOrientation orientation;

  /// The chosen state's hue.
  final KunUIColor color;

  /// The indicator, dot and text scale, shared with [KunCheckBox].
  final KunUISize size;

  /// Corner rounding, [KunRadioVariant.card] only — the other two have no
  /// surface of their own to round. Defaults to [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// [KunRadioVariant.card] only: drop the dot and let the tinted border and
  /// fill carry the selection, the icon-card look.
  final bool hideIndicator;

  /// Whether the whole group is inert and dimmed. One option is disabled
  /// through its own [KunRadioOption.disabled].
  final bool disabled;

  /// A heading above the group, which also names it to assistive technology.
  final String? label;

  /// The group's accessible name when it has no visible [label].
  final String? semanticLabel;

  /// An error under the group.
  final String? error;

  @override
  State<KunRadioGroup<T>> createState() => _KunRadioGroupState<T>();
}

/// The web's `min-w-[8rem]` on a horizontal card.
const double _kCardMinWidth = KunSpacing.unit * 32;

class _KunRadioGroupState<T> extends State<KunRadioGroup<T>> {
  List<FocusNode> _focusNodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();
  }

  @override
  void didUpdateWidget(KunRadioGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      _syncFocusNodes();
    }
  }

  @override
  void dispose() {
    for (final FocusNode node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncFocusNodes() {
    for (final FocusNode node in _focusNodes) {
      node.dispose();
    }
    _focusNodes = <FocusNode>[
      for (int i = 0; i < widget.options.length; i++)
        FocusNode(debugLabel: 'KunRadioGroup.option.$i'),
    ];
  }

  bool _optionDisabled(KunRadioOption<T> option) =>
      widget.disabled || option.disabled;

  /// Only one option is Tab-reachable: the chosen one, or the first enabled
  /// one when nothing is chosen.
  int get _tabIndex {
    final int chosen = widget.options.indexWhere(
      (KunRadioOption<T> option) => option.value == widget.value,
    );
    if (chosen >= 0 && !_optionDisabled(widget.options[chosen])) {
      return chosen;
    }
    return widget.options.indexWhere(
      (KunRadioOption<T> option) => !_optionDisabled(option),
    );
  }

  void _select(KunRadioOption<T> option, int index) {
    if (_optionDisabled(option) || option.value == widget.value) {
      return;
    }
    widget.onChanged?.call(option.value);
    widget.onSelected?.call(option.value, index);
  }

  void _move(int from, int delta) {
    final int total = widget.options.length;
    if (total == 0) {
      return;
    }
    int cursor = from;
    for (int step = 0; step < total; step++) {
      cursor = (cursor + delta + total) % total;
      final KunRadioOption<T> candidate = widget.options[cursor];
      if (!_optionDisabled(candidate)) {
        _select(candidate, cursor);
        _focusNodes[cursor].requestFocus();
        return;
      }
    }
  }

  KeyEventResult _onKey(KeyEvent event, int index) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.arrowRight:
        _move(index, 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowLeft:
        _move(index, -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.enter:
        _select(widget.options[index], index);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final bool horizontal =
        widget.orientation == KunRadioOrientation.horizontal;
    final int tabIndex = _tabIndex;

    final List<Widget> items = <Widget>[
      for (int i = 0; i < widget.options.length; i++)
        _KunRadioItem<T>(
          key: ValueKey<String>(
              'KunRadioGroup.option.${widget.options[i].value}'),
          option: widget.options[i],
          index: i,
          state: this,
          focusNode: _focusNodes[i],
          tabbable: i == tabIndex,
          theme: theme,
        ),
    ];

    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.radioGroup,
      label: widget.label ?? widget.semanticLabel ?? 'radio group',
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
              crossAxisAlignment: widget.variant == KunRadioVariant.card
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

class _KunRadioItem<T> extends StatefulWidget {
  const _KunRadioItem({
    required this.option,
    required this.index,
    required this.state,
    required this.focusNode,
    required this.tabbable,
    required this.theme,
    super.key,
  });

  final KunRadioOption<T> option;
  final int index;
  final _KunRadioGroupState<T> state;
  final FocusNode focusNode;
  final bool tabbable;
  final KunThemeData theme;

  @override
  State<_KunRadioItem<T>> createState() => _KunRadioItemState<T>();
}

class _KunRadioItemState<T> extends State<_KunRadioItem<T>> {
  bool _hovered = false;
  bool _showRing = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_syncRing);
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    widget.focusNode.removeListener(_syncRing);
    super.dispose();
  }

  void _handleHighlightMode(FocusHighlightMode mode) => _syncRing();

  void _syncRing() {
    final bool show = widget.focusNode.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (show != _showRing && mounted) {
      setState(() => _showRing = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    final KunRadioGroup<T> group = widget.state.widget;
    final KunColorScheme scheme = widget.theme.colors;
    final KunColorScale scale = group.color.scaleOf(scheme);
    final KunSelectionMetrics metrics = KunSelectionMetrics.of(group.size);
    final bool chosen = widget.option.value == group.value;
    final bool disabled = widget.state._optionDisabled(widget.option);

    final Widget body = switch (group.variant) {
      KunRadioVariant.classic => _classic(scheme, scale, metrics, chosen),
      KunRadioVariant.pill => _pill(scheme, scale, metrics, chosen),
      KunRadioVariant.card => _card(scheme, scale, metrics, chosen),
    };

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: chosen,
      enabled: !disabled,
      label: widget.option.label,
      hint: widget.option.description,
      onTap: disabled
          ? null
          : () => widget.state._select(widget.option, widget.index),
      child: ExcludeSemantics(
        child: Focus(
          focusNode: widget.focusNode,
          canRequestFocus: !disabled,
          skipTraversal: !widget.tabbable,
          onKeyEvent: (FocusNode node, KeyEvent event) =>
              widget.state._onKey(event, widget.index),
          child: MouseRegion(
            cursor:
                disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: disabled
                  ? null
                  : () => widget.state._select(widget.option, widget.index),
              child: Opacity(opacity: disabled ? 0.5 : 1, child: body),
            ),
          ),
        ),
      ),
    );
  }

  Widget _indicator(
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
        shape: BoxShape.circle,
        border: Border.all(
          color: chosen
              ? scale.solid
              : (hoverable && _hovered
                  ? scheme.neutral.shade400
                  : scheme.neutral.shade300),
          width: 2,
        ),
      ),
      child: Center(
        child: chosen
            ? Container(
                width: metrics.dot,
                height: metrics.dot,
                decoration: BoxDecoration(
                  color: scale.solid,
                  shape: BoxShape.circle,
                ),
              )
            : const SizedBox.shrink(),
      ),
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
            _indicator(scheme, scale, metrics, chosen, hoverable: true),
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
          // The web keeps a 2px transparent border so switching between the
          // chosen and unchosen look never moves the pill.
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
    final KunRadioGroup<T> group = widget.state.widget;
    final KunUIRounded rounded = group.rounded ?? widget.theme.rounded;
    final BorderRadius radius = BorderRadius.circular(rounded.radius);
    final bool horizontal = group.orientation == KunRadioOrientation.horizontal;

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
              child:
                  _indicator(scheme, scale, metrics, chosen, hoverable: false),
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
