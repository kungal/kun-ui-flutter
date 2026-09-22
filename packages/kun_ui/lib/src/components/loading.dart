import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'spinner.dart';

/// A loading state, either over the content it is loading or on its own.
///
/// With a [child] it is a veil: the content dims and the loader sits over it
/// while [loading] holds, so the page does not jump. Without one it is the
/// loader alone, and [loading] is not consulted — a standalone loader is
/// there because something is loading.
///
/// [spinner] swaps the mascot for a compact ring, for a loading state beside
/// a button or in a table cell.
class KunLoading extends StatelessWidget {
  /// Creates a loading state.
  const KunLoading({
    this.child,
    this.loading = false,
    this.spinner = false,
    this.size = KunUISize.md,
    this.description,
    this.image = KunImages.loadingImage,
    super.key,
  });

  /// The content being loaded. It stays in place, dimmed, under the loader.
  final Widget? child;

  /// Whether the veil is up. Ignored without a [child].
  final bool loading;

  /// Whether to draw a compact ring instead of the mascot.
  final bool spinner;

  /// The ring's size. [spinner] only; the mascot has one size.
  final KunUISize size;

  /// The line under the loader; defaults to the locale's.
  final String? description;

  /// The mascot (web `src`). Defaults to the bundled
  /// [KunImages.loadingImage], which costs no network request.
  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunMessages messages = KunMessagesScope.of(context);
    final String text = description ?? messages.loading.description;
    final bool veiled = child != null;

    final Widget loader = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: KunSpacing.unit * 3,
      children: <Widget>[
        if (spinner)
          KunSpinner(size: _ringSize, color: scheme.primary.solid)
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(KunRadius.md),
            child: Image(
              image: image,
              width: _kMascotWidth,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: spinner
              ? KunText.sm.copyWith(color: scheme.neutral.shade600)
              : _mascotTextStyle(scheme, veiled: veiled),
        ),
      ],
    );

    // The web's `role="status"` with `aria-live="polite"`. Flutter asserts a
    // node cannot be both a status and a live region, because its status role
    // already is one — as the ARIA role is, which defines `aria-live: polite`
    // implicitly. One node, naming itself, so neither the mascot nor the ring
    // becomes a node of its own.
    final Widget announced = Semantics(
      container: true,
      role: SemanticsRole.status,
      label: text,
      child: ExcludeSemantics(child: loader),
    );

    if (!veiled) {
      return Center(child: announced);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kVeilMinHeight),
      child: Stack(
        children: <Widget>[
          AnimatedOpacity(
            duration: kunMotion(context, KunDurations.slow),
            opacity: loading ? 0.5 : 1,
            child: child,
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !loading,
              child: AnimatedOpacity(
                duration: kunMotion(context, KunDurations.slow),
                opacity: loading ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // Web `bg-background/50`: the token is stored opaque and
                    // the web paints it at the global opacity, which the
                    // modifier then halves.
                    color: scheme.background.withValues(
                      alpha: KunColors.globalOpacity * 0.5,
                    ),
                    borderRadius: BorderRadius.circular(KunRadius.md),
                  ),
                  // The mascot is 320 wide and the veil is only as tall as
                  // the content under it, which may be less: the web spills
                  // out of the overlay and CSS says nothing, while a Flutter
                  // Column reports the overflow. scaleDown is a no-op when
                  // there is room and shrinks the whole loader when there is
                  // not, so nothing is ever cut off.
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: announced,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _ringSize => switch (size) {
        KunUISize.xs => KunSpacing.unit * 4,
        KunUISize.sm => KunSpacing.unit * 6,
        KunUISize.md => KunSpacing.unit * 8,
        KunUISize.lg => KunSpacing.unit * 10,
        KunUISize.xl => KunSpacing.unit * 12,
      };

  /// The web's `.info`: white text outlined by five 1px shadows in the
  /// foreground colour, so the line stays legible over the mascot whatever
  /// the image behind it is. It grows to `text-xl` over content.
  TextStyle _mascotTextStyle(KunColorScheme scheme, {required bool veiled}) {
    const List<Offset> offsets = <Offset>[
      Offset(0, 1),
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, -1),
      Offset(1, 2),
    ];
    return (veiled ? KunText.xl : KunText.base).copyWith(
      color: KunColors.white,
      shadows: <Shadow>[
        for (final Offset offset in offsets)
          Shadow(offset: offset, color: scheme.foreground),
      ],
    );
  }
}

/// The web's `w-80` on the mascot.
const double _kMascotWidth = KunSpacing.unit * 80;

/// The web's `min-h-24` on a veiled block.
const double _kVeilMinHeight = KunSpacing.unit * 24;
