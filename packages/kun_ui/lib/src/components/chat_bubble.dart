import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../chat/album.dart';
import '../chat/support.dart';
import '../chat/types.dart';
import '../config/config.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'chat_shared.dart';
import 'chat_text.dart';
import 'image.dart';
import 'lightbox.dart';
import 'tooltip.dart';

/// Web `max-w-[min(85%,34rem)]` fraction.
const double _kMaxWidthFraction = 0.85;

/// Web `34rem` at a 16 px rem.
const double _kMaxWidth = 34 * 16;

/// Web `text-[0.9375rem]`.
const double _kFontSize = 15;

/// Web `leading-5`.
const double _kLineHeight = 20;

/// Web `PHOTO_MAX_W`.
const double _kPhotoMaxW = 320;

/// Web `PHOTO_MAX_H`.
const double _kPhotoMaxH = 420;

/// Web `PHOTO_MIN_W`.
const double _kPhotoMinW = 140;

/// Web single-photo aspect floor.
const double _kPhotoMinRatio = 0.5;

/// Web single-photo aspect cap.
const double _kPhotoMaxRatio = 2.4;

/// Web `ALBUM_W`.
const double _kAlbumWidth = 320;

/// Web `bg-black/55`: the least that keeps white at 4.5:1 over any photo.
const double _kMediaMetaAlpha = 0.55;

/// Web tail `viewBox` width.
const double _kTailWidth = 7;

/// Web tail `viewBox` height.
const double _kTailHeight = 17;

/// Web `-right-[6px]` / `-left-[6px]`.
const double _kTailOverlap = 6;

/// Web retry `absolute -left-8`.
const double _kRetryGutter = KunSpacing.unit * 8;

/// Web retry `size-6`.
const double _kRetrySize = KunSpacing.unit * 6;

/// Web reaction chip `h-7`.
const double _kChipHeight = KunSpacing.unit * 7;

/// Web reaction art `size-5`.
const double _kChipArt = KunSpacing.unit * 5;

/// Web meta `text-[11px]`.
const double _kMetaFont = 11;

/// Web `border-l-[3px]`.
const double _kReplyBorder = 3;

/// Web tail path `M6 17`.
const double _kTailStartX = 6;

/// Web tail path `H0 V0`.
const double _kTailOrigin = 0;

/// First cubic of the tail: `c.193 2.84.876 5.767 2.05 8.782`.
const double _kTailC1a = 0.193;
const double _kTailC1b = 2.84;
const double _kTailC1c = 0.876;
const double _kTailC1d = 5.767;
const double _kTailC1e = 2.05;
const double _kTailC1f = 8.782;

/// Second cubic: `.904 2.325 2.446 4.485 4.625 6.48`.
const double _kTailC2a = 0.904;
const double _kTailC2b = 2.325;
const double _kTailC2c = 2.446;
const double _kTailC2d = 4.485;
const double _kTailC2e = 4.625;
const double _kTailC2f = 6.48;

/// Tail arc radius `A1 1`.
const double _kTailArc = 1;

/// Where a bubble sits in its sender's run (web `KunChatBubblePosition`).
enum KunChatBubblePosition {
  /// A lone message. Full corners and a tail.
  single,

  /// First of a run. The sender-side bottom corner shrinks; no tail.
  first,

  /// Inside a run. Both sender-side corners shrink; no tail.
  middle,

  /// Last of a run. The sender-side top corner shrinks; a tail.
  last,
}

/// Which URL [KunChatMediaUrlResolver] should return (web `'preview' | 'original'`).
enum KunChatMediaVariant {
  /// The in-bubble picture.
  preview,

  /// The lightbox picture.
  original,
}

/// Turns a media payload into a URL the image loader can fetch.
typedef KunChatMediaUrlResolver = String Function(
  KunChatMedia media,
  KunChatMediaVariant variant,
);

/// One message: text, photo or album, with its reply preview, context card,
/// reactions and meta. A service message renders as a centred pill instead.
///
/// Positioning in a row (left / right, avatar column) is the list's job.
class KunChatBubble extends StatefulWidget {
  /// Creates a chat bubble.
  const KunChatBubble({
    super.key,
    required this.message,
    this.album,
    this.currentUserId,
    this.disabled = false,
    this.lightbox = true,
    this.own = false,
    this.position = KunChatBubblePosition.single,
    this.reactionOptions = const <KunChatReactionOption>[],
    this.resolveMediaUrl,
    this.resolveMessage,
    this.semanticActions,
    this.showSender = false,
    this.status,
    this.users = const <KunChatUser>[],
    this.onLink,
    this.onMention,
    this.onUserTap,
    this.onPhotoTap,
    this.onReact,
    this.onReplyTap,
    this.onRetry,
  });

  /// The message. For an album, the one it acts as (reactions, replies).
  final KunChatMessage message;

  /// Every photo of an album, in order; omitted for anything else.
  final List<KunChatMessage>? album;

  /// The viewer's id, so a service message can say "you".
  final String? currentUserId;

  /// Swallow taps on the sender, the reply preview, the reactions and the
  /// photos. Retry and the context card stay live, as on the web.
  final bool disabled;

  /// Open photos in a built-in lightbox on tap. The message list turns this
  /// off and shows every loaded photo in one lightbox instead.
  final bool lightbox;

  /// Sent by the viewer: primary tint. Alignment is the list's job.
  final bool own;

  /// Where the bubble sits in its sender's run.
  final KunChatBubblePosition position;

  /// The reaction vocabulary, to draw each reaction key.
  final List<KunChatReactionOption> reactionOptions;

  /// Turns a photo into a URL. Without it a photo shows its
  /// [KunChatPhoto.url], and a photo with neither shows nothing. Pass it to
  /// serve a smaller preview than the server's URL.
  final KunChatMediaUrlResolver? resolveMediaUrl;

  /// Finds a loaded message by seq — the text a "pinned a message" service
  /// line quotes.
  final KunChatMessage? Function(int seq)? resolveMessage;

  /// Extra actions merged onto the labelled text node and each photo
  /// button. [KunChatMessageList] uses this so a screen reader can open
  /// the message menu.
  final Map<CustomSemanticsAction, VoidCallback>? semanticActions;

