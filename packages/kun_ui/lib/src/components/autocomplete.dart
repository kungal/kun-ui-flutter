import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/anchored.dart';
import '../foundation/design.dart';
import '../foundation/dismiss_layers.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'input.dart';
import 'spinner.dart';

/// One suggestion in a [KunAutocomplete].
@immutable
class KunAutocompleteOption {
  /// Creates an option.
  const KunAutocompleteOption({
    required this.value,
    required this.label,
    this.disabled = false,
  });

  /// What the application identifies the option by. The field's text is
  /// [label]; this is what reaches `onSelected`.
  final String value;

  /// The text shown in the list, and the text the field takes when the
  /// option is chosen.
  final String label;

  /// Whether the option cannot be chosen. It is skipped by the arrow keys.
  final bool disabled;

  @override
  bool operator ==(Object other) =>
      other is KunAutocompleteOption &&
      other.value == value &&
      other.label == label &&
      other.disabled == disabled;

  @override
  int get hashCode => Object.hash(value, label, disabled);
}

/// A text field with a list of suggestions under it.
///
/// The value is the field's *text*, not a chosen option: the user may type
/// anything unless [allowCustomValue] is false, and [onSelected] carries the
/// whole option when one is committed. Filtering is local unless
/// [manualFilter] is set, which hands it to [onSearch] for a remote source.
///
/// This is not [KunSelect] with a search box. A select owns a value out of a
/// closed set and its trigger is a button; an autocomplete owns text and its
/// trigger is the field itself, so the keyboard stays in the field the whole
/// time and the list only suggests.
class KunAutocomplete<T extends KunAutocompleteOption> extends StatefulWidget {
  /// Creates an autocomplete.
  const KunAutocomplete({
    required this.options,
    this.value = '',
    this.onChanged,
    this.onSelected,
    this.onSearch,
    this.optionBuilder,
    this.allowCustomValue = true,
    this.clearable = false,
    this.color = KunUIColor.neutral,
    this.debounce = Duration.zero,
    this.description,
    this.disabled = false,
    this.error,
    this.isInvalid = false,
    this.label,
    this.loading = false,
    this.loadingText,
    this.manualFilter = false,
    this.noResultText,
    this.placeholder,
    this.rounded,
    this.size = KunUISize.md,
    this.semanticLabel,
    super.key,
  });

  /// The suggestions, before filtering.
  final List<T> options;

  /// The field's text.
  final String value;

  /// Called on every edit, and when an option is chosen or the field is
  /// cleared.
  final ValueChanged<String>? onChanged;

  /// Called with the option the user committed by tap or Enter. Free text
  /// accepted through [allowCustomValue] does not call it.
  final ValueChanged<T>? onSelected;

  /// Called with the field's text, [debounce] after the last edit. Pair it
  /// with [manualFilter] for a remote source.
  final ValueChanged<String>? onSearch;

  /// Draws a row in place of its label, the web's `option` slot.
  final Widget Function(BuildContext context, T option, bool active)?
      optionBuilder;

  /// Whether text that matches no option is kept. False clears the field
  /// shortly after it loses focus.
  final bool allowCustomValue;

  /// Whether to show a button that empties the field.
  final bool clearable;

  /// The focus ring's hue. The resting border and text stay neutral.
  final KunUIColor color;

  /// How long after the last edit [onSearch] fires. Zero fires on every
  /// edit. While the timer is armed the list shows the spinner, so the gap
  /// before a request never reads as "no matches".
  final Duration debounce;

  /// Helper text under the field; hidden while [error] is set.
  final String? description;

  /// Whether the field is inert and dimmed.
  final bool disabled;

  /// An error under the field, which also turns the border and ring danger.
  final String? error;

  /// Whether to show the invalid styling without a message.
  final bool isInvalid;

  /// A label above the field.
  final String? label;

  /// Whether a request is in flight: the list shows a spinner instead of
  /// options or the no-result line.
  final bool loading;

  /// Replaces the locale's loading line.
  final String? loadingText;

  /// Whether the application filters [options] itself, in [onSearch].
  final bool manualFilter;

  /// Replaces the locale's no-result line.
  final String? noResultText;

  /// Placeholder text for the empty field.
  final String? placeholder;

  /// Corner rounding; defaults to [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// The control scale.
  final KunUISize size;

  /// The field's accessible name when it has no visible [label].
  final String? semanticLabel;

  @override
  State<KunAutocomplete<T>> createState() => _KunAutocompleteState<T>();
}

