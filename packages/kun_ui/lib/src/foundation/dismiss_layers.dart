import 'package:flutter/foundation.dart' show visibleForTesting;

/// The open dismissable layers, innermost last.
///
/// A layer is anything a back gesture should close before the page under it:
/// a modal route, an anchored popup. Routes and portals cannot see each
/// other's `PopScope`s — a portal has no route of its own, so its scope
/// registers with the route it was opened from, and a route invokes *every*
/// scope registered with it. One back therefore reaches a popup and the
/// modal holding it at the same time. Each layer registers here while it is
/// open and acts only when [isTop], so the innermost one answers alone.
///
/// The stack is global because the gesture is: there is one back for the
/// application, and the layer that should answer is the last one opened.
class KunDismissLayers {
  KunDismissLayers._();

  static final List<Object> _open = <Object>[];

  /// Marks [token]'s layer open, on top of the ones already there.
  static void add(Object token) {
    _open.remove(token);
    _open.add(token);
  }

  /// Marks [token]'s layer closed. Safe to call for a layer never added.
  static void remove(Object token) => _open.remove(token);

  /// Whether [token]'s layer is the innermost open one.
  static bool isTop(Object token) =>
      _open.isNotEmpty && identical(_open.last, token);

  /// The open layers, innermost last. For tests.
  @visibleForTesting
  static List<Object> get debugLayers => List<Object>.unmodifiable(_open);
}
