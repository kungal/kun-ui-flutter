import 'dart:async';
import 'dart:ui' show Rect, VoidCallback;

import 'package:flutter/gestures.dart';

/// How long after a group member closes its siblings still skip the open
/// delay, so a menu bar switches instantly once it is "hot".
const Duration _kGroupSkipWindow = Duration(milliseconds: 300);

final Map<String, KunPointerMenu> _groupOpen = <String, KunPointerMenu>{};
final Map<String, DateTime> _groupHotUntil = <String, DateTime>{};

/// Hover intent for a menu whose panel is a separate overlay child.
///
/// The Flutter translation of the web's `useKunPointerMenu`. Three behaviours
/// come with it, and each exists for a failure the naive version has:
///
/// - a **safe triangle** from where the pointer left the trigger to the two
///   corners of the panel edge facing it, so travelling diagonally towards
///   the panel does not close the menu on the way;
/// - **open and close delays**, so brushing past a trigger does not open it
///   and crossing the gap does not close it;
/// - a **group**, so a row of menus switches instantly between siblings and
///   only one of them is open.
///
/// The triangle is computed from coordinates rather than from the widget
/// tree, because the panel is an overlay child and is not a descendant of
/// the trigger's box.
class KunPointerMenu {
  /// Creates a hover controller.
  ///
  /// [panelRect] returns the panel's global box, or null while it is closed.
  KunPointerMenu({
    required this.onOpen,
    required this.onClose,
    required this.panelRect,
    this.openDelay = const Duration(milliseconds: 100),
    this.closeDelay = const Duration(milliseconds: 120),
    this.group,
  });

  /// Opens the menu. Never called while it is already open.
  final VoidCallback onOpen;

  /// Closes the menu. Never called while it is already closed.
  final VoidCallback onClose;

  /// The panel's global box while it is open.
  final Rect? Function() panelRect;

  /// How long the pointer must rest on the trigger before it opens.
  final Duration openDelay;

  /// How long the menu stays open after the pointer leaves it.
  final Duration closeDelay;

  /// Siblings sharing this name switch instantly and never overlap.
  final String? group;

  Timer? _openTimer;
  Timer? _closeTimer;
  Offset? _exit;
  bool _routing = false;
  bool _isOpen = false;

  /// Whether the pointer may open this menu — false for a touch, which falls
  /// back to the click path so the first tap does not act twice.
  static bool handles(PointerEvent event) =>
      event.kind == PointerDeviceKind.mouse;

  /// Call when the menu opened, however it opened.
  void opened() {
    _isOpen = true;
    final String? name = group;
    if (name == null) {
      return;
    }
    final KunPointerMenu? other = _groupOpen[name];
    if (other != null && !identical(other, this)) {
      other.onClose();
    }
    _groupOpen[name] = this;
  }

  /// Call when the menu closed, however it closed.
  void closed() {
    _isOpen = false;
    _cancelTimers();
    _stopRouting();
    final String? name = group;
    if (name != null && identical(_groupOpen[name], this)) {
      _groupOpen.remove(name);
      _groupHotUntil[name] = DateTime.now().add(_kGroupSkipWindow);
    }
  }

  /// Releases the timers and the global pointer route.
  void dispose() {
    _cancelTimers();
    _stopRouting();
    final String? name = group;
    if (name != null && identical(_groupOpen[name], this)) {
      _groupOpen.remove(name);
    }
  }

  /// The pointer entered the trigger.
  void enterTrigger() {
    _closeTimer?.cancel();
    _closeTimer = null;
    _stopRouting();
    if (_isOpen || _openTimer != null) {
      return;
    }
    if (_groupIsHot || openDelay <= Duration.zero) {
      onOpen();
    } else {
      _openTimer = Timer(openDelay, () {
        _openTimer = null;
        if (!_isOpen) {
          onOpen();
        }
      });
    }
  }

  /// The pointer left the trigger at [position].
  void leaveTrigger(Offset position) => _requestClose(position);

  /// The pointer entered the panel.
  void enterPanel() {
    _closeTimer?.cancel();
    _closeTimer = null;
    _stopRouting();
  }

  /// The pointer left the panel at [position].
  void leavePanel(Offset position) => _requestClose(position);

  bool get _groupIsHot {
    final String? name = group;
    if (name == null) {
      return false;
    }
    if (_groupOpen.containsKey(name)) {
      return true;
    }
    final DateTime? until = _groupHotUntil[name];
    return until != null && until.isAfter(DateTime.now());
  }

  void _cancelTimers() {
    _openTimer?.cancel();
    _openTimer = null;
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _requestClose(Offset position) {
    _openTimer?.cancel();
    _openTimer = null;
    if (!_isOpen) {
      return;
    }
    _exit = position;
    _startGrace();
    _startRouting();
  }

  void _startGrace() {
    _closeTimer?.cancel();
    _closeTimer = Timer(closeDelay, () {
      _closeTimer = null;
      if (_isOpen) {
        onClose();
      }
    });
  }

  void _startRouting() {
    if (_routing) {
      return;
    }
    _routing = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
  }

  void _stopRouting() {
    if (!_routing) {
      return;
    }
    _routing = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
  }

  void _onGlobalPointer(PointerEvent event) {
    if (event is! PointerHoverEvent || !handles(event)) {
      return;
    }
    final Rect? panel = panelRect();
    final Offset? exit = _exit;
    if (panel == null || exit == null) {
      return;
    }
    if (panel.contains(event.position)) {
      _closeTimer?.cancel();
      _closeTimer = null;
      _stopRouting();
    } else if (_inSafeTriangle(event.position, exit, panel)) {
      _startGrace();
    } else {
      _stopRouting();
      _cancelTimers();
      if (_isOpen) {
        onClose();
      }
    }
  }
}

double _sign(Offset p, Offset a, Offset b) =>
    (p.dx - b.dx) * (a.dy - b.dy) - (a.dx - b.dx) * (p.dy - b.dy);

bool _inTriangle(Offset p, Offset a, Offset b, Offset c) {
  final double d1 = _sign(p, a, b);
  final double d2 = _sign(p, b, c);
  final double d3 = _sign(p, c, a);
  final bool negative = d1 < 0 || d2 < 0 || d3 < 0;
  final bool positive = d1 > 0 || d2 > 0 || d3 > 0;
  return !(negative && positive);
}

/// Whether [pointer] is still heading for [panel] after leaving at [exit]:
/// inside the triangle from the exit point to the two corners of the panel
/// edge that faces it.
bool _inSafeTriangle(Offset pointer, Offset exit, Rect panel) {
  final Offset corner1;
  final Offset corner2;
  if (exit.dy <= panel.top) {
    corner1 = panel.topLeft;
    corner2 = panel.topRight;
  } else if (exit.dy >= panel.bottom) {
    corner1 = panel.bottomLeft;
    corner2 = panel.bottomRight;
  } else if (exit.dx <= panel.left) {
    corner1 = panel.topLeft;
    corner2 = panel.bottomLeft;
  } else {
    corner1 = panel.topRight;
    corner2 = panel.bottomRight;
  }
  return _inTriangle(pointer, exit, corner1, corner2);
}
