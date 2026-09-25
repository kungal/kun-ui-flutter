import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/design.dart';
import '../foundation/focus_outline.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'pulse.dart';

/// A frame asset on a square canvas 1.2× the avatar, the avatar circle
/// centred in it. [src] is the still image; [animatedSrc], when present,
/// is played on hover or always, depending on [KunAvatar.decoration].
@immutable
class KunAvatarDecoration {
  /// Creates a frame asset.
  const KunAvatarDecoration({required this.src, this.animatedSrc});

  /// The still frame image URL.
  final String src;

  /// The animated frame image URL, when there is one.
  final String? animatedSrc;

  @override
  bool operator ==(Object other) =>
      other is KunAvatarDecoration &&
      other.src == src &&
      other.animatedSrc == animatedSrc;

  @override
  int get hashCode => Object.hash(src, animatedSrc);
}

/// Web type `KunUser`.
@immutable
class KunUser {
  /// Creates a user brief.
  const KunUser({
    required this.id,
    required this.name,
    this.avatar = '',
    this.avatarDecoration,
  });

  /// The user's id, used to build the profile path.
  ///
  /// `0` means there is no profile to link to — an unknown or deleted author,
  /// a signed-out viewer. [KunAvatar] and [KunUserChip] render it without a
  /// link.
  final int id;

  /// The display name. Empty is treated as missing in [KunUserChip], and
  /// as an empty `alt` on [KunAvatar].
  final String name;

  /// An image URL. Empty means none, so a pool pick or the bundled
  /// fallback is used.
  final String avatar;

  /// An avatar frame drawn around the avatar (NextMoe
  /// `cosmetics.avatar_frame`). Absent or null → no frame.
  final KunAvatarDecoration? avatarDecoration;

  @override
  bool operator ==(Object other) =>
      other is KunUser &&
      other.id == id &&
      other.name == name &&
      other.avatar == avatar &&
      other.avatarDecoration == avatarDecoration;

  @override
  int get hashCode => Object.hash(id, name, avatar, avatarDecoration);
}

/// Web type `KunAvatarSize`: the shared scale plus the two profile sizes
/// (`original-sm` → [originalSm]).
enum KunAvatarSize {
  /// Web `xs` — `size-4`.
  xs,

  /// Web `sm` — `size-6`.
  sm,

  /// Web `md` — `size-8`, the default.
  md,

  /// Web `lg` — `size-10`.
  lg,

  /// Web `xl` — `size-12`.
  xl,

  /// Web `original-sm` — `size-24`.
  originalSm,

  /// Web `original` — `size-40`.
  original,
}

/// How [KunUser.avatarDecoration] is drawn.
enum KunAvatarDecorationMode {
  /// Shows the still frame and plays the animated one while the avatar is
  /// hovered or focused.
  hover,

  /// Plays the animated asset continuously.
  always,

  /// Never animates.
  static,

  /// Hides the frame.
  none,
}

bool _warnedEmptyAvatarPool = false;

/// Clears the empty-pool warning so a test can see it fire again.
@visibleForTesting
void debugResetKunAvatarWarning() {
  _warnedEmptyAvatarPool = false;
}

/// A user's picture, implementing the web `KunAvatar` contract.
///
/// When [isNavigation] is true (the default) and [user] is non-null with a
/// [KunUser.id] that is not 0, a tap opens the profile through
/// [KunUIConfigScope]. A null [user], or a user whose id is 0, always shows
/// the picture and is never a link.
class KunAvatar extends StatefulWidget {
  /// Creates an avatar.
  const KunAvatar({
    super.key,
    required this.user,
    this.size = KunAvatarSize.md,
    this.isNavigation = true,
    this.decoration = KunAvatarDecorationMode.hover,
  });

  /// Null: the fallback picture, never a link.
  final KunUser? user;

  /// The rendered square.
  final KunAvatarSize size;

  /// When true (the default) and [user] is non-null with a [KunUser.id] that
  /// is not 0, the avatar is a real link to the user's profile.
  final bool isNavigation;

