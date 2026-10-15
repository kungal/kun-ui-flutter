import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/design.dart';
import '../foundation/dismiss_layers.dart';
import '../foundation/motion.dart';
import '../foundation/shortcut.dart';
import '../foundation/text_selection.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'button.dart';
import 'command_results.dart';
import 'command_shortcuts.dart';

/// Opening scale of the panel.
/// CommandPalette.vue:447 `transform: translateY(-8px) scale(0.98)`
const double _kPanelScaleFrom = 0.98;

/// Overlay top inset as a fraction of the viewport.
/// CommandPalette.vue:281 `pt-[12vh]`
const double _kOverlayTopFraction = 0.12;

/// Panel height cap as a fraction of the viewport.
/// CommandPalette.vue:286 `max-h-[70dvh]`
const double _kPanelMaxHeightFraction = 0.70;

/// Overlay fade. CommandPalette.vue:431 `transition: opacity 0.15s ease`.
const Duration _kCommandFade = Duration(milliseconds: 150);

/// CSS `ease`, the same transition's curve.
const Curve _kCommandEase = Curves.ease;

/// Footer hints. CommandPalette.vue:416 `text-[11px]`.
const double _kFooterFont = 11;

/// One result row of a [KunCommandPalette].
///
/// [value] falls back to [label], as on the web. The shell does not search:
/// the application computes the list it passes in.
@immutable
class KunCommandItem {
  /// Creates an item.
  const KunCommandItem({
    this.value,
    required this.label,
    this.description,
    this.section,
    this.icon,
    this.href,
    this.disabled = false,
    this.removable = false,
  });

  /// Stable key and what [KunCommandPalette.onSelected] carries. Null uses
  /// [label].
  final Object? value;

  /// Primary line.
  final String label;

  /// Secondary line — a match snippet or description.
  final String? description;

  /// Small caption above [label] (a breadcrumb or category).
  final String? section;

  /// Leading icon.
  final IconData? icon;

  /// Hands this row to [KunUIConfig.navigate] when it is activated, as
  /// [KunDropdown] href rows do. [KunCommandPalette.onSelected] still fires.
  final String? href;

  /// Whether the row is inert: it is skipped by the arrow keys and
  /// activating it does nothing.
  final bool disabled;

  /// Show a remove button on the row (a recent search, say) and let
  /// Shift+Delete remove the highlighted row; both emit
  /// [KunCommandPalette.onRemoved]. The shell removes nothing itself:
  /// drop the item from [KunCommandPalette.items].
  final bool removable;

  /// [value], or [label] when [value] is null.
  Object get resolvedValue => value ?? label;
}

/// A labelled cluster of [KunCommandItem]s.
///
/// A flat web list is one unlabelled group: pass a single [KunCommandGroup]
/// with a null [label].
@immutable
class KunCommandGroup {
  /// Creates a group.
  const KunCommandGroup({this.label, required this.items});

  /// Optional heading above the rows. Null draws no heading.
  final String? label;

  /// Rows in this group, in order.
  final List<KunCommandItem> items;
}

/// Global open shortcut of a [KunCommandPalette].
///
/// The web's `shortcut` is `true` (Mod+K), a single-character string (Mod
/// plus that character), or `false` (none). This class is that closed set.
@immutable
class KunCommandShortcut {
  const KunCommandShortcut._(this.character);

  /// Mod+K, the web's `true`.
  static const KunCommandShortcut modK = KunCommandShortcut._('k');

  /// No global shortcut, the web's `false`.
  static const KunCommandShortcut none = KunCommandShortcut._(null);

  /// Mod plus [char].
  ///
  /// [char] is taken as its first character, lowercased. An empty string is
  /// [none]. `'k'` is [modK].
  factory KunCommandShortcut.key(String char) {
    final String trimmed = char.trim();
    if (trimmed.isEmpty) {
      return none;
    }
    final String letter = trimmed[0].toLowerCase();
    if (letter == 'k') {
      return modK;
    }
    return KunCommandShortcut._(letter);
  }

