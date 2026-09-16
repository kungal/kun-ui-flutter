import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'host.dart';
import 'index.dart';
import 'navigator.dart';
import 'registry.dart';
import 'route.dart';

/// Turns a [RouteInformation] into a [GalleryRoute] and back.
class GalleryRouteInformationParser
    extends RouteInformationParser<GalleryRoute> {
  /// Creates a parser.
  const GalleryRouteInformationParser();

  @override
  Future<GalleryRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) {
    return SynchronousFuture<GalleryRoute>(
      GalleryRoute.parse(routeInformation.uri),
    );
  }

  @override
  RouteInformation restoreRouteInformation(GalleryRoute configuration) {
    return RouteInformation(uri: configuration.toUri());
  }
}

/// Holds the current [GalleryRoute] and builds the wrapped tree.
class GalleryRouterDelegate extends RouterDelegate<GalleryRoute>
    with ChangeNotifier {
  GalleryRoute _route = const GalleryRoute();

  @override
  GalleryRoute get currentConfiguration => _route;

  /// Pushes [route] into the URL.
  void go(GalleryRoute route) {
    if (_route == route) return;
    _route = route;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(GalleryRoute configuration) {
    if (_route == configuration) {
      return SynchronousFuture<void>(null);
    }
    _route = configuration;
    notifyListeners();
    return SynchronousFuture<void>(null);
  }

  @override
  Future<bool> popRoute() => SynchronousFuture<bool>(false);

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = _route.theme == GalleryTheme.dark
        ? KunThemeData.dark(rounded: _route.rounded)
        : KunThemeData.light(rounded: _route.rounded);
    final Widget page;
    if (_route.isIndex) {
      page = GalleryIndex(route: _route);
    } else if (_route.extra.isEmpty &&
        _route.component != null &&
        _route.demo != null) {
      final GalleryDemo? demo = demoBySlug(_route.component!, _route.demo!);
      page = demo == null
          ? UnknownDemoPage(path: _route.path)
          : DemoHost(builder: demo.builder);
    } else {
      page = UnknownDemoPage(path: _route.path);
    }

    return GalleryNavigator(
      go: go,
      child: KunTheme(
        data: theme,
        child: KunMessagesScope(
          messages: _route.lang,
          child: DefaultTextStyle(
            style: KunText.sm.copyWith(
              color: theme.colors.foreground,
            ),
            child: page,
          ),
        ),
      ),
    );
  }
}