  /// Show the sender's name on top: group chats, first of a run.
  final bool showSender;

  /// Delivery state of an own message.
  final KunChatSendStatus? status;

  /// Users the message refers to. A missing or deleted user shows as deleted.
  final List<KunChatUser> users;

  /// A link in the text or the context card was tapped.
  final KunChatLinkCallback? onLink;

  /// A mention in the text was tapped.
  final KunChatUserCallback? onMention;

  /// The sender's name was tapped. The default is navigating to
  /// [KunUIConfig.userLinkForId] unless prevented.
  final KunChatUserCallback? onUserTap;

  /// A photo was tapped (index into the photo-filtered album). Fires with
  /// [lightbox] on as well.
  final ValueChanged<int>? onPhotoTap;

  /// A reaction chip was tapped: the key to set, or null to remove the
  /// viewer's own.
  final ValueChanged<String?>? onReact;

  /// The reply preview was tapped: jump to the replied-to message.
  final ValueChanged<int>? onReplyTap;

  /// The failed-status button was tapped.
  final VoidCallback? onRetry;

  /// Surface decoration, for tests.
  @visibleForTesting
  static const Key surfaceKey = ValueKey<String>('kunChatBubbleSurface');

  /// Absolutely positioned text meta, for tests.
  @visibleForTesting
  static const Key metaKey = ValueKey<String>('kunChatBubbleMeta');

  /// Retry control, for tests.
  @visibleForTesting
  static const Key retryKey = ValueKey<String>('kunChatBubbleRetry');

  /// Tail paint, for tests.
  @visibleForTesting
  static const Key tailKey = ValueKey<String>('kunChatBubbleTail');

  /// Service pill, for tests.
  @visibleForTesting
  static const Key serviceKey = ValueKey<String>('kunChatBubbleService');

  /// Reply preview, for tests.
  @visibleForTesting
  static const Key replyKey = ValueKey<String>('kunChatBubbleReply');

  /// Visible sender name, for tests.
  @visibleForTesting
  static const Key senderKey = ValueKey<String>('kunChatBubbleSender');

  /// Photo or album tile at [index] in the photo-filtered album.
  @visibleForTesting
  static Key photoKey(int index) =>
      ValueKey<String>('kunChatBubblePhoto-$index');

  /// The box a lone photo occupies, matching the web clamp.
  @visibleForTesting
  static Size debugSinglePhotoSize(KunChatPhoto photo) =>
      _singlePhotoSize(photo);

  @override
  State<KunChatBubble> createState() => _KunChatBubbleState();
}

Size _singlePhotoSize(KunChatPhoto photo) {
  final double natural =
      photo.width > 0 && photo.height > 0 ? photo.width / photo.height : 1;
  final double ratio = math.min(
    math.max(natural, _kPhotoMinRatio),
    _kPhotoMaxRatio,
  );
  double width = math.min(
    _kPhotoMaxW,
    photo.width > 0 ? photo.width.toDouble() : _kPhotoMaxW,
  );
  if (width / ratio > _kPhotoMaxH) {
    width = _kPhotoMaxH * ratio;
  }
  width = (math.max(width, _kPhotoMinW)).roundToDouble();
  return Size(width, width / ratio);
}

List<KunChatPhoto> _photosOf(
  KunChatMessage message,
  List<KunChatMessage>? album,
) {
  final List<KunChatMessage> source =
      album != null && album.isNotEmpty ? album : <KunChatMessage>[message];
  return <KunChatPhoto>[
    for (final KunChatMessage item in source)
      if (item.media is KunChatPhoto) item.media! as KunChatPhoto,
  ];
}

String _hostOf(String? href, String fallback) {
  if (href == null || href.isEmpty) {
    return fallback;
  }
  final Uri? uri = Uri.tryParse(href);
  if (uri == null || uri.host.isEmpty) {
    return fallback;
  }
  return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
}

IconData? _statusIcon(KunChatSendStatus? status) {
  return switch (status) {
    KunChatSendStatus.sending => KunIcons.clock,
    KunChatSendStatus.sent => KunIcons.check,
    KunChatSendStatus.read => KunIcons.checkCheck,
    KunChatSendStatus.failed || null => null,
  };
}

String? _statusLabel(KunChatSendStatus? status, KunMessages messages) {
  return switch (status) {
    KunChatSendStatus.sending => messages.chatStatus.sending,
    KunChatSendStatus.sent => messages.chatStatus.sent,
    KunChatSendStatus.read => messages.chatStatus.read,
    KunChatSendStatus.failed => messages.chatStatus.failed,
    null => null,
  };
}

Widget _withSenderPrefix(
  String? prefix,
  Widget child, {
  Map<CustomSemanticsAction, VoidCallback>? semanticActions,
}) {
  if (prefix == null && (semanticActions == null || semanticActions.isEmpty)) {
    return child;
  }
  // A zero-size semantics node is dropped by Android.
  return Semantics(
    label: prefix,
    customSemanticsActions: semanticActions,
    child: child,
  );
}

BorderRadius _corners({
  required KunChatBubblePosition position,
  required bool own,
  required bool tail,
}) {
  const Radius lg = Radius.circular(KunRadius.lg);
  const Radius sm = Radius.circular(KunRadius.sm);
  const Radius none = Radius.zero;
  final bool nearTop = position == KunChatBubblePosition.middle ||
      position == KunChatBubblePosition.last;
  final bool nearBottom = position == KunChatBubblePosition.first ||
      position == KunChatBubblePosition.middle;
  if (own) {
    return BorderRadius.only(
      topLeft: lg,
      topRight: nearTop ? sm : lg,
      bottomLeft: lg,
      bottomRight: tail ? none : (nearBottom ? sm : lg),
    );
  }
  return BorderRadius.only(
    topLeft: nearTop ? sm : lg,
    topRight: lg,
    bottomLeft: tail ? none : (nearBottom ? sm : lg),
    bottomRight: lg,
  );
}