  /// The character bound with Mod, or null when this is [none].
  final String? character;

  /// Chord for [KunKbd.keys]: `Mod+k`, or empty when this is [none].
  String get keys {
    final String? character = this.character;
    return character == null ? '' : 'Mod+$character';
  }

  /// Platform label: `⌘K` on Apple, `Ctrl K` elsewhere, empty when this is
  /// [none].
  String label(KunShortcutPlatform platform) {
    final String? character = this.character;
    if (character == null) {
      return '';
    }
    final String k = character.toUpperCase();
    return platform == KunShortcutPlatform.apple ? '⌘$k' : 'Ctrl $k';
  }

  @override
  bool operator ==(Object other) =>
      other is KunCommandShortcut && other.character == character;

  @override
  int get hashCode => character.hashCode;
}

/// A ⌘K command-palette shell.
///
/// It owns the dialog, query input, keyboard navigation, grouped rendering,
/// highlighting and accessibility — not the search. Feed it [items]
/// (grouped; a flat web list is one unlabelled [KunCommandGroup]) computed
/// from the [query] it exposes, and it renders and navigates them. Selecting
/// emits [onSelected].
///
/// There is no HTML here, so the web's escaping steps before wrapping a
/// match in `<mark>` have no counterpart; the term split and
/// case-insensitive match are the same.
class KunCommandPalette extends StatefulWidget {
  /// Creates a command palette.
  const KunCommandPalette({
    super.key,
    this.items = const <KunCommandGroup>[],
    this.loading = false,
    this.placeholder,
    this.noResultText,
    this.emptyText,
    this.shortcut = KunCommandShortcut.modK,
    this.highlight = true,
    this.semanticLabel,
    this.open = false,
    this.onOpenChanged,
    this.query = '',
    this.onQueryChanged,
    this.onSelected,
    this.onSubmitted,
    this.onRemoved,
    this.trigger,
    this.itemBuilder,
    this.empty,
    this.noResult,
    this.loadingBuilder,
    this.footer,
  });

  /// Results to show, already filtered by the application.
  ///
  /// A flat web list is one unlabelled [KunCommandGroup]. The shell does no
  /// matching of its own.
  final List<KunCommandGroup> items;

  /// Async search in flight: a loading state instead of the no-result text.
  final bool loading;

  /// Placeholder in the search input; also the dialog's accessible name when
  /// [semanticLabel] is unset. Null uses the locale catalog.
  final String? placeholder;

  /// Shown when [query] is non-empty but there are no results. Null uses the
  /// locale catalog.
  final String? noResultText;

  /// Shown when [query] is empty. Null uses the locale catalog.
  final String? emptyText;

  /// Global open shortcut. [KunCommandShortcut.modK] is the default;
  /// [KunCommandShortcut.none] disables it.
  final KunCommandShortcut shortcut;

  /// Highlight the query terms in the default item render.
  final bool highlight;

  /// Accessible name for the dialog (web `ariaLabel`).
  final String? semanticLabel;

  /// Whether the dialog is open (web `open`).
  final bool open;

  /// Called when the dialog wants to open or close (web `update:open`).
  final ValueChanged<bool>? onOpenChanged;

  /// The query text (web `query`).
  final String query;

  /// Called on every edit (web `update:query`).
  final ValueChanged<String>? onQueryChanged;

  /// The item the user activated. A disabled item never emits.
  final ValueChanged<KunCommandItem>? onSelected;

  /// Enter with nothing to select — no results, or every result disabled.
  /// The payload is the trimmed query.
  final ValueChanged<String>? onSubmitted;

  /// The remove button or Shift+Delete on a [KunCommandItem.removable] row.
  /// Drop the item from [items]; the highlight stays on the row that takes
  /// its place.
  final ValueChanged<KunCommandItem>? onRemoved;

