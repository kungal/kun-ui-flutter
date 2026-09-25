import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/design.dart';
import 'button.dart';

/// One destination of an app shell's navigation, implementing the web
/// `KunNavItem` contract.
///
/// A full-width [KunButton]: [KunUIVariant.flat] in [color] when [current],
/// [KunUIVariant.light] and [KunUIColor.neutral] otherwise. KunUI does not
/// read the route; the app decides which item is [current]. The containers
/// — a rail, a sidebar, a bottom bar — are the app's.
class KunNavItem extends StatelessWidget {
  /// Creates a navigation item.
  const KunNavItem({
    super.key,
    required this.label,
    this.icon,
    this.href,
    this.onPressed,
    this.current = false,
    this.stacked = false,
    this.color = KunUIColor.primary,
    this.disabled = false,
  });

  /// The destination's name, shown under or beside the icon.
  final String label;

  /// The destination's icon (web `icon` prop and `#icon` slot).
  ///
  /// A bare [Icon] without its own size takes 20px when [stacked] and 16px
  /// otherwise. Wrap it in a [KunBadge] to show an unread count.
  final Widget? icon;

  /// Where the item goes. A non-empty value is handed to
  /// [KunUIConfig.navigate] through [KunUIConfigScope]. Without it the
  /// item is a button and [onPressed] is the action.
  final String? href;

  /// Called on a press (web event `click`), before navigation when [href]
  /// is non-empty.
  ///
  /// A null callback does not gray the item out; [disabled] does.
  final VoidCallback? onPressed;

  /// Marks the page the user is on: the item turns `flat` in [color], and
  /// says so to assistive technology (`selected`, the web's
  /// `aria-current="page"`). KunUI does not read the route; the app
  /// decides which item is current.
  final bool current;

  /// Icon over label, as a rail or a bottom bar draws a destination. Off,
  /// the icon sits beside the label, as a sidebar row draws it.
  final bool stacked;

  /// Colour of the current item. Every other item stays neutral.
  final KunUIColor color;

  /// Blocks clicks and navigation and dims the item.
  final bool disabled;

  void _handlePressed(BuildContext context) {
    onPressed?.call();
    final String? href = this.href;
    if (href != null && href.isNotEmpty) {
      KunUIConfigScope.of(context).navigateTo(context, href);
    }
  }

  Widget? _themedIcon(double size) {
    final Widget? icon = this.icon;
    if (icon == null) {
      return null;
    }
    return _NavItemIcon(size: size, child: icon);
  }

  Widget _stackedBody() {
    final Widget? leading = _themedIcon(KunSpacing.unit * 5);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit,
      children: [
        if (leading != null) leading,
        DefaultTextStyle.merge(
          style: KunText.xs,
          child: Text(label),
        ),
      ],
    );
  }

  Widget _inlineBody() {
    final Widget? leading = _themedIcon(KunSpacing.unit * 4);
    // KunButton centres its content, so the web's justify-start is a
    // full-width child whose Row starts at the button's padding.
    return SizedBox(
      width: double.infinity,
      child: Row(
        spacing: KunSpacing.unit * 2,
        children: [
          if (leading != null) leading,
          Flexible(child: Text(label)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        selected: current ? true : null,
        child: KunButton(
          fullWidth: true,
          variant: current ? KunUIVariant.flat : KunUIVariant.light,
          color: current ? color : KunUIColor.neutral,
          disabled: disabled,
          onPressed: () => _handlePressed(context),
          child: stacked ? _stackedBody() : _inlineBody(),
        ),
      ),
    );
  }
}

class _NavItemIcon extends StatelessWidget {
  const _NavItemIcon({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IconTheme.merge(
      data: IconThemeData(
        size: size,
        color: DefaultTextStyle.of(context).style.color,
      ),
      child: child,
    );
  }
}
