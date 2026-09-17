part of 'select.dart';

class _KunSelectField<T, O extends KunSelectOption<T>> extends StatelessWidget {
  const _KunSelectField({required this.state, required this.trigger});

  final _KunSelectState<T, O> state;
  final Widget trigger;

  @override
  Widget build(BuildContext context) {
    final KunSelect<T, O> widget = state.widget;
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final bool fullWidth = widget.fullWidth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          fullWidth ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        if (widget.label?.isNotEmpty ?? false) ...[
          Text(
            widget.label!,
            style: KunText.sm.copyWith(
              fontWeight: KunFontWeights.medium,
              color: scheme.neutral.shade700,
            ),
          ),
          const SizedBox(height: KunSpacing.unit),
        ],
        trigger,
        if (widget.error?.isNotEmpty ?? false) ...[
          const SizedBox(height: KunSpacing.unit),
          Text(
            widget.error!,
            style: KunText.sm.copyWith(color: scheme.danger.solid),
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

class _KunSelectTrigger<T, O extends KunSelectOption<T>>
    extends StatelessWidget {
  const _KunSelectTrigger({required this.state});

  final _KunSelectState<T, O> state;

  @override
  Widget build(BuildContext context) {
    final KunSelect<T, O> widget = state.widget;
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunControlMetrics metrics = KunControlMetrics.of(widget.size);
    final KunUIRounded rounded = widget.rounded ?? theme.rounded;
    final BorderRadius radius = BorderRadius.circular(rounded.radius);
    final bool invalid = widget.error?.isNotEmpty ?? false;
    final KunColorScale ringScale =
        (invalid ? KunUIColor.danger : widget.color).scaleOf(scheme);
    final Color borderColor = invalid ? scheme.danger.shade300 : scheme.border;
    final KunMessages messages = KunMessagesScope.of(context);
    final TextStyle textStyle = metrics.textStyle.copyWith(
      color: scheme.foreground,
    );
    final double em = textStyle.fontSize!;
    final bool hasSelection = state._hasSelection;
    final String triggerText = state._triggerText;

    Widget content;
    if (state._showsChips) {
      content = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double maxChipWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : double.infinity;
          return Wrap(
            spacing: KunSpacing.unit,
            runSpacing: KunSpacing.unit,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final ({T value, String label}) chip in state._visibleTags)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxChipWidth),
                  child: _KunSelectChip<T>(
                    label: chip.label,
                    disabled: widget.disabled,
                    scheme: scheme,
                    messages: messages,
                    onRemove: () => state._removeValue(chip.value),
                    onAbsorbTap: () => state._absorbTriggerTap = true,
                    onAbsorbTapDone: () => state._absorbTriggerTap = false,
                  ),
                ),
              if (state._hiddenTagCount > 0)
                _KunSelectChipBox(
                  scheme: scheme,
                  child: Text(
                    '+${state._hiddenTagCount}',
                    style: KunText.xs.copyWith(
                      color: scheme.neutral.shade700,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
    } else {
      content = Text(
        triggerText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle.copyWith(
          color: hasSelection ? scheme.foreground : scheme.neutral.shade400,
        ),
      );
    }

    Widget box = TweenAnimationBuilder<BoxShadow>(
      tween: KunFieldRingTween(
        end: kunFieldRing(ringScale.solid, visible: state._showTriggerRing),
      ),
      duration: kunMotion(context, KunDefaultTransition.duration),
      curve: KunDefaultTransition.curve,
      builder: (BuildContext context, BoxShadow ring, Widget? child) {
        return Container(
          key: const ValueKey<String>('KunSelect.trigger'),
          width: widget.fullWidth ? double.infinity : null,
          padding: metrics.padding,
          decoration: BoxDecoration(
            color: scheme.content1,
            border: Border.all(color: borderColor),
            borderRadius: radius,
            boxShadow: <BoxShadow>[
              ring,
              ...KunShadows.sm,
            ],
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: KunSpacing.unit * 2,
        children: [
          if (widget.icon != null)
            Icon(
              widget.icon,
              size: em,
              color: scheme.neutral.shade500,
            ),
          Flexible(
            fit: widget.fullWidth ? FlexFit.tight : FlexFit.loose,
            child: content,
          ),
          if (widget.clearable && hasSelection && !widget.disabled)
            _KunSelectIconButton(
              icon: KunIcons.circleX,
              size: KunSpacing.unit * 4,
              semanticLabel: messages.select.clear,
              color: scheme.neutral.shade400,
              hoverColor: scheme.neutral.shade600,
              onPressed: state._clearAll,
              onAbsorbTap: () => state._absorbTriggerTap = true,
              onAbsorbTapDone: () => state._absorbTriggerTap = false,
            ),
          AnimatedRotation(
            key: const ValueKey<String>('KunSelect.chevron'),
            turns: state._isOpen ? 0.5 : 0,
            duration: kunMotion(context, KunDefaultTransition.duration),
            curve: KunDefaultTransition.curve,
            child: Icon(
              KunIcons.chevronDown,
              size: em,
              color: textStyle.color,
            ),
          ),
        ],
      ),
    );

    if (widget.disabled) {
      box = Opacity(opacity: 0.6, child: box);
    }

    box = MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: box,
    );

    box = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.disabled
          ? null
          : () {
              if (state._absorbTriggerTap) {
                state._absorbTriggerTap = false;
                return;
              }
              state._triggerFocus.requestFocus();
              state._toggle();
            },
      child: box,
    );

    box = Focus(
      focusNode: state._triggerFocus,
      canRequestFocus: !widget.disabled,
      includeSemantics: false,
      onKeyEvent: (FocusNode node, KeyEvent event) => state._onKey(event),
      child: box,
    );

    box = TapRegion(
      groupId: state._tapGroup,
      onTapOutside: (_) {
        if (state._isOpen) {
          state._close(returnFocus: false);
        }
      },
      child: box,
    );

    box = Listener(
      onPointerDown: (_) => state._setRingSuppressed(true),
      child: box,
    );

    // Flutter 3.47.2's SemanticsRole.comboBox is `_unimplemented` and throws
    // `Missing checks for role` when the node is sent, so the role is omitted;
    // expanded / collapse / expand still match `:aria-expanded` and the
    // general expandable-node rules.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      enabled: !widget.disabled,
      expanded: state._isOpen,
      focusable: !widget.disabled,
      focused: state._triggerFocus.hasFocus,
      label: state._triggerSemanticLabel(),
      value: triggerText,
      onTap: widget.disabled
          ? null
          : () {
              state._triggerFocus.requestFocus();
              state._toggle();
            },
      // Mirrors what `Focus` does with `includeSemantics`, iOS exclusion
      // included (flutter/flutter#150030).
      onFocus: widget.disabled || defaultTargetPlatform == TargetPlatform.iOS
          ? null
          : state._triggerFocus.requestFocus,
      onExpand: widget.disabled || state._isOpen ? null : state._open,
      onCollapse:
          widget.disabled || !state._isOpen ? null : () => state._close(),
      child: box,
    );
  }
}

class _KunSelectChipBox extends StatelessWidget {
  const _KunSelectChipBox({required this.scheme, required this.child});

  final KunColorScheme scheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            scheme.neutral.shade100.withValues(alpha: KunColors.globalOpacity),
        borderRadius: BorderRadius.circular(KunRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 1.5,
          vertical: KunSpacing.unit * 0.5,
        ),
        child: child,
      ),
    );
  }
}

class _KunSelectChip<T> extends StatelessWidget {
  const _KunSelectChip({
    required this.label,
    required this.disabled,
    required this.scheme,
    required this.messages,
    required this.onRemove,
    required this.onAbsorbTap,
    required this.onAbsorbTapDone,
  });