  /// Optional trigger. The arguments are `open`, the platform
  /// [KunCommandShortcut.label], and [KunCommandShortcut.keys].
  final Widget Function(
    BuildContext context,
    VoidCallback open,
    String shortcutLabel,
    String keys,
  )? trigger;

  /// Custom row. The default paints the icon, section, highlighted label
  /// and description.
  final Widget Function(
    BuildContext context,
    KunCommandItem item,
    bool active,
  )? itemBuilder;

  /// Replaces the empty-query hint.
  final Widget? empty;

  /// Replaces the no-result copy.
  final Widget? noResult;

  /// Replaces the loading copy.
  final Widget? loadingBuilder;

  /// Replaces the footer hints.
  final Widget? footer;

  @override
  State<KunCommandPalette> createState() => _KunCommandPaletteState();
}

enum _KunCommandPaletteRemoval { none, user, silent }

class _KunCommandPaletteSession extends ChangeNotifier {
  _KunCommandPaletteSession({
    required this.state,
    required this.captured,
    required this.dismiss,
    required this.onBack,
  });

  _KunCommandPaletteState state;
  CapturedThemes captured;
  final VoidCallback dismiss;
  final VoidCallback onBack;

  void notify() => notifyListeners();
}

class _KunCommandPaletteState extends State<KunCommandPalette> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _inputFocus = FocusNode(
    debugLabel: 'KunCommandPalette.input',
    onKeyEvent: _onInputKey,
  );
  final ScrollController _listScroll = ScrollController();
  final Map<int, GlobalKey> _rowKeys = <int, GlobalKey>{};
  NavigatorState? _navigator;
  ModalRoute<Object?>? _hostRoute;
  _KunCommandPaletteRoute? _route;
  _KunCommandPaletteSession? _session;
  _KunCommandPaletteRemoval _removal = _KunCommandPaletteRemoval.none;
  FocusNode? _previouslyFocused;
  int _activeIndex = 0;
  int? _hoveredIndex;
  ({Object key, int index})? _removed;
  KunCommandShortcutRegistration? _shortcutRegistration;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.query;
    _controller.addListener(_onControllerTick);
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
    _shortcutRegistration =
        KunCommandShortcutCoordinator.instance.registerPalette(
      shortcut: () => widget.shortcut,
      eligible: () => mounted && _ownsShortcut(),
      activate: _toggleFromShortcut,
    );
    if (widget.open) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openIfNeeded());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.of(context, rootNavigator: true);
    _hostRoute = ModalRoute.of(context);
    _publish();
  }

  @override
  void didUpdateWidget(KunCommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text && !_isComposing) {
      _scheduleControllerSync();
    }
    if (widget.open && !oldWidget.open) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openIfNeeded());
    } else if (!widget.open && oldWidget.open) {
      _closeSilent();
    }
    if (widget.query != oldWidget.query) {
      _removed = null;
    }
    if (!_sameRows(oldWidget.items, widget.items)) {
      _applyItemsChanged();
    }
    _publish();
  }

  @override
  void dispose() {
    _disposed = true;
    _shortcutRegistration?.unregister();
    _shortcutRegistration = null;
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    _controller.removeListener(_onControllerTick);
    _controller.dispose();
    _inputFocus.dispose();
    _listScroll.dispose();
    final _KunCommandPaletteRoute? route = _route;
    final NavigatorState? navigator = _navigator;
    _route = null;
    final _KunCommandPaletteSession? session = _session;
    if (session != null) {
      KunDismissLayers.remove(session);
    }
    session?.dispose();
    _session = null;
    if (route != null && navigator != null && route.isActive) {
      navigator.removeRoute(route);
    }
    super.dispose();
  }

  bool _sameRows(List<KunCommandGroup> a, List<KunCommandGroup> b) {
    if (identical(a, b)) {
      return true;
    }
    final List<KunCommandItem> left = _flatten(a);
    final List<KunCommandItem> right = _flatten(b);
    if (left.length != right.length) {
      return false;
    }
    for (int i = 0; i < left.length; i++) {
      if (!identical(left[i], right[i])) {
        return false;
      }
    }
    return true;
  }

  List<KunCommandItem> _flatten(List<KunCommandGroup> groups) {
    return kunCommandFlat(kunCommandToRows(groups));
  }

  List<KunCommandItem> get _flat => _flatten(widget.items);

  String get _liveQuery => _controller.text;

  bool get _isComposing {
    final TextRange composing = _controller.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  int _firstEnabled() {
    final List<KunCommandItem> flat = _flat;
    final int i = flat.indexWhere((KunCommandItem item) => !item.disabled);
    return i == -1 ? 0 : i;
  }

  int _lastEnabled() {
    final List<KunCommandItem> flat = _flat;
    for (int i = flat.length - 1; i >= 0; i--) {
      if (!flat[i].disabled) {
        return i;
      }
    }
    return 0;
  }

  GlobalKey _rowKey(int index) => _rowKeys.putIfAbsent(index, GlobalKey.new);

  void _syncControllerFromWidget() {
    if (_disposed || _isComposing) {
      return;
    }
    if (_controller.text == widget.query) {
      return;
    }
    _controller.value = TextEditingValue(
      text: widget.query,
      selection: TextSelection.collapsed(offset: widget.query.length),
    );
  }

  void _scheduleControllerSync() {
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && mounted) {
          _syncControllerFromWidget();
        }
      });
    } else {
      _syncControllerFromWidget();
    }
  }

  void _onControllerTick() {
    _session?.notify();
    if (_isComposing) {
      return;
    }
    if (_controller.text == widget.query) {
      return;
    }
    _removed = null;
    widget.onQueryChanged?.call(_controller.text);
  }

  void _applyItemsChanged() {
    final ({Object key, int index})? removed = _removed;
    _removed = null;
    final List<KunCommandItem> list = _flat;
    if (removed != null &&
        list.isNotEmpty &&
        !list.any(
          (KunCommandItem item) => item.resolvedValue == removed.key,
        )) {
      final int i = math.min(removed.index, list.length - 1);
      _activeIndex = list[i].disabled ? _firstEnabled() : i;
      return;
    }
    _activeIndex = _firstEnabled();
  }

  void _removeItem(KunCommandItem item, int index) {
    if (item.disabled) {
      return;
    }
    _removed = (key: item.resolvedValue, index: index);
    widget.onRemoved?.call(item);
  }

  bool _ownsShortcut() {
    if (widget.open) {
      return true;
    }
    return _hostRoute?.isCurrent ?? true;
  }

  bool _onGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }
    if (widget.open && event.logicalKey == LogicalKeyboardKey.escape) {
      _requestClose();
      return true;
    }
    return false;
  }

  void _toggleFromShortcut() {
    if (widget.open) {
      _requestClose();
    } else {
      _requestOpen();
    }
  }

  KeyEventResult _onInputKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (_isComposing) {
      // Leave the key to the IME (the web returns before the switch and
      // does not preventDefault). Select and submit stay off.
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _setActive(_firstEnabled());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        _setActive(_lastEnabled());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
        _onEnter();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _requestClose();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.delete:
        if (HardwareKeyboard.instance.isShiftPressed) {
          final List<KunCommandItem> flat = _flat;
          if (_activeIndex >= 0 && _activeIndex < flat.length) {
            final KunCommandItem row = flat[_activeIndex];
            if (row.removable) {
              _removeItem(row, _activeIndex);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _move(int delta) {
    final List<KunCommandItem> flat = _flat;
    final int n = flat.length;
    if (n == 0) {
      return;
    }
    int i = _activeIndex;
    for (int step = 0; step < n; step++) {
      i = (i + delta + n) % n;
      if (!flat[i].disabled) {
        _setActive(i);
        return;
      }
    }
  }

  void _setHovered(int index, bool hovered) {
    if (hovered) {
      _hoveredIndex = index;
    } else if (_hoveredIndex == index) {
      _hoveredIndex = null;
    }
    _session?.notify();
  }

  void _setActive(int index) {
    if (_activeIndex == index) {
      _scrollActiveIntoView();
      return;
    }
    _activeIndex = index;
    _session?.notify();
    _scrollActiveIntoView();
  }

  void _scrollActiveIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) {
        return;
      }
      final BuildContext? context = _rowKey(_activeIndex).currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
  }

  void _onEnter() {
    final List<KunCommandItem> flat = _flat;
    if (_activeIndex >= 0 && _activeIndex < flat.length) {
      final KunCommandItem row = flat[_activeIndex];
      if (!row.disabled) {
        _select(row);
        return;
      }
    }
    final String trimmed = _liveQuery.trim();
    if (trimmed.isNotEmpty) {
      widget.onSubmitted?.call(trimmed);
    }
  }

  void _select(KunCommandItem item) {
    if (item.disabled) {
      return;
    }
    widget.onSelected?.call(item);
    final String? href = item.href;
    if (href != null) {
      KunUIConfigScope.of(context).navigateTo(context, href);
    }
    _requestClose();
  }

  void _requestOpen() {
    if (widget.open) {
      return;
    }
    widget.onOpenChanged?.call(true);
  }

  void _requestClose() {
    if (!widget.open) {
      return;
    }
    widget.onQueryChanged?.call('');
    widget.onOpenChanged?.call(false);
  }

  CapturedThemes _capture() {
    return InheritedTheme.capture(
      from: context,
      to: Navigator.of(context, rootNavigator: true).context,
    );
  }

  void _publish() {
    final _KunCommandPaletteSession? session = _session;
    if (session == null) {
      return;
    }
    session.state = this;
    session.captured = _capture();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _session != session) {
        return;
      }
      session.notify();
    });
  }

  void _openIfNeeded() {
    if (_disposed || !mounted || !widget.open || _route != null) {
      return;
    }
    _open();
  }

  void _open() {
    if (_disposed || !mounted || _route != null) {
      return;
    }
    final NavigatorState navigator =
        _navigator ?? Navigator.of(context, rootNavigator: true);
    _navigator = navigator;
    _removal = _KunCommandPaletteRemoval.none;
    _previouslyFocused = FocusManager.instance.primaryFocus;
    if (_previouslyFocused is FocusScopeNode) {
      _previouslyFocused = null;
    }
    _activeIndex = _firstEnabled();
    _session = _KunCommandPaletteSession(
      state: this,
      captured: _capture(),
      dismiss: _dismiss,
      onBack: _onBack,
    );
    final _KunCommandPaletteRoute route = _KunCommandPaletteRoute(
      session: _session!,
      transitionDuration: kunMotion(context, _kCommandFade),
      reverseTransitionDuration: kunMotion(context, _kCommandFade),
    );
    _route = route;
    KunDismissLayers.add(_session!);
    unawaited(navigator.push<void>(route).whenComplete(_onRouteCompleted));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && mounted && widget.open) {
        _inputFocus.requestFocus();
      }
    });
  }

  void _takeDown({required bool popIfCurrent}) {
    void run() {
      final _KunCommandPaletteRoute? route = _route;
      final NavigatorState? navigator = _navigator;
      if (route == null || navigator == null || !route.isActive) {
        _route = null;
        return;
      }
      if (popIfCurrent && route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          run();
        }
      });
    } else {
      run();
    }
  }

  void _dismiss() {
    if (_route == null || _removal != _KunCommandPaletteRemoval.none) {
      return;
    }
    _removal = _KunCommandPaletteRemoval.user;
    _takeDown(popIfCurrent: true);
    widget.onQueryChanged?.call('');
    widget.onOpenChanged?.call(false);
  }

  void _closeSilent() {
    if (_route == null || _removal != _KunCommandPaletteRemoval.none) {
      return;
    }
    _removal = _KunCommandPaletteRemoval.silent;
    _takeDown(popIfCurrent: true);
  }

  void _onBack() {
    if (_route == null || _removal != _KunCommandPaletteRemoval.none) {
      return;
    }
    _dismiss();
  }

  void _onRouteCompleted() {
    final bool ours = _route != null;
    _route = null;
    final _KunCommandPaletteSession? session = _session;
    _session = null;
    if (session != null) {
      KunDismissLayers.remove(session);
    }
    session?.dispose();
    _activeIndex = 0;
    _scheduleControllerSync();
    final FocusNode? previous = _previouslyFocused;
    _previouslyFocused = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (previous != null && previous.canRequestFocus) {
        previous.requestFocus();
      }
    });
    if (_disposed || !ours) {
      return;
    }
    if (_removal == _KunCommandPaletteRemoval.none) {
      widget.onQueryChanged?.call('');
      widget.onOpenChanged?.call(false);
    }
    _removal = _KunCommandPaletteRemoval.none;
  }

  @override
  Widget build(BuildContext context) {
    KunTheme.of(context);
    KunMessagesScope.of(context);
    KunUIConfigScope.of(context);
    final KunShortcutPlatform platform = kunShortcutPlatform();
    final Widget Function(
      BuildContext context,
      VoidCallback open,
      String shortcutLabel,
      String keys,
    )? trigger = widget.trigger;
    if (trigger == null) {
      return const SizedBox.shrink();
    }
    return trigger(
      context,
      _requestOpen,
      widget.shortcut.label(platform),
      widget.shortcut.keys,
    );
  }
}

