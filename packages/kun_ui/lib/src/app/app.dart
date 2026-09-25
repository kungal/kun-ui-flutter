import 'package:flutter/widgets.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'page.dart';
import 'scroll_behavior.dart';

/// Which [KunThemeData] [KunApp] resolves.
enum KunThemeMode {
  /// Follow [MediaQuery.platformBrightnessOf].
  system,

  /// [KunApp.theme], or [KunThemeData.light] when that is null.
  light,

  /// [KunApp.darkTheme], or [KunThemeData.dark] when that is null.
  dark,
}

/// A Material-free application shell: [WidgetsApp] plus KunUI's theme,
/// messages, config, scroll behavior and page routes.
///
/// Does **not** install `KunMessageProvider`. An app that shows toasts
/// wraps that itself via [builder].
class KunApp extends StatelessWidget {
  /// Creates an application that uses a [Navigator].
  const KunApp({
    super.key,
    this.navigatorKey,
    this.home,
    Map<String, WidgetBuilder> this.routes = const <String, WidgetBuilder>{},
    this.initialRoute,
    this.onGenerateRoute,
    this.onUnknownRoute,
    List<NavigatorObserver> this.navigatorObservers =
        const <NavigatorObserver>[],
    this.title = '',
    this.onGenerateTitle,
    this.color,
    this.theme,
    this.darkTheme,
    this.themeMode = KunThemeMode.system,
    this.messages,
    this.config,
    this.builder,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.debugShowCheckedModeBanner = true,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
    this.scrollBehavior = const KunScrollBehavior(),
  })  : routeInformationProvider = null,
        routeInformationParser = null,
        routerDelegate = null,
        backButtonDispatcher = null,
        routerConfig = null;

  /// Creates an application that uses the [Router] instead of a [Navigator].
  const KunApp.router({
    super.key,
    this.routerConfig,
    this.routeInformationProvider,
    this.routeInformationParser,
    this.routerDelegate,
    this.backButtonDispatcher,
    this.title = '',
    this.onGenerateTitle,
    this.color,
    this.theme,
    this.darkTheme,
    this.themeMode = KunThemeMode.system,
    this.messages,
    this.config,
    this.builder,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.debugShowCheckedModeBanner = true,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
    this.scrollBehavior = const KunScrollBehavior(),
  })  : assert(routerDelegate != null || routerConfig != null),
        navigatorObservers = null,
        navigatorKey = null,
        onGenerateRoute = null,
        home = null,
        onUnknownRoute = null,
        routes = null,
        initialRoute = null;

  /// {@macro flutter.widgets.widgetsApp.navigatorKey}
  final GlobalKey<NavigatorState>? navigatorKey;

  /// {@macro flutter.widgets.widgetsApp.home}
  final Widget? home;

  /// {@macro flutter.widgets.widgetsApp.routes}
  final Map<String, WidgetBuilder>? routes;

  /// {@macro flutter.widgets.widgetsApp.initialRoute}
  final String? initialRoute;

  /// {@macro flutter.widgets.widgetsApp.onGenerateRoute}
  final RouteFactory? onGenerateRoute;

  /// {@macro flutter.widgets.widgetsApp.onUnknownRoute}
  final RouteFactory? onUnknownRoute;

  /// {@macro flutter.widgets.widgetsApp.navigatorObservers}
  final List<NavigatorObserver>? navigatorObservers;

  /// {@macro flutter.widgets.widgetsApp.routeInformationProvider}
  final RouteInformationProvider? routeInformationProvider;

  /// {@macro flutter.widgets.widgetsApp.routeInformationParser}
  final RouteInformationParser<Object>? routeInformationParser;

  /// {@macro flutter.widgets.widgetsApp.routerDelegate}
  final RouterDelegate<Object>? routerDelegate;

  /// {@macro flutter.widgets.widgetsApp.backButtonDispatcher}
  final BackButtonDispatcher? backButtonDispatcher;

  /// {@macro flutter.widgets.widgetsApp.routerConfig}
  final RouterConfig<Object>? routerConfig;

  /// {@macro flutter.widgets.widgetsApp.title}
  final String title;

  /// {@macro flutter.widgets.widgetsApp.onGenerateTitle}
  final GenerateAppTitle? onGenerateTitle;

  /// {@macro flutter.widgets.widgetsApp.color}
  ///
  /// Defaults to the light theme's primary solid when null.
  final Color? color;

  /// The theme used in light mode and when [themeMode] is [KunThemeMode.light].
  final KunThemeData? theme;

  /// The theme used in dark mode and when [themeMode] is [KunThemeMode.dark].
  final KunThemeData? darkTheme;