/// The web's `offset: 4` between the field and its list.
const double _kListOffset = 4;

/// The web's `maxHeight: min(280, availableHeight - 8)`.
const double _kListMaxHeight = 280;

/// How long after losing focus a rejected custom value is cleared. The web
/// defers by the same 120ms so a tap on an option still lands first.
const Duration _kBlurGrace = Duration(milliseconds: 120);

class _KunAutocompleteState<T extends KunAutocompleteOption>
    extends State<KunAutocomplete<T>> with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final Object _tapGroup = Object();
  final GlobalKey _fieldKey = GlobalKey(debugLabel: 'KunAutocomplete.field');
  final ScrollController _listScroll = ScrollController();

  late final AnimationController _openClose;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;

  bool _isOpen = false;
  bool _dirty = false;
  bool _pending = false;
  int _activeIndex = -1;
  Timer? _searchTimer;
  Timer? _blurTimer;
  final ValueNotifier<KunAnchorResolution> _resolved =
      ValueNotifier<KunAnchorResolution>(
    const KunAnchorResolution(side: KunAnchorSide.bottom, arrowCross: 0),
  );

  @override
  void initState() {
    super.initState();
    _openClose = AnimationController(
      vsync: this,
      duration: KunDurations.base,
      reverseDuration: KunDurations.exit,
    );
    _curve = CurvedAnimation(
      parent: _openClose,
      curve: KunEasing.enter,
      reverseCurve: KunEasing.exit,
    );
    _scale = Tween<double>(begin: 0.95, end: 1).animate(_curve);
    _openClose.addListener(_hidePortalIfDismissed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openClose.duration = kunMotion(context, KunDurations.base);
    _openClose.reverseDuration = kunMotion(context, KunDurations.exit);
  }

  @override
  void didUpdateWidget(KunAutocomplete<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disabled && _isOpen) {
      _close();
    }
    if (_isOpen) {
      _repairActive();
    }
  }

  @override
  void dispose() {
    KunDismissLayers.remove(this);
    _searchTimer?.cancel();
    _blurTimer?.cancel();
    _openClose.removeListener(_hidePortalIfDismissed);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _openClose.dispose();
    _curve.dispose();
    _listScroll.dispose();
    _resolved.dispose();
    super.dispose();
  }

  void _hidePortalIfDismissed() {
    if (!_isOpen && _openClose.value == 0 && _portal.isShowing) {
      _portal.hide();
    }
  }

  List<T> _filter(String query) {
    if (widget.manualFilter || query.trim().isEmpty) {
      return widget.options;
    }
    final String q = query.trim().toLowerCase();
    return <T>[
      for (final T option in widget.options)
        if (option.label.toLowerCase().contains(q)) option,
    ];
  }

  List<T> get _shown => _dirty ? _filter(widget.value) : widget.options;

  bool get _showSpinner => widget.loading || _pending;

  int _firstEnabled(List<T> list) =>
      list.indexWhere((T option) => !option.disabled);

  void _repairActive() {
    final List<T> shown = _shown;
    if (_activeIndex < 0 ||
        _activeIndex >= shown.length ||
        shown[_activeIndex].disabled) {
      _activeIndex = _firstEnabled(shown);
    }
  }

  void _open() {
    if (widget.disabled || _isOpen) {
      return;
    }
    KunDismissLayers.add(this);
    setState(() {
      _isOpen = true;
      _activeIndex = _firstEnabled(_shown);
    });
    _portal.show();
    _openClose.forward();
  }

  void _close() {
    if (!_isOpen) {
      return;
    }
    KunDismissLayers.remove(this);
    setState(() => _isOpen = false);
    _openClose.reverse();
  }

  void _cancelPendingSearch() {
    _searchTimer?.cancel();
    _searchTimer = null;
    if (_pending) {
      setState(() => _pending = false);
    }
  }

  void _emitSearch(String query, {bool immediate = false}) {
    _cancelPendingSearch();
    if (immediate || widget.debounce <= Duration.zero) {
      widget.onSearch?.call(query);
      return;
    }
    setState(() => _pending = true);
    _searchTimer = Timer(widget.debounce, () {
      _searchTimer = null;
      if (!mounted) {
        return;
      }
      setState(() => _pending = false);
      widget.onSearch?.call(query);
    });
  }

  void _onInput(String text) {
    _dirty = true;
    widget.onChanged?.call(text);
    _emitSearch(text);
    _open();
    // Everything here runs off the text just typed, never off widget.value:
    // that is still the pre-keystroke text until the parent rebuilds, and the
    // web's port of this bug searched one keystroke behind.
    setState(() => _activeIndex = _firstEnabled(_filter(text)));
  }

  void _select(T option) {
    if (option.disabled) {
      return;
    }
    _cancelPendingSearch();
    _dirty = false;
    widget.onChanged?.call(option.label);
    widget.onSelected?.call(option);
    _close();
  }

  void _clear() {
    _dirty = true;
    widget.onChanged?.call('');
    _emitSearch('', immediate: true);
    _open();
  }

  void _move(int delta) {
    final List<T> shown = _shown;
    if (shown.isEmpty) {
      return;
    }
    int cursor = _activeIndex;
    for (int step = 0; step < shown.length; step++) {
      cursor = (cursor + delta + shown.length) % shown.length;
      if (!shown[cursor].disabled) {
        setState(() => _activeIndex = cursor);
        _scrollActiveIntoView();
        return;
      }
    }
  }

  void _scrollActiveIntoView() {
    if (!_listScroll.hasClients || _activeIndex < 0) {
      return;
    }
    final double row = _rowHeight;
    final double top = _activeIndex * row;
    final double bottom = top + row;
    final double viewTop = _listScroll.offset;
    final double viewBottom = viewTop + _listScroll.position.viewportDimension;
    if (top < viewTop) {
      _listScroll.jumpTo(math.max(0, top));
    } else if (bottom > viewBottom) {
      _listScroll.jumpTo(
        math.min(_listScroll.position.maxScrollExtent,
            bottom - (viewBottom - viewTop)),
      );
    }
  }

  /// A row is the web's `py-2` either side of one line of `text-sm`.
  double get _rowHeight =>
      KunText.sm.fontSize! * KunText.sm.height! + KunSpacing.unit * 2 * 2;

  void _onFocusChange(bool focused) {
    if (focused) {
      _blurTimer?.cancel();
      _blurTimer = null;
      _open();
      return;
    }
    _close();
    if (widget.allowCustomValue || widget.value.isEmpty) {
      return;
    }
    // Deferred so a tap on an option commits before the text is judged.
    _blurTimer = Timer(_kBlurGrace, () {
      _blurTimer = null;
      if (!mounted) {
        return;
      }
      final bool matches = widget.options.any(
        (T option) => option.label.toLowerCase() == widget.value.toLowerCase(),
      );
      if (!matches) {
        widget.onChanged?.call('');
        _emitSearch('', immediate: true);
      }
    });
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || widget.disabled) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _isOpen ? _move(1) : _open();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (_isOpen) {
          _move(-1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.enter:
        final List<T> shown = _shown;
        if (_isOpen && _activeIndex >= 0 && _activeIndex < shown.length) {
          _select(shown[_activeIndex]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.escape:
        if (_isOpen) {
          _close();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.tab:
        _close();
        return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  void _onResolved(KunAnchorResolution resolution) {
    if (_resolved.value == resolution) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resolved.value = resolution;
      }
    });
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunUIRounded rounded = widget.rounded ?? theme.rounded;
    final double radius =
        (rounded == KunUIRounded.full ? KunUIRounded.lg : rounded).radius;
    final Rect anchor = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    final List<T> shown = _shown;
    final KunMessages messages = KunMessagesScope.of(context);

    Widget body;
    if (_showSpinner) {
      body = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 3,
          vertical: KunSpacing.unit * 6,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: KunSpacing.unit * 2,
          children: <Widget>[
            KunSpinner(
              size: KunSpacing.unit * 6,
              color: scheme.primary.solid,
              semanticLabel:
                  widget.loadingText ?? messages.autocomplete.loading,
            ),
            Text(
              widget.loadingText ?? messages.autocomplete.loading,
              style: KunText.sm.copyWith(color: scheme.neutral.shade600),
            ),
          ],
        ),
      );
    } else if (shown.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 3,
          vertical: KunSpacing.unit * 6,
        ),
        child: Text(
          widget.noResultText ?? messages.autocomplete.noResult,
          textAlign: TextAlign.center,
          style: KunText.sm.copyWith(color: scheme.neutral.shade400),
        ),
      );
    } else {
      body = ListView.builder(
        controller: _listScroll,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: shown.length,
        itemExtent: _rowHeight,
        itemBuilder: (BuildContext context, int index) =>
            _KunAutocompleteRow<T>(
          key: ValueKey<String>('KunAutocomplete.option.${shown[index].value}'),
          option: shown[index],
          active: index == _activeIndex && !shown[index].disabled,
          scheme: scheme,
          builder: widget.optionBuilder,
          onHover: () {
            if (!shown[index].disabled && _activeIndex != index) {
              setState(() => _activeIndex = index);
            }
          },
          onTap: () => _select(shown[index]),
        ),
      );
    }

    final Widget panel = DecoratedBox(
      key: const ValueKey<String>('KunAutocomplete.list'),
      decoration: BoxDecoration(
        color: scheme.content1,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: KunShadows.md,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: const EdgeInsets.all(KunSpacing.unit),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            role: SemanticsRole.list,
            child: body,
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: TapRegion(
        groupId: _tapGroup,
        child: CustomSingleChildLayout(
          delegate: _KunAutocompleteListLayout(
            anchor: anchor,
            viewport: kunAnchorViewport(context, info.overlaySize),
            onResolved: _onResolved,
          ),
          child: FadeTransition(
            opacity: _curve,
            child: ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[_scale, _resolved]),
              builder: (BuildContext context, Widget? child) => Transform.scale(
                scale: _scale.value,
                alignment: kunAnchorOrigin(
                  _resolved.value.side,
                  KunAnchorAlign.start,
                ),
                child: child,
              ),
              child: panel,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget field = KunInput(
      key: _fieldKey,
      value: widget.value,
      onChanged: _onInput,
      onClear: _clear,
      isClearable: widget.clearable,
      label: widget.label,
      placeholder: widget.placeholder,
      description: widget.description,
      error: widget.error,
      isInvalid: widget.isInvalid,
      disabled: widget.disabled,
      color: widget.color,
      size: widget.size,
      rounded: widget.rounded,
    );

    final Widget named = widget.semanticLabel == null || widget.label != null
        ? field
        // KunInput names its field from the visible label; this one may have
        // none, and a combobox with no name is what `ariaLabel` exists for.
        : Semantics(label: widget.semanticLabel, child: field);

    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && KunDismissLayers.isTop(this)) {
          _close();
        }
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        // The field owns the keyboard, so the list's keys are caught on the
        // way up from it rather than by a node of their own — the panel is an
        // overlay child and focus must never leave the field while it is open.
        onKeyEvent: (FocusNode node, KeyEvent event) => _onKey(event),
        onFocusChange: _onFocusChange,
        child: TapRegion(
          groupId: _tapGroup,
          onTapOutside: (PointerDownEvent event) {
            if (_isOpen) {
              _close();
            }
          },
          child: OverlayPortal.overlayChildLayoutBuilder(
            controller: _portal,
            overlayLocation: OverlayChildLocation.rootOverlay,
            overlayChildBuilder: _buildOverlay,
            child: named,
          ),
        ),
      ),
    );
  }
}