class _KunCommandPaletteRoute extends PopupRoute<void> {
  _KunCommandPaletteRoute({
    required this.session,
    required this.transitionDuration,
    required this.reverseTransitionDuration,
  });

  final _KunCommandPaletteSession session;

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  TraversalEdgeBehavior get traversalEdgeBehavior =>
      TraversalEdgeBehavior.closedLoop;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _KunCommandPalettePage(route: this);
  }
}

class _KunCommandPalettePage extends StatelessWidget {
  const _KunCommandPalettePage({required this.route});

  final _KunCommandPaletteRoute route;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: route.session,
      builder: (BuildContext context, Widget? _) {
        return route.session.captured.wrap(
          Builder(builder: _buildCaptured),
        );
      },
    );
  }

  Widget _buildCaptured(BuildContext context) {
    final _KunCommandPaletteSession session = route.session;
    final _KunCommandPaletteState state = session.state;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void result) {
        if (didPop || !KunDismissLayers.isTop(session)) {
          return;
        }
        session.onBack();
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (DismissIntent intent) {
              session.dismiss();
              return null;
            },
          ),
        },
        child: FadeTransition(
          key: const ValueKey<String>('KunCommandPalette.overlay'),
          opacity: CurvedAnimation(
            parent: route.animation!,
            curve: _kCommandEase,
            reverseCurve: _kCommandEase,
          ),
          child: BlockSemantics(
            child: _KunCommandPaletteLayer(
              animation: route.animation!,
              state: state,
              onBackdrop: session.dismiss,
            ),
          ),
        ),
      ),
    );
  }
}