BorderRadius _tileCorners(int sides, BorderRadius outer) {
  final bool top = sides & KunChatAlbumSide.top != 0;
  final bool right = sides & KunChatAlbumSide.right != 0;
  final bool bottom = sides & KunChatAlbumSide.bottom != 0;
  final bool left = sides & KunChatAlbumSide.left != 0;
  return BorderRadius.only(
    topLeft: top && left ? outer.topLeft : Radius.zero,
    topRight: top && right ? outer.topRight : Radius.zero,
    bottomLeft: bottom && left ? outer.bottomLeft : Radius.zero,
    bottomRight: bottom && right ? outer.bottomRight : Radius.zero,
  );
}

class _KunChatBubbleState extends State<KunChatBubble> {
  final Set<String> _hovered = <String>{};

  bool _isHovered(String key) => _hovered.contains(key);

  void _setHovered(String key, bool value) {
    if (value == _isHovered(key)) {
      return;
    }
    setState(() {
      if (value) {
        _hovered.add(key);
      } else {
        _hovered.remove(key);
      }
    });
  }

  String _src(KunChatPhoto photo, KunChatMediaVariant variant) {
    return widget.resolveMediaUrl?.call(photo, variant) ?? photo.url ?? '';
  }

  void _openPhoto(
    BuildContext context,
    int index,
    List<KunChatPhoto> photos,
    String senderName,
  ) {
    if (widget.disabled) {
      return;
    }
    widget.onPhotoTap?.call(index);
    if (!widget.lightbox || photos.isEmpty) {
      return;
    }
    final KunMessages messages = KunMessagesScope.of(context);
    showKunLightbox(
      context,
      images: <KunLightboxImage>[
        for (final KunChatPhoto photo in photos)
          KunLightboxImage(
            src: _src(photo, KunChatMediaVariant.original),
            alt: messages.chat.photoFrom(name: senderName),
          ),
      ],
      initialIndex: index,
    );
  }

  void _onUserTap(BuildContext context, KunChatResolvedUser sender) {
    if (widget.disabled || sender.deleted) {
      return;
    }
    final KunChatUserEvent event = KunChatUserEvent(sender.id);
    widget.onUserTap?.call(event);
    if (!event.defaultPrevented) {
      final KunUIConfig config = KunUIConfigScope.of(context);
      config.navigateTo(context, config.userLinkForId(sender.id));
    }
  }

  void _onContextTap(BuildContext context, String href) {
    final KunChatLinkEvent event = KunChatLinkEvent(href);
    widget.onLink?.call(event);
    if (!event.defaultPrevented) {
      KunUIConfigScope.of(context).navigateTo(context, href);
    }
  }

