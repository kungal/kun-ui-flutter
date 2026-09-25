import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'src/router.dart';

void main() {
  runApp(const GalleryApp());
}

/// The KunUI component gallery.
class GalleryApp extends StatefulWidget {
  /// Creates the gallery app.
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  final GalleryRouteInformationParser _parser =
      const GalleryRouteInformationParser();
  final GalleryRouterDelegate _delegate = GalleryRouterDelegate();
  final RootBackButtonDispatcher _backButtonDispatcher =
      RootBackButtonDispatcher();

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KunApp.router(
      color: KunColors.light.primary.solid,
      title: 'KunUI',
      routeInformationParser: _parser,
      routerDelegate: _delegate,
      backButtonDispatcher: _backButtonDispatcher,
    );
  }
}