/// The list matches the field's width and caps at 280, the web's `size()`
/// middleware; it is otherwise the shared placement.
class _KunAutocompleteListLayout extends KunAnchoredLayout {
  _KunAutocompleteListLayout({
    required super.anchor,
    required super.viewport,
    required super.onResolved,
  }) : super(
          side: KunAnchorSide.bottom,
          align: KunAnchorAlign.start,
          offset: _kListOffset,
        );

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final BoxConstraints shared = super.getConstraintsForChild(constraints);
    return BoxConstraints(
      minWidth: anchor.width,
      maxWidth: anchor.width,
      maxHeight: math.min(_kListMaxHeight, shared.maxHeight),
    );
  }
}

class _KunAutocompleteRow<T extends KunAutocompleteOption>
    extends StatelessWidget {
  const _KunAutocompleteRow({
    required this.option,
    required this.active,
    required this.scheme,
    required this.builder,
    required this.onHover,
    required this.onTap,
    super.key,
  });

  final T option;
  final bool active;
  final KunColorScheme scheme;
  final Widget Function(BuildContext context, T option, bool active)? builder;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = builder?.call(context, option, active) ??
        Text(
          option.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KunText.sm.copyWith(
            color:
                option.disabled ? scheme.neutral.shade300 : scheme.foreground,
          ),
        );

    return Semantics(
      selected: active,
      enabled: !option.disabled,
      label: option.label,
      onTap: option.disabled ? null : onTap,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: option.disabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onHover: (_) => onHover(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: option.disabled ? null : onTap,
            child: Container(
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(
                horizontal: KunSpacing.unit * 3,
              ),
              decoration: BoxDecoration(
                color: active ? scheme.neutral.shade100 : null,
                borderRadius: BorderRadius.circular(KunRadius.md),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
