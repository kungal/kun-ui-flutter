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

/// Web type `KunUser`.
@immutable
class KunUser {
  /// Creates a user brief.
  const KunUser({required this.id, required this.name, this.avatar = ''});

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

  @override
  bool operator ==(Object other) =>
      other is KunUser &&
      other.id == id &&
      other.name == name &&
      other.avatar == avatar;

  @override
  int get hashCode => Object.hash(id, name, avatar);
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
  });

  /// Null: the fallback picture, never a link.
  final KunUser? user;

  /// The rendered square.
  final KunAvatarSize size;

  /// When true (the default) and [user] is non-null with a [KunUser.id] that
  /// is not 0, the avatar is a real link to the user's profile.
  final bool isNavigation;

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
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              opacity: frame != null ? 1 : 0,
              duration: kunMotion(context, KunDurations.slow),
              curve: KunDefaultTransition.curve,
              child: child,
            ),
            if (frame == null) _loadingLayer(loadingColor),
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
      child: ClipOval(child: picture),
    );

    if (!_isLink) {
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