  @override
  Widget build(BuildContext context) {
    final KunMessages messages = KunMessagesScope.of(context);
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final String locale = messages.code;
    final Map<String, KunChatUser> users = kunChatUserMap(widget.users);
    final KunChatResolvedUser sender = resolveKunChatUser(
      users,
      widget.message.senderId,
      messages,
    );

    if (widget.message.kind == KunChatMessageKind.service) {
      return _ServicePill(
        text: kunChatServiceText(
          widget.message,
          KunChatServiceContext(
            users: users,
            currentUserId: widget.currentUserId,
            messages: messages,
            resolveMessage: widget.resolveMessage,
          ),
        ),
        scheme: scheme,
      );
    }

    final List<KunChatPhoto> photos = _photosOf(widget.message, widget.album);
    final bool isAlbum = photos.length > 1;
    final Size? single =
        !isAlbum && photos.isNotEmpty ? _singlePhotoSize(photos.first) : null;
    final KunChatAlbumLayout? albumLayout = isAlbum
        ? layoutKunChatAlbum(<KunChatAlbumSize>[
            for (final KunChatPhoto photo in photos)
              KunChatAlbumSize(
                width: photo.width.toDouble(),
                height: photo.height.toDouble(),
              ),
          ])
        : null;
    final bool hasText = widget.message.text.isNotEmpty;
    final bool mediaOnly = photos.isNotEmpty && !hasText;
    final KunChatReplyTo? reply = widget.message.replyTo;
    final KunChatContext? rawContext = widget.message.context;
    final bool showName = widget.showSender && !widget.own;
    final bool bare =
        mediaOnly && reply == null && rawContext == null && !showName;
    final bool tail = !bare &&
        (widget.position == KunChatBubblePosition.last ||
            widget.position == KunChatBubblePosition.single);
    final BorderRadius corners = _corners(
      position: widget.position,
      own: widget.own,
      tail: tail,
    );
    final bool showRetry =
        widget.own && widget.status == KunChatSendStatus.failed;
    final Color surface =
        widget.own ? scheme.primary.shade100 : scheme.content1;
    final Color metaColor =
        widget.own ? scheme.primary.text : scheme.foregroundMuted;
    final String time = formatKunChatTime(widget.message.createdAt, locale);
    final String fullTime = formatKunChatFullTime(
      widget.message.createdAt,
      locale,
    );
    final IconData? statusIcon = _statusIcon(widget.status);
    final String? statusLabel = _statusLabel(widget.status, messages);
    final bool hasReactions = widget.message.reactions.isNotEmpty;
    final bool insetMedia = reply != null || showName;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _kMaxWidth / _kMaxWidthFraction;
        final double cap = math.min(available * _kMaxWidthFraction, _kMaxWidth);
        double? boxWidth;
        if (single != null) {
          boxWidth = math.min(single.width, cap);
        } else if (albumLayout != null) {
          boxWidth = math.min(_kAlbumWidth, cap);
        }

        final String? senderPrefix = widget.showSender
            ? null
            : messages.chat.senderPrefix(
                name: widget.own ? messages.chat.you : sender.name,
              );
        final String? mediaPrefix = hasText ? null : senderPrefix;
        final String? photoPrefix = reply == null ? mediaPrefix : null;
        final String? contextPrefix = photos.isEmpty ? photoPrefix : null;

        final List<Widget> bodyChildren = <Widget>[
          if (showName)
            _SenderName(
              sender: sender,
              scheme: scheme,
              mediaOnly: mediaOnly,
              hovered: _isHovered('sender'),
              onHover: (bool v) => _setHovered('sender', v),
              onTap: () => _onUserTap(context, sender),
            ),
          if (reply != null)
            _withSenderPrefix(
              mediaPrefix,
              _ReplyPreview(
                reply: reply,
                quote: widget.message.replyQuote,
                users: users,
                messages: messages,
                scheme: scheme,
                own: widget.own,
                mediaOnly: mediaOnly,
                disabled: widget.disabled,
                hovered: _isHovered('reply'),
                onHover: (bool v) => _setHovered('reply', v),
                onTap: () => widget.onReplyTap?.call(reply.seq),
                duration: kunMotion(context, KunDefaultTransition.duration),
              ),
            ),
          if (single != null)
            _withSenderPrefix(
              photoPrefix,
              _SinglePhoto(
                photo: photos.first,
                size: Size(
                  boxWidth!,
                  boxWidth / (single.width / single.height),
                ),
                src: _src(photos.first, KunChatMediaVariant.preview),
                radius: insetMedia
                    ? BorderRadius.circular(KunRadius.md)
                    : (hasText
                        ? corners.copyWith(
                            bottomLeft: Radius.zero,
                            bottomRight: Radius.zero,
                          )
                        : corners),
                inset: insetMedia,
                label: messages.chat.photoFrom(name: sender.name),
                onTap: () => _openPhoto(context, 0, photos, sender.name),
                semanticActions: widget.semanticActions,
                overlay: mediaOnly && !hasReactions
                    ? _MediaMeta(
                        edited: widget.message.editedAt != null
                            ? messages.chat.edited
                            : null,
                        time: time,
                        fullTime: fullTime,
                        icon: widget.own ? statusIcon : null,
                        scheme: scheme,
                      )
                    : null,
              ),
            ),
          if (albumLayout != null)
            _withSenderPrefix(
              photoPrefix,
              _AlbumMosaic(
                photos: photos,
                layout: albumLayout,
                width: boxWidth!,
                srcOf: (KunChatPhoto photo) =>
                    _src(photo, KunChatMediaVariant.preview),
                radius: insetMedia
                    ? BorderRadius.circular(KunRadius.md)
                    : (hasText
                        ? corners.copyWith(
                            bottomLeft: Radius.zero,
                            bottomRight: Radius.zero,
                          )
                        : corners),
                inset: insetMedia,
                label: messages.chat.photoFrom(name: sender.name),
                onTap: (int i) => _openPhoto(context, i, photos, sender.name),
                semanticActions: widget.semanticActions,
                overlay: mediaOnly && !hasReactions
                    ? _MediaMeta(
                        time: time,
                        fullTime: fullTime,
                        icon: widget.own ? statusIcon : null,
                        scheme: scheme,
                      )
                    : null,
              ),
            ),
          if (rawContext != null)
            _withSenderPrefix(
              contextPrefix,
              _ContextCard(
                raw: rawContext,
                scheme: scheme,
                hovered: _isHovered('context'),
                onHover: (bool v) => _setHovered('context', v),
                onTap: (String href) => _onContextTap(context, href),
                duration: kunMotion(context, KunDefaultTransition.duration),
              ),
            ),
          if (hasText)
            _TextBlock(
              message: widget.message,
              senderPrefix: senderPrefix,
              semanticActions: widget.semanticActions,
              onLink: widget.onLink,
              onMention: widget.onMention,
              showCornerMeta: !hasReactions,
              twin: !hasReactions
                  ? _MetaLine(
                      edited: widget.message.editedAt != null
                          ? messages.chat.edited
                          : null,
                      time: time,
                      icon: widget.own ? statusIcon : null,
                      color: metaColor,
                      twin: true,
                    )
                  : null,
              meta: !hasReactions
                  ? _MetaLine(
                      edited: widget.message.editedAt != null
                          ? messages.chat.edited
                          : null,
                      time: time,
                      fullTime: fullTime,
                      icon: widget.own ? statusIcon : null,
                      iconLabel: widget.own ? statusLabel : null,
                      color: metaColor,
                    )
                  : null,
            ),
          if (hasReactions)
            _ReactionsRow(
              reactions: widget.message.reactions,
              options: widget.reactionOptions,
              messages: messages,
              scheme: scheme,
              own: widget.own,
              hasText: hasText,
              disabled: widget.disabled,
              hovered: _hovered,
              onHover: _setHovered,
              onReact: (KunChatReaction reaction) {
                if (!widget.disabled) {
                  widget.onReact?.call(
                    reaction.reacted ? null : reaction.reaction,
                  );
                }
              },
              duration: kunMotion(context, KunDefaultTransition.duration),
              meta: _MetaLine(
                edited: widget.message.editedAt != null
                    ? messages.chat.edited
                    : null,
                time: time,
                fullTime: fullTime,
                icon: widget.own ? statusIcon : null,
                iconLabel: widget.own ? statusLabel : null,
                color: metaColor,
              ),
            ),
        ];

        final Widget body = boxWidth != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: bodyChildren,
              )
            : _WFitColumn(cap: cap, children: bodyChildren);

        Widget bubble = DefaultTextStyle(
          style: TextStyle(
            fontSize: _kFontSize,
            height: _kLineHeight / _kFontSize,
            leadingDistribution: TextLeadingDistribution.even,
            color: scheme.foreground,
          ),
          child: body,
        );

        if (!bare) {
          bubble = DecoratedBox(
            key: KunChatBubble.surfaceKey,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: corners,
              boxShadow: widget.own ? null : KunShadows.sm,
            ),
            child: bubble,
          );
        }

        bubble = Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            bubble,
            if (tail)
              Positioned(
                right: widget.own ? -_kTailOverlap : null,
                left: widget.own ? null : -_kTailOverlap,
                bottom: 0,
                child: Transform.flip(
                  flipX: !widget.own,
                  child: CustomPaint(
                    key: KunChatBubble.tailKey,
                    size: const Size(_kTailWidth, _kTailHeight),
                    painter: _TailPainter(color: surface),
                  ),
                ),
              ),
          ],
        );

        if (boxWidth != null) {
          bubble = SizedBox(width: boxWidth, child: bubble);
        }

        bubble = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cap),
          child: bubble,
        );

        if (showRetry) {
          bubble = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              SizedBox(
                width: _kRetryGutter,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _RetryButton(
                    label: messages.chatStatus.failed,
                    scheme: scheme,
                    onTap: widget.onRetry,
                  ),
                ),
              ),
              bubble,
            ],
          );
        }

        return Align(
          alignment: Alignment.topLeft,
          widthFactor: 1,
          child: bubble,
        );
      },
    );
  }
}