  /// How `user.avatarDecoration` is drawn. [KunAvatarDecorationMode.hover]
  /// (default) shows the still frame and plays the animated one while the
  /// avatar is hovered or focused; [KunAvatarDecorationMode.always] plays it
  /// continuously; [KunAvatarDecorationMode.static] never animates;
  /// [KunAvatarDecorationMode.none] hides the frame. Below the `md` size
  /// the frame is never drawn, and a reader who asked for reduced motion
  /// always gets the still image.
  final KunAvatarDecorationMode decoration;

  @override
  State<KunAvatar> createState() => _KunAvatarState();
}

class _KunAvatarState extends State<KunAvatar> {
  bool _failed = false;
  bool _hovered = false;
  bool _focused = false;
  bool _fallbackScheduled = false;

  bool get _isLink =>
      widget.isNavigation && widget.user != null && widget.user!.id != 0;

  double get _side =>
      KunSpacing.unit *
      switch (widget.size) {
        KunAvatarSize.xs => 4,
        KunAvatarSize.sm => 6,
        KunAvatarSize.md => 8,
        KunAvatarSize.lg => 10,
        KunAvatarSize.xl => 12,
        KunAvatarSize.originalSm => 24,
        KunAvatarSize.original => 40,
      };

  @override
  void didUpdateWidget(KunAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.avatar != widget.user?.avatar) {
      _failed = false;
      _fallbackScheduled = false;
    }
  }

  ImageProvider _provider(KunUIConfig config) {
    if (_failed) {
      return KunImages.avatarFallback;
    }
    final String? avatar = widget.user?.avatar;
    if (avatar != null && avatar.isNotEmpty) {
      return config.imageProvider(avatar);
    }
    final String? picked = kunPickAvatarFallback(
      widget.user?.name ?? '',
      config.avatarFallbackPool,
    );
    if (picked == null) {
      return KunImages.avatarFallback;
    }
    return config.imageProvider(picked);
  }

  void _warnEmptyPool(KunUIConfig config) {
    assert(() {
      if (widget.user == null) {
        return true;
      }
      if (widget.user!.avatar.isNotEmpty) {
        return true;
      }
      if (config.avatarFallbackPool.isNotEmpty) {
        return true;
      }
      if (_warnedEmptyAvatarPool) {
        return true;
      }
      _warnedEmptyAvatarPool = true;
      debugPrint(
        '[KunAvatar] rendering the fallback avatar for a user with no '
        '`avatar` image, but `avatarFallbackPool` is empty — so EVERY such '
        'user gets the same bundled image. Configure a pool of absolute '
        'image URLs: `KunUIConfigScope(config: KunUIConfig('
        'avatarFallbackPool: …))`. See "Navigation, avatars and images" '
        'in kun_ui\'s docs/INTEGRATION.md.',
      );
      return true;
    }());
  }

  void _open() {
    final KunUser? user = widget.user;
    if (!_isLink || user == null) {
      return;
    }
    final KunUIConfig config = KunUIConfigScope.of(context);
    config.navigateTo(context, config.userLinkFor(user.id));
  }

  Widget _loadingLayer(Color color) {
    return ExcludeSemantics(
      child: KunPulseLayer(
        child: ColoredBox(color: color),
      ),
    );
  }

  String? _frameUrl(BuildContext context) {
    final KunAvatarDecoration? decoration = widget.user?.avatarDecoration;
    if (decoration == null ||
        decoration.src.isEmpty ||
        widget.decoration == KunAvatarDecorationMode.none ||
        widget.size == KunAvatarSize.xs ||
        widget.size == KunAvatarSize.sm) {
      return null;
    }
    if (kunReducedMotion(context)) {
      return decoration.src;
    }
    final String? animated = decoration.animatedSrc;
    final bool hasAnimated = animated != null && animated.isNotEmpty;
    switch (widget.decoration) {
      case KunAvatarDecorationMode.always:
        return hasAnimated ? animated : decoration.src;
      case KunAvatarDecorationMode.hover:
        if (hasAnimated && (_hovered || _focused)) {
          return animated;
        }
        return decoration.src;
      case KunAvatarDecorationMode.static:
        return decoration.src;
      case KunAvatarDecorationMode.none:
        return null;
    }
  }

  bool _tracksDecorationHover() {
    final KunAvatarDecoration? decoration = widget.user?.avatarDecoration;
    return widget.decoration == KunAvatarDecorationMode.hover &&
        decoration != null &&
        decoration.src.isNotEmpty &&
        decoration.animatedSrc != null &&
        decoration.animatedSrc!.isNotEmpty &&
        widget.size != KunAvatarSize.xs &&
        widget.size != KunAvatarSize.sm;
  }

  @override
  Widget build(BuildContext context) {
    final KunUIConfig config = KunUIConfigScope.of(context);
    _warnEmptyPool(config);

    final ImageProvider provider = _provider(config);
    final Color loadingColor = KunTheme.of(context).colors.neutral.shade200;
    final String? pictureLabel = widget.user == null
        ? KunMessagesScope.of(context).avatar.unknownUser
        : (widget.user!.name.isEmpty ? null : widget.user!.name);
    final double side = _side;
    final String? frameUrl = _frameUrl(context);

    Widget picture = Image(
      // By value: an app's imageProvider returns a new provider per call,
      // and an identity key remounted the picture on every hover.
      key: ValueKey<ImageProvider>(provider),
      image: provider,
      width: side,
      height: side,
      fit: BoxFit.cover,
      excludeFromSemantics: _isLink || pictureLabel == null,
      semanticLabel: _isLink ? null : pictureLabel,
      frameBuilder: (
        BuildContext context,
        Widget child,
        int? frame,
        bool wasSynchronouslyLoaded,
      ) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        final bool loaded = frame != null;
        final bool reduce = kunReducedMotion(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              opacity: loaded ? 1 : 0,
              duration: kunMotion(context, KunDurations.slow),
              curve: KunDefaultTransition.curve,
              child: child,
            ),
            // The placeholder stays opaque for slow after the first frame,
            // then fades — dropping it in the same frame the picture starts
            // to fade in left the fade playing over the bare page
            // (kun-ui 2.45.0).
            if (!(loaded && reduce))
              _KunAvatarPlaceholder(
                loaded: loaded,
                color: loadingColor,
              ),
          ],
        );
      },
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        if (!_failed &&
            !_fallbackScheduled &&
            provider != KunImages.avatarFallback) {
          _fallbackScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_failed) {
              setState(() {
                _failed = true;
                _fallbackScheduled = false;
              });
            }
          });
        }
        return _loadingLayer(loadingColor);
      },
    );

    Widget body = SizedBox.square(
      dimension: side,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(child: picture),
          if (frameUrl != null)
            Positioned(
              left: side * -0.1,
              top: side * -0.1,
              width: side * 1.2,
              height: side * 1.2,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Image(
                    image: config.imageProvider(frameUrl),
                    width: side * 1.2,
                    height: side * 1.2,
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!_isLink) {
      if (_tracksDecorationHover()) {
        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: body,
        );
      }
      return body;
    }

    return Semantics(
      container: true,
      link: true,
      label: pictureLabel,
      onTap: _open,
      excludeSemantics: true,
      child: FocusableActionDetector(
        onShowFocusHighlight: (bool value) => setState(() => _focused = value),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _open();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              _open();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            child: AnimatedScale(
              scale: _hovered ? 1.1 : 1,
              duration: kunMotion(context, KunDurations.fast),
              curve: KunEasing.standard,
              child: KunFocusOutline(
                visible: _focused,
                color: KunUIColor.primary
                    .scaleOf(KunTheme.of(context).colors)
                    .solid
                    .withValues(alpha: 0.5),
                circle: true,
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KunAvatarPlaceholder extends StatelessWidget {
  const _KunAvatarPlaceholder({
    required this.loaded,
    required this.color,
  });

  final bool loaded;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedOpacity(
        key: const ValueKey<String>('kunAvatarPlaceholder'),
        opacity: loaded ? 0 : 1,
        duration: kunMotion(context, KunDurations.slow) * (loaded ? 2 : 1),
        curve: loaded
            ? const Interval(0.5, 1.0, curve: KunDefaultTransition.curve)
            : KunDefaultTransition.curve,
        child: loaded
            ? ColoredBox(color: color)
            : KunPulseLayer(child: ColoredBox(color: color)),
      ),
    );
  }
}
