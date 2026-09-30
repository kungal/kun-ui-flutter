import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import '../avatar_pool.dart';

ImageProvider _galleryImageProvider(String url) =>
    NetworkImage(url, webHtmlElementStrategy: WebHtmlElementStrategy.fallback);

const KunUser _kun = KunUser(id: 42, name: '鲲', avatar: 'favicon.png');
const KunUser _site = KunUser(
  id: 7,
  name: 'KUN Galgame',
  avatar: 'favicon.png',
);
const KunUser _passer = KunUser(id: 103, name: '路过的旅人', avatar: 'favicon.png');

Widget _scope({required Widget child}) {
  return KunUIConfigScope(
    config: KunUIConfig(
      avatarFallbackPool: galleryAvatarPool,
      imageProvider: _galleryImageProvider,
    ),
    child: child,
  );
}

Widget _caption(BuildContext context, String text) {
  return Text(
    text,
    style: KunText.sm.copyWith(
      color: KunTheme.of(context).colors.neutral.shade600,
    ),
  );
}

Widget _userCard(
  BuildContext context,
  KunUser user, {
  required String joined,
  String? bio,
  VoidCallback? close,
}) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return SizedBox(
    width: KunSpacing.unit * 72,
    child: Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 3,
        children: <Widget>[
          Row(
            spacing: KunSpacing.unit * 3,
            children: <Widget>[
              KunAvatar(
                user: user,
                size: KunAvatarSize.lg,
                isNavigation: false,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.name,
                      style: KunText.sm.copyWith(
                        fontWeight: KunFontWeights.semibold,
                      ),
                    ),
                    Text(
                      joined,
                      style: KunText.xs.copyWith(
                        color: scheme.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (close != null)
                KunButton(
                  size: KunUISize.sm,
                  onPressed: close,
                  child: const Text('Follow'),
                ),
            ],
          ),
          if (bio != null)
            Text(
              bio,
              style: KunText.sm.copyWith(color: scheme.neutral.shade600),
            ),
        ],
      ),
    ),
  );
}

