import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../chat/types.dart';
import '../foundation/anchored.dart';
import '../foundation/design.dart';
import '../foundation/dismiss_layers.dart';
import '../foundation/motion.dart';
import '../foundation/variant_style.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'chat_reaction_picker.dart';
import 'chat_shared.dart';

/// Web `pad = 8` in `ChatMessageMenu.vue:78`.
const double _kClamp = 8;

/// Web `max-h-72` on the expanded picker scroller.
const double _kPickerMaxHeight = 288;

/// Web `hover:scale-110`.
const double _kHoverScale = 1.1;

/// Web `min-w-52`.
const double _kMinWidth = KunSpacing.unit * 52;

/// Web `w-76` on the expanded picker.
const double _kPickerWidth = KunSpacing.unit * 76;

/// Web `size-9` quick-reaction hit target.
const double _kQuickSize = KunSpacing.unit * 9;

/// Web `size-7` reaction art in the quick row.
const double _kQuickArt = KunSpacing.unit * 7;

/// Web `size-8` expand button.
const double _kMoreSize = KunSpacing.unit * 8;

/// A built-in message action. Each has its own label and icon.
enum KunChatMessageActionKey {
  /// Wire `reply`.
  reply('reply'),

  /// Wire `quote`.
  quote('quote'),

  /// Wire `copy`.
  copy('copy'),

  /// Wire `edit`.
  edit('edit'),

  /// Wire `pin`.
  pin('pin'),

  /// Wire `unpin`.
  unpin('unpin'),

  /// Wire `delete`.
  delete('delete'),

  /// Wire `report`.
  report('report'),

  /// Wire `retry`.
  retry('retry');

  /// Creates a value with this [wireName].
  const KunChatMessageActionKey(this.wireName);

  /// The web string for this key.
  final String wireName;
}

/// An action of a [KunChatMessageMenu]: a built-in key, or an item of the
/// site's own.
@immutable
sealed class KunChatMessageAction {
  /// Creates an action.
  const KunChatMessageAction();

  /// Built-in `reply`.
  static const KunChatBuiltInAction reply = KunChatBuiltInAction(
    KunChatMessageActionKey.reply,
  );

  /// Built-in `quote`.
  static const KunChatBuiltInAction quote = KunChatBuiltInAction(
    KunChatMessageActionKey.quote,
  );

  /// Built-in `copy`.
  static const KunChatBuiltInAction copy = KunChatBuiltInAction(
    KunChatMessageActionKey.copy,
  );

  /// Built-in `edit`.
  static const KunChatBuiltInAction edit = KunChatBuiltInAction(
    KunChatMessageActionKey.edit,
  );

  /// Built-in `pin`.
  static const KunChatBuiltInAction pin = KunChatBuiltInAction(
    KunChatMessageActionKey.pin,
  );

  /// Built-in `unpin`.
  static const KunChatBuiltInAction unpin = KunChatBuiltInAction(
    KunChatMessageActionKey.unpin,
  );

  /// Built-in `delete`.
  static const KunChatBuiltInAction delete = KunChatBuiltInAction(
    KunChatMessageActionKey.delete,
  );

  /// Built-in `report`.
  static const KunChatBuiltInAction report = KunChatBuiltInAction(
    KunChatMessageActionKey.report,
  );

  /// Built-in `retry`.
  static const KunChatBuiltInAction retry = KunChatBuiltInAction(
    KunChatMessageActionKey.retry,
  );
}

/// A built-in action whose label, icon and colour come from the catalog.
@immutable
class KunChatBuiltInAction extends KunChatMessageAction {
  /// Creates a built-in action for [key].
  const KunChatBuiltInAction(this.key);

  /// Which built-in this is.
  final KunChatMessageActionKey key;

  /// The web string for [key].
  String get wireName => key.wireName;

  @override
  bool operator ==(Object other) =>
      other is KunChatBuiltInAction && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// An action of the site's own.
@immutable
class KunChatMessageMenuItem extends KunChatMessageAction {
  /// Creates a custom action.
  const KunChatMessageMenuItem({
    required this.key,
    required this.label,
    this.icon,
    this.color,
    this.disabled = false,
  });