class _KunCommandPaletteLayer extends StatelessWidget {
  const _KunCommandPaletteLayer({
    required this.animation,
    required this.state,
    required this.onBackdrop,
  });

  final Animation<double> animation;
  final _KunCommandPaletteState state;
  final VoidCallback onBackdrop;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double top = media.size.height * _kOverlayTopFraction;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onBackdrop,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: KunBlur.sm,
              sigmaY: KunBlur.sm,
            ),
            child: ColoredBox(
              color: KunColors.black.withValues(alpha: 0.4),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            top: top,
            left: KunSpacing.unit * 4,
            right: KunSpacing.unit * 4,
            bottom: media.viewInsets.bottom,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? _) {
                final double t = CurvedAnimation(
                  parent: animation,
                  curve: _kCommandEase,
                  reverseCurve: _kCommandEase,
                ).value;
                final double ty = (1 - t) * -KunSpacing.unit * 2;
                final double scale =
                    _kPanelScaleFrom + (1 - _kPanelScaleFrom) * t;
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, ty),
                    child: Transform.scale(
                      scale: scale,
                      child: _KunCommandPalettePanel(state: state),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _KunCommandPalettePanel extends StatelessWidget {
  const _KunCommandPalettePanel({required this.state});

  final _KunCommandPaletteState state;

  @override
  Widget build(BuildContext context) {
    final KunCommandPalette widget = state.widget;
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunCommandPaletteStrings strings =
        KunMessagesScope.of(context).commandPalette;
    final String placeholder = widget.placeholder ?? strings.placeholder;
    final String dialogName =
        (widget.semanticLabel != null && widget.semanticLabel!.isNotEmpty)
            ? widget.semanticLabel!
            : placeholder;
    final double maxHeight =
        MediaQuery.sizeOf(context).height * _kPanelMaxHeightFraction;
    final double radius = KunRadius.lg;

    return Semantics(
      container: true,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      role: SemanticsRole.dialog,
      label: dialogName,
      child: ConstrainedBox(
        key: const ValueKey<String>('KunCommandPalette.panel'),
        constraints: BoxConstraints(
          maxWidth: KunContainerWidths.xl,
          maxHeight: maxHeight,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.content1,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: scheme.border),
            boxShadow: KunShadows.lg,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _KunCommandPaletteInput(
                  state: state,
                  placeholder: placeholder,
                  closeLabel: strings.close,
                ),
                Flexible(
                  child: _KunCommandPaletteResults(
                    state: state,
                    strings: strings,
                  ),
                ),
                widget.footer ?? _KunCommandPaletteFooter(state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KunCommandPaletteInput extends StatelessWidget {
  const _KunCommandPaletteInput({
    required this.state,
    required this.placeholder,
    required this.closeLabel,
  });

  final _KunCommandPaletteState state;
  final String placeholder;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final TextStyle style = KunText.sm.copyWith(color: scheme.foreground);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KunSpacing.unit * 4),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                KunIcons.search,
                size: KunText.base.fontSize,
                color: scheme.neutral.shade400,
              ),
            ),
            SizedBox(width: KunSpacing.unit * 3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: KunSpacing.unit * 3.5,
                ),
                child: Stack(
                  children: <Widget>[
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: state._controller,
                      builder: (
                        BuildContext context,
                        TextEditingValue value,
                        Widget? child,
                      ) {
                        if (value.text.isNotEmpty) {
                          return const SizedBox.shrink();
                        }
                        return child!;
                      },
                      child: IgnorePointer(
                        child: Text(
                          placeholder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.copyWith(
                            color: scheme.foregroundMuted,
                          ),
                        ),
                      ),
                    ),
                    EditableText(
                      controller: state._controller,
                      focusNode: state._inputFocus,
                      autofocus: true,
                      style: style,
                      cursorColor: scheme.foreground,
                      backgroundCursorColor: scheme.neutral.shade300,
                      selectionColor:
                          scheme.primary.solid.withValues(alpha: 0.2),
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      enableSuggestions: false,
                      spellCheckConfiguration:
                          SpellCheckConfiguration.disabled(),
                      maxLines: 1,
                      selectionControls: KunTextSelectionControls(
                        handleColor: scheme.primary.solid,
                      ),
                      contextMenuBuilder: kunTextSelectionContextMenu,
                      onSubmitted: (String _) {
                        if (!state._isComposing) {
                          state._onEnter();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            KunButton(
              variant: KunUIVariant.light,
              color: KunUIColor.neutral,
              isIconOnly: true,
              semanticLabel: closeLabel,
              onPressed: state._requestClose,
              child: Icon(
                KunIcons.x,
                color: scheme.neutral.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KunCommandPaletteResults extends StatelessWidget {
  const _KunCommandPaletteResults({
    required this.state,
    required this.strings,
  });

  final _KunCommandPaletteState state;
  final KunCommandPaletteStrings strings;

  @override
  Widget build(BuildContext context) {
    final KunCommandPalette widget = state.widget;
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final List<KunCommandItem> flat = state._flat;
    final bool hasResults = flat.isNotEmpty;
    final String liveQuery = state._liveQuery;
    final TextStyle muted = KunText.sm.copyWith(
      color: scheme.foregroundMuted,
    );

    Widget body;
    if (widget.loading) {
      body = widget.loadingBuilder ??
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 3,
              vertical: KunSpacing.unit * 6,
            ),
            child: Center(
              child: Text(strings.loading, style: muted),
            ),
          );
    } else if (hasResults) {
      body = Semantics(
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.list,
        child: Padding(
          padding: const EdgeInsets.all(KunSpacing.unit * 2),
          child: KunCommandResults(
            groups: kunCommandToRows(widget.items),
            activeIndex: state._activeIndex,
            hoveredIndex: state._hoveredIndex,
            query: liveQuery,
            highlight: widget.highlight,
            itemKeyPrefix: 'KunCommandPalette.item',
            rowKey: state._rowKey,
            itemBuilder: widget.itemBuilder,
            onSelect: state._select,
            onHover: (int index) {
              if (index >= 0 && index < flat.length && !flat[index].disabled) {
                state._setActive(index);
              }
            },
            onPointerEnter: (int index) => state._setHovered(index, true),
            onPointerExit: (int index) => state._setHovered(index, false),
            onRemove: state._removeItem,
          ),
        ),
      );
    } else if (liveQuery.trim().isNotEmpty) {
      body = widget.noResult ??
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 3,
              vertical: KunSpacing.unit * 6,
            ),
            child: Center(
              child: Text.rich(
                TextSpan(
                  style: muted,
                  children: <InlineSpan>[
                    TextSpan(
                        text: '${widget.noResultText ?? strings.noResult}:'),
                    TextSpan(
                      text: liveQuery,
                      style: KunText.sm.copyWith(
                        color: scheme.neutral.shade600,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
    } else {
      body = widget.empty ??
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 3,
              vertical: KunSpacing.unit * 6,
            ),
            child: Center(
              child: Text(
                widget.emptyText ?? strings.empty,
                style: muted,
              ),
            ),
          );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        overscroll: false,
      ),
      child: SingleChildScrollView(
        key: const ValueKey<String>('KunCommandPalette.list'),
        controller: state._listScroll,
        child: body,
      ),
    );
  }
}

class _KunCommandPaletteFooter extends StatelessWidget {
  const _KunCommandPaletteFooter({required this.state});

  final _KunCommandPaletteState state;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunCommandPaletteStrings strings =
        KunMessagesScope.of(context).commandPalette;
    final TextStyle muted = KunText.xs.copyWith(
      fontSize: _kFooterFont,
      color: scheme.foregroundMuted,
    );
    // The web's bare `<kbd>`, which the preflight sets in the mono stack.
    final TextStyle key = muted.copyWith(
      fontFamily: KunFontFamilies.mono,
      fontFamilyFallback: KunFontFamilies.monoFallback,
    );
    Widget hint(String glyph, String text) => Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(text: glyph, style: key),
              TextSpan(text: ' $text'),
            ],
          ),
          style: muted,
        );
    final int count = state._flat.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 4,
          vertical: KunSpacing.unit * 2,
        ),
        child: Row(
          children: <Widget>[
            hint('↑↓', strings.hintSelect),
            SizedBox(width: KunSpacing.unit * 4),
            hint('↵', strings.hintOpen),
            SizedBox(width: KunSpacing.unit * 4),
            hint('esc', strings.hintClose),
            const Spacer(),
            Text(strings.resultCount(count: count), style: muted),
          ],
        ),
      ),
    );
  }
}
