import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

/// Whether the platform asks for reduced motion.
///
/// kun-ui's base stylesheet collapses every CSS transition and animation
/// under `prefers-reduced-motion: reduce`; [MediaQuery.disableAnimationsOf]
/// carries the same setting here.
bool kunReducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// [duration], or [Duration.zero] under [kunReducedMotion].
///
/// Every KunUI transition runs its duration through this. `KunSpinner` does
/// not: the web spinner turns by SMIL, which the stylesheet rule does not
/// reach.
Duration kunMotion(BuildContext context, Duration duration) =>
    kunReducedMotion(context) ? Duration.zero : duration;

/// [parent] eased the way a KunUI surface enters and leaves: the web's
/// `ease-kun-out` while it runs forward and `ease-kun-in` while it reverses.
///
/// [CurvedAnimation] applies `reverseCurve` to the reversing value as is, so
/// an unflipped `ease-kun-in` decelerates out. Every popup passed it that
/// way until 0.31.1. Flipped, it accelerates out like the web's leave
/// transition. The caller disposes the result.
CurvedAnimation kunSurfaceCurve(Animation<double> parent) => CurvedAnimation(
      parent: parent,
      curve: KunEasing.enter,
      reverseCurve: KunEasing.exit.flipped,
    );
