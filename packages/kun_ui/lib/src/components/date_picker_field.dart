part of 'date_picker.dart';

class _KunDatePickerField extends StatelessWidget {
  const _KunDatePickerField({required this.state, required this.trigger});

  final _KunDatePickerState state;
  final Widget trigger;

  @override
  Widget build(BuildContext context) {
    final KunDatePicker widget = state.widget;
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
        ],
      ],
    );
  }
}

class _KunDatePickerTrigger extends StatelessWidget {
  const _KunDatePickerTrigger({required this.state});

  final _KunDatePickerState state;

  @override
  Widget build(BuildContext context) {
    final KunDatePicker widget = state.widget;
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunControlMetrics metrics = KunControlMetrics.of(widget.size);
    final KunUIRounded rounded = widget.rounded ?? theme.rounded;
    final BorderRadius radius = BorderRadius.circular(rounded.radius);
    final bool invalid = widget.error?.isNotEmpty ?? false;
    final KunColorScale ringScale =
        (invalid ? KunUIColor.danger : widget.color).scaleOf(scheme);
    final Color borderColor = invalid ? scheme.danger.shade300 : scheme.border;
    final TextStyle textStyle = metrics.textStyle.copyWith(
      color: scheme.foreground,
    );
    final double em = textStyle.fontSize!;
    final String displayText = state._displayTextOf(context);
    final bool hasValue = displayText.isNotEmpty;
    final String placeholder = state._resolvedPlaceholder(context);
    final String painted = hasValue ? displayText : placeholder;
    final bool showClear = widget.clearable && hasValue && !widget.disabled;

    final Widget content = Text(
      painted,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle.copyWith(
        color: hasValue ? scheme.foreground : scheme.neutral.shade400,
      ),
    );

    final Size minTap = kunMinTapTargetSize(context);
    final double slotWidth = math.max(em, minTap.width);
    final double hPad = metrics.horizontalPadding;

    Widget box = KunTapBand(
      background: TweenAnimationBuilder<BoxShadow>(
        tween: KunFieldRingTween(
          end: kunFieldRing(ringScale.solid, visible: state._showTriggerRing),
        ),
        duration: kunMotion(context, KunDefaultTransition.duration),
        curve: KunDefaultTransition.curve,
        builder: (BuildContext context, BoxShadow ring, Widget? child) {
          return Container(
            key: const ValueKey<String>('KunDatePicker.trigger'),
            width: widget.fullWidth ? double.infinity : null,
            decoration: BoxDecoration(
              color: scheme.content1,
              border: Border.all(color: borderColor),
              borderRadius: radius,
              boxShadow: <BoxShadow>[
                ring,
                ...KunShadows.sm,
              ],
            ),
          );
        },
      ),
      child: Row(
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: KunSpacing.unit * 2,
        children: [
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Padding(
                padding:
                    EdgeInsets.symmetric(vertical: metrics.verticalPadding),
                child: SizedBox(width: 0, height: metrics.lineHeight),
              ),
            ),
          ),
          SizedBox(width: hPad),
          if (widget.icon != null)
            Icon(
              widget.icon,
              size: em,
              color: scheme.neutral.shade500,
            ),
          Flexible(
            fit: widget.fullWidth ? FlexFit.tight : FlexFit.loose,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              enabled: !widget.disabled,
              expanded: state._isOpen,
              focusable: !widget.disabled,
              focused: state._triggerFocus.hasFocus,
              label: (widget.label?.isNotEmpty ?? false)
                  ? widget.label!
                  : placeholder,
              value: displayText,
              onTap: widget.disabled
                  ? null
                  : () {
                      state._triggerFocus.requestFocus();
                      state._toggle();
                    },
              onFocus:
                  widget.disabled || defaultTargetPlatform == TargetPlatform.iOS
                      ? null
                      : state._triggerFocus.requestFocus,
              onExpand: widget.disabled || state._isOpen ? null : state._open,
              onCollapse: widget.disabled || !state._isOpen
                  ? null
                  : () => state._close(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTap.width),
                child: SizedBox(
                  height: double.infinity,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: widget.fullWidth ? null : 1,
                    child: ExcludeSemantics(child: content),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: KunSpacing.unit * 2,
            children: [
              if (showClear)
                SizedBox(
                  key: state._clearKey,
                  width: slotWidth,
                  height: double.infinity,
                  child: ExcludeSemantics(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Icon(
                        KunIcons.x,
                        key: const ValueKey<String>('KunDatePicker.clear'),
                        size: em,
                        color: state._clearHovered
                            ? scheme.neutral.shade800
                            : scheme.neutral.shade500,
                      ),
                    ),
                  ),
                ),
              ExcludeSemantics(
                child: Icon(
                  KunIcons.calendar,
                  size: em,
                  color: scheme.neutral.shade500,
                ),
              ),
            ],
          ),
          SizedBox(width: hPad),
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
      onHover: showClear
          ? (PointerHoverEvent event) =>
              state._setClearHovered(state._hitsClear(event.position))
          : null,
      onExit: (_) => state._setClearHovered(false),
      child: box,
    );

    box = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapUp: widget.disabled
          ? null
          : (TapUpDetails details) {
              if (showClear && state._hitsClear(details.globalPosition)) {
                state._clear();
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

    return Listener(
      onPointerDown: (_) => state._setRingSuppressed(true),
      child: box,
    );
  }
}
