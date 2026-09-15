import 'package:flutter/widgets.dart';

import 'route.dart';

/// Lets a descendant push a [GalleryRoute] into the URL.
class GalleryNavigator extends InheritedWidget {
  /// Provides [go] to the subtree under [child].
  const GalleryNavigator({
    required void Function(GalleryRoute route) go,
    required super.child,
    super.key,
  }) : _go = go;

  final void Function(GalleryRoute route) _go;

  /// The nearest [GalleryNavigator] ancestor.
  static GalleryNavigator of(BuildContext context) {
    final GalleryNavigator? navigator =
        context.dependOnInheritedWidgetOfExactType<GalleryNavigator>();
    if (navigator == null) {
      throw FlutterError(
        'GalleryNavigator.of() was called with a context that has no '
        'GalleryNavigator ancestor.',
      );
    }
    return navigator;
  }

  /// Moves to [route], pushing a browser history entry.
  void go(GalleryRoute route) => _go(route);

  @override
  bool updateShouldNotify(GalleryNavigator oldWidget) => false;
}
