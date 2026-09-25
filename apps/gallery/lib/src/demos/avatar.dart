import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import '../avatar_pool.dart';

ImageProvider _galleryImageProvider(String url) => NetworkImage(
      url,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
    );

const KunUser _kun = KunUser(id: 1, name: 'Kun', avatar: 'favicon.png');

Widget _scope({
  required Widget child,
  KunNavigate? navigate,
}) {
  return KunUIConfigScope(
    config: KunUIConfig(
      avatarFallbackPool: galleryAvatarPool,
      imageProvider: _galleryImageProvider,
      navigate: navigate,
    ),
    child: child,
  );
}

Widget avatarBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(
      child: const KunAvatar(user: _kun, isNavigation: false),
    ),
  );
}

Widget avatarSizes(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: KunSpacing.unit * 3,
        children: [
          KunAvatar(user: _kun, size: KunAvatarSize.xs, isNavigation: false),
          KunAvatar(user: _kun, size: KunAvatarSize.sm, isNavigation: false),
          KunAvatar(user: _kun, size: KunAvatarSize.md, isNavigation: false),
          KunAvatar(user: _kun, size: KunAvatarSize.lg, isNavigation: false),
          KunAvatar(user: _kun, size: KunAvatarSize.xl, isNavigation: false),
          KunAvatar(
            user: _kun,
            size: KunAvatarSize.originalSm,
            isNavigation: false,
          ),
          KunAvatar(
            user: _kun,
            size: KunAvatarSize.original,
            isNavigation: false,
          ),
        ],
      ),
    ),
  );
}

Widget avatarFallback(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        spacing: KunSpacing.unit * 3,
        children: [
          KunAvatar(
            user: KunUser(id: 1, name: 'Alice', avatar: ''),
            size: KunAvatarSize.lg,
            isNavigation: false,
          ),
          KunAvatar(
            user: KunUser(id: 2, name: 'Bob', avatar: ''),
            size: KunAvatarSize.lg,
            isNavigation: false,
          ),
          KunAvatar(
            user: KunUser(id: 3, name: 'Carol', avatar: ''),
            size: KunAvatarSize.lg,
            isNavigation: false,
          ),
          KunAvatar(
            user: null,
            size: KunAvatarSize.lg,
            isNavigation: false,
          ),
        ],
      ),
    ),
  );
}

Widget avatarNavigation(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _AvatarNavigation(),
  );
}

class _AvatarNavigation extends StatefulWidget {
  const _AvatarNavigation();

  @override
  State<_AvatarNavigation> createState() => _AvatarNavigationState();
}

class _AvatarNavigationState extends State<_AvatarNavigation> {
  String? _href;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return _scope(
      navigate: (BuildContext context, String href) {
        setState(() => _href = href);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: KunSpacing.unit * 2,
        children: [
          const KunAvatar(
            user: KunUser(id: 42, name: 'Kun', avatar: 'favicon.png'),
            size: KunAvatarSize.lg,
          ),
          if (_href != null)
            Text(
              _href!,
              style: KunText.sm.copyWith(color: scheme.neutral.shade500),
            ),
        ],
      ),
    );
  }
}

const KunUser _decorated = KunUser(
  id: 1,
  name: 'Kun',
  avatar: 'favicon.png',
  avatarDecoration: KunAvatarDecoration(
    src: 'demo/decorations/sakura.png',
    animatedSrc: 'demo/decorations/sakura.webp',
  ),
);

Widget avatarDecoration(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: KunSpacing.unit * 8,
        children: [
          _DecorationSample(
            mode: KunAvatarDecorationMode.hover,
            caption: 'hover',
          ),
          _DecorationSample(
            mode: KunAvatarDecorationMode.always,
            caption: 'always',
          ),
          _DecorationSample(
            mode: KunAvatarDecorationMode.static,
            caption: 'static',
          ),
          _DecorationSample(
            mode: KunAvatarDecorationMode.none,
            caption: 'none',
          ),
          _DecorationSample(
            mode: KunAvatarDecorationMode.hover,
            size: KunAvatarSize.sm,
            caption: 'sm',
          ),
        ],
      ),
    ),
  );
}

class _DecorationSample extends StatelessWidget {
  const _DecorationSample({
    required this.mode,
    required this.caption,
    this.size = KunAvatarSize.xl,
  });

  final KunAvatarDecorationMode mode;
  final KunAvatarSize size;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: [
        KunAvatar(
          user: _decorated,
          size: size,
          decoration: mode,
          isNavigation: false,
        ),
        Text(
          caption,
          style: KunText.xs.copyWith(color: scheme.neutral.shade500),
        ),
      ],
    );
  }
}