  /// Identifies the item to the application; never shown.
  final String key;

  /// The row's text.
  final String label;

  /// Drawn before [label].
  final IconData? icon;

  /// Tints the row, through the `light` variant. Null is the web `default`.
  final KunUIColor? color;

  /// Whether the row is inert.
  final bool disabled;

  @override
  bool operator ==(Object other) =>
      other is KunChatMessageMenuItem &&
      other.key == key &&
      other.label == label &&
      other.icon == icon &&
      other.color == color &&
      other.disabled == disabled;

  @override
  int get hashCode => Object.hash(key, label, icon, color, disabled);
}

class _ResolvedAction {
  const _ResolvedAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.disabled,
  });

  final String key;
  final String label;
  final IconData? icon;
  final KunUIColor color;
  final bool disabled;
}

/// The long-press / right-click menu of a message: a row of quick reactions
/// on top, which expands into a full [KunChatReactionPicker], over a list of
/// actions.
class KunChatMessageMenu extends StatefulWidget {
  /// Creates a message menu.
  const KunChatMessageMenu({
    super.key,
    required this.visible,
    this.actions = const <KunChatMessageAction>[
      KunChatMessageAction.reply,
      KunChatMessageAction.copy,
    ],
    this.currentReaction,
    this.position,
    this.quickReactions = 7,
    this.reactions = const <KunChatReactionOption>[],
    this.onClose,
    this.onReact,
    this.onSelect,
  });

  /// Whether the menu is open. It asks to close by calling [onClose]; it never
  /// hides itself.
  final bool visible;

  /// The actions, in order: built-in keys, or items of your own.
  final List<KunChatMessageAction> actions;

  /// The viewer's current reaction on the message, highlighted.
  final String? currentReaction;

  /// Viewport point to open at — the cursor, or the long-press point. Null is
  /// the web's `{ x: 0, y: 0 }`.
  final Offset? position;

  /// How many reactions the row shows before the expand button.
  final int quickReactions;

  /// The quick-reaction row on top; empty hides it.
  final List<KunChatReactionOption> reactions;

  /// The menu closed, for any reason.
  final VoidCallback? onClose;

  /// A reaction was chosen: its key, or null when the current one was chosen
  /// again.
  final ValueChanged<String?>? onReact;

  /// An action was chosen: a built-in key's [KunChatMessageActionKey.wireName]
  /// or a custom item's [KunChatMessageMenuItem.key].
  final ValueChanged<String>? onSelect;

  @override
  State<KunChatMessageMenu> createState() => _KunChatMessageMenuState();
}

