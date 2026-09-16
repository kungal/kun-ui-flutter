import 'package:flutter/foundation.dart';
import 'package:kun_ui/kun_ui.dart';

/// Which [KunThemeData] factory [GalleryRoute.theme] selects.
enum GalleryTheme {
  /// [KunThemeData.light].
  light,

  /// [KunThemeData.dark].
  dark,
}

/// An address in the gallery: index, a demo, or an unknown path, plus the
/// theme, language, and corner radius that wrap it.
@immutable
class GalleryRoute {
  /// Creates a gallery address. Null [component] is the index.
  const GalleryRoute({
    this.component,
    this.demo,
    this.extra = const <String>[],
    this.theme = GalleryTheme.light,
    this.lang = KunMessages.zhCN,
    this.rounded = KunUIRounded.md,
  });

  /// Component slug (`kunbutton`), or null on the index.
  final String? component;

  /// Demo slug (`matrix`), or null on the index / a one-segment unknown path.
  final String? demo;

  /// Path segments past the two-slug grammar; any extra makes the path unknown.
  final List<String> extra;

  /// Selects light or dark [KunThemeData].
  final GalleryTheme theme;

  /// The message catalog [KunMessagesScope] wraps the tree with.
  final KunMessages lang;

  /// The theme-wide corner radius the page's [KunThemeData] is built with.
  final KunUIRounded rounded;

  /// Whether this address is the index (`#/`).
  bool get isIndex => component == null && demo == null && extra.isEmpty;

  /// Path as it appears in the URL, including a leading slash.
  String get path {
    if (isIndex) return '/';
    final List<String> segments = <String>[
      if (component != null) component!,
      if (demo != null) demo!,
      ...extra,
    ];
    return '/${segments.join('/')}';
  }

  /// Parses a hash-strategy location (`/kunbutton/matrix?theme=dark`).
  factory GalleryRoute.parse(Uri uri) {
    final Uri source = _effective(uri);
    final GalleryTheme theme = switch (source.queryParameters['theme']) {
      'dark' => GalleryTheme.dark,
      _ => GalleryTheme.light,
    };
    final KunMessages lang = switch (source.queryParameters['lang']) {
      'en' => KunMessages.en,
      _ => KunMessages.zhCN,
    };
    final KunUIRounded rounded = switch (source.queryParameters['rounded']) {
      'none' => KunUIRounded.none,
      'sm' => KunUIRounded.sm,
      'lg' => KunUIRounded.lg,
      'full' => KunUIRounded.full,
      _ => KunUIRounded.md,
    };
    final List<String> segments = source.pathSegments
        .where((String segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return GalleryRoute(theme: theme, lang: lang, rounded: rounded);
    }
    return GalleryRoute(
      component: segments[0],
      demo: segments.length >= 2 ? segments[1] : null,
      extra: segments.length > 2 ? segments.sublist(2) : const <String>[],
      theme: theme,
      lang: lang,
      rounded: rounded,
    );
  }

  static Uri _effective(Uri uri) {
    if (uri.fragment.isEmpty) return uri;
    final String fragment = uri.fragment;
    return Uri.parse(fragment.startsWith('/') ? fragment : '/$fragment');
  }

  /// Serialises to a path-and-query [Uri] that [parse] round-trips.
  Uri toUri() {
    final Map<String, String> query = <String, String>{};
    if (theme == GalleryTheme.dark) query['theme'] = 'dark';
    if (lang.code != 'zh-CN') query['lang'] = lang.code;
    if (rounded != KunUIRounded.md) query['rounded'] = rounded.name;
    return Uri(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );
  }

  /// A copy with [theme], [lang], and/or [rounded] replaced; the path is
  /// unchanged.
  GalleryRoute copyWith({
    GalleryTheme? theme,
    KunMessages? lang,
    KunUIRounded? rounded,
  }) =>
      GalleryRoute(
        component: component,
        demo: demo,
        extra: extra,
        theme: theme ?? this.theme,
        lang: lang ?? this.lang,
        rounded: rounded ?? this.rounded,
      );

  @override
  String toString() => toUri().toString();

  @override
  bool operator ==(Object other) =>
      other is GalleryRoute &&
      other.component == component &&
      other.demo == demo &&
      listEquals(other.extra, extra) &&
      other.theme == theme &&
      other.lang.code == lang.code &&
      other.rounded == rounded;

  @override
  int get hashCode => Object.hash(
        component,
        demo,
        Object.hashAll(extra),
        theme,
        lang.code,
        rounded,
      );
}
