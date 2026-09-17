import 'package:flutter/widgets.dart';

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
