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

Widget userChipBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(
      child: const KunUserChip(user: _kun, isNavigation: false),
    ),
  );
}

Widget userChipDescription(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(
      child: const KunUserChip(
        user: _kun,
        description: '2024 年加入 · 管理员',
        size: KunAvatarSize.lg,
        isNavigation: false,
      ),
    ),
  );
}

Widget userChipTruncate(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(
      child: const SizedBox(
        width: KunSpacing.unit * 56,
        child: KunUserChip(
          user: KunUser(
            id: 1,
            name: '这是一个非常非常长的用户名会被自动截断显示省略号',
            avatar: 'favicon.png',
          ),
          description: '同样很长的一段个人简介也会被截断而不会撑破布局',
          isNavigation: false,
        ),
      ),
    ),
  );
}

Widget userChipNavigation(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _UserChipNavigation(),
  );
}

class _UserChipNavigation extends StatefulWidget {
  const _UserChipNavigation();

  @override
  State<_UserChipNavigation> createState() => _UserChipNavigationState();
}

class _UserChipNavigationState extends State<_UserChipNavigation> {
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
          const KunUserChip(
            user: KunUser(id: 42, name: 'Kun', avatar: 'favicon.png'),
            description: '点击进入个人主页',
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
