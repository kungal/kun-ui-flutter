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
///
/// The page sits in a [Navigator], as it does under any real router: KunUI's
/// text fields need the navigator's `Overlay`, and its modals are pushed onto
/// the navigator. Without one, a text field asserted on its first tap under
/// `flutter run`.
class GalleryRouterDelegate extends RouterDelegate<GalleryRoute>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<GalleryRoute> {
  GalleryRoute _route = const GalleryRoute();

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
            child: KunMessageProvider(
              child: Navigator(
                key: navigatorKey,
                pages: <Page<void>>[
                  _GalleryPage(
                    key: ValueKey<String>(_route.path),
                    child: page,
                  ),
                ],
                onDidRemovePage: (Page<Object?> page) {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryPage extends Page<void> {
  const _GalleryPage({required this.child, super.key});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => PageRouteBuilder<void>(
        settings: this,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            (ModalRoute.settingsOf(context)! as _GalleryPage).child,
      );
}
