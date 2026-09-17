import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Carries out a navigation a KunUI widget asks for, such as a tab with an
/// `href` or a tap on an avatar.
typedef KunNavigate = FutureOr<void> Function(
  BuildContext context,
  String href,
);

/// Turns an image URL a KunUI widget was given into the [ImageProvider] that
/// loads it.
typedef KunImageResolver = ImageProvider Function(String url);

/// App-wide settings for the KunUI widgets that navigate or load images: the
/// Flutter side of the web's `KunUIConfig`.
///
/// Four of the web type's eight keys live elsewhere or nowhere here:
/// `rounded` is `KunThemeData.rounded`, `locale` is `KunMessagesScope`, and
/// `linkComponent` and `iconComponent` have no counterpart, because a link is
/// a tap that calls [navigate] and an icon is `IconData`.
///
/// Provide it with a [KunUIConfigScope]. It is never required: without one,
/// widgets read [KunUIConfig.fallback].
@immutable
class KunUIConfig {
  /// Creates a config. Every field has the web's default except [navigate].
  const KunUIConfig({
    this.navigate,
    this.userLinkTemplate = '/user/{id}/info',
    this.avatarFallbackPool = const <String>[],
    this.imageProvider = NetworkImage.new,
  });

  /// What widgets read when no [KunUIConfigScope] is above them.
  static const KunUIConfig fallback = KunUIConfig();

  /// Carries out the navigations KunUI widgets ask for (web
  /// `navigate(href)`), typically with the app's router:
  /// `(context, href) => GoRouter.of(context).go(href)`.
  ///
  /// The web's default is a full page load of `href`. Flutter has no such
  /// universal default, so this one is null: a widget that would navigate
  /// still looks and behaves like a link, and a tap on it does nothing
  /// except, in a debug build, say once that no navigation is configured.
  final KunNavigate? navigate;

  /// The path a user's avatar or chip links to, where `{id}` is replaced
  /// with the user's id (web `userLinkTemplate`).
  final String userLinkTemplate;

  /// Image URLs to pick from for a user with no avatar (web
  /// `avatarFallbackPool`).
  ///
  /// The pick is `hash(name) % length`, the same hash the web uses, so a
  /// user gets the same image in the app and on the site. That makes the list
  /// an index space, not a ranking: replace an entry in place to move only
  /// the users who land on it, and avoid changing its length, which moves
  /// everyone. Empty means every such user gets the bundled
  /// `KunImages.avatarFallback`.
  final List<String> avatarFallbackPool;

  /// Resolves every image URL KunUI loads, which is where an app plugs in
  /// its own caching (web `imageComponent`). Defaults to [NetworkImage].
  final KunImageResolver imageProvider;

  /// [userLinkTemplate] with its first `{id}` replaced by [id].
  String userLinkFor(int id) => userLinkTemplate.replaceFirst('{id}', '$id');

  /// Hands [href] to [navigate], or reports once in a debug build that
  /// there is nothing to hand it to.
  Future<void> navigateTo(BuildContext context, String href) async {
    final KunNavigate? navigate = this.navigate;
    if (navigate == null) {
      assert(() {
        if (!_warnedNoNavigate) {
          _warnedNoNavigate = true;
          debugPrint(
            'KunUI: a widget asked to navigate to "$href", but no '
            'KunUIConfig.navigate is configured, so nothing happened. '
            'Wrap the app in KunUIConfigScope(config: KunUIConfig(navigate: '
            '...)) to route these through your router.',
          );
        }
        return true;
      }());
      return;
    }
    await navigate(context, href);
  }

  /// A copy with the given fields replaced.
  KunUIConfig copyWith({
    KunNavigate? navigate,
    String? userLinkTemplate,
    List<String>? avatarFallbackPool,
    KunImageResolver? imageProvider,
  }) =>
      KunUIConfig(
        navigate: navigate ?? this.navigate,
        userLinkTemplate: userLinkTemplate ?? this.userLinkTemplate,
        avatarFallbackPool: avatarFallbackPool ?? this.avatarFallbackPool,
        imageProvider: imageProvider ?? this.imageProvider,
      );

  @override
  bool operator ==(Object other) =>
      other is KunUIConfig &&
      other.navigate == navigate &&
      other.userLinkTemplate == userLinkTemplate &&
      listEquals(other.avatarFallbackPool, avatarFallbackPool) &&
      other.imageProvider == imageProvider;

  @override
  int get hashCode => Object.hash(
        navigate,
        userLinkTemplate,
        Object.hashAll(avatarFallbackPool),
        imageProvider,
      );
}

bool _warnedNoNavigate = false;

/// Picks the entry of [pool] a user named [seed] gets when they have no
/// avatar, or null when [pool] is empty (web `pickAvatarFallback`).
///
/// This is the web's hash, bit for bit, over the same UTF-16 code units, so
/// an app and a site configured with the same pool show a user the same
/// image.
String? kunPickAvatarFallback(String seed, List<String> pool) {
  if (pool.isEmpty) return null;
  var hash = 0;
  for (final int unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0xFFFFFFFF;
  }
  return pool[hash % pool.length];
}

/// Provides a [KunUIConfig] to the KunUI widgets below it.
///
/// ```dart
/// KunUIConfigScope(
///   config: KunUIConfig(
///     navigate: (context, href) => GoRouter.of(context).go(href),
///     avatarFallbackPool: pool,
///   ),
///   child: const App(),
/// )
/// ```
///
/// Like `KunMessagesScope`, and unlike `KunTheme`, this is never required.
class KunUIConfigScope extends InheritedWidget {
  /// Applies [config] to the subtree under [child].
  const KunUIConfigScope({
    required this.config,
    required super.child,
    super.key,
  });

  /// The config the subtree reads.
  final KunUIConfig config;

  /// The config of the closest [KunUIConfigScope] ancestor, or
  /// [KunUIConfig.fallback] when there is none.
  static KunUIConfig of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KunUIConfigScope>()?.config ??
      KunUIConfig.fallback;

  @override
  bool updateShouldNotify(KunUIConfigScope oldWidget) =>
      config != oldWidget.config;
}