Widget hoverCardBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 4,
        children: <Widget>[
          _caption(
            context,
            'Rest on the name. The card opens after 600ms; a click still '
            'reaches the trigger. Touch never opens it.',
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: KunSpacing.unit * 2,
            children: <Widget>[
              KunHoverCard(
                trigger: const KunUserChip(user: _kun, isNavigation: false),
                builder: (BuildContext context, VoidCallback close) =>
                    _userCard(
                  context,
                  _kun,
                  joined: 'Joined 2019 · admin',
                  bio:
                      'Writes walkthroughs and patches, and sometimes fixes bugs.',
                  close: close,
                ),
              ),
              Text(
                'posted 3 hours ago',
                style: KunText.sm.copyWith(
                  color: KunTheme.of(context).colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget hoverCardGroup(BuildContext context) {
  const List<({KunUser user, String joined, String text})> replies =
      <({KunUser user, String joined, String text})>[
    (
      user: _kun,
      joined: 'Joined 2019',
      text: 'The patch is on 1.2 now; old saves work again.',
    ),
    (
      user: _site,
      joined: 'Joined 2021',
      text: 'Thanks to the translation team.',
    ),
    (
      user: _passer,
      joined: 'Joined 2024',
      text: 'Does the Steam build take this patch as-is?',
    ),
  ];
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: _scope(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 4,
        children: <Widget>[
          _caption(
            context,
            'One group for a list of authors: only one card is open, and '
            'moving to a sibling switches at once.',
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final ({KunUser user, String joined, String text}) reply
                  in replies)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: KunTheme.of(context).colors.border,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: KunSpacing.unit * 3,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: KunSpacing.unit * 3,
                      children: <Widget>[
                        KunHoverCard(
                          group: 'replies',
                          position: KunPopoverPosition.rightStart,
                          trigger: KunAvatar(
                            user: reply.user,
                            isNavigation: false,
                          ),
                          builder: (BuildContext context, VoidCallback close) =>
                              _userCard(
                            context,
                            reply.user,
                            joined: reply.joined,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                reply.user.name,
                                style: KunText.sm.copyWith(
                                  fontWeight: KunFontWeights.medium,
                                ),
                              ),
                              Text(
                                reply.text,
                                style: KunText.sm.copyWith(
                                  color: KunTheme.of(context)
                                      .colors
                                      .neutral
                                      .shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget hoverCardLazy(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _LazyCard(),
  );
}

class _LazyCard extends StatefulWidget {
  const _LazyCard();

  @override
  State<_LazyCard> createState() => _LazyCardState();
}

class _LazyCardState extends State<_LazyCard> {
  bool _open = false;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    return _scope(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 4,
        children: <Widget>[
          _caption(
            context,
            'v-model:open. The card is built only while open, so a fetch in '
            'the builder runs on the first rest.',
          ),
          KunHoverCard(
            open: _open,
            onOpenChanged: (bool value) {
              setState(() => _open = value);
              if (value && !_loaded) {
                Future<void>.delayed(KunDurations.slow * 2, () {
                  if (mounted) {
                    setState(() => _loaded = true);
                  }
                });
              }
            },
            trigger: const KunUserChip(
              user: _site,
              description: 'Rest to load the profile',
              isNavigation: false,
            ),
            builder: (BuildContext context, VoidCallback close) {
              final KunColorScheme scheme = KunTheme.of(context).colors;
              return SizedBox(
                width: KunSpacing.unit * 56,
                child: Padding(
                  padding: const EdgeInsets.all(KunSpacing.unit * 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: KunSpacing.unit * 2,
                    children: <Widget>[
                      Text(
                        _site.name,
                        style: KunText.sm.copyWith(
                          fontWeight: KunFontWeights.semibold,
                        ),
                      ),
                      if (_loaded) ...<Widget>[
                        Text(
                          '56 topics',
                          style: KunText.sm.copyWith(
                            color: scheme.neutral.shade600,
                          ),
                        ),
                        Text(
                          '1,024 followers',
                          style: KunText.sm.copyWith(
                            color: scheme.neutral.shade600,
                          ),
                        ),
                      ] else ...<Widget>[
                        const KunSkeleton(
                          variant: KunSkeletonVariant.text,
                          widthFactor: 0.6,
                        ),
                        const KunSkeleton(
                          variant: KunSkeletonVariant.text,
                          widthFactor: 0.4,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget hoverCardArrow(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(context, 'A caret points at the trigger.'),
        KunHoverCard(
          showArrow: true,
          rounded: KunUIRounded.lg,
          trigger: KunButton(
            onPressed: () {},
            variant: KunUIVariant.bordered,
            child: const Text('Preview'),
          ),
          builder: (BuildContext context, VoidCallback close) {
            return Padding(
              padding: const EdgeInsets.all(KunSpacing.unit * 4),
              child: Text(
                'The caret sits on the panel edge.',
                style: KunText.sm.copyWith(
                  color: KunTheme.of(context).colors.neutral.shade600,
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

Widget hoverCardDisabled(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'A trigger with nothing to preview: the chip stays, the card never '
          'opens.',
        ),
        KunHoverCard(
          disabled: true,
          trigger: KunButton(
            onPressed: () {},
            variant: KunUIVariant.light,
            child: const Text('deleted user'),
          ),
          builder: (BuildContext context, VoidCallback close) =>
              const Text('should not mount'),
        ),
      ],
    ),
  );
}

Widget hoverCardFixed(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'Both ask for the top. The first flips below when there is no room; '
          'the second honours position verbatim.',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 4,
          children: <Widget>[
            KunHoverCard(
              position: KunPopoverPosition.topStart,
              trigger: KunButton(
                onPressed: () {},
                variant: KunUIVariant.bordered,
                child: const Text('autoPosition'),
              ),
              builder: (BuildContext context, VoidCallback close) {
                return SizedBox(
                  width: 200,
                  child: Padding(
                    padding: const EdgeInsets.all(KunSpacing.unit * 4),
                    child: Text('Flipped', style: KunText.sm),
                  ),
                );
              },
            ),
            KunHoverCard(
              autoPosition: false,
              position: KunPopoverPosition.topStart,
              trigger: KunButton(
                onPressed: () {},
                variant: KunUIVariant.bordered,
                child: const Text('fixed'),
              ),
              builder: (BuildContext context, VoidCallback close) {
                return SizedBox(
                  width: 200,
                  child: Padding(
                    padding: const EdgeInsets.all(KunSpacing.unit * 4),
                    child: Text('Pinned', style: KunText.sm),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    ),
  );
}
