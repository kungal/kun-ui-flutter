part of 'select.dart';

class _KunSelectPopup<T, O extends KunSelectOption<T>> extends StatelessWidget {
  const _KunSelectPopup({required this.state});

  final _KunSelectState<T, O> state;

  @override
  Widget build(BuildContext context) {
    final KunSelect<T, O> widget = state.widget;
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunUIRounded rounded = widget.rounded ?? theme.rounded;
    final double panelRadius =
        (rounded == KunUIRounded.full ? KunUIRounded.lg : rounded).radius;
    final BorderRadius radius = BorderRadius.circular(panelRadius);
    final List<O> shown = state._shown;
    final bool showSpinner = state._showSpinner;
    state._ensureRowKeys(showSpinner ? 0 : shown.length);

    Widget list;
    if (showSpinner) {
      list = _KunSelectSpinner(
        text: widget.loadingText ?? KunMessagesScope.of(context).select.loading,
        color: scheme.primary.solid,
        scheme: scheme,
      );
    } else if (shown.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 3,
          vertical: KunSpacing.unit * 6,
        ),
        child: Text(
          widget.noResultText ?? KunMessagesScope.of(context).select.noResult,
          textAlign: TextAlign.center,
          style: KunText.sm.copyWith(color: scheme.neutral.shade400),
        ),
      );
    } else {
      list = ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: CustomScrollView(
          key: const ValueKey<String>('KunSelect.list'),
          shrinkWrap: true,
          primary: false,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                role: SemanticsRole.list,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int index = 0; index < shown.length; index++)
                      _KunSelectOptionRow<T, O>(
                        key: state._rowKeys[index],
                        state: state,
                        option: shown[index],
                        index: index,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.searchable) _KunSelectSearchField<T, O>(state: state),
        Flexible(
          fit: FlexFit.loose,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KunRadius.sm),
            child: DefaultTextStyle.merge(
              style: KunText.sm.copyWith(color: scheme.foreground),
              child: SelectionContainer.disabled(child: list),
            ),
          ),
        ),
      ],
    );

    return Listener(
      onPointerDown: (_) => state._setRingSuppressed(true),
      child: DecoratedBox(
        key: const ValueKey<String>('KunSelect.popup'),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: KunShadows.md,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: ColoredBox(
            color: scheme.content1,
            child: Padding(
              padding: const EdgeInsets.all(KunSpacing.unit),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _KunSelectSpinner extends StatelessWidget {
  const _KunSelectSpinner({
    required this.text,
    required this.color,
    required this.scheme,
  });

  final String text;
  final Color color;
  final KunColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 3,
          vertical: KunSpacing.unit * 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KunSpinner(size: KunSpacing.unit * 6, color: color),
            const SizedBox(height: KunSpacing.unit * 3),
            Text(
              text,
              textAlign: TextAlign.center,
              style: KunText.sm.copyWith(color: scheme.neutral.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _KunSelectOptionRow<T, O extends KunSelectOption<T>>
    extends StatelessWidget {
  const _KunSelectOptionRow({
    super.key,
    required this.state,
    required this.option,
    required this.index,
  });

  final _KunSelectState<T, O> state;
  final O option;
  final int index;

  @override
  Widget build(BuildContext context) {
    final KunSelect<T, O> widget = state.widget;
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final bool selected = state._selectedSet.contains(option.value);
    final bool active =
        !state._showSpinner && index == state._activeIndex && !option.disabled;
    final double em =
        DefaultTextStyle.of(context).style.fontSize ?? KunText.sm.fontSize!;
    final Widget content = widget.optionBuilder?.call(
          context,
          option,
          index,
          active,
          selected,
        ) ??
        Text(
          option.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

    Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KunSpacing.unit * 3,
        vertical: KunSpacing.unit * 2,
      ),
      child: Row(
        spacing: KunSpacing.unit * 2,
        children: [
          Expanded(child: content),
          if (selected)
            Icon(
              KunIcons.check,
              size: em,
              color: scheme.primary.solid,
            ),
        ],
      ),
    );

    row = DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? scheme.neutral.shade100.withValues(alpha: KunColors.globalOpacity)
            : null,
        borderRadius: BorderRadius.circular(KunRadius.md),
      ),
      child: DefaultTextStyle.merge(
        style: KunText.sm.copyWith(
          color: option.disabled ? scheme.neutral.shade300 : scheme.foreground,
        ),
        child: row,
      ),
    );

    row = MouseRegion(
      cursor: option.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onHover: option.disabled
          ? null
          : (_) {
              state._setActiveIndex(index);
            },
      child: row,
    );

    row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: option.disabled ? null : () => state._selectOption(option),
      child: row,
    );

    return Semantics(
      key: ValueKey<String>('KunSelect.option.$index'),
      container: true,
      excludeSemantics: true,
      role: SemanticsRole.listItem,
      enabled: !option.disabled,
      selected: selected,
      label: option.label,
      onTap: option.disabled ? null : () => state._selectOption(option),
      child: row,
    );
  }
}

class _KunSelectSearchField<T, O extends KunSelectOption<T>>
    extends StatefulWidget {
  const _KunSelectSearchField({required this.state});

  final _KunSelectState<T, O> state;

  @override
  State<_KunSelectSearchField<T, O>> createState() =>
      _KunSelectSearchFieldState<T, O>();
}

class _KunSelectSearchFieldState<T, O extends KunSelectOption<T>>
    extends State<_KunSelectSearchField<T, O>>
    implements TextSelectionGestureDetectorBuilderDelegate {
  late final TextSelectionGestureDetectorBuilder
      _selectionGestureDetectorBuilder;
  bool _focused = false;

  _KunSelectState<T, O> get state => widget.state;

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  @override
  void initState() {
    super.initState();
    _selectionGestureDetectorBuilder =
        TextSelectionGestureDetectorBuilder(delegate: this);
    state._searchFocus.addListener(_handleFocusChange);
    state._searchController.addListener(_handleText);
    _focused = state._searchFocus.hasFocus;
  }

  @override
  void dispose() {
    state._searchFocus.removeListener(_handleFocusChange);
    state._searchController.removeListener(_handleText);
    super.dispose();
  }

  void _handleText() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleFocusChange() {
    final bool focused = state._searchFocus.hasFocus;
    if (focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  void _handleSemanticsTap() {
    if (!state._searchController.selection.isValid) {
      state._searchController.selection = TextSelection.collapsed(
        offset: state._searchController.text.length,
      );
    }
    editableTextKey.currentState?.requestKeyboard();
  }

  void _handleSemanticsFocus() {
    if (!state._searchFocus.hasFocus) {
      state._searchFocus.requestFocus();
    } else {
      editableTextKey.currentState?.requestKeyboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final KunSelect<T, O> widget = state.widget;
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final String placeholder = widget.searchPlaceholder ??
        KunMessagesScope.of(context).select.searchPlaceholder;
    final TextStyle textStyle = KunText.sm.copyWith(color: scheme.foreground);
    final Color ringColor = widget.color.scaleOf(scheme).solid;

    final EditableText editable = EditableText(
      key: editableTextKey,
      controller: state._searchController,
      focusNode: state._searchFocus,
      style: textStyle,
      cursorColor: scheme.foreground,
      backgroundCursorColor: scheme.neutral.shade300,
      // The library's established tint alpha — the same 20% the `light` and
      // `flat` variants use. The web leaves selection to the browser, so
      // there is no upstream token to translate.
      selectionColor: ringColor.withValues(alpha: 0.2),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      maxLines: 1,
      rendererIgnoresPointer: true,
    );

    Widget field = Stack(
      children: [
        if (state._searchController.text.isEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  placeholder,
                  style: textStyle.copyWith(color: scheme.neutral.shade400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        editable,
      ],
    );

    field = TweenAnimationBuilder<BoxShadow>(
      tween: KunFieldRingTween(
        end: kunFieldRing(ringColor, visible: _focused),
      ),
      duration: kunMotion(context, KunDefaultTransition.duration),
      curve: KunDefaultTransition.curve,
      builder: (BuildContext context, BoxShadow ring, Widget? child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: KunSpacing.unit * 2.5,
            vertical: KunSpacing.unit * 1.5,
          ),
          decoration: BoxDecoration(
            color: scheme.content1,
            border: Border.all(color: scheme.border),
            borderRadius: BorderRadius.circular(KunRadius.sm),
            boxShadow: <BoxShadow>[
              ring,
              ...KunShadows.sm,
            ],
          ),
          child: child,
        );
      },
      child: field,
    );

    field = Semantics(
      enabled: true,
      onTap: _handleSemanticsTap,
      onFocus: _handleSemanticsFocus,
      child: TextFieldTapRegion(
        child: _selectionGestureDetectorBuilder.buildGestureDetector(
          behavior: HitTestBehavior.translucent,
          child: field,
        ),
      ),
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: (FocusNode node, KeyEvent event) => state._onKey(event),
      child: Padding(
        padding: const EdgeInsets.all(KunSpacing.unit),
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: field,
        ),
      ),
    );
  }
}
