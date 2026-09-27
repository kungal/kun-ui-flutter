import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../chat/types.dart';
import '../config/config.dart';
import '../foundation/focus_outline.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';

/// Web `size-8` reaction art.
const double _kArtSize = 32;

/// Web `hover:scale-110`.
const double _kHoverScale = 1.1;

/// The reaction vocabulary as a grid.
///
/// One reaction per person: choosing another replaces the current one,
/// choosing the current one removes it.
class KunChatReactionPicker extends StatefulWidget {
  /// Creates a reaction picker.
  const KunChatReactionPicker({
    super.key,
    required this.options,
    this.semanticLabel,
    this.columns = 8,
    this.value,
    this.onChanged,
    this.autofocus = false,
  });

  /// The reaction vocabulary, as `GET /v2/chat/reactions` serves it.
  final List<KunChatReactionOption> options;

  /// Accessible name of the grid (web `ariaLabel`). Defaults to the locale
  /// `chat.reactions` string.
  final String? semanticLabel;

  /// Columns of the grid.
  final int columns;

  /// The viewer's current reaction key, or null (web `modelValue`).
  final String? value;

  /// A reaction was chosen: its key, or null when the current one was chosen
  /// again.
  final ValueChanged<String?>? onChanged;

  /// Focus the current cell when the picker is first built. Stands in for
  /// the web's exposed `focus()`.
  final bool autofocus;

  @override
  State<KunChatReactionPicker> createState() => _KunChatReactionPickerState();
}

class _KunChatReactionPickerState extends State<KunChatReactionPicker> {
  int _active = 0;
  List<FocusNode> _nodes = const <FocusNode>[];

  @override
  void initState() {
    super.initState();
    _syncNodes();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _nodes.isNotEmpty) {
          _focusAt(_active);
        }
      });
    }
  }

  @override
  void didUpdateWidget(KunChatReactionPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      _syncNodes();
    }
  }

  @override
  void dispose() {
    for (final FocusNode node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncNodes() {
    final int n = widget.options.length;
    if (_nodes.length > n) {
      for (int i = n; i < _nodes.length; i++) {
        _nodes[i].dispose();
      }
      _nodes = _nodes.sublist(0, n);
    } else if (_nodes.length < n) {
      _nodes = <FocusNode>[
        ..._nodes,
        for (int i = _nodes.length; i < n; i++)
          FocusNode(debugLabel: 'KunChatReactionPicker.$i'),
      ];
    }
    if (n == 0) {
      _active = 0;
      return;
    }
    _active = _active.clamp(0, n - 1);
  }

  void _focusAt(int index) {
    final int n = widget.options.length;
    if (n == 0) {
      return;
    }
    setState(() => _active = ((index % n) + n) % n);
    _nodes[_active].requestFocus();
  }

  void _choose(String key) {
    widget.onChanged?.call(widget.value == key ? null : key);
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      _focusAt(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _focusAt(index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusAt(index + widget.columns);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _focusAt(index - widget.columns);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _focusAt(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _focusAt(widget.options.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final String label =
        widget.semanticLabel ?? KunMessagesScope.of(context).chat.reactions;
    final int columns = widget.columns < 1 ? 1 : widget.columns;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.options.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: KunSpacing.unit * 0.5,
          crossAxisSpacing: KunSpacing.unit * 0.5,
        ),
        itemBuilder: (BuildContext context, int i) {
          final KunChatReactionOption option = widget.options[i];
          return _ReactionCell(
            option: option,
            selected: widget.value == option.key,
            autofocus: widget.autofocus && i == _active,
            focusNode: _nodes[i],
            skipTraversal: i != _active,
            primary: scheme.primary.solid,
            idle: scheme.neutral.solid,
            onFocus: () {
              if (_active != i) {
                setState(() => _active = i);
              }
            },
            onKey: (KeyEvent event) => _onKey(i, event),
            onChoose: () => _choose(option.key),
          );
        },
      ),
    );
  }
}

class _ReactionCell extends StatefulWidget {
  const _ReactionCell({
    required this.option,
    required this.selected,
    required this.autofocus,
    required this.focusNode,
    required this.skipTraversal,
    required this.primary,
    required this.idle,
    required this.onFocus,
    required this.onKey,
    required this.onChoose,
  });

  final KunChatReactionOption option;
  final bool selected;
  final bool autofocus;
  final FocusNode focusNode;
  final bool skipTraversal;
  final Color primary;
  final Color idle;
  final VoidCallback onFocus;
  final KeyEventResult Function(KeyEvent event) onKey;
  final VoidCallback onChoose;

  @override
  State<_ReactionCell> createState() => _ReactionCellState();
}

class _ReactionCellState extends State<_ReactionCell> {
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.onKeyEvent = _onKey;
  }

  @override
  void didUpdateWidget(_ReactionCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.onKeyEvent = null;
      widget.focusNode.onKeyEvent = _onKey;
    }
  }

  @override
  void dispose() {
    widget.focusNode.onKeyEvent = null;
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) => widget.onKey(event);

  @override
  Widget build(BuildContext context) {
    final Color? fill = widget.selected
        ? widget.primary.withValues(alpha: 0.2)
        : (_hovered ? widget.idle.withValues(alpha: 0.2) : null);
    final String? imageUrl = widget.option.imageUrl;
    final Widget glyph = imageUrl != null && imageUrl.isNotEmpty
        ? Image(
            image: KunUIConfigScope.of(context).imageProvider(imageUrl),
            width: _kArtSize,
            height: _kArtSize,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          )
        : ExcludeSemantics(
            child: Text(
              widget.option.emoji,
              style: KunText.xl2.copyWith(
                height: 1,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          );

    widget.focusNode.skipTraversal = widget.skipTraversal;

    return Semantics(
      container: true,
      button: true,
      toggled: widget.selected,
      label: widget.option.label,
      onTap: widget.onChoose,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        descendantsAreFocusable: false,
        descendantsAreTraversable: false,
        onShowFocusHighlight: (bool value) => setState(() => _focused = value),
        onFocusChange: (bool focused) {
          if (focused) {
            widget.onFocus();
          }
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onChoose();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              widget.onChoose();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: widget.onChoose,
            child: KunFocusOutline(
              visible: _focused,
              color: widget.primary,
              offset: 2,
              borderRadius: BorderRadius.circular(KunRadius.md),
              child: AnimatedScale(
                scale: _hovered ? _kHoverScale : 1,
                duration: kunMotion(context, KunDefaultTransition.duration),
                curve: KunDefaultTransition.curve,
                child: AnimatedContainer(
                  duration: kunMotion(context, KunDefaultTransition.duration),
                  curve: KunDefaultTransition.curve,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(KunRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: glyph,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