class _ServicePill extends StatelessWidget {
  const _ServicePill({required this.text, required this.scheme});

  final String text;
  final KunColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KunSpacing.unit * 2),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: double.infinity),
          child: DecoratedBox(
            key: KunChatBubble.serviceKey,
            decoration: BoxDecoration(
              color: scheme.neutral.solid.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(KunRadius.full),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KunSpacing.unit * 3,
                vertical: KunSpacing.unit,
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: KunText.xs.copyWith(
                  color: scheme.foreground.withValues(alpha: 0.8),
                  fontWeight: KunFontWeights.medium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SenderName extends StatelessWidget {
  const _SenderName({
    required this.sender,
    required this.scheme,
    required this.mediaOnly,
    required this.hovered,
    required this.onHover,
    required this.onTap,
  });

  final KunChatResolvedUser sender;
  final KunColorScheme scheme;
  final bool mediaOnly;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = KunText.sm.copyWith(
      fontWeight: KunFontWeights.semibold,
      color: scheme.primary.text,
      decoration: hovered && !sender.deleted ? TextDecoration.underline : null,
      decorationColor: scheme.primary.text,
    );
    final Widget name = Text(
      sender.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return Padding(
      key: KunChatBubble.senderKey,
      padding: EdgeInsets.fromLTRB(
        KunSpacing.unit * 3,
        KunSpacing.unit * 1.5,
        KunSpacing.unit * 3,
        mediaOnly ? KunSpacing.unit : 0,
      ),
      child: sender.deleted
          ? name
          : MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => onHover(true),
              onExit: (_) => onHover(false),
              child: GestureDetector(
                onTap: onTap,
                child: Semantics(button: true, label: sender.name, child: name),
              ),
            ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.reply,
    required this.quote,
    required this.users,
    required this.messages,
    required this.scheme,
    required this.own,
    required this.mediaOnly,
    required this.disabled,
    required this.hovered,
    required this.onHover,
    required this.onTap,
    required this.duration,
  });

  final KunChatReplyTo reply;
  final KunChatReplyQuote? quote;
  final Map<String, KunChatUser> users;
  final KunMessages messages;
  final KunColorScheme scheme;
  final bool own;
  final bool mediaOnly;
  final bool disabled;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final KunChatResolvedUser replySender = resolveKunChatUser(
      users,
      reply.senderId,
      messages,
    );
    final Color idle = own
        ? scheme.primary.shade200.withValues(alpha: 0.6)
        : scheme.primary.solid.withValues(alpha: 0.1);
    final Color hover = own
        ? scheme.primary.shade200
        : scheme.primary.solid.withValues(alpha: 0.15);
    final Widget body;
    if (reply.deleted) {
      body = Text(
        messages.chat.deletedMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: KunText.sm.copyWith(
          color: scheme.foregroundMuted,
          fontStyle: FontStyle.italic,
        ),
      );
    } else if (quote != null || reply.text.isNotEmpty) {
      body = DefaultTextStyle.merge(
        style: KunText.sm.copyWith(
          color: scheme.foreground.withValues(alpha: 0.8),
        ),
        child: KunChatText(
          text: quote != null ? quote!.text : reply.text,
          entities: quote != null ? quote!.entities : reply.entities,
          preview: true,
        ),
      );
    } else {
      final KunChatMedia? media = reply.mediaType == 'photo'
          ? const KunChatPhoto(imageHash: '', width: 0, height: 0)
          : (reply.mediaType != null
              ? KunChatUnknownMedia(type: reply.mediaType!)
              : null);
      body = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            KunIcons.image,
            size: KunText.xs.fontSize,
            color: scheme.foreground.withValues(alpha: 0.8),
          ),
          const SizedBox(width: KunSpacing.unit),
          Text(
            kunChatMediaLabel(media, messages),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KunText.sm.copyWith(
              color: scheme.foreground.withValues(alpha: 0.8),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        KunSpacing.unit * 2,
        KunSpacing.unit * 1.5,
        KunSpacing.unit * 2,
        mediaOnly ? KunSpacing.unit : 0,
      ),
      child: MouseRegion(
        cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          onTap: disabled ? null : onTap,
          child: AnimatedContainer(
            key: KunChatBubble.replyKey,
            duration: duration,
            curve: KunDefaultTransition.curve,
            padding: const EdgeInsets.fromLTRB(
              KunSpacing.unit * 2,
              KunSpacing.unit,
              KunSpacing.unit * 2,
              KunSpacing.unit,
            ),
            decoration: BoxDecoration(
              color: hovered && !disabled ? hover : idle,
              borderRadius: BorderRadius.circular(KunRadius.sm),
              border: Border(
                left: BorderSide(
                  color: scheme.primary.solid,
                  width: _kReplyBorder,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (quote != null) ...<Widget>[
                      Icon(
                        KunIcons.quote,
                        size: KunText.xs.fontSize,
                        color: scheme.primary.solid,
                      ),
                      const SizedBox(width: KunSpacing.unit),
                    ],
                    Text(
                      replySender.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KunText.sm.copyWith(
                        fontWeight: KunFontWeights.semibold,
                        color: scheme.primary.text,
                      ),
                    ),
                  ],
                ),
                body,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SinglePhoto extends StatelessWidget {
  const _SinglePhoto({
    required this.photo,
    required this.size,
    required this.src,
    required this.radius,
    required this.inset,
    required this.label,
    required this.onTap,
    this.semanticActions,
    this.overlay,
  });

  final KunChatPhoto photo;
  final Size size;
  final String src;
  final BorderRadius radius;
  final bool inset;
  final String label;
  final VoidCallback onTap;
  final Map<CustomSemanticsAction, VoidCallback>? semanticActions;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: inset
          ? const EdgeInsets.fromLTRB(
              KunSpacing.unit,
              KunSpacing.unit,
              KunSpacing.unit,
              0,
            )
          : EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          key: KunChatBubble.photoKey(0),
          width: size.width,
          height: size.height,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              MouseRegion(
                cursor: SystemMouseCursors.zoomIn,
                child: GestureDetector(
                  onTap: onTap,
                  child: Semantics(
                    button: true,
                    label: label,
                    customSemanticsActions: semanticActions,
                    child: KunImage(
                      src: src,
                      thumbhash: photo.thumbhash,
                      aspectRatio: size.width / size.height,
                      width: photo.width.toDouble(),
                      height: photo.height.toDouble(),
                      alt: '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              if (overlay != null)
                Positioned(
                  right: KunSpacing.unit * 1.5,
                  bottom: KunSpacing.unit * 1.5,
                  child: overlay!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumMosaic extends StatelessWidget {
  const _AlbumMosaic({
    required this.photos,
    required this.layout,
    required this.width,
    required this.srcOf,
    required this.radius,
    required this.inset,
    required this.label,
    required this.onTap,
    this.semanticActions,
    this.overlay,
  });

  final List<KunChatPhoto> photos;
  final KunChatAlbumLayout layout;
  final double width;
  final String Function(KunChatPhoto photo) srcOf;
  final BorderRadius radius;
  final bool inset;
  final String label;
  final ValueChanged<int> onTap;
  final Map<CustomSemanticsAction, VoidCallback>? semanticActions;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final double height = width * layout.height / layout.width;
    return Padding(
      padding: inset
          ? const EdgeInsets.fromLTRB(
              KunSpacing.unit,
              KunSpacing.unit,
              KunSpacing.unit,
              0,
            )
          : EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: <Widget>[
              for (int i = 0; i < layout.tiles.length; i++)
                _albumTile(i, width, height),
              if (overlay != null)
                Positioned(
                  right: KunSpacing.unit * 1.5,
                  bottom: KunSpacing.unit * 1.5,
                  child: overlay!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _albumTile(int i, double mosaicW, double mosaicH) {
    final KunChatAlbumTile tile = layout.tiles[i];
    final KunChatPhoto photo = photos[i];
    final double left = tile.x / layout.width * mosaicW;
    final double top = tile.y / layout.height * mosaicH;
    final double tileW = tile.width / layout.width * mosaicW;
    final double tileH = tile.height / layout.height * mosaicH;
    return Positioned(
      left: left,
      top: top,
      width: tileW,
      height: tileH,
      child: ClipRRect(
        borderRadius: _tileCorners(tile.sides, radius),
        child: MouseRegion(
          cursor: SystemMouseCursors.zoomIn,
          child: GestureDetector(
            onTap: () => onTap(i),
            child: Semantics(
              key: KunChatBubble.photoKey(i),
              button: true,
              label: label,
              customSemanticsActions: semanticActions,
              child: KunImage(
                src: srcOf(photo),
                thumbhash: photo.thumbhash,
                width: tileW,
                height: tileH,
                alt: '',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.raw,
    required this.scheme,
    required this.hovered,
    required this.onHover,
    required this.onTap,
    required this.duration,
  });

  final KunChatContext raw;
  final KunColorScheme scheme;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final ValueChanged<String> onTap;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final String? href = kunChatSafeUrl(raw.url);
    final String host = _hostOf(href, raw.site);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KunSpacing.unit * 2,
        KunSpacing.unit * 1.5,
        KunSpacing.unit * 2,
        0,
      ),
      child: MouseRegion(
        cursor: href != null ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          onTap: href == null ? null : () => onTap(href),
          child: AnimatedContainer(
            duration: duration,
            curve: KunDefaultTransition.curve,
            padding: const EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 2.5,
              vertical: KunSpacing.unit * 1.5,
            ),
            decoration: BoxDecoration(
              color: href != null && hovered
                  ? scheme.neutral.solid.withValues(alpha: 0.1)
                  : null,
              borderRadius: BorderRadius.circular(KunRadius.sm),
              border: Border.all(
                color: scheme.neutral.solid.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      KunIcons.externalLink,
                      size: KunText.xs.fontSize,
                      color: scheme.foregroundMuted,
                    ),
                    const SizedBox(width: KunSpacing.unit),
                    Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KunText.xs.copyWith(
                        color: scheme.foregroundMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  raw.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KunText.sm.copyWith(fontWeight: KunFontWeights.medium),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.message,
    this.senderPrefix,
    this.semanticActions,
    required this.onLink,
    required this.onMention,
    required this.showCornerMeta,
    this.twin,
    this.meta,
  });

  final KunChatMessage message;
  final String? senderPrefix;
  final Map<CustomSemanticsAction, VoidCallback>? semanticActions;
  final KunChatLinkCallback? onLink;
  final KunChatUserCallback? onMention;
  final bool showCornerMeta;
  final Widget? twin;
  final Widget? meta;

  @override
  Widget build(BuildContext context) {
    // A wrapping Semantics(label) joins with the paragraph; link spans keep
    // their own nodes when the recognizer sits on the text-bearing span.
    final Widget text = _withSenderPrefix(
      senderPrefix,
      KunChatText(
        text: message.text,
        entities: message.entities,
        trailing: twin == null
            ? null
            : _TwinSeat(
                child: ExcludeSemantics(
                  child: Visibility(
                    visible: false,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: KunSpacing.unit * 2,
                      ),
                      child: twin,
                    ),
                  ),
                ),
              ),
        onLink: onLink,
        onMention: onMention,
      ),
      semanticActions: semanticActions,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KunSpacing.unit * 3,
            KunSpacing.unit * 1.5,
            KunSpacing.unit * 3,
            KunSpacing.unit * 1.5,
          ),
          child: text,
        ),
        if (showCornerMeta && meta != null)
          Positioned(
            key: KunChatBubble.metaKey,
            right: KunSpacing.unit * 2.5,
            bottom: KunSpacing.unit * 1.5,
            child: meta!,
          ),
      ],
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({
    required this.reactions,
    required this.options,
    required this.messages,
    required this.scheme,
    required this.own,
    required this.hasText,
    required this.disabled,
    required this.hovered,
    required this.onHover,
    required this.onReact,
    required this.duration,
    required this.meta,
  });

  final List<KunChatReaction> reactions;
  final List<KunChatReactionOption> options;
  final KunMessages messages;
  final KunColorScheme scheme;
  final bool own;
  final bool hasText;
  final bool disabled;
  final Set<String> hovered;
  final void Function(String key, bool value) onHover;
  final ValueChanged<KunChatReaction> onReact;
  final Duration duration;
  final Widget meta;

  KunChatReactionOption? _option(String key) {
    for (final KunChatReactionOption option in options) {
      if (option.key == key) {
        return option;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KunSpacing.unit * 2,
        hasText ? 0 : KunSpacing.unit * 1.5,
        KunSpacing.unit * 2,
        KunSpacing.unit * 1.5,
      ),
      child: Semantics(
        container: true,
        label: messages.chat.reactions,
        child: _ChipWrap(
          spacing: KunSpacing.unit,
          children: <Widget>[
            for (int i = 0; i < reactions.length; i++)
              _ReactionChip(
                reaction: reactions[i],
                option: _option(reactions[i].reaction),
                messages: messages,
                scheme: scheme,
                own: own,
                disabled: disabled,
                hovered: hovered.contains('react:${reactions[i].reaction}'),
                onHover: (bool v) =>
                    onHover('react:${reactions[i].reaction}', v),
                onTap: () => onReact(reactions[i]),
                duration: duration,
              ),
            SizedBox(
              key: KunChatBubble.metaKey,
              height: _kChipHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: KunSpacing.unit),
                child: Center(child: meta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.reaction,
    required this.option,
    required this.messages,
    required this.scheme,
    required this.own,
    required this.disabled,
    required this.hovered,
    required this.onHover,
    required this.onTap,
    required this.duration,
  });

  final KunChatReaction reaction;
  final KunChatReactionOption? option;
  final KunMessages messages;
  final KunColorScheme scheme;
  final bool own;
  final bool disabled;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final String label = option?.label ?? reaction.reaction;
    final Color background;
    final Color foreground;
    if (reaction.reacted) {
      background = scheme.primary.solid;
      foreground = scheme.primary.onSolid;
    } else if (own) {
      background = hovered ? scheme.primary.shade300 : scheme.primary.shade200;
      foreground = scheme.primary.shade700;
    } else {
      background = scheme.primary.solid.withValues(alpha: hovered ? 0.2 : 0.1);
      foreground = scheme.primary.shade700;
    }
    final Widget art = kunChatReactionArt(
      context: context,
      size: _kChipArt,
      emoji: option?.emoji ?? reaction.reaction,
      imageUrl: option?.imageUrl,
      style: KunText.base.copyWith(color: foreground),
    );

    return MouseRegion(
      cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Semantics(
          button: true,
          enabled: !disabled,
          toggled: reaction.reacted,
          label: messages.chat.reactionCount(
            label: label,
            count: reaction.count,
          ),
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: duration,
              curve: KunDefaultTransition.curve,
              height: _kChipHeight,
              padding: const EdgeInsets.symmetric(
                horizontal: KunSpacing.unit * 2,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(KunRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  art,
                  const SizedBox(width: KunSpacing.unit),
                  Text(
                    '${reaction.count}',
                    style: KunText.sm.copyWith(
                      color: foreground,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    this.edited,
    required this.time,
    this.fullTime,
    this.icon,
    this.iconLabel,
    required this.color,
    this.twin = false,
  });

  final String? edited;
  final String time;
  final String? fullTime;
  final IconData? icon;
  final String? iconLabel;
  final Color color;
  final bool twin;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: _kMetaFont,
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
      color: color,
    );
    final Widget clock = Text(time, style: style);
    return DefaultTextStyle(
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (edited != null) ...<Widget>[
            Text(edited!, style: style),
            const SizedBox(width: KunSpacing.unit),
          ],
          if (!twin && fullTime != null)
            KunTooltip(text: fullTime!, child: clock)
          else
            clock,
          if (icon != null) ...<Widget>[
            const SizedBox(width: KunSpacing.unit),
            Semantics(
              label: iconLabel,
              child: Icon(icon, size: KunText.sm.fontSize, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaMeta extends StatelessWidget {
  const _MediaMeta({
    this.edited,
    required this.time,
    required this.fullTime,
    this.icon,
    required this.scheme,
  });

  final String? edited;
  final String time;
  final String fullTime;
  final IconData? icon;
  final KunColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KunColors.black.withValues(alpha: _kMediaMetaAlpha),
          borderRadius: BorderRadius.circular(KunRadius.full),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KunSpacing.unit * 1.5,
            vertical: 1,
          ),
          child: _MetaLine(
            edited: edited,
            time: time,
            fullTime: fullTime,
            icon: icon,
            color: KunColors.white,
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    required this.label,
    required this.scheme,
    required this.onTap,
  });

  final String label;
  final KunColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: KunChatBubble.retryKey,
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: KunTooltip(
        text: label,
        child: GestureDetector(
          excludeFromSemantics: true,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.content1,
              shape: BoxShape.circle,
              boxShadow: KunShadows.sm,
            ),
            child: SizedBox(
              width: _kRetrySize,
              height: _kRetrySize,
              child: Center(
                child: Icon(
                  KunIcons.circleAlert,
                  size: KunText.base.fontSize,
                  color: scheme.danger.solid,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(_kTailStartX, _kTailHeight)
      ..lineTo(_kTailOrigin, _kTailHeight)
      ..lineTo(_kTailOrigin, _kTailOrigin)
      ..relativeCubicTo(
        _kTailC1a,
        _kTailC1b,
        _kTailC1c,
        _kTailC1d,
        _kTailC1e,
        _kTailC1f,
      )
      ..relativeCubicTo(
        _kTailC2a,
        _kTailC2b,
        _kTailC2c,
        _kTailC2d,
        _kTailC2e,
        _kTailC2f,
      )
      ..arcToPoint(
        const Offset(_kTailStartX, _kTailHeight),
        radius: const Radius.circular(_kTailArc),
        largeArc: false,
        clockwise: true,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TwinSeat extends SingleChildRenderObjectWidget {
  const _TwinSeat({required super.child});

  @override
  RenderBox createRenderObject(BuildContext context) => _RenderTwinSeat();
}

class _RenderTwinSeat extends RenderProxyBox {
  static const BoxConstraints _unbounded = BoxConstraints();

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_unbounded, parentUsesSize: true);
    size = child.size;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return child?.getDryLayout(_unbounded) ?? constraints.smallest;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return child?.getMaxIntrinsicWidth(double.infinity) ?? 0;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return child?.getMinIntrinsicWidth(double.infinity) ?? 0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return child?.getMaxIntrinsicHeight(double.infinity) ?? 0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return child?.getMinIntrinsicHeight(double.infinity) ?? 0;
  }
}

class _WFitParentData extends ContainerBoxParentData<RenderBox> {}

class _WFitColumn extends MultiChildRenderObjectWidget {
  const _WFitColumn({required this.cap, required super.children});

  final double cap;

  @override
  RenderBox createRenderObject(BuildContext context) {
    return _RenderWFitColumn(cap: cap);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderWFitColumn renderObject,
  ) {
    renderObject.cap = cap;
  }
}

class _RenderWFitColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _WFitParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _WFitParentData> {
  _RenderWFitColumn({required double cap}) : _cap = cap;

  double _cap;
  double get cap => _cap;
  set cap(double value) {
    if (_cap == value) {
      return;
    }
    _cap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _WFitParentData) {
      child.parentData = _WFitParentData();
    }
  }

  double _capped(double width) {
    return width.isFinite ? math.min(width, _cap) : _cap;
  }

  static double _finiteMax(double width, double candidate) {
    return candidate.isFinite ? math.max(width, candidate) : width;
  }

  Size _layout({
    required BoxConstraints constraints,
    required ChildLayouter layouter,
    required bool position,
  }) {
    final List<RenderBox> children = <RenderBox>[];
    RenderBox? child = firstChild;
    while (child != null) {
      children.add(child);
      child = childAfter(child);
    }
    final double maxW = _capped(constraints.maxWidth);
    final BoxConstraints loose = BoxConstraints(maxWidth: maxW);
    double width = 0;
    for (final RenderBox child in children) {
      width = _finiteMax(width, layouter(child, loose).width);
      width = _finiteMax(width, child.getMaxIntrinsicWidth(double.infinity));
    }
    width = constraints.constrainWidth(math.min(width, maxW));
    final BoxConstraints tight = BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: constraints.maxHeight,
    );
    double y = 0;
    for (final RenderBox child in children) {
      final Size laidOut = layouter(child, tight);
      if (position) {
        (child.parentData! as _WFitParentData).offset = Offset(0, y);
      }
      y += laidOut.height;
    }
    return constraints.constrain(Size(width, y));
  }

  @override
  void performLayout() {
    size = _layout(
      constraints: constraints,
      layouter: ChildLayoutHelper.layoutChild,
      position: true,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _layout(
      constraints: constraints,
      layouter: ChildLayoutHelper.dryLayoutChild,
      position: false,
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return computeMaxIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    double width = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      width = _finiteMax(width, child.getMaxIntrinsicWidth(height));
      child = childAfter(child);
    }
    return math.min(width, _cap);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return computeMaxIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final double w = _capped(width);
    double height = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      height += child.getMaxIntrinsicHeight(w);
      child = childAfter(child);
    }
    return height;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToFirstActualBaseline(baseline);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}

class _ChipWrapParentData extends ContainerBoxParentData<RenderBox> {}

class _ChipWrap extends MultiChildRenderObjectWidget {
  const _ChipWrap({required this.spacing, required super.children});

  final double spacing;

  @override
  RenderBox createRenderObject(BuildContext context) {
    return _RenderChipWrap(spacing: spacing);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderChipWrap renderObject,
  ) {
    renderObject.spacing = spacing;
  }
}

class _RenderChipWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ChipWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ChipWrapParentData> {
  _RenderChipWrap({required double spacing}) : _spacing = spacing;

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) {
      return;
    }
    _spacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ChipWrapParentData) {
      child.parentData = _ChipWrapParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    double width = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      width = math.max(width, child.getMinIntrinsicWidth(height));
      child = childAfter(child);
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    double sum = 0;
    int n = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      sum += child.getMaxIntrinsicWidth(height);
      n++;
      child = childAfter(child);
    }
    return n == 0 ? 0 : sum + spacing * (n - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return computeMaxIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return getDryLayout(BoxConstraints(maxWidth: width)).height;
  }

  Size _layout({
    required BoxConstraints constraints,
    required ChildLayouter layouter,
    required bool position,
  }) {
    final List<RenderBox> children = <RenderBox>[];
    final List<Size> sizes = <Size>[];
    RenderBox? child = firstChild;
    while (child != null) {
      children.add(child);
      sizes.add(layouter(child, const BoxConstraints()));
      child = childAfter(child);
    }
    if (children.isEmpty) {
      return constraints.smallest;
    }
    final bool tight = constraints.hasTightWidth;
    final double maxW =
        constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;
    final int last = children.length - 1;
    double x = 0;
    double y = 0;
    double rowH = 0;
    double contentW = 0;

    void wrapRow() {
      y += rowH + spacing;
      x = 0;
      rowH = 0;
    }

    bool overflows(double childWidth) {
      return x > 0 && maxW.isFinite && x + spacing + childWidth > maxW;
    }

    void place(int i, double dx) {
      final Size sz = sizes[i];
      if (position) {
        final double dy = (math.max(rowH, sz.height) - sz.height) / 2;
        (children[i].parentData! as _ChipWrapParentData).offset = Offset(
          dx,
          y + dy,
        );
      }
      x = dx + sz.width;
      rowH = math.max(rowH, sz.height);
      contentW = math.max(contentW, x);
    }

    for (int i = 0; i < last; i++) {
      if (overflows(sizes[i].width)) {
        wrapRow();
      }
      place(i, x > 0 ? x + spacing : 0);
    }

    final Size meta = sizes[last];
    if (overflows(meta.width)) {
      wrapRow();
    }
    final double start = x > 0 ? x + spacing : 0;
    place(last, tight ? math.max(start, maxW - meta.width) : start);
    return constraints.constrain(Size(tight ? maxW : contentW, y + rowH));
  }

  @override
  void performLayout() {
    size = _layout(
      constraints: constraints,
      layouter: ChildLayoutHelper.layoutChild,
      position: true,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _layout(
      constraints: constraints,
      layouter: ChildLayoutHelper.dryLayoutChild,
      position: false,
    );
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}