class _KunChatMessageMenuState extends State<KunChatMessageMenu>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final Object _tapGroup = Object();
  final GlobalKey _panelKey = GlobalKey();
  final FocusNode _panelFocus = FocusNode(debugLabel: 'KunChatMessageMenu');
  final List<FocusNode> _itemFocus = <FocusNode>[];
  final List<FocusNode> _quickFocus = <FocusNode>[];

  late final AnimationController _openClose;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;

  bool _isOpen = false;
  bool _expanded = false;
  bool _restoreFocus = false;
  bool _scrollRoute = false;
  Size? _viewSize;
  FocusNode? _previouslyFocused;

  bool get _hasContent =>
      widget.actions.isNotEmpty || widget.reactions.isNotEmpty;

  int get _quickCap => widget.quickReactions < 0 ? 0 : widget.quickReactions;

  int get _quickShown => math.min(_quickCap, widget.reactions.length);

  bool get _hasMore => widget.reactions.length > _quickCap;

  int get _quickNodeCount => _quickShown + (_hasMore ? 1 : 0);

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
    _syncFocusNodes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncOpen();
      }
    });
  }

  @override
  void didUpdateWidget(KunChatMessageMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions.length != widget.actions.length ||
        oldWidget.reactions.length != widget.reactions.length ||
        oldWidget.quickReactions != widget.quickReactions) {
      _syncFocusNodes();
    }
    final bool want = widget.visible && _hasContent;
    if (want != _isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncOpen();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openClose.duration = kunMotion(context, KunDurations.base);
    _openClose.reverseDuration = kunMotion(context, KunDurations.exit);
    final Size size = MediaQuery.sizeOf(context);
    if (_isOpen && _viewSize != null && size != _viewSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestClose();
        }
      });
    }
    _viewSize = size;
  }

  @override
  void dispose() {
    _removeScrollClose();
    KunDismissLayers.remove(this);
    _openClose.removeListener(_hidePortalIfDismissed);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _openClose.dispose();
    _curve.dispose();
    _panelFocus.dispose();
    for (final FocusNode node in _itemFocus) {
      node.dispose();
    }
    for (final FocusNode node in _quickFocus) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncFocusNodes() {
    _resizeNodes(_itemFocus, widget.actions.length, 'item');
    _resizeNodes(_quickFocus, _quickNodeCount, 'quick');
  }

  void _resizeNodes(List<FocusNode> nodes, int count, String label) {
    if (nodes.length > count) {
      for (int i = count; i < nodes.length; i++) {
        nodes[i].dispose();
      }
      nodes.removeRange(count, nodes.length);
    } else {
      while (nodes.length < count) {
        nodes.add(
          FocusNode(debugLabel: 'KunChatMessageMenu.$label.${nodes.length}'),
        );
      }
    }
  }

  void _hidePortalIfDismissed() {
    if (_isOpen || _openClose.value != 0 || !_portal.isShowing) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _hidePortalIfDismissed();
        }
      });
      return;
    }
    _portal.hide();
  }

  void _syncOpen() {
    final bool want = widget.visible && _hasContent;
    if (want && !_isOpen) {
      _present();
    } else if (!want && _isOpen) {
      _dismissVisual();
    }
  }

  void _present() {
    if (_isOpen || !mounted || !widget.visible || !_hasContent) {
      return;
    }
    _previouslyFocused = FocusManager.instance.primaryFocus;
    _restoreFocus = false;
    _expanded = false;
    _isOpen = true;
    KunDismissLayers.add(this);
    _installScrollClose();
    if (!_portal.isShowing) {
      _portal.show();
    }
    _openClose.forward();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isOpen) {
        _focusInitial();
      }
    });
  }

  void _dismissVisual() {
    if (!_isOpen) {
      return;
    }
    _isOpen = false;
    _expanded = false;
    KunDismissLayers.remove(this);
    _removeScrollClose();
    _openClose.reverse();
    if (_restoreFocus) {
      _previouslyFocused?.requestFocus();
    }
    _restoreFocus = false;
    setState(() {});
  }

  void _requestClose({bool returnFocus = false}) {
    if (!_isOpen) {
      return;
    }
    _restoreFocus = returnFocus;
    widget.onClose?.call();
  }

  void _installScrollClose() {
    if (_scrollRoute) {
      return;
    }
    _scrollRoute = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  void _removeScrollClose() {
    if (!_scrollRoute) {
      return;
    }
    _scrollRoute = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
  }

  void _onPointer(PointerEvent event) {
    if (event is! PointerScrollEvent || !_isOpen) {
      return;
    }
    final Rect? panel = _panelRect();
    if (panel != null && panel.contains(event.position)) {
      return;
    }
    _requestClose();
  }

  Rect? _panelRect() {
    final RenderObject? ro = _panelKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) {
      return null;
    }
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  void _focusInitial() {
    if (_itemFocus.isNotEmpty) {
      _itemFocus.first.requestFocus();
    } else if (_quickFocus.isNotEmpty) {
      _quickFocus.first.requestFocus();
    } else {
      _panelFocus.requestFocus();
    }
  }

  bool get _inQuickRow => _quickFocus.any((FocusNode n) => n.hasPrimaryFocus);

  void _focusQuick(int index) {
    if (_quickFocus.isEmpty) {
      return;
    }
    final int n = _quickFocus.length;
    _quickFocus[((index % n) + n) % n].requestFocus();
  }

  void _moveQuick(int delta) {
    if (_quickFocus.isEmpty) {
      return;
    }
    int i = _quickFocus.indexWhere((FocusNode n) => n.hasPrimaryFocus);
    if (i < 0) {
      i = 0;
    }
    _focusQuick(i + delta);
  }

  void _focusItem(int index) {
    if (_itemFocus.isEmpty) {
      return;
    }
    final int n = _itemFocus.length;
    _itemFocus[((index % n) + n) % n].requestFocus();
  }

  void _moveItems(int delta) {
    if (_itemFocus.isEmpty) {
      return;
    }
    int i = _itemFocus.indexWhere((FocusNode n) => n.hasPrimaryFocus);
    if (i < 0) {
      _focusItem(delta < 0 ? _itemFocus.length - 1 : 0);
      return;
    }
    _focusItem(i + delta);
  }

  KeyEventResult _onPanelKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final bool inRow = _inQuickRow;
    switch (key) {
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.arrowUp:
        if (_expanded) {
          return KeyEventResult.ignored;
        }
        if (inRow) {
          if (_itemFocus.isEmpty) {
            return KeyEventResult.handled;
          }
          _focusItem(
            key == LogicalKeyboardKey.arrowDown ? 0 : _itemFocus.length - 1,
          );
        } else {
          _moveItems(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
      case LogicalKeyboardKey.end:
        if (_expanded) {
          return KeyEventResult.ignored;
        }
        final bool home = key == LogicalKeyboardKey.home;
        if (inRow) {
          if (_quickFocus.isNotEmpty) {
            _focusQuick(home ? 0 : _quickFocus.length - 1);
          }
        } else if (_itemFocus.isNotEmpty) {
          _focusItem(home ? 0 : _itemFocus.length - 1);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowRight:
        if (!inRow) {
          return KeyEventResult.ignored;
        }
        _moveQuick(key == LogicalKeyboardKey.arrowRight ? 1 : -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _requestClose(returnFocus: true);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.tab:
        if (_quickFocus.isNotEmpty && _itemFocus.isNotEmpty && !_expanded) {
          if (inRow) {
            _focusItem(0);
          } else {
            _focusQuick(0);
          }
        } else {
          _requestClose(returnFocus: true);
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _select(_ResolvedAction item) {
    if (item.disabled) {
      return;
    }
    widget.onSelect?.call(item.key);
    _requestClose(returnFocus: true);
  }

  void _react(String? key) {
    widget.onReact?.call(key);
    _requestClose(returnFocus: true);
  }

  void _toggleReaction(String key) {
    _react(widget.currentReaction == key ? null : key);
  }

  void _expand() {
    setState(() => _expanded = true);
  }

  List<_ResolvedAction> _resolve(KunMessages messages) {
    return <_ResolvedAction>[
      for (final KunChatMessageAction action in widget.actions)
        switch (action) {
          KunChatBuiltInAction(:final KunChatMessageActionKey key) =>
            _ResolvedAction(
              key: key.wireName,
              label: _builtInLabel(messages.chatMenu, key),
              icon: _builtInIcon(key),
              color: _builtInColor(key),
              disabled: false,
            ),
          KunChatMessageMenuItem(
            :final String key,
            :final String label,
            :final IconData? icon,
            :final KunUIColor? color,
            :final bool disabled,
          ) =>
            _ResolvedAction(
              key: key,
              label: label,
              icon: icon,
              color: color ?? KunUIColor.neutral,
              disabled: disabled,
            ),
        },
    ];
  }

  static String _builtInLabel(
    KunChatMenuStrings menu,
    KunChatMessageActionKey key,
  ) {
    return switch (key) {
      KunChatMessageActionKey.reply => menu.reply,
      KunChatMessageActionKey.quote => menu.quote,
      KunChatMessageActionKey.copy => menu.copy,
      KunChatMessageActionKey.edit => menu.edit,
      KunChatMessageActionKey.pin => menu.pin,
      KunChatMessageActionKey.unpin => menu.unpin,
      KunChatMessageActionKey.delete => menu.delete,
      KunChatMessageActionKey.report => menu.report,
      KunChatMessageActionKey.retry => menu.retry,
    };
  }

  static IconData _builtInIcon(KunChatMessageActionKey key) {
    return switch (key) {
      KunChatMessageActionKey.reply => KunIcons.reply,
      KunChatMessageActionKey.quote => KunIcons.quote,
      KunChatMessageActionKey.copy => KunIcons.copy,
      KunChatMessageActionKey.edit => KunIcons.pencil,
      KunChatMessageActionKey.pin => KunIcons.pin,
      KunChatMessageActionKey.unpin => KunIcons.pinOff,
      KunChatMessageActionKey.retry => KunIcons.rotateCw,
      KunChatMessageActionKey.delete => KunIcons.trash2,
      KunChatMessageActionKey.report => KunIcons.flag,
    };
  }

  static KunUIColor _builtInColor(KunChatMessageActionKey key) {
    return switch (key) {
      KunChatMessageActionKey.delete ||
      KunChatMessageActionKey.report =>
        KunUIColor.danger,
      _ => KunUIColor.neutral,
    };
  }

  Offset _overlayPoint(BuildContext overlayContext, Offset global) {
    final OverlayState overlay = Overlay.of(overlayContext);
    final RenderObject? ro = overlay.context.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      return ro.globalToLocal(global);
    }
    return global;
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunMessages messages = KunMessagesScope.of(context);
    final List<_ResolvedAction> items = _resolve(messages);
    final Offset point = _overlayPoint(context, widget.position ?? Offset.zero);
    final Rect viewport = kunAnchorViewport(context, info.overlaySize);

    final Widget panel = _buildPanel(
      context: context,
      theme: theme,
      scheme: scheme,
      messages: messages,
      items: items,
    );

    return Positioned.fill(
      child: TapRegion(
        groupId: _tapGroup,
        child: CustomSingleChildLayout(
          delegate: _KunChatMessageMenuLayout(
            point: point,
            viewport: viewport,
            padding: _kClamp,
            minWidth: _kMinWidth,
          ),
          child: FadeTransition(
            opacity: _curve,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.topLeft,
              child: panel,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel({
    required BuildContext context,
    required KunThemeData theme,
    required KunColorScheme scheme,
    required KunMessages messages,
    required List<_ResolvedAction> items,
  }) {
    final Widget body;
    if (_expanded) {
      body = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = math.min(_kPickerWidth, constraints.maxWidth);
          final double height = math.min(
            _kPickerMaxHeight,
            constraints.maxHeight,
          );
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: height,
              minWidth: width,
              maxWidth: width,
            ),
            child: Padding(
              padding: const EdgeInsets.all(KunSpacing.unit),
              child: SingleChildScrollView(
                child: KunChatReactionPicker(
                  options: widget.reactions,
                  columns: 7,
                  value: widget.currentReaction,
                  autofocus: true,
                  onChanged: _react,
                ),
              ),
            ),
          );
        },
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.reactions.isNotEmpty) _buildQuickRow(context, messages),
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < items.length; i++)
                  _KunChatMessageMenuRow(
                    key: ValueKey<String>(
                      'KunChatMessageMenu.item.${items[i].key}',
                    ),
                    item: items[i],
                    focusNode: _itemFocus[i],
                    theme: theme,
                    onActivate: () => _select(items[i]),
                    onHover: () {
                      if (!items[i].disabled) {
                        _focusItem(i);
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Focus(
      focusNode: _panelFocus,
      skipTraversal: true,
      onKeyEvent: (FocusNode node, KeyEvent event) => _onPanelKey(event),
      child: Semantics(
        key: const ValueKey<String>('KunChatMessageMenu.panel'),
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.menu,
        label: messages.chatMenu.label,
        child: GestureDetector(
          onSecondaryTap: () {},
          child: DecoratedBox(
            key: _panelKey,
            decoration: BoxDecoration(
              color: scheme.content1,
              borderRadius: BorderRadius.circular(KunRadius.lg),
              boxShadow: KunShadows.md,
            ),
            child: Padding(
              padding: const EdgeInsets.all(KunSpacing.unit),
              child: DefaultTextStyle.merge(
                style: KunText.sm.copyWith(color: scheme.foreground),
                child: _expanded
                    ? body
                    : ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: _kMinWidth,
                        ),
                        child: IntrinsicWidth(child: body),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickRow(BuildContext context, KunMessages messages) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final List<KunChatReactionOption> quick =
        widget.reactions.take(_quickShown).toList(growable: false);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: messages.chat.reactions,
      child: Padding(
        padding: const EdgeInsets.only(bottom: KunSpacing.unit),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.neutral.solid.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KunSpacing.unit * 0.5,
              0,
              KunSpacing.unit * 0.5,
              KunSpacing.unit,
            ),
            child: Row(
              mainAxisAlignment: _hasMore
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int i = 0; i < quick.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: KunSpacing.unit * 0.5),
                      _KunChatQuickReaction(
                        key: ValueKey<String>(
                          'KunChatMessageMenu.quick.${quick[i].key}',
                        ),
                        option: quick[i],
                        selected: widget.currentReaction == quick[i].key,
                        focusNode: _quickFocus[i],
                        primary: scheme.primary.solid,
                        idle: scheme.neutral.solid,
                        onChoose: () => _toggleReaction(quick[i].key),
                      ),
                    ],
                  ],
                ),
                if (_hasMore)
                  _KunChatMoreButton(
                    key: const ValueKey<String>('KunChatMessageMenu.more'),
                    focusNode: _quickFocus[_quickShown],
                    label: messages.chatMenu.moreReactions,
                    onChoose: _expand,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && KunDismissLayers.isTop(this)) {
          _requestClose(returnFocus: true);
        }
      },
      child: TapRegion(
        groupId: _tapGroup,
        onTapOutside: (PointerDownEvent event) {
          if (_isOpen) {
            _requestClose();
          }
        },
        child: OverlayPortal.overlayChildLayoutBuilder(
          controller: _portal,
          overlayLocation: OverlayChildLocation.rootOverlay,
          overlayChildBuilder: _buildOverlay,
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _KunChatMessageMenuLayout extends SingleChildLayoutDelegate {
  _KunChatMessageMenuLayout({
    required this.point,
    required this.viewport,
    required this.padding,
    required this.minWidth,
  });

  final Offset point;
  final Rect viewport;
  final double padding;
  final double minWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final double maxW = math.max(0, viewport.width - padding * 2);
    final double maxH = math.max(0, viewport.height - padding * 2);
    return BoxConstraints(
      minWidth: minWidth.clamp(0, maxW),
      maxWidth: maxW,
      maxHeight: maxH,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double minX = viewport.left + padding;
    final double minY = viewport.top + padding;
    final double maxX = viewport.right - padding - childSize.width;
    final double maxY = viewport.bottom - padding - childSize.height;
    final double x = math.min(math.max(point.dx, minX), math.max(minX, maxX));
    final double y = math.min(math.max(point.dy, minY), math.max(minY, maxY));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _KunChatMessageMenuLayout oldDelegate) {
    return point != oldDelegate.point ||
        viewport != oldDelegate.viewport ||
        padding != oldDelegate.padding ||
        minWidth != oldDelegate.minWidth;
  }
}

class _KunChatMessageMenuRow extends StatefulWidget {
  const _KunChatMessageMenuRow({
    required this.item,
    required this.focusNode,
    required this.theme,
    required this.onActivate,
    required this.onHover,
    super.key,
  });

  final _ResolvedAction item;
  final FocusNode focusNode;
  final KunThemeData theme;
  final VoidCallback onActivate;
  final VoidCallback onHover;

  @override
  State<_KunChatMessageMenuRow> createState() => _KunChatMessageMenuRowState();
}

class _KunChatMessageMenuRowState extends State<_KunChatMessageMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final _ResolvedAction item = widget.item;
    final KunVariantStyle style = KunVariantStyle.resolve(
      scheme: widget.theme.colors,
      brightness: widget.theme.brightness,
      variant: KunUIVariant.light,
      color: item.color,
    );
    final bool lit = !item.disabled && (_hovered || widget.focusNode.hasFocus);

    final Widget row = Container(
      decoration: BoxDecoration(
        color: lit ? style.hoverOverlay : null,
        borderRadius: BorderRadius.circular(KunRadius.md),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: KunSpacing.unit * 3,
        vertical: KunSpacing.unit * 1.5,
      ),
      child: Row(
        children: <Widget>[
          if (item.icon != null) ...<Widget>[
            Icon(
              item.icon,
              size: KunText.base.fontSize,
              color: style.foreground,
            ),
            const SizedBox(width: KunSpacing.unit * 2.5),
          ],
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KunText.sm.copyWith(
                color: style.foreground,
                fontWeight: KunFontWeights.medium,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      role: SemanticsRole.menuItem,
      label: item.label,
      enabled: !item.disabled,
      onTap: item.disabled ? null : widget.onActivate,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          descendantsAreFocusable: false,
          descendantsAreTraversable: false,
          onShowFocusHighlight: (_) => setState(() {}),
          onFocusChange: (_) => setState(() {}),
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onActivate();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (_) {
                widget.onActivate();
                return null;
              },
            ),
          },
          child: MouseRegion(
            cursor: item.disabled
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onEnter: (_) {
              setState(() => _hovered = true);
              if (!item.disabled) {
                widget.onHover();
              }
            },
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: item.disabled ? null : widget.onActivate,
              child: Opacity(opacity: item.disabled ? 0.5 : 1, child: row),
            ),
          ),
        ),
      ),
    );
  }
}

class _KunChatQuickReaction extends StatefulWidget {
  const _KunChatQuickReaction({
    required this.option,
    required this.selected,
    required this.focusNode,
    required this.primary,
    required this.idle,
    required this.onChoose,
    super.key,
  });

  final KunChatReactionOption option;
  final bool selected;
  final FocusNode focusNode;
  final Color primary;
  final Color idle;
  final VoidCallback onChoose;

  @override
  State<_KunChatQuickReaction> createState() => _KunChatQuickReactionState();
}

class _KunChatQuickReactionState extends State<_KunChatQuickReaction> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    widget.focusNode.skipTraversal = true;
    final Color? fill = widget.selected
        ? widget.primary.withValues(alpha: 0.2)
        : ((_hovered || _focused) ? widget.idle.withValues(alpha: 0.2) : null);
    final Widget glyph = kunChatReactionArt(
      context: context,
      size: _kQuickArt,
      emoji: widget.option.emoji,
      imageUrl: widget.option.imageUrl,
      style: KunText.xl,
    );

    return Semantics(
      container: true,
      button: true,
      toggled: widget.selected,
      label: widget.option.label,
      onTap: widget.onChoose,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        descendantsAreFocusable: false,
        descendantsAreTraversable: false,
        onShowFocusHighlight: (bool value) => setState(() => _focused = value),
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
          onEnter: (_) {
            setState(() => _hovered = true);
            widget.focusNode.requestFocus();
          },
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: widget.onChoose,
            child: AnimatedScale(
              scale: _hovered ? _kHoverScale : 1,
              duration: kunMotion(context, KunDefaultTransition.duration),
              curve: KunDefaultTransition.curve,
              child: SizedBox.square(
                dimension: _kQuickSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: glyph),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KunChatMoreButton extends StatefulWidget {
  const _KunChatMoreButton({
    required this.focusNode,
    required this.label,
    required this.onChoose,
    super.key,
  });

  final FocusNode focusNode;
  final String label;
  final VoidCallback onChoose;

  @override
  State<_KunChatMoreButton> createState() => _KunChatMoreButtonState();
}

class _KunChatMoreButtonState extends State<_KunChatMoreButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    widget.focusNode.skipTraversal = true;
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final Color tint = scheme.neutral.solid.withValues(alpha: 0.2);
    final Color color = _hovered ? scheme.foreground : scheme.neutral.shade500;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onChoose,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        descendantsAreFocusable: false,
        descendantsAreTraversable: false,
        onShowFocusHighlight: (bool value) => setState(() => _focused = value),
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
          onEnter: (_) {
            setState(() => _hovered = true);
            widget.focusNode.requestFocus();
          },
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: widget.onChoose,
            child: SizedBox.square(
              dimension: _kMoreSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: (_hovered || _focused) ? tint : null,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    KunIcons.chevronDown,
                    size: KunText.base.fontSize,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