  /// Which theme to resolve. Defaults to [KunThemeMode.system].
  final KunThemeMode themeMode;

  /// The catalog [KunMessagesScope] installs. Null leaves KunUI's built-in
  /// zh-CN fallback in place.
  final KunMessages? messages;

  /// App-wide navigation and image settings. Null leaves
  /// [KunUIConfig.fallback] in place.
  final KunUIConfig? config;

  /// {@macro flutter.widgets.widgetsApp.builder}
  final TransitionBuilder? builder;

  /// {@macro flutter.widgets.widgetsApp.locale}
  final Locale? locale;

  /// {@macro flutter.widgets.widgetsApp.localizationsDelegates}
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  /// {@macro flutter.widgets.widgetsApp.localeListResolutionCallback}
  final LocaleListResolutionCallback? localeListResolutionCallback;

  /// {@macro flutter.widgets.widgetsApp.localeResolutionCallback}
  final LocaleResolutionCallback? localeResolutionCallback;

  /// {@macro flutter.widgets.widgetsApp.supportedLocales}
  final Iterable<Locale> supportedLocales;

  /// {@macro flutter.widgets.widgetsApp.debugShowCheckedModeBanner}
  final bool debugShowCheckedModeBanner;

  /// {@macro flutter.widgets.widgetsApp.shortcuts}
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// {@macro flutter.widgets.widgetsApp.actions}
  final Map<Type, Action<Intent>>? actions;

  /// {@macro flutter.widgets.widgetsApp.restorationScopeId}
  final String? restorationScopeId;

  /// How descendant scrollables overscroll and whether they grow a scrollbar.
  ///
  /// Defaults to [KunScrollBehavior].
  final ScrollBehavior scrollBehavior;

  bool get _usesRouter => routerDelegate != null || routerConfig != null;

  @override
  Widget build(BuildContext context) {
    final Color resolvedColor =
        color ?? (theme ?? KunThemeData.light()).colors.primary.solid;
    if (_usesRouter) {
      return WidgetsApp.router(
        routeInformationProvider: routeInformationProvider,
        routeInformationParser: routeInformationParser,
        routerDelegate: routerDelegate,
        routerConfig: routerConfig,
        backButtonDispatcher: backButtonDispatcher,
        builder: _kunBuilder,
        title: title,
        onGenerateTitle: onGenerateTitle,
        color: resolvedColor,
        locale: locale,
        localizationsDelegates: localizationsDelegates,
        localeListResolutionCallback: localeListResolutionCallback,
        localeResolutionCallback: localeResolutionCallback,
        supportedLocales: supportedLocales,
        debugShowCheckedModeBanner: debugShowCheckedModeBanner,
        shortcuts: shortcuts,
        actions: actions,
        restorationScopeId: restorationScopeId,
      );
    }
    return WidgetsApp(
      navigatorKey: navigatorKey,
      navigatorObservers: navigatorObservers!,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          KunPageRoute<T>(settings: settings, builder: builder),
      home: home,
      routes: routes!,
      initialRoute: initialRoute,
      onGenerateRoute: onGenerateRoute,
      onUnknownRoute: onUnknownRoute,
      builder: _kunBuilder,
      title: title,
      onGenerateTitle: onGenerateTitle,
      color: resolvedColor,
      locale: locale,
      localizationsDelegates: localizationsDelegates,
      localeListResolutionCallback: localeListResolutionCallback,
      localeResolutionCallback: localeResolutionCallback,
      supportedLocales: supportedLocales,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
      shortcuts: shortcuts,
      actions: actions,
      restorationScopeId: restorationScopeId,
    );
  }

  Widget _kunBuilder(BuildContext context, Widget? child) {
    final bool dark = switch (themeMode) {
      KunThemeMode.dark => true,
      KunThemeMode.light => false,
      KunThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    final KunThemeData resolved = dark
        ? (darkTheme ?? KunThemeData.dark())
        : (theme ?? KunThemeData.light());

    final Widget navigator = child ?? const SizedBox.shrink();
    Widget result = navigator;
    if (builder != null) {
      result = Builder(
        builder: (BuildContext context) => builder!(context, navigator),
      );
    }
    result = DefaultTextStyle(
      style: KunText.base.copyWith(color: resolved.colors.foreground),
      child: result,
    );
    result = ScrollConfiguration(behavior: scrollBehavior, child: result);
    if (config != null) {
      result = KunUIConfigScope(config: config!, child: result);
    }
    if (messages != null) {
      result = KunMessagesScope(messages: messages!, child: result);
    }
    return KunTheme(data: resolved, child: result);
  }
}