  final String label;
  final bool disabled;
  final KunColorScheme scheme;
  final KunMessages messages;
  final VoidCallback onRemove;
  final VoidCallback onAbsorbTap;
  final VoidCallback onAbsorbTapDone;

  @override
  Widget build(BuildContext context) {
    return _KunSelectChipBox(
      scheme: scheme,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: KunSpacing.unit,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KunText.xs.copyWith(color: scheme.neutral.shade700),
            ),
          ),
          if (!disabled)
            _KunSelectIconButton(
              icon: KunIcons.x,
              size: KunSpacing.unit * 3,
              semanticLabel: messages.select.removeOption(label: label),
              color: scheme.neutral.shade700,
              hoverColor: scheme.danger.solid,
              onPressed: onRemove,
              onAbsorbTap: onAbsorbTap,
              onAbsorbTapDone: onAbsorbTapDone,
            ),
        ],
      ),
    );
  }
}

class _KunSelectIconButton extends StatefulWidget {
  const _KunSelectIconButton({
    required this.icon,
    required this.size,
    required this.semanticLabel,
    required this.color,
    required this.hoverColor,
    required this.onPressed,
    required this.onAbsorbTap,
    required this.onAbsorbTapDone,
  });

  final IconData icon;
  final double size;
  final String semanticLabel;
  final Color color;
  final Color hoverColor;
  final VoidCallback onPressed;
  final VoidCallback onAbsorbTap;
  final VoidCallback onAbsorbTapDone;

  @override
  State<_KunSelectIconButton> createState() => _KunSelectIconButtonState();
}

class _KunSelectIconButtonState extends State<_KunSelectIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Listener(
          onPointerDown: (_) => widget.onAbsorbTap(),
          onPointerUp: (_) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              widget.onAbsorbTapDone();
            });
          },
          onPointerCancel: (_) => widget.onAbsorbTapDone(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: Icon(
              widget.icon,
              size: widget.size,
              color: _hovered ? widget.hoverColor : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
